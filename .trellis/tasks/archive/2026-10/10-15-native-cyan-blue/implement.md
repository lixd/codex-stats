# 顺序执行计划

- [x] D：实现原生布局和固定浅青，不添加另一配色或偏好。
- [x] D门禁：编译、原生预览/对比度/表格检查、格式/Core/Store/菜单相关回归，检查并记录 stage-d.md。未通过不得写晴蓝代码。
- [x] A：增加晴蓝角色、设置选择、隔离UserDefaults持久化与环境更新。
- [x] A：验证同宿主实际配色切换、搜索/选择不丢失、不扫描及重启恢复；两色深浅色预览。
- [x] 最终：必要回归、优化App构建及签名/依赖核验、独立检查、文档与spec更新。
- [x] 无提交收尾：archive --no-commit、journal --no-commit，保留原有工作。

命令：Scripts/render-ui-previews.sh /tmp/codex-stats-native-cyan-blue-20261015/stage-d；Scripts/test.sh；Scripts/test-token-display.sh；Scripts/test-usage-store.sh；Scripts/test-menu-lifecycle.sh；Scripts/build-macos.sh /tmp/codex-stats-native-cyan-blue-20261015/native。
