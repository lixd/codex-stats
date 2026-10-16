# 执行计划

- [x] 用户选择A；更新需求、UI、产品提案及spec为approved pending。
- [x] trellis-implement：仅模型渲染与相关UI预览harness，实现并typecheck；将证据写入research/implementation.md。
- [x] trellis-check：全任务范围独立复核，修复缺陷并验证适用检查。
- [x] 原生两配色预览/几何/状态，Core和格式测试，macOS14目标构建。
- [x] 通过后推进v0.2.15/build17基线，更新VERIFICATION和spec，独立App/源码包。
- [x] Trellis以--no-commit归档与session记录，不提交推送。

源码允许：DashboardView.swift仅模型部分、Tests/UIPreview/main.swift模型及相关断言、Assets/Info.plist，以及Scripts/render-ui-previews.sh仅追加测试进程启动参数/调用。其他仅文档和任务记录。
命令：Scripts/render-ui-previews.sh /tmp/codex-stats-model-groups-20261015/cyan cyan（blue独立目录）；Scripts/test.sh；Scripts/test-token-display.sh；Scripts/build-macos.sh /tmp/codex-stats-model-groups-20261015/native。
