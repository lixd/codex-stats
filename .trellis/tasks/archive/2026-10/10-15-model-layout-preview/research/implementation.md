# A 原生分组列表实现记录

2026-10-15；本记录仅报告本轮代码与受控原生测试，不把 HTML 预览或历史结果作为原生产品验收。

## 改动

- `Sources/App/DashboardView.swift` 仅 ModelsContent 与私有 ModelUsageGroup：八列 Table 替换为纵向 ScrollView/LazyVStack，每模型一个白底分组；14pt名称、21pt总量、会话，输入/输出及从属缓存/非缓存/推理；18pt组内/12pt组间、可换行名称和未知状态。
- 工具区15pt标题/筛选数量/范围、170pt搜索/原生六项排序，可换行工具区；保持原有搜索与排序算法、Store/摘要/时间/错误共享，不增加选择或展开状态。
- 逐项采用原有 abbreviated/detailedNumber、known标志；数字有字段级 accessibilityLabel 和精确 accessibilityValue/help。缓存 unknown 同时影响非缓存，真实0保持0。Unknown model不猜归属。
- `Tests/UIPreview/main.swift` 删除过时模型NSTableView断言，保留请求Table全部原有断言；模型实际NSScrollView文档/clip尺寸、80条真实扫描结果、滚到底部及末项截图；原生输入框搜索→无匹配移除滚动内容→恢复单模型文档高度、配色往返保持查询/高度/Store状态；长名/大值/known0/unknown三模型真实合成日志。
- `Scripts/render-ui-previews.sh` 在正常矩阵成功后增加同一隔离测试可执行文件的 legacy-only 子进程，启动参数 `-AppleShowScrollBars Always`，只跑950/1120两个浅色模型图；不改用户或系统偏好。

## 受控测试校准

- 初始尝试NSAccessibilityProtocol及selector/KVC访问SwiftUI虚拟AX树。离屏测试root仅提供一个opaque AccessibilityNode，其children=nil/identifier空，不能读取模型数量或末项。因此删除不能执行的AX断言，而非声称通过。精确AX值以源码复核；真实VoiceOver与交互朗读仍需人工。
- mount后强行改NSScrollView.scrollerStyle为legacy时，SwiftUI仍依旧preferred style布局，950文档717而clip700；tile/等待/resize亦未改变。没有隐藏滚动条、放宽断言或扣17pt改产品。
- process运行时仅设置volatile NSArgumentDomain Always仍preferred=overlay；从启动参数读取Always时preferred=legacy。独立probe在创建时断言实际preferred/实际scroll为legacy，通过：950文档/clip700/700；1120为870/870，真实80模型滚到底。最终harness按此启动时序验证。
- 宽度证明是document<=clip；80数据数量由Store扫描结果确认，不以LazyVStack实例化视图计数冒充全部数据。末项身份必须独立查看end图确认synthetic-model-0，不能仅凭底部坐标声称末项标签已读。

## 验证状态

- 完整原生App swiftc typecheck通过；独立复核与Core/formatter/优化构建由父任务记录，避免重复测试。
- 当前最终原生矩阵输出 `/tmp/codex-stats-model-groups-20261015/cyan` 和 `blue`，以本文件末尾的最终结果为准。最终运行前清理的是本任务生成的这两个目录，其他产物不受影响。
- 当前source稳定；无Core/Store/请求产品修改，无用户App安装/运行/退出/替换，无真实日志修改，无提交或推送。

## 留人工验证

真实VoiceOver、鼠标悬停精确help、原生Picker非默认排序的键盘操作，以及真实系统增加对比度偏好切换不能由离屏截图证明。测试中的输入框绑定、配色切换和AppKit程序滚动不等同于鼠标/键盘人工验收。

## 最终结果（2026-10-15 本轮执行）

- `Scripts/render-ui-previews.sh /tmp/codex-stats-model-groups-20261015/cyan cyan` **exit0**；`blue blue` 同样 **exit0**。每次包括正常完整矩阵和独立 preferred-legacy 子进程；最终输出每配色159 PNG、14模型几何txt（常规4、80模型4、边界4、legacy2）。原生请求Table及sheet断言继续全部通过。
- 完整最终日志：`/tmp/codex-stats-model-groups-20261015/validation/cyan-previews.log` 和 `blue-previews.log`。均有正常矩阵及legacy子进程的PASS；无harness FAIL。系统离屏桥接XPC日志不作为功能成功或失败的替代证据。
- 正常模型document/clip：950×630为717/717，1120×760为887/887；legacy分别700/700、870/870。80模型document高度12960，clip389/519；滚到底并返回顶部均执行。`end-models-many-*` / `end-models-legacy-*` 截图中最终synthetic-model-0可见；独立审查者也复核末项。
- 已亲自查看cyan普通1120light、80末项950light、长名/大值/未知边界950light和1120light，以及blue普通950light、legacy末项950light、边界1120dark。长名自然多行、巨大紧凑值完整；未知缓存/非缓存/推理均完整“未完整记录”；1120边界图含真实zero模型输出/缓存/推理0。没有以unknown显示0。
- 同一native host原生文本框绑定实际执行：3模型→匹配1模型文档缩短→不匹配移除滚动内容→恢复相同单模型文档高度；cyan→blue→cyan保持查询/文档高度/成功刷新时间/摘要对象身份且不扫描。状态证据在每配色palette-switch.txt，截图在switch-cpu-*。数值AX的运行时朗读仍未验证，不在通过范围。
- 对任务前保存的产品/脚本/测试哈希逐个比较，仅DashboardView.swift、Info.plist（父任务版本）、render-ui-previews.sh和Tests/UIPreview/main.swift改变；本实现范围git diff --check通过。未修改其他既有dirty产品工作。
