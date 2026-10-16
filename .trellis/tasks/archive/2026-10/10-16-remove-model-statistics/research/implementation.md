# Implementation — R22 删除独立模型统计页

2026-10-16；执行者 trellis-implement。以本任务 `research/before.json` 为本轮输入基线；保留此前全部未提交工作。本轮产品/测试/脚本仅改变三个文件，sha256 记录见 `implementation-inputs.json`。

## 删除范围

- `Sources/App/DashboardView.swift`：删除 `DashboardSection.models`、专属图标及路由，完整移除文件尾 `ModelsContent`、`ModelUsageGroup`，以及其私有排序、搜索、卡片。侧栏继续由枚举生成，只剩总览、请求日志、历史会话、设置；默认仍为总览。
- `Tests/UIPreview/main.swift`：移除专页截图、搜索绑定/卡片高度检查、80 模型及专页边界渲染、`expectedModelRows` 几何分支、`--legacy-models` 分支。80 条记录改为请求滚动 fixture，保留原生 Table 最后一行可达、所有列可见、真实 sheet、配色状态保持等检查。保留金额模型字典与精确美元手算断言，将对应页面渲染改为仍存在的总览。四页状态检查继续使用实际 `DashboardSection.allCases` 渲染。
- `Scripts/render-ui-previews.sh`：删除只服务已删专页的启动 legacy 子进程。保留请求矩阵中的原生 legacy Table 几何检查；总览启动 legacy 独立矩阵由 root 运行。

没有将专页搬入总览，没有增加替代页面。Core 全部文件、Store、CLI、总览模型筛选与 `ModelBar`、请求/会话/设置组件、价格管理均与本轮 before 哈希一致；其历史脏改动没有回退。

## 本轮验证

- `bash -n Scripts/render-ui-previews.sh`、`git diff --check` 通过。
- Sources/Tests/Scripts 中查找 `DashboardSection.models`、`initialSection: .models`、`ModelsContent`、`ModelUsageGroup`、`expectedModelRows`、`--legacy-models`，无残留。保留的 `summary.models` / `valuation.models` 是数据聚合和共享估值，不属于已删页面。
- cyan 完整原生 UI 矩阵 exit 0：`/tmp/codex-stats-remove-model-statistics-20261016/ui-cyan.log`；149 PNG、35 TXT，其中四页 × warning/failed-refresh/recovered-info × 明暗共 24 张页面状态图。950/1120 请求、真实原生详情 sheet、288 宽菜单、未知/空/失败恢复、同 host 配色切换、精确金额断言均完成。
- blue 完整原生 UI 矩阵亦 exit 0：`/tmp/codex-stats-remove-model-statistics-20261016/ui-blue.log`；同样 149 PNG、35 TXT，四页双明暗/状态与请求/菜单/估值检查全部通过。两配色合计 298 PNG、70 TXT，无旧模型专页产物。
- 请求滚动 fixture 保留 80 条实际合成记录；950 legacy Table document/clip 均 716pt，7 列；1117 legacy 均 883pt，10 列；末行可达并能返回首行。其他边界 1116/1118/1120 同样由矩阵断言。
- 亲自检查 cyan 总览浅色、950 warning 请求页、950 recovered 会话暗色、950 设置估值页，以及 blue 总览暗色：四项侧栏、原有内容与状态可读。双配色总览专项与独立 macOS14 typecheck 由 root/checker 执行，不冒充本执行者结果。

本轮只渲染隔离测试宿主：临时 UserDefaults suite、临时价格路径、合成日志，未安装/启动/退出/替换用户 App，未读取或改变真实日志/价表，未提交或推送。

离屏渲染与程序化控件驱动不证明真实鼠标点击、菜单 Picker 手动选择、实际系统高对比开关、VoiceOver 或键盘全流程。宿主日志保留沙箱下系统拼写/输入服务 XPC 提示；不将这些提示当作产品交互验收。

## 冻结

已向 root/checker 明确通知 Sources/Tests/Scripts 冻结。后续仅补充本任务证据，产品文件若需再改须先通知 root 停止编译并获得协调确认。
