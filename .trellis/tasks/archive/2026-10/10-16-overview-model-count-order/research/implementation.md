# Implementation — 总览模型按记录数量排序（R21/T15）

2026-10-16，trellis-implement。正式批准设计与 PRD、三条 implement manifest 已阅读；保留全部已有脏改动。

本轮仅修改 `Sources/App/DashboardView.swift:195`：原候选 Set 的 `.sorted()` 改为按 `summary.modelRecordCounts` 降序，缺键按0，同数按精确模型ID升序。全部模型 `Text` 仍在 `ForEach` 前且不参与排序；候选仍由全部历史已用模型和当前选择合并去重，`overviewModel` 的绑定与值完全不改。当前范围计数来自现有索引，不改 Core/Store、记录统计或价格，也不增 helper/API/cache。

实施前文件副本：`/tmp/codex-stats-overview-model-count-order-20261016/DashboardView.before.swift`。与该副本逐行 diff 仅包含上述一处排序修改（新增4行）；`git diff --check` 通过。根据轻量任务约定，没有新增镜像 comparator 的测试，没有执行重复 Core 全套。现有总览原生矩阵/build 由 root 执行；独立读源/typecheck 由 checker 执行，结果由各执行者记录。本记录不把未执行项目算作通过，不将静态或离屏预览称为真实弹出菜单点击证明。

Sources 已通知 root/checker 冻结，`Sources/App/DashboardView.swift` SHA256：`fcf3b1f9a49d627ef5a43fdc28cd99bb794e632bea1df85294f77d5e44490ae3`。此后不改 Sources/Tests/Scripts；若出现问题，先通知 root 停止并发编译并协调修改。

未读取/改变真实日志、配置或运行用户 App，未提交或推送。
