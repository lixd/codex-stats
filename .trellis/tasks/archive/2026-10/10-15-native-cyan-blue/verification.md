# D 布局 / 浅青和晴蓝：最终验证

2026-10-15，本轮独立证据。宿主macOS27.0.1/arm64、AppleSwift6.4/SDK27；目标macOS14。所有运行数据均为脚本合成JSONL，偏好为UUID UserDefaults。未读取真实日志、安装/启动/退出/替换用户App，未提交推送。任务前已有审查/配色脏改动完整保留。

## 顺序与结果

先完成固定D浅青、记录[stage-d门禁](stage-d.md) PASS（88张原生PNG、Core/Store/格式/菜单/优化构建），之后才开始晴蓝/偏好实现；阶段交接分别见stage-d-implementation.md及stage-a-implementation.md。不能把之前v0.2.12证据算本轮。

| 本轮实际命令 | 结果 |
|---|---|
| Scripts/test.sh | 最终133 Core tests通过、0失败，App/CLI目标编译通过；final-core.log |
| Scripts/test-token-display.sh | en_US/zh_CN/fr_FR各16边界及unknown/exact通过；独立复核check-format.log |
| Scripts/test-usage-store.sh | 真实合成扫描/失败保留/恢复/summary边界及两配色默认/未知/重新实例恢复通过；切换无loading/report发布、摘要身份/成功时间/根路径/范围/刷新配置保留；check-store.log |
| Scripts/test-menu-lifecycle.sh | 阶段D临时UUID App的准确窗口关闭顺序、复用/替换、dashboard所有权、驻留与显式终止通过；A不改生命周期；stage-d-menu.log |
| Scripts/render-ui-previews.sh OUT cyan/blue | 各120张PNG：88张完整矩阵+32张同宿主切换样本；全部成功退出；final-{cyan,blue}-preview.log |
| 原生Table检查 | 模型3/80真实行，无交替空纹、保留自有NSScrollView，80行程序滚到末行；1120/950 light/dark通过；请求保留原生交替行和右侧详情 |
| 同宿主实际颜色更新 | 请求/模型/会话/设置四页×light/dark；真实NSTextField委托发送文本变化，搜索过滤生效；同一Dashboard/Menu host内Store.palette浅青→晴蓝→浅青，像素对应生产颜色；查询、请求选中行、目录草稿、范围/根路径/成功时间及summary对象保持；palette-switch.txt |
| 颜色/对比度 | 两套×light/dark生产resolve精确sRGB通过；自有普通文字最低4.605:1、白字操作最低5.418:1、风险合成底最低4.792:1；预期HC描边数学最低3.366:1；theme-contrast.txt |
| Scripts/build-macos.sh 独立OUT | 优化App v0.2.13/build15，arm64、minOS14.0、strict codesign、plist、仅系统框架/Swift库；final-{build,package}.log |
| 独立Trellis check | 完整App与菜单历史原型macOS14 typecheck、Store/三区域格式/diff检查通过；发现并修复共享ShapeStyle接口在历史原型中两处Color调用；[review](review.md) |
| 范围 | scope-check.json：Core/Report/AppLifecycle/构建安装交付脚本与任务起始hash相同；Store只新增配色偏好；无新增Timer/Task/扫描策略；index仍空，无提交推送 |

原始日志/PNG/构建均在 `/tmp/codex-stats-native-cyan-blue-20261015/`：validation、stage-d、final-cyan、final-blue、native目录。最终可执行SHA256：`daf704d1b2c6d774eedcaa20ba264d1701458aeda41cd9f46d3499f8625eb9ef`。优化App只构建和检查，未启动。临时预览宿主均正常退出。

## 失败尝试及修正

- SwiftPM嵌套sandbox、菜单LaunchServices及iconutil最初受sandbox限制；在相同授权范围内受控重跑通过。没有为失败改产品代码。默认模块缓存写入受限的独立check改用/tmp模块缓存通过。
- colorSchemeContrast为只读，不能人工赋值构造HC环境；测试保留四种普通环境和独立预期swatch数学，不宣称实际系统增强对比度通过。
- 最初cacheDisplay像素再转sRGB造成一次额外calibrated→sRGB变换（原始RGB234/245/245匹配目标，却被转成约238/247/247）；改为比较渲染编码通道。对比度仍依据生产resolve的sRGB，不依据截图。
- 尝试用NSPopUpButton驱动SwiftUI menu Picker时查不到对应控件，测试明确失败。移除不成立的宿主假设，保留已通过的原生文本/行选择/Store绑定切换检查，不把Picker操作算通过；没有改产品掩盖测试。

## 未验收边界与人工步骤

1. 配色Picker实际鼠标/键盘选择：设置改晴蓝，查看菜单/窗口/已开状态sheet；再开App确认偏好。当前自动测试验证的是相同Store绑定和重新创建实例，不是跨进程启动实际产品。
2. 非默认模型筛选/排序和非首项会话选择：先建立这些状态，再从另一窗口/设置切换配色，确认保持。源码身份不重建；本轮自动化仅实际操作文本搜索及已有请求选择，没有把其他状态推断成实测。
3. 真实MenuBarExtra点击、sheet打开与Esc/复制、系统按钮激活着色、VoiceOver/键盘完整导航：仍需真人实际操作。静态图和AppKit程序操作不替代这些验收。
4. 实际系统增强对比度/降低透明度、macOS14和Intel实机、睡眠唤醒与长期驻留、DeveloperID/公证：未执行。没有改用户系统偏好。
5. 本轮无新内存/CPU/帧时间基准，不把旧RSS/footprint数值或未测性能写成新主题收益。仅两套固定颜色，不引入新依赖或轮询。

## 交付收尾

任务已使用--no-commit归档，journal session13记录完成；旧脏工作和bootstrap任务保留。文档本地链接及git diff --check通过。独立源码包CodexStats-v0.2.13-source.zip已更新（474文件），CRC及源码/排除个人journal、运行状态、构建缓存、认证文件边界检查通过；不替换旧dist或发布包。
