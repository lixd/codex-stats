# 当前原生界面设计（v0.2.9）

本文描述 **v0.2.9 / build 11 已实现的界面**，用于复建当前 App。菜单 B 方案已获用户选择但未进入生产，见 [B 方案目标设计](ui-design-b.md)。功能和统计以 [主设计](design.md)、[数据设计](data-design.md) 为共同契约；不能用原型中的固定数字替代真实日志。

尺寸单位均为 macOS points，字体为系统字体，除非另有注明。截图像素受 Retina 比例影响，不能把 576 像素宽当作 576 points。未指定高度的容器使用 SwiftUI 自适应高度；系统控件的外观、行高和窗口装饰随 macOS 版本变化，本文没有给它们虚构固定像素值。

## 1. 设计原则与结构

菜单只承担快速查看和入口，分析窗口承担完整查询。重要数字优先，次要口径放在帮助文本；信息与告警分级折叠，避免正常历史元数据占满页面。原生 Table 负责自己的滚动，不再包第二层水平 ScrollView，否则宽表可能被居中裁切而隐藏首列。

共用一个 `UsageStore`，菜单和分析窗口的时间选择、数据、扫描状态与刷新偏好同步。导航是分析窗口本地状态，启动默认总览。只有完整分析窗口有五个页面：总览、请求日志、模型统计、历史会话、设置。切换页面会重新建立其内容视图；搜索、排序、详情选择不是跨启动持久化偏好。

主要源码映射：

| 职责 | 文件 / 类型 |
|---|---|
| 场景与全局数据注入 | `Sources/App/CodexStatsApp.swift` |
| 菜单布局 | `Sources/App/MenuPanelView.swift` |
| 主题、数字、公共卡片、诊断 | `Sources/App/Components.swift` |
| 窗口骨架、总览、模型表 | `Sources/App/DashboardView.swift` |
| 请求表与右侧详情 | `Sources/App/RequestsContent.swift` |
| 会话主从界面、设置 | `Sources/App/SessionsContent.swift` |
| 窗口关闭顺序、后台驻留 | `Sources/App/AppLifecycle.swift` |

## 2. 公共视觉参数

颜色使用 SwiftUI `Color` 的 RGB 0–1 值；语义背景由系统管理深浅色。

| 名称 | 定义 | 用途 |
|---|---|---|
| accent | (0.14, 0.60, 0.53) | 总量、缓存、主操作、选中项 |
| cyan | (0.19, 0.61, 0.80) | 输入、趋势图、信息 |
| purple | (0.55, 0.47, 0.82) | 输出 |
| orange | (0.85, 0.53, 0.29) | 推理、警告、错误 |
| cardBackground | `NSColor.controlBackgroundColor` | 卡片 |
| viewBackground | `NSColor.windowBackgroundColor` | 主内容与菜单 |
| stroke | primary × 0.065 | 卡片边框 |
| sidebarBackground | `NSColor.underPageBackgroundColor` | 导航侧栏 |

`CPLogo`：默认 34×34；圆角为 size×0.27，连续圆角；从左上 (0.12,0.27,0.29) 到右下 (0.08,0.13,0.17) 的渐变。内部 `waveform.path.ecg`，字体 size×0.48 / medium，颜色 (0.56,0.92,0.77)。不同位置显式设置尺寸。

`Surface`：内边距默认 20，圆角 18 / continuous，语义卡片背景及 stroke 边框。`SectionHeader`：标题 27 / bold / rounded，副标题 12 / secondary，垂直间距 5。

`MetricTile`：Surface 内边距 16，垂直间距 9；图标及标签 12 / medium，标签 secondary；数字 26 / semibold / rounded、等宽数字、单行、最小缩放 0.65、numericText 过渡；副行 10 / secondary，紧凑数量加 tokens。缓存字段不完整时副行提示日志缺少部分缓存字段。

`TokenDetails`：两列 Grid，横距 22，行距 9，字体 12，标签 secondary，数值右对齐、等宽数字，可选择文字。行序固定为 Input / Cached Input / Non-cached Input / Output / Reasoning / Total Tokens。

`ModelBar`：名称 12 / medium / rounded，数值 12 / semibold / rounded；单行名称，数字等宽；垂直间距 8。条高 6，底条 accent×0.10，前景 accent，宽度 `max(3, 可用宽×本模型总量/max(1,第一名总量))`。底行 10 / secondary，显示输入、输出和会话数。条表示相对第一名的排行，不是占总用量的百分比。

`EmptyViewCard`：垂直间距 10；`chart.bar.xaxis` 30 / light / accent，标题 headline；副标题 12 / secondary / 居中、最大宽 390；容器撑满可用宽、最小高 190。

`StatusBanner`：警告实心图标、orange；文字 12 / secondary 可选择；间距 8、内边距 12、圆角 12、orange×0.07 背景。

## 3. 数量、时间和缺失值

全部 Token 文本及图表纵轴调用 `Components.swift` 的 `abbreviated`，不使用自动科学计数法或随中文区域变成万/亿的 compactName。K=1,000，M=1,000,000；大于十亿仍显示 M，不使用 B。

| 输入 | 展示 |
|---|---|
| 0；0.5（图表 Double） | 0；0.5 |
| 9,999 | 原数值（区域固定为 en_US_POSIX） |
| 563,240 | 563.2K |
| 999,949；999,950 | 999.9K；1M |
| 109,946,996 | 109.95M |
| 1,000,000,000 | 1000M |
| 缓存 / 推理字段未完整记录 | 未完整记录，不能显示为 0 |

M 最多两位小数，K 最多一位，去尾零；999,950 提前提升为 M，避免 1000K。显示舍入不改变底层整数。完整整数通过 `.help(detailedNumber(...))` 提供，完整值允许本地千分位。正式 JSON/CLI 保留整数。公共契约及验证见 [Token 展示规范](../.trellis/spec/frontend/token-display.md)。

菜单和头部最近刷新时间采用当前区域的 time.standard（不显示日期）；会话日期使用 abbreviated date + shortened time；请求列表使用 HH:mm:ss 加 MM/dd 第二行，完整日期时间放帮助文本。时间范围固定今天 / 7 天 / 30 天 / 全部，原生 segmented Picker，分析窗口宽 292，菜单宽 260，不增加日期选择器。

## 4. 菜单栏弹窗

`MenuBarExtra` 使用 `.window` 样式，菜单栏符号为 `waveform.path.ecg.rectangle`，无障碍标签 Codex Stats。生产菜单固定 **宽 288**，外内边距 14，有效内容宽 260。主 VStack 左对齐、间距 12；高度根据数据、诊断、错误动态决定，没有生产固定高度。

从上到下重建：

1. 标题 HStack 间距 8：Logo 27，Codex Stats 14 / semibold，Spacer，borderless 刷新。扫描时改小型 ProgressView、禁用按钮；帮助文本“重新扫描本地日志”。
2. 时间 Picker 宽 260，四段，共享 `store.period`。
3. 总量卡：VStack 间距 10，内边距 12，圆角 12、accent×0.08 背景、撑满宽。总量 30 / bold / rounded / 等宽数字，tokens 11 / secondary，基线对齐、间距 6。下方两行：输入/输出，缓存/推理；每行横距 14。每个指标色点 5，标签 secondary，数值 medium；整体 10 字体，单行、最小缩放 0.85，Spacer 最少 2。缓存或推理缺失显示“未完整记录”。卡片帮助说明缓存/推理包含关系。
4. 主要模型：标题 11 / medium / secondary，区域间距 8。只展示排行前两名；每项行内名称单行、悬停全名，数字紧凑且精确整数帮助，字体 11 / medium。名称与值之间 Spacer 最少 8；该行和进度条间距 4。条高 3、底条 accent×0.09，前景宽为本模型/第一名，无 3pt 最小宽强制。
5. 有扫描失败时显示 orange 10 字体，最多两行，帮助文本保留完整错误；不清除已有成功数据。
6. 有诊断时显示一行 button：图标、警告/错误数、信息数、右箭头。字体 10、箭头 9；有警告/错误用 orange，否则 cyan。这里不展开全部源文件明细；点击执行与完整分析相同动作。
7. 主操作“打开完整分析”：白色 12 / semibold、图表图标，右侧箭头 10；水平内边距 10、垂直 9、accent 背景、圆角 8、plain button。
8. 底行：左侧两行“刷新于 …”/“每 30 秒刷新 · 本地只读”或手动刷新，9 / secondary、间距 3；右侧 borderless power+“退出”10，直接终止 App，帮助显示 ⌘Q。

首次没有成功结果：总量卡显示“正在读取本地日志…”或“尚未取得用量”14 / medium / secondary，不展示假 0 和四项指标；模型处显示“等待扫描结果”。成功扫描但范围空：真实总量 0，模型处“该时间范围没有使用记录”。

打开分析时先关闭菜单自己的 hosting NSWindow，再 `openWindow(id:"dashboard")`，再激活 App。不能关闭当前 keyWindow，因为它可能是分析窗口。诊断入口目前只打开分析窗口，**不自动跳转诊断或设置页面**。

## 5. 分析窗口骨架

SwiftUI 单实例 `Window("Codex Stats",id:"dashboard")`，默认 1120×760，contentMinSize；内容最小 950×630，标题栏装饰不计入内容设计。关闭此窗口保留菜单 App。

外层 HStack spacing 0：侧栏 218 + Divider + 主内容 VStack spacing 0。侧栏水平内边距 16、垂直 27；Logo 39，产品名 15 / bold / rounded，副标 LOCAL ANALYTICS 为 9 / medium / rounded、tracking 1.15、tertiary；品牌区域底距 36。

导航行：图标 14 / medium、占宽 20，文字 12（选中 semibold，否则 medium）；间距 12，水平内边距 12、垂直 12，圆角 10；选中 accent、背景 accent×0.09，未选 primary×0.70，各项下距 3。图标按页面依次 square.grid.2x2 / list.bullet.rectangle / cpu / rectangle.stack / gearshape。

侧栏底部：7pt 色点；状态文字 11 / medium、文件数 10 / secondary、行距 4；卡片内边距 12、圆角 12、accent×0.055。状态优先扫描中→读取失败→已有数据→尚未读取；错误色点 orange，否则 accent。退出应用 bordered / regular，字体 12 / medium，距状态卡 14。

头部：水平内边距 24、垂直 16，两行间距 14。首行页面标签 17 / semibold（总览显示“用量统计”），刷新状态 11 / secondary，bordered 立即刷新，刷新方式 Menu fixedSize；行间距 14。Menu 选项手动刷新、每30秒/1分钟/5分钟/15分钟，选择间隔同时开启自动刷新。设置外的第二行左为 Codex·本地会话日志 11 / secondary，右为时间 Picker。设置不显示第二行。

非设置页首次未成功扫描，统一显示 PendingUsageView：垂直间距 16，加载时 ProgressView，空态标题读取中/尚未取得用量，副标题显示错误或首次扫描说明，内边距 24。设置始终可进入以修改错误路径。

## 6. 总览页

ScrollView 内左对齐 VStack 间距 18，外内边距 24。

- 顶部四个等宽 MetricTile 横距12：总 Token、输入 Token、输出 Token、缓存输入，对应 accent/cyan/purple/accent。
- 趋势 Surface：内部间距16，标题13/semibold，右为7pt cyan 色点和 Tokens 11/secondary。今天按本地小时用 BarMark，X 时间每4小时标签 HH:mm；其他范围按日期，仅最近30个有记录的日期，标签MM-dd。所有柱 cyan、圆角3，图高210，Y零基线包含0且轴在左，数字走公共格式。没有用量替换为空态，不绘制假曲线。底部口径说明10/secondary。当前正式实现是柱状图，旧截图中的折线图不是当前复建目标。
- 下方两列 Surface 顶对齐、横距12：左模型前5名，标题13/semibold，右上按总Token10/secondary；右Token明细，内间距14，标题13/semibold，共用TokenDetails。缓存完整且输入>0才显示缓存/输入百分比（1位小数），随后10字体说明包含关系及非订阅扣费。
- 页面末尾错误 Banner 和折叠 DiagnosticSummary。

## 7. 模型统计页

外 VStack 左对齐、间距17、内边距30。标题模型消耗明细+口径副标题；右下对齐搜索框宽190、roundedBorder。排序Picker宽200，项为总Token/输入/输出/缓存输入/推理/模型名称；数字降序、相同值按模型名升序，名称模式纯名称升序。搜索不区分大小写，不写死模型列表。

原生 Table 自己管理滚动，圆角裁切12，无外部横滚动；列宽如下。模型名单行并帮助全名，数字12/rounded/等宽/右对齐，总计semibold，其余regular，完整值帮助。会话数等宽右对齐。AX标识model-table。

| 模型 | 输入 | 缓存输入 | 非缓存输入 | 输出 | 推理 | 总计 | 会话 |
|---:|---:|---:|---:|---:|---:|---:|---:|
|150|76|76|76|76|76|76|44|

空数据显示没有匹配的模型；底部11/secondary说明字段包含关系。固定首列宽避免旧版自定义宽表留下过多空白、模型名被裁到左边。列较多时允许原生水平滚动；不强行压到全部同屏。

## 8. 请求日志与右侧详情

页面 VStack 间距14、内边距24。记录数16/semibold，右侧范围11/secondary；搜索 roundedBorder，字段项目/会话ID/模型/请求ID/TurnID，trim空白后不区分大小写。模型Menu宽160，排序Menu宽130，筛选行横距12。排序最近记录（默认）/总Token/模型名称；范围变化清空模型筛选。提示明确“一行不一定等于一个请求”。错误Banner及compact诊断先于表。

原生Table(selection:String?)，AX request-table，最小宽170；右边选择了当前筛选结果中的记录才显示Divider+360宽详情，不是模态sheet或遮罩。表自己水平滚动，详情出现后允许表变窄，不隐藏时间列。

| 列 | 宽度 | 表现 |
|---|---|---|
|时间|78|HH:mm:ss；第二行MM/dd 10/secondary，行距2，等宽|
|项目/会话|min80 ideal95 max130|项目单行；会话前8位或未记录，10/monospaced/secondary，间距3|
|模型|min100 ideal115 max170|单行，帮助全名|
|新增输入|65|输入−缓存，未知不能伪造|
|输出|58|紧凑值|
|缓存输入|65|紧凑值或未完整记录|
|总Token|68|紧凑值|
|耗时≈|65|≈N s或—，等宽、口径帮助|
|速度≈|78|≈N tok/s或—，等宽、口径帮助|
|类型/详情|90|borderless accent 10按钮，压缩优先，否则依据标签|

表底显示当前筛选列表合计（10/secondary，完整整数帮助），右侧新增输入口径。点击行或类型按钮选中记录；Esc或详情×关闭。筛选导致已选记录不可见时详情消失，选择ID本身不被强制清空。

详情标题区内边距20，标题18/semibold，时间11/secondary、间距4，×帮助关闭详情（Esc），AX close-request-detail。下方ScrollView内边距12，四块Surface(padding14)间距18，顺序：

1. **性能**：标题13/semibold；请求估算子标题12/medium；耗时与输出速度、口径10/secondary；Divider后完整Turn·含工具与等待，Turn耗时、首次Token、平均输出。完整Turn均速不能代替请求速度。请求时间保留最多1位小数并前缀≈；Turn时间最多3位小数。请求速度仅Core已满足输出≥200且耗时≥1秒才展示；缺失为—，不填0。若Turn输出覆盖确认，显示整段去重响应数及紧凑输出量，否则说明未确认；这些值不受当前日期和列表筛选裁切。
2. **基本信息**：项目、模型、来源、真实SessionID、TurnID、response_id、文件名；真实SessionID缺失时额外显示本地归组ID，不能当作原始ID。复制按钮仅在对应真实ID存在时出现。键宽92，值右对齐可选择、允许换行；整体12，横距12。复制写系统剪贴板。
3. **已计入Token用量**：共用TokenDetails及包含关系说明。
4. **统计依据**：依据标签与解释；压缩额外标记；原始last_token_usage/usage和累计快照可折叠查看。native thread_token_usage与legacy total_token_usage各自标明口径，不能直接累加。

详情只显示元数据与计量，**不展示或持久化提示词全文**。速度空白问题的正确表达是“—+缺少边界说明”，不是推测模型速度；资格规则由数据设计决定。

## 9. 历史会话页

主从HStack spacing0。左列表宽360（包含内边距24），VStack间距15：标题/当前匹配数、搜索、排序、Divider、ScrollView内LazyVStack间距7、右内边距5。搜索标题/项目/SessionID/当前范围模型；排序最近活动/Token用量/项目名称。优先选中匹配ID，否则默认匹配第一项；范围内没有匹配时右侧空态。

列表卡padding12、圆角12，选中accent×0.105背景、边框accent×0.36，否则语义卡片/stroke。内部间距9：标题12/semibold单行尾截断、继承不确定时警告图标；项目和最近活动10/secondary；ID9/monospaced/tertiary单行；末行总量11/semibold/rounded、模型列表10/secondary单行。

右侧ScrollView，内VStack间距20、内边距26；标题23/bold/rounded可选择，项目11/secondary，目录或ID10/monospaced/tertiary单行、右为复制ID。会话Surface内部间距14，标题会话Token·当前范围13/semibold，来源10/tertiary；大总量37/semibold/rounded，副行紧凑tokens12/monospaced/secondary+精确help；Divider、TokenDetails、开始及最后活动10/secondary。下方会话内模型明细标题14/semibold，每模型Surface(padding14)、间距9，名称12/semibold，总量13/semibold/rounded，随后TokenDetails。已去除继承快照显示绿色说明，未核验显示警告Banner。末尾完整SessionID可选择。

会话开始/最后活动是会话元数据，Token是当前范围值，不应把开始日期误写为筛选范围内首条。

当前会话页使用 `SessionUsage.id` 展示并复制 ID；若日志缺少 session_meta ID，这个值是文件名生成的本地归组标识，页面尚未专门标出它不是原始 Session ID。请求详情则保留 `recordedSessionID=nil` 并显示“未记录”。这是当前实现限制，不能据此在复建的数据层伪造真实身份；后续完善会话页时须先更新设计和 T06 验收。

## 10. 设置页

ScrollView内VStack间距22、内边距30，标题偏好设置。三个默认Surface：

- 日志位置：标题14/semibold，说明12/secondary，路径TextField12/monospaced+保存并扫描accent prominent（横距10）；Finder打开按钮、自动刷新switch11；刷新间隔menu宽220，关闭自动刷新时禁用。onAppear把当前rootPath拷入编辑框；只有保存操作改变实际路径。
- 数据与隐私：四条checkmark.circle.fill accent，文字12/secondary、允许换行，逐条间距8，明确本地日志、非订阅额度、不上传不保存原文、继承或压缩的归属限制。
- 扫描状态：会话文件数、会话数、上次成功扫描、无效行数、复用缓存数，整体12；完整诊断和错误Banner。

Finder打开逗号分隔路径中的第一项并展开~。保存路径、扫描与刷新偏好详见数据设计。

## 11. 诊断、加载与生命周期状态矩阵

DiagnosticSummary缺省收起，按severity+kind分组，组顺序error→warning→information，再按key；标题分别orange或cyan，不通过文本猜告警等级。一般内边距14、标题12/medium、背景相应色×0.06、圆角12；compact内边距10、标题10，展开内容使用固定120高ScrollView（不是maxHeight），少量明细时也占120。详情说明诊断涉及全部扫描日志，不限当前筛选；组内明细11、文件名10/monospaced，可选择。正常history引用/去重信息仍可查看，不被当成警告。

| 状态 / 操作 | 菜单 | 分析窗口 |
|---|---|---|
|首次扫描|读取中，不展示假0，刷新spinner|非设置页PendingUsageView；设置可用|
|成功、范围空|真实0，模型空态|图表/表对应空态|
|后台刷新已有结果|保留旧成功数值、禁用刷新|保留数据、头部读取中|
|刷新失败已有结果|旧数据+错误，成功时间不变|旧数据+错误Banner|
|首次失败|尚未取得用量+错误|Pending错误；设置可修路径|
|未知模型|Unknown model，单行/全名help|独立模型条目，不能猜归属|
|字段缺失|未完整记录|对应明细/表字段未完整记录|
|无性能边界|菜单无性能项目|请求耗时速度—，详情解释|
|诊断存在|单行数量入口|默认折叠、按级别/类型分组|
|打开完整分析|先close菜单自身窗口|打开/激活dashboard，保留菜单图标|
|关闭分析窗口|菜单保留|窗口关闭，进程驻留|
|显式退出/⌘Q|菜单消失|所有窗口和进程退出|
|重复启动同bundleID|较早启动实例保留|新实例退出并激活旧实例|

驻留通过Info.plist的NSSupportsAutomaticTermination及AppDelegate显式disableAutomaticTermination，加最后窗口关闭不退出实现；不是登录启动、守护进程或崩溃后自动恢复，也不阻止睡眠/App Nap。MenuWindowProbe弱引用跟踪真正的hostingwindow，旧probe拆卸不能清除更新后的窗口关联。

## 12. 复建与验收

按主题→公共组件→菜单→窗口骨架→总览→模型表→请求详情→会话→设置顺序实现，直接使用数据设计给出的模型与Store状态。不要实现额外Provider、成本、OAuth、日期选择器或B样式切换。

| 验收层 | 方法 | 能证明 / 不能证明 |
|---|---|---|
|数字契约|`Scripts/test-token-display.sh`|三种locale一致格式；不证明hover交互|
|当前页面|`Scripts/render-ui-previews.sh`|合成数据原生深浅色布局；不证明真实日志匹配|
|窄菜单|`Scripts/render-ui-previews.sh`（menu输出）|加载/空态/未知字段等合成状态布局|
|窗口机制|`Scripts/test-menu-lifecycle.sh`|owned AppKit窗口关闭顺序/驻留callback；不等于实际鼠标点MenuBarExtra|
|用户验收|安装后点击菜单、打开分析、关闭窗口、切范围/筛选、详情×/Esc、深浅色|真实交互；macOS14实机仍须单独验收|

运行脚本前检查仓库实际名称与参数；历史执行证据见 [VERIFICATION](../VERIFICATION.md)。本次文档同步依据源码，不产生新的UI运行或macOS14验收声明。系统字体字形、默认Table行高、segmented样式、阴影和窗口外圆角由系统绘制；复建要求结构、数据口径、指定points与交互一致，不承诺跨OS逐像素完全相同。
