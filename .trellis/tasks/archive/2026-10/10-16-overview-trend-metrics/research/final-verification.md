# 最终验证：v0.2.21/build23（2026-10-16）

R23/T16：先更新需求、正式趋势设计、Trellis计划，后实现与独立review。相对任务开始仅7个产品/测试/资源文件变化：OverviewIndex、UsageValuation、DashboardView、Core overview测试、Store测试、原生Overview宿主、Info.plist；没有新产品文件。Scanner/Models/Store生产代码/CLI/价格/生命周期等既有脏修改字节不变。

## 本轮实际执行

- Scripts/test.sh：146 Core tests通过。Store真实隔离日志/价表测试通过，验证日小时金额重估和记录桶不变、不重扫；格式测试en_US/zh_CN/fr_FR通过。日志在 /tmp/codex-stats-trend-20261016/logs。
- 独立review手算40断言通过（research/review-oracle.swift，review/oracle.log）。上海today6条1872Token，已估算小计USD0.00307、未估210Token；七天/30天7条1982Token/USD0.00319；全部8条1987Token/USD0.00319、未估215Token。包括日/小时合计、模型、跨日、部分/全部缺价、零价、微额、重估和DST23/25小时。最终Core哈希不变。
- 最终 Scripts/render-overview.sh：overview-axis-final，两配色×启动普通/legacy四进程exit0，共320PNG/320TXT，950/1120×明暗、三指标、筛选/空/长名/未知/失败、微小金额/零价/35日期→30柱、请求带入8条真实NSTable行。document<=clip几何通过；root及独立checker目视稠密图6日期标签与两种未知标记/图例，微额刻度可区分。
- 最终独立macOS14 arm64优化全App typecheck exit0无诊断，51 Sources/Tests/Scripts输入不变；git diff --check与相关脚本bash -n通过。没有独立配置的SwiftLint/SwiftFormat，不虚报执行了它们。
- 最终release-native优化构建exit0，v0.2.21/build23、arm64、macOS14最低目标；codesign --verify --deep --strict通过，仅系统依赖。57构建输入前后哈希不变，delivery.json保留App及ZIP散列。可执行SHA256：fe4af9713c1c86e74edd744642255dad4bf41e89b3b60c8cbccc62b27f4c1519.

## 中间失败与修复

原生压力图发现30日期和逐点文字重叠，补正式密集契约后改为6个首尾日期刻度、△小计/◇未计价及持续图例。第一次参数放错位置产生编译失败，修正后仍发现Charts分类轴忽略仅values:ticks的限制；显式检查标签日期后原生图确认修复。失败构建/前轮预览不当最终交付；release-build.log才是最终构建。两个早期已完成App和中间失败日志保留作诊断，交付只用release-native。

## 证据边界

所有日志/defaults/价格文件均隔离合成；静态/注入模式及程序原生几何不证明实际鼠标/键盘/VoiceOver切换。密集图保留逐点AX和全局帮助，不承诺逐点悬停提示。系统增强对比度、macOS14/Intel运行实机、DeveloperID公证及长期资源仍未验收；没有本轮RSS/footprint/性能收益测量。没有安装/启动/退出/替换用户App，没有真实日志或价表改写，没有Git提交推送。工作区既有修改保留，不生成源码包。

产物：/tmp/codex-stats-trend-20261016/release-native/Codex Stats.app 与 Codex-Stats-v0.2.21-build23-macOS-arm64.zip。设计、实现、review和手算fixture随Trellis保留。
