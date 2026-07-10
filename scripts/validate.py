#!/usr/bin/env python3
"""Validate litepowers manifests, Skill metadata, references, and fixtures."""

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

import yaml
from yaml.constructor import ConstructorError
from yaml.resolver import BaseResolver

ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = ROOT / "skills"
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FRONTMATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
README_SKILL_RE = re.compile(r"^\| `([a-z0-9-]+)` \|", re.MULTILINE)


class UniqueKeyLoader(yaml.SafeLoader):
    """Safe YAML loader that rejects duplicate mapping keys."""


def construct_unique_mapping(loader, node, deep=False):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ConstructorError(
                "while constructing a mapping",
                node.start_mark,
                f"found duplicate key {key!r}",
                key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(BaseResolver.DEFAULT_MAPPING_TAG, construct_unique_mapping)


def fail(errors, message):
    errors.append(message)


def load_json(path, errors):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(errors, f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        return None


def load_yaml(text, source, errors):
    try:
        return yaml.load(text, Loader=UniqueKeyLoader)
    except yaml.YAMLError as exc:
        fail(errors, f"{source}: invalid YAML: {exc}")
        return None


def parse_frontmatter(path, errors):
    text = path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        fail(errors, f"{path.relative_to(ROOT)}: missing YAML frontmatter")
        return None
    metadata = load_yaml(match.group(1), path.relative_to(ROOT), errors)
    if metadata is None:
        return None
    if not isinstance(metadata, dict):
        fail(errors, f"{path.relative_to(ROOT)}: frontmatter must be a mapping")
        return None
    allowed = {
        "name", "description", "license", "compatibility", "metadata", "allowed-tools",
        "when_to_use", "argument-hint", "arguments", "disable-model-invocation", "user-invocable",
        "disallowed-tools", "model", "effort", "context", "agent", "hooks", "paths", "shell",
    }
    unknown = set(metadata) - allowed
    if unknown:
        fail(errors, f"{path.relative_to(ROOT)}: unsupported frontmatter keys {sorted(unknown)}")
    license_value = metadata.get("license")
    if license_value is not None and (not isinstance(license_value, str) or not license_value.strip()):
        fail(errors, f"{path.relative_to(ROOT)}: license must be a non-empty string")
    compatibility = metadata.get("compatibility")
    if compatibility is not None and (
        not isinstance(compatibility, str) or not compatibility.strip() or len(compatibility) > 500
    ):
        fail(errors, f"{path.relative_to(ROOT)}: compatibility must be a non-empty string up to 500 characters")
    metadata_value = metadata.get("metadata")
    if metadata_value is not None and (
        not isinstance(metadata_value, dict)
        or any(not isinstance(key, str) or not isinstance(value, str) for key, value in metadata_value.items())
    ):
        fail(errors, f"{path.relative_to(ROOT)}: metadata must map strings to strings")
    tool_fields = ("allowed-tools", "disallowed-tools")
    for field in tool_fields:
        value = metadata.get(field)
        if value is not None and not (
            isinstance(value, str) and value.strip()
            or isinstance(value, list) and value and all(isinstance(item, str) and item.strip() for item in value)
        ):
            fail(errors, f"{path.relative_to(ROOT)}: {field} must be a non-empty string or list of strings")
    for field in ("disable-model-invocation", "user-invocable"):
        value = metadata.get(field)
        if value is not None and not isinstance(value, bool):
            fail(errors, f"{path.relative_to(ROOT)}: {field} must be boolean")
    for field in ("when_to_use", "argument-hint", "model", "effort", "context", "agent", "shell"):
        value = metadata.get(field)
        if value is not None and (not isinstance(value, str) or not value.strip()):
            fail(errors, f"{path.relative_to(ROOT)}: {field} must be a non-empty string")
    for field in ("arguments", "paths"):
        value = metadata.get(field)
        if value is not None and not (
            isinstance(value, str) and value.strip()
            or isinstance(value, list) and all(isinstance(item, str) and item.strip() for item in value)
        ):
            fail(errors, f"{path.relative_to(ROOT)}: {field} must be a string or list of strings")
    if metadata.get("context") not in (None, "fork"):
        fail(errors, f"{path.relative_to(ROOT)}: context currently supports only 'fork'")
    if metadata.get("shell") not in (None, "bash", "powershell"):
        fail(errors, f"{path.relative_to(ROOT)}: shell must be bash or powershell")
    hooks = metadata.get("hooks")
    if hooks is not None and not isinstance(hooks, dict):
        fail(errors, f"{path.relative_to(ROOT)}: hooks must be a mapping")
    return metadata, text[match.end() :]


def validate_skills(errors):
    skill_files = sorted(SKILLS_DIR.glob("*/SKILL.md"))
    if not skill_files:
        fail(errors, "skills/: no SKILL.md files found")
        return set()

    names = set()
    bodies = []
    for path in skill_files:
        parsed = parse_frontmatter(path, errors)
        if parsed is None:
            continue
        metadata, body = parsed
        name = metadata.get("name", "")
        description = metadata.get("description", "")

        if not isinstance(name, str) or not NAME_RE.fullmatch(name):
            fail(errors, f"{path.relative_to(ROOT)}: invalid name {name!r}")
            continue
        if name != path.parent.name:
            fail(errors, f"{path.relative_to(ROOT)}: name must equal directory {path.parent.name!r}")
        if name in names:
            fail(errors, f"{path.relative_to(ROOT)}: duplicate skill name {name!r}")
        names.add(name)

        if not isinstance(description, str) or not description.strip():
            fail(errors, f"{path.relative_to(ROOT)}: description must be a non-empty string")
        elif len(description) > 1024:
            fail(errors, f"{path.relative_to(ROOT)}: description exceeds 1024 characters")
        elif "Use " not in description:
            fail(errors, f"{path.relative_to(ROOT)}: description must state when to use the skill")
        bodies.append((path, body))

    # Explicit `skill:<name>` markers make references distinguishable from ordinary
    # backticked identifiers and keep renamed/deleted references deterministic.
    explicit_re = re.compile(r"`skill:([a-z0-9]+(?:-[a-z0-9]+)*)`")
    for path, body in bodies:
        for reference in explicit_re.findall(body):
            if reference not in names:
                fail(errors, f"{path.relative_to(ROOT)}: unknown Skill reference `skill:{reference}`")

    return names


def markdown_anchors(text):
    anchors = set()
    counts = {}
    for heading in re.findall(r"^#{1,6}\s+(.+?)\s*#*\s*$", text, re.MULTILINE):
        slug = heading.strip().lower()
        slug = re.sub(r"[^\w\-\s一-鿿]", "", slug)
        slug = re.sub(r"\s+", "-", slug).strip("-")
        if not slug:
            continue
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        anchors.add(slug if count == 0 else f"{slug}-{count}")
    return anchors


def validate_local_links(path, errors):
    text = path.read_text(encoding="utf-8")
    for raw_target in re.findall(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", text):
        raw_target = raw_target.strip()
        target, separator, fragment = raw_target.partition("#")
        fragment = unquote(fragment)
        if re.match(r"^[a-z][a-z0-9+.-]*://", target, re.IGNORECASE) or target.startswith("mailto:"):
            continue
        resolved = (path.parent / target).resolve() if target else path.resolve()
        try:
            resolved.relative_to(ROOT)
        except ValueError:
            fail(errors, f"{path.relative_to(ROOT)}: local link escapes repository: {raw_target}")
            continue
        if not resolved.exists():
            fail(errors, f"{path.relative_to(ROOT)}: broken local link: {raw_target}")
            continue
        if separator and fragment and resolved.is_file() and resolved.suffix.lower() == ".md":
            anchors = markdown_anchors(resolved.read_text(encoding="utf-8"))
            if fragment.lower() not in anchors:
                fail(errors, f"{path.relative_to(ROOT)}: broken Markdown anchor: {raw_target}")


def validate_readme(names, errors):
    readme_path = ROOT / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    table_section = readme.split("## Skills", 1)
    if len(table_section) != 2:
        fail(errors, "README.md: missing Skills section")
        return
    listed = set(README_SKILL_RE.findall(table_section[1].split("## ", 1)[0]))
    if listed != names:
        fail(errors, f"README.md: Skill table mismatch; missing={sorted(names - listed)}, extra={sorted(listed - names)}")
    for path in [readme_path, ROOT / "OPTIMIZATION-PLAN.md", *sorted(SKILLS_DIR.glob("*/SKILL.md"))]:
        if path.exists():
            validate_local_links(path, errors)


def validate_manifests(errors):
    plugin = load_json(ROOT / ".claude-plugin/plugin.json", errors)
    marketplace = load_json(ROOT / ".claude-plugin/marketplace.json", errors)
    if isinstance(plugin, dict):
        version = plugin.get("version")
        if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+", version):
            fail(errors, ".claude-plugin/plugin.json: version must be semantic X.Y.Z")
    if isinstance(marketplace, dict):
        plugins = marketplace.get("plugins")
        if not isinstance(plugins, list) or not any(
            isinstance(item, dict) and item.get("name") == "litepowers" and item.get("source") == "./"
            for item in plugins
        ):
            fail(errors, ".claude-plugin/marketplace.json: missing local litepowers plugin entry")


def validate_workflow(errors):
    path = ROOT / ".github/workflows/auto-version.yml"
    text = path.read_text(encoding="utf-8")
    workflow = load_yaml(text, path.relative_to(ROOT), errors)
    if not isinstance(workflow, dict):
        return
    trigger = workflow.get("on") or workflow.get(True)  # YAML 1.1 loaders treat `on` as boolean.
    push = trigger.get("push") if isinstance(trigger, dict) else None
    branches = push.get("branches") if isinstance(push, dict) else None
    if branches != ["main"]:
        fail(errors, f"{path.relative_to(ROOT)}: must trigger on pushes to main")
    permissions = workflow.get("permissions")
    if not isinstance(permissions, dict) or permissions.get("contents") != "write":
        fail(errors, f"{path.relative_to(ROOT)}: contents permission must be write")
    concurrency = workflow.get("concurrency")
    if not isinstance(concurrency, dict) or concurrency.get("queue") != "max":
        fail(errors, f"{path.relative_to(ROOT)}: concurrency must preserve pending runs with queue: max")
    jobs = workflow.get("jobs")
    if not isinstance(jobs, dict) or set(jobs) != {"validate", "release"}:
        fail(errors, f"{path.relative_to(ROOT)}: expected validate and release jobs")
        return
    release = jobs.get("release")
    if not isinstance(release, dict) or release.get("needs") != "validate":
        fail(errors, f"{path.relative_to(ROOT)}: release must need validate")
    release_steps = release.get("steps") if isinstance(release, dict) else None
    if not isinstance(release_steps, list):
        fail(errors, f"{path.relative_to(ROOT)}: release steps must be a list")
        return
    run_scripts = [step.get("run", "") for step in release_steps if isinstance(step, dict)]
    executable_runs = []
    for script in run_scripts:
        executable_runs.extend(line for line in script.splitlines() if not line.lstrip().startswith("#"))
    joined_runs = "\n".join(executable_runs)
    required_run_patterns = [
        (r"^\s*git\s+reset\s+--hard\s+origin/main\s*$", "git reset --hard origin/main"),
        (r"^\s*python3\s+scripts/validate\.py\s*$", "python3 scripts/validate.py"),
        (r"^\s*git\s+push\s+--atomic\s+origin\s+HEAD:main\s+\"refs/tags/\$\{TAG\}\"\s*$", "atomic branch/tag push"),
        (r"^\s*gh\s+release\s+view\s+\"\$tag\".*$", "GitHub Release existence check"),
    ]
    for pattern, label in required_run_patterns:
        if not re.search(pattern, joined_runs, re.MULTILINE):
            fail(errors, f"{path.relative_to(ROOT)}: release run steps missing safeguard {label!r}")
    checkout_steps = [step for step in release_steps if isinstance(step, dict) and str(step.get("uses", "")).startswith("actions/checkout@")]
    checkout_with = checkout_steps[0].get("with", {}) if checkout_steps else {}
    if checkout_with.get("ref") != "main" or checkout_with.get("fetch-depth") != 0:
        fail(errors, f"{path.relative_to(ROOT)}: release checkout must use main with full history")


def validate_string_list(case, key, case_id, names, errors, allow_empty=False):
    values = case.get(key)
    if not isinstance(values, list) or (not allow_empty and not values):
        fail(errors, f"tests/behavior-fixtures.json: {case_id} requires {'a list' if allow_empty else 'non-empty list'} {key}")
        return set()
    if any(not isinstance(value, str) or not value.strip() for value in values):
        fail(errors, f"tests/behavior-fixtures.json: {case_id} {key} must contain non-empty strings")
        return set()
    if key in {"expected_initial_skills", "forbidden_initial_skills", "expected_sequence"}:
        unknown = set(values) - names
        if unknown:
            fail(errors, f"tests/behavior-fixtures.json: {case_id} {key} has unknown Skills {sorted(unknown)}")
    return set(values)


def validate_fixtures(names, errors):
    path = ROOT / "tests/behavior-fixtures.json"
    data = load_json(path, errors)
    if not isinstance(data, dict) or set(data) != {"schema_version", "purpose", "cases"}:
        fail(errors, "tests/behavior-fixtures.json: expected schema_version, purpose, and cases only")
        return
    if data.get("schema_version") != 2:
        fail(errors, "tests/behavior-fixtures.json: unsupported schema_version")
    if not isinstance(data.get("purpose"), str) or not data["purpose"].strip():
        fail(errors, "tests/behavior-fixtures.json: purpose must be a non-empty string")
    if not isinstance(data.get("cases"), list) or not data["cases"]:
        fail(errors, "tests/behavior-fixtures.json: cases must be a non-empty array")
        return

    required = {"id", "prompt", "expected_initial_skills", "forbidden_initial_skills", "expected_sequence", "assertions"}
    ids = set()
    for index, case in enumerate(data["cases"]):
        if not isinstance(case, dict):
            fail(errors, f"tests/behavior-fixtures.json: case {index} must be an object")
            continue
        if set(case) != required:
            fail(errors, f"tests/behavior-fixtures.json: case {index} fields must be {sorted(required)}")
        case_id = case.get("id")
        if not isinstance(case_id, str) or not NAME_RE.fullmatch(case_id):
            fail(errors, f"tests/behavior-fixtures.json: case {index} has invalid id")
            case_id = str(index)
        elif case_id in ids:
            fail(errors, f"tests/behavior-fixtures.json: duplicate id {case_id!r}")
        else:
            ids.add(case_id)
        if not isinstance(case.get("prompt"), str) or not case["prompt"].strip():
            fail(errors, f"tests/behavior-fixtures.json: {case_id} prompt must be a non-empty string")
        expected = validate_string_list(case, "expected_initial_skills", case_id, names, errors, allow_empty=True)
        forbidden = validate_string_list(case, "forbidden_initial_skills", case_id, names, errors)
        sequence = validate_string_list(case, "expected_sequence", case_id, names, errors, allow_empty=True)
        validate_string_list(case, "assertions", case_id, names, errors)
        overlap = expected & forbidden
        if overlap:
            fail(errors, f"tests/behavior-fixtures.json: {case_id} initially expects and forbids {sorted(overlap)}")
        sequence_values = case.get("expected_sequence") if isinstance(case.get("expected_sequence"), list) else []
        initial_values = case.get("expected_initial_skills") if isinstance(case.get("expected_initial_skills"), list) else []
        if expected and not sequence:
            fail(errors, f"tests/behavior-fixtures.json: {case_id} has initial Skills but no expected_sequence")
        if initial_values and sequence_values[: len(initial_values)] != initial_values:
            fail(errors, f"tests/behavior-fixtures.json: {case_id} expected_sequence must start with expected_initial_skills")


def main():
    errors = []
    validate_manifests(errors)
    names = validate_skills(errors)
    validate_readme(names, errors)
    validate_workflow(errors)
    validate_fixtures(names, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"Validation failed with {len(errors)} error(s).", file=sys.stderr)
        return 1
    print(f"Validation passed: {len(names)} skills, manifests, README, workflow, and behavior fixtures.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
