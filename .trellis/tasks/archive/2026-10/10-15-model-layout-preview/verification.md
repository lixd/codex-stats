# v0.2.15/build17 原生 A 最终验证

2026-10-15。用户选择A后先更新需求/设计，再实现。HTML阶段证据在research/verification.md，不能代替下列原生结果。

## 本轮完成

- 仅模型ModelsContent/私有ModelUsageGroup改为纵向ScrollView+LazyVStack；全字段、known标志、生产格式/精确help及AX、六种排序/搜索保持。代码diff相对上一轮源码包且其hash匹配起始快照，ModelsContent之前字节完全相同。其余Core/Store/菜单/请求/会话/生命周期保持。
- 四个允许路径变化：DashboardView.swift、Info.plist版本、UIPreview测试、render-ui-previews.sh受控legacy子进程。scope-check.json确认；无用户App安装/启动/退出/替换、真实日志读取、提交或推送。
- Scripts/test.sh宿主执行exit0：133 Core tests/0失败，App/CLI编译通过；真实格式en_US/zh_CN/fr_FR各16边界通过。初次普通SwiftPM manifest被嵌套sandbox拒绝；--disable-sandbox可启动但运行器停滞，停止已确认本轮PID后宿主重跑通过。这些失败未当通过。
- 两个独立完整App macOS14 typecheck通过；独立UIPreview macOS14 typecheck、bash -n及git diff --check通过。
- 两套最终预览均脚本exit0：cyan/blue各159PNG、14模型几何记录。每套含正常明暗矩阵及两个浅色legacy宽度，不声称legacy深色已执行。
- 常规950×630文档/clip717/717，1120×760为887/887；legacy分别700/700、870/870。28份实际模型几何记录均无横向溢出。
- 每套6张80模型底图由独立复核者查看，最终synthetic-model-0完整可见；长192字符模型名自然换行、大值、真实0和unknown完整。实际NSTextField搜索→无匹配→恢复，以及配色往返查询/文档高度/摘要身份/刷新时间保持通过。
- 优化App v0.2.15/build17、arm64、minOS14、仅系统库、plist及strict ad-hoc签名通过。初次受限iconutil失败，完整宿主重跑通过；没有修改产品脚本规避图标失败。
- 可执行SHA256：055eea77f6f6f9da21ab7a9026728b6f032854b266becdbc724a213693f3d42a。构建后Sources/Assets hash仍匹配。

## 原始产物

/tmp/codex-stats-model-groups-20261015/：cyan、blue原生图/几何；validation/{core-host,token-display,build-host,cyan-previews,blue-previews}.log、artifact-check.txt、build-source-hashes.json、model-only.diff；native/Codex Stats.app。

## 受控测试校准与人工边界

强改已挂载NSScrollView.scrollerStyle只使clip缩小，SwiftUI仍读取启动时preferred；实际进程启动参数-AppleShowScrollBars Always可创建legacy。最终测试断言preferred及实际scroll.style；不改系统偏好、不隐藏条、不修改documentframe或硬扣宽度。离屏虚拟AXroot不可枚举：精确AX/help为源码复核，不声称运行时VoiceOver或悬停成功。

实际鼠标/触控板流畅度、非默认Picker键盘操作、悬停help/VoiceOver、macOS14/Intel实机、实际系统增强对比度、正式签名公证未执行；本轮没有内存/帧时间基准。旧性能结果不作为新收益。源码包与Trellis收尾另记录，不做Git提交。

## 交付收尾

Trellis已--no-commit归档，journal session15；相关Markdown本地文件链接与diff检查通过，构建Sources/Assets hash保持。源码包CodexStats-v0.2.15-source.zip包含最终产品代码、设计、测试及归档任务，排除个人workspace/runtime/认证/构建缓存；CRC核验通过。
