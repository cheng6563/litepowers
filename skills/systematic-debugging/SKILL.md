---
name: systematic-debugging
description: "用复现、数据流和单一假设定位未知故障的根因。Use after align has selected root-cause investigation for a bug, failing test, stack trace, or unexpected behavior whose cause is not established."
---

# 系统化调试

根因未知时，不猜修法：

1. 读取完整错误和相关上下文，复现问题；不能复现时先收集能区分假设的证据。
2. 沿调用链或数据流回溯异常，从症状追到最早偏离预期的位置。
3. 提出一个具体根因假设，用最小诊断或实验验证；一次只改变一个变量。
4. 假设失败时撤销实验，再提出新假设，不在失败尝试上叠补丁。
5. 根因成立后记录证据、影响边界和修复方向，然后返回执行合同。

连续三个假设失败时停止试改，重审证据、前提和架构。无法证明根因时如实标为未知，不用“外部因素”提前结束调查。

本 Skill 只定位根因，不修改生产行为。返回主任务后按既定 Approach 修复、按 Evidence 验证，不重新询问测试方式或交付终点。
