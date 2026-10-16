# 当前原生界面设计（v0.2.21）

本文描述 **v0.2.21 / build 23 已实现的界面**，用于复建当前 App。菜单已接入用户选择的 B 方案，选择背景与参数见 [B 菜单设计](ui-design-b.md)。功能和统计以 [主设计](design.md)、[数据设计](data-design.md) 为共同契约；不能用原型中的固定数字替代真实日志。

尺寸单位均为 macOS points，字体为系统字体，除非另有注明。截图像素受 Retina 比例影响，不能把 576 像素宽当作 576 points。未指定高度的容器使用 SwiftUI 自适应高度；系统控件的外观、行高和窗口装饰随 macOS 版本变化，本文没有给它们虚构固定像素值。

## 1. 设计原则与结构

菜单只承担快速查看和入口，分析窗口承担完整查询。重要数字优先，次要口径放在帮助文本；信息与告警分级折叠，避免正常历史元数据占满页面。原生 Table 负责自己的滚动，不再包第二层水平 ScrollView，否则宽表可能被居中裁切而隐藏首列。

共用一个 `UsageStore`，菜单和分析窗口的时间选择、数据、扫描状态与刷新偏好同步。导航是分析窗口本地状态，启动默认总览。只有完整分析窗口有四个页面：总览、请求日志、历史会话、设置。切换页面会重新建立其内容视图；搜索、排序、详情选择不是跨启动持久化偏好。

主要源码映射：

| 职责 | 文件 / 类型 |
|---|---|
| 场景与全局数据注入 | `Sources/App/CodexStatsApp.swift` |
| 菜单布局 | `Sources/App/MenuPanelView.swift` |
| 两套配色、环境颜色角色 | `Sources/App/Appearance.swift` |
| 数字、公共卡片、诊断 | `Sources/App/Components.swift` |
| 窗口骨架、总览、模型表 | `Sources/App/DashboardView.swift` |
| 请求表与右侧详情 | `Sources/App/RequestsContent.swift` |
| 会话主从界面、设置 | `Sources/App/SessionsContent.swift` |
| 窗口关闭顺序、后台驻留 | `Sources/App/AppLifecycle.swift` |

## 2. 公共视觉参数

D 是唯一布局；配色为默认「浅青」和「晴蓝」，明暗跟随系统。`Appearance.swift` 中 `CPTheme: ShapeStyle` 通过 `resolve(in:)` 读取环境的 appPalette/colorScheme/colorSchemeContrast；菜单和Dashboard从共享Store注入选项，诊断sheet显式注入。颜色表及阶段顺序见 [D 与双配色契约](native-cyan-blue-design.md#配色角色)。正文继续用系统 primary/secondary，原生控件遵循系统/用户强调色，没有全局tint或.id重建。只有自有白字主操作使用actionFill。实际系统增强对比度仍待人工验收，不用色值计算冒充。

| 名称 | 用途 |
|---|---|
| accent | 总量/指标图标、应用自有链接与选中导航 |
| chart | 淡色趋势柱与总览模型排行条，增强对比度时用accent |
| cyan / purple | 输入 / 输出指标辅助色 |
| orange | 风险、推理；文字与符号共同表达 |
| viewBackground | 页面与菜单底 |
| sectionBackground | 导航、会话左栏 |
| headerBackground / metricBackground | 独立近白窗口头部 / 连续指标条底 |
| cardBackground | 内容卡、表格、请求详情头部 |
| selection | 导航、会话选中卡、菜单总量卡、信息级诊断底 |
| actionFill | 白字“打开完整分析”及保存主操作底 |
| stroke | 卡片和内容边界，增强对比度适配 |

`CPLogo`：默认34×34，圆角size×0.27，selection浅底，内部waveform.path.ecg为size×0.48/medium/accent。无渐变和阴影；侧栏28、菜单24。

`Surface`：内边距默认18，圆角12/continuous，cardBackground及stroke。`SectionHeader`：标题23/semibold（会话列表18），副标题12/secondary、间距5。

`MetricTile`：只绘制连续指标条的一格，padding16、垂直间距9；图标accent、标签12/medium/secondary；数字26/semibold系统字体、等宽数字、单行、最小缩放0.65、numericText。仅总量强调accent，其余primary。副行10/secondary说明字段口径；字段未知明确未完整记录，不填0。精确整数help保留。

`TokenDetails`：两列 Grid，横距 22，行距 9，字体 12，标签 secondary，数值右对齐、等宽数字，可选择文字。行序固定为输入 Token / 缓存输入 / 非缓存输入 / 输出 Token / 推理 Token / 总 Token；未知字段保留“未完整记录”，紧凑值仍提供精确整数 help。总览和会话主卡使用showTotal:false省去已强调的总量，其余完整详情保留六项。

`ModelBar`：名称 12 / medium / rounded，数值 12 / semibold / rounded；单行名称，数字等宽；垂直间距 8。条高 6，底条selection，前景chart，宽度 `max(3, 可用宽×本模型总量/max(1,第一名总量))`。默认底行10/secondary显示输入、输出和会话数；总览showSessionCount:false省略该行，其他使用处可保留该行。条表示相对第一名的排行，不是占总用量的百分比。

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

`MenuBarExtra` 使用 `.window` 样式，菜单栏符号为 `waveform.path.ecg.rectangle`，无障碍标签 Codex Stats。B 菜单固定 **宽 288**，外内边距 14，有效内容宽 260。主 VStack 左对齐、间距 10；高度由内容决定，没有生产固定高度。

从上到下重建：

1. 标题 HStack 间距 8：Logo 24，Codex Stats 13 / semibold，Spacer，borderless 刷新。标签区域 24×24，扫描时小型 ProgressView、禁用按钮；帮助文本“重新扫描本地日志”，可访问性标签按状态为“刷新本地日志”或“正在刷新本地日志”。
2. 时间 Picker 宽 260，四段，共享 `store.period`，segmented / small / labelsHidden。
3. 总量卡：VStack 间距 6，内边距 10，圆角 10、selection 背景、撑满宽。首行“今日用量”或所选范围 rawValue 加“用量”，10 / medium / secondary。总量 29 / semibold / rounded / 等宽数字、单行、最小缩放 0.65，tokens 10 / secondary；基线对齐、横距 5。精确整数 help，卡片帮助说明总计与缓存/推理包含关系。
4. 独立四卡：LazyVGrid 两列 flexible，行距 8，列距使用 GridItem 系统默认。顺序输入/输出、缓存输入/推理；小卡内边距 8、圆角 9、语义卡片背景及 stroke。内部左对齐、间距 6；标签 Label 色点 5、字体 9 / secondary，颜色 cyan/purple/accent/orange；数值 16 / semibold / 等宽，字段未知时文字“未完整记录”用 12 字体。数值单行、最小缩放 0.65、数值区域最小高 19，保证未知卡与已知卡对齐。每卡 help 与无障碍标签保留字段和精确值或明确未知状态。
5. 主要模型：标题 10 / secondary，区域间距 8。只展示当前范围前两名；名称与值 10 / medium，名称单行并帮助全名，值固定其固有宽度、等宽并提供完整整数 help。两者间 Spacer 最少 8；行与条间距 4。条高 3、底条 accent×0.10，前景按本模型/第一名归一化，无最小宽强制。未知模型显示 Unknown model。
6. 扫描失败时 orange 10 字体、最多两行，帮助文本保留完整错误；已有成功数据保持。
7. 有诊断时一行 button：图标、警告/错误数、信息数、右箭头。字体 10、箭头 8；有警告/错误用 orange，否则 accent。这里不展开源文件明细；点击与完整分析相同。
8. 主操作“打开完整分析”：白色 11 / medium、图表图标，右侧箭头 10；水平内边距 10、垂直 9、actionFill 背景、圆角 8、plain button。
9. 底行左侧两行“刷新于 …”/“每 30 秒刷新 · 本地只读”或手动刷新，9 / secondary、间距 3；右侧 borderless power+“退出”10 / secondary，标签最小 24×24。直接终止 App，帮助显示 ⌘Q；可访问性标签“退出 Codex Stats”，保留 quit-app 标识。

2026-10-15 原生合成预览实测：正常/四范围 **288×466**、首扫 **288×270**、真实空态 **288×409**、首次失败 **288×306**、完整字段且 Unknown model 单模型 **288×415**，深浅色均覆盖。这些是当前宿主的内容 fittingSize，不是固定高度承诺；不同诊断、错误、系统字体和状态会改变高度。预览同时覆盖长模型名、缓存/推理未知及十亿以上统一 M 单位，未证明真实菜单点击或 macOS 14 布局。

首次没有成功结果：总量卡显示“正在读取本地日志…”或“尚未取得用量”14 / medium / secondary，不展示假 0 和四项指标；模型处显示“等待扫描结果”。成功扫描但范围空：真实总量 0，模型处“该时间范围没有使用记录”。

打开分析时先关闭菜单自己的 hosting NSWindow，再 `openWindow(id:"dashboard")`，再激活 App。不能关闭当前 keyWindow，因为它可能是分析窗口。诊断入口目前只打开分析窗口，**不自动跳转诊断或设置页面**。

## 5. 分析窗口骨架

SwiftUI 单实例 `Window("Codex Stats",id:"dashboard")`，默认 1120×760，contentMinSize；内容最小 950×630，标题栏装饰不计入内容设计。关闭此窗口保留菜单 App。

外层 HStack spacing 0：侧栏184 + Divider + 主内容 VStack spacing 0。侧栏水平内边距13、垂直24；Logo28，产品名14/semibold，品牌底距28，无英文副标。

导航行：图标 14 / medium、占宽 20，文字 12（选中 semibold，否则 medium）；间距 12，水平内边距 12、垂直10，圆角8；选中 accent、背景 selection，未选 primary×0.70，各项下距 3。图标按页面依次 square.grid.2x2 / list.bullet.rectangle / cpu / rectangle.stack / gearshape。

侧栏底部：7pt 色点；状态文字 11 / medium、文件数 10 / secondary、行距 4；卡片内边距 12、圆角 12、accent×0.055。状态优先错误→风险→扫描中→已有数据→尚未读取；错误色点 orange，否则 accent。退出应用 bordered / regular，字体 12 / medium，距状态卡 14。

头部：headerBackground，水平内边距24、垂直 16，两行间距12。首行页面标签 17 / semibold（总览显示“用量统计”），刷新状态 11 / secondary，bordered 立即刷新，刷新方式 Menu fixedSize；行间距12。Menu 选项手动刷新、每30秒/1分钟/5分钟/15分钟，选择间隔同时开启自动刷新。设置外的第二行左为 Codex·本地会话日志 11 / secondary，右为时间 Picker。设置不显示第二行。请求页也不显示第二行，头部改横16/纵12；四档范围移到记录数同行（仍共享Store），其他页头不变。

非设置页首次未成功扫描，统一显示 PendingUsageView：垂直间距 16，加载时 ProgressView，空态标题读取中/尚未取得用量，副标题显示错误或首次扫描说明，内边距 24。设置始终可进入以修改错误路径。

## 6. 总览页

ScrollView内左对齐VStack间距16，外横边距24、纵20。

- 顶部四项MetricTile放同一个连续metricBackground指标条，横距0，三个竖分隔线上下16，圆角12/stroke：总Token、输入Token、输出Token、缓存输入。
- 趋势 Surface：内部间距16，标题13/semibold，右为7pt chart色点和 Tokens 11/secondary。今天按本地小时用 BarMark，X 时间每4小时标签 HH:mm；其他范围按日期，仅最近30个有记录的日期，标签MM-dd。所有柱chart、圆角3，图高144，Y零基线包含0且轴在左，数字走公共格式。没有用量替换为空态，不绘制假曲线。底部口径说明10/secondary。当前正式实现是柱状图，旧截图中的折线图不是当前复建目标。
- 下方两列Surface顶对齐、横距16：左模型前5名，标题13/semibold，右上按总Token10/secondary，名称/数值/条形；右Token明细间距14，标题13，showTotal:false。卡内不重复总量/百分比/解释，页底一处10pt包含关系和本地日志限制。
- 全局错误与诊断使用共享头部状态入口，页面不重复显示。

## 7. 独立模型统计页（已移除）

v0.2.19按用户授权与R22删除独立入口、路由、A分组卡片及该页搜索/排序。当前仅四页导航；总览模型下拉支持全部历史已用模型，选中后四卡、趋势、分布与完整Token明细同步变化。请求页模型筛选、会话内模型拆分及设置价格管理保持。旧A设计和测试仅作为[历史提案](model-layout-proposals.md)保留，不再要求重建该页。删除边界与验收见[正式契约](remove-model-statistics-design.md)。

## 8. 请求日志与右侧详情

页面VStack间距8、横边距16/纵12。记录数16/semibold，右侧292pt四档PeriodPicker；搜索 roundedBorder，字段项目/会话ID/模型/请求ID/TurnID，trim空白后不区分大小写。模型Menu宽160，排序Menu宽130，筛选行横距8。排序最近记录（默认）/总Token/模型名称；范围变化清空模型筛选。11pt提示明确“一行不一定等于一个请求”。全局错误与诊断使用共享头部入口。

原生Table(selection:String?)，AX request-table；GeometryReader只测可用宽，不引入外层滚动。可用宽>=900pt显示十列，否则七列把相关字段双行呈现，全部十项信息保留；正文约12pt，次要身份/类型10pt。表格自有纵向滚动与选择，禁止靠裁切/隐藏滚动条掩盖横向溢出；宽度预算包含原生约17pt列间距和常显纵向滚动条。隐藏系统内容底，cardBackground、12圆角和stroke，保留原生交替行。完整数值/模型/项目/身份help保留；配对数字的AX标签同时包含精确accessibilityValue（未知仍为未完整记录）。

| 宽窗列 | 宽度 | 表现 |
|---|---|---|
|时间|60|HH:mm:ss；第二行MM/dd 10/secondary，行距2，等宽|
|项目/会话|min80 ideal80 max100|项目单行；会话前8位或未记录，10/monospaced/secondary，间距3；完整项目与真实身份help|
|模型|min100 ideal100 max130|单行，帮助全名|
|新增输入|72|输入−缓存，未知不能伪造|
|输出|48|紧凑值|
|缓存输入|72|紧凑值或未完整记录|
|总Token|58|紧凑值|
|耗时≈|58|≈N s或—，等宽、口径帮助|
|速度≈|80|≈N tok/s或—，等宽、口径帮助|
|类型|66|borderless accent 10按钮，压缩优先，否则完整依据标签|

窄窗七列顺序：时间60、项目/会话min70 ideal70 max100、模型/类型min88 ideal88 max150、新增/缓存72、输出48、总Token58、耗时/速度≈78。配对列按表头先后上下对应；模型/类型第二行为依据按钮，耗时与速度保留单位/≈，缺失不填零。1120/950与切换边界、overlay/legacy滚动条证据见[紧凑布局](request-density-design.md)和[验证记录](../VERIFICATION.md)。

表底显示当前筛选列表合计（10/secondary，完整整数帮助），右侧新增输入口径。点击行或类型按钮选中记录，用同一个RequestDetailView打开原生420×600pt sheet，不占列表宽度；接收Store当前配色。关闭×或Esc清空selection，保留搜索/筛选/排序；不增加第二套详情状态。实际生产按钮/Esc操作仍需人工验收，程序呈现不等于点击验证。

详情标题区cardBackground、内边距20，标题18/semibold，时间11/secondary、间距4，×帮助关闭详情（Esc），AX close-request-detail。下方ScrollView内边距12，四块Surface(padding14)间距18，顺序：

1. **性能**：标题13/semibold；请求估算子标题12/medium；耗时与输出速度、口径10/secondary；Divider后完整Turn·含工具与等待，Turn耗时、首次Token、平均输出。完整Turn均速不能代替请求速度。请求时间保留最多1位小数并前缀≈；Turn时间最多3位小数。请求速度仅Core已满足输出≥200且耗时≥1秒才展示；缺失为—，不填0。若Turn输出覆盖确认，显示整段去重响应数及紧凑输出量，否则说明未确认；这些值不受当前日期和列表筛选裁切。
2. **基本信息**：项目、模型、来源、真实SessionID、TurnID、response_id、文件名；真实SessionID缺失时额外显示本地归组ID，不能当作原始ID。复制按钮仅在对应真实ID存在时出现。键宽92，值右对齐可选择、允许换行；整体12，横距12。复制写系统剪贴板。
3. **已计入Token用量**：共用TokenDetails及包含关系说明。
4. **统计依据**：依据标签与解释；压缩额外标记；原始last_token_usage/usage和累计快照可折叠查看。native thread_token_usage与legacy total_token_usage各自标明口径，不能直接累加。

详情只显示元数据与计量，**不展示或持久化提示词全文**。速度空白问题的正确表达是“—+缺少边界说明”，不是推测模型速度；资格规则由数据设计决定。

## 9. 历史会话页

主从HStack spacing0；左侧sectionBackground，右侧viewBackground。左列表宽280（包含内边距16），标题18/semibold，VStack间距15：标题/当前匹配数、搜索、排序、Divider、ScrollView内LazyVStack间距7、右内边距5。搜索标题/项目/SessionID/当前范围模型；排序最近活动/Token用量/项目名称。优先选中匹配ID，否则默认匹配第一项；范围内没有匹配时右侧空态。

列表卡padding12、圆角10，选中selection背景、accent不透明边框并声明selected无障碍trait，否则cardBackground/stroke。内部间距9：标题12/semibold单行尾截断、继承不确定时警告图标；项目和最近活动10/secondary；ID9/monospaced/tertiary单行、完整ID help；末行总量11/semibold/rounded、模型列表10/secondary单行。

右侧ScrollView，内VStack间距20、内边距24；标题21/semibold可选择，项目11/secondary，目录或ID10/monospaced/tertiary单行、右为复制ID。会话Surface内部间距14，标题会话Token·当前范围13/semibold，来源10/tertiary；大总量37/semibold/accent、精确整数help，无重复副行；Divider、TokenDetails(showTotal:false)、开始及最后活动10/secondary。下方会话内模型明细标题14/semibold，每模型Surface(padding14)、间距9，名称12/semibold，总量13/semibold/rounded，随后TokenDetails。已去除继承快照显示绿色说明，未核验显示警告Banner。末尾完整SessionID可选择。

会话开始/最后活动是会话元数据，Token是当前范围值，不应把开始日期误写为筛选范围内首条。

会话页只用 `SessionUsage.recordedSessionID` 展示、搜索及复制真实 ID；缺失时列表显示“Session ID 未记录”，详情显示“未记录”，复制按钮禁用且帮助说明缺失。`SessionUsage.id` 只作为内部归组/选择标识，不能冒充原始 Session ID。一次 body 捕获相同 now，以 `ScanReport.sessionRows` 共享日期边界和单次会话聚合，再按搜索筛选及用户排序；查询本身不预排序。一次 body 中只计算一次匹配列表与选中项，行比较选中 ID，不逐行重新筛选；Token 排序复用预先计算的每会话范围用量。请求详情仍遵守真实 ID 与本地归组 ID 的独立标记。

## 10. 设置页

ScrollView内VStack间距22、横边距24/纵20，标题偏好设置。四个默认Surface：

- 日志位置：标题14/semibold，说明12/secondary，路径TextField12/monospaced+保存并扫描actionFill prominent（横距10）；Finder打开按钮、自动刷新switch11；刷新间隔menu宽220，关闭自动刷新时禁用。onAppear把当前rootPath拷入编辑框；只有保存操作改变实际路径。
- 配色：原生menu Picker宽220，选项浅青/晴蓝，说明“只改变配色，外观跟随系统”。共享store.palette即时生效，保存CodexStatsColorPalette；无扫描、无summary清空、不重建页面，保持路径草稿及搜索/筛选/排序/选择。
- 数据与隐私：四条checkmark.circle.fill accent，文字12/secondary、允许换行，逐条间距8，明确本地日志、非订阅额度、不上传不保存原文、继承或压缩的归属限制。
- 扫描状态：会话文件数、会话数、上次成功扫描、无效行数、复用缓存数，整体12；全局详情使用共享入口。仅首次失败、尚无成功报告时保留错误Banner，便于修正目录。

Finder打开逗号分隔路径中的第一项并展开~。保存路径、扫描与刷新偏好详见数据设计。

## 11. 诊断、加载与生命周期状态矩阵

已有成功报告时，共享header下出现紧凑状态行，水平内边距24、垂直8、间距8、11pt字。刷新失败明确保留上次成功数据；风险诊断显示不完整提示，侧栏同步警示；仅信息诊断仍为正常状态。重试保留旧错误和诊断上下文。点击入口打开640×420pt原生sheet，完整错误可选择、滚动，关闭按钮支持Esc；不会切换页面、范围、搜索或选择。详情标明诊断涉及全部扫描日志，不限当前筛选。

sheet复用DiagnosticSummary并在打开时展开，按severity+kind分组，组顺序error→warning→information，再按key；标题分别orange或accent，不通过文本猜告警等级。内边距14、标题12/medium、风险背景orange×0.06、信息背景不透明selection、圆角12；展开明细11、文件名10/monospaced，可选择。正常history引用/去重信息仍可查看，不被当成警告。已移除不再使用的compact模式与固定120pt诊断滚动区；会话自身继承风险仍在会话详情展示。

| 状态 / 操作 | 菜单 | 分析窗口 |
|---|---|---|
|首次扫描|读取中，不展示假0，刷新spinner|非设置页PendingUsageView；设置可用|
|成功、范围空|真实0，模型空态|图表/表对应空态|
|后台刷新已有结果|保留旧成功数值、禁用刷新|保留数据、头部读取中|
|刷新失败已有结果|旧数据+错误，成功时间不变|旧数据+共享状态入口，重试时错误仍保留|
|首次失败|尚未取得用量+错误|Pending错误；设置可修路径|
|未知模型|Unknown model，单行/全名help|独立模型条目，不能猜归属|
|字段缺失|未完整记录|对应明细/表字段未完整记录|
|无性能边界|菜单无性能项目|请求耗时速度—，详情解释|
|诊断存在|单行数量入口|共享入口→sheet，按级别/类型分组；信息不升级为风险|
|打开完整分析|先close菜单自身窗口|打开/激活dashboard，保留菜单图标|
|关闭分析窗口|菜单保留|窗口关闭，进程驻留|
|显式退出/⌘Q|菜单消失|所有窗口和进程退出|
|重复启动同bundleID|较早启动实例保留|新实例退出并激活旧实例|

驻留通过Info.plist的NSSupportsAutomaticTermination及AppDelegate显式disableAutomaticTermination，加最后窗口关闭不退出实现；不是登录启动、守护进程或崩溃后自动恢复，也不阻止睡眠/App Nap。MenuWindowProbe弱引用跟踪真正的hostingwindow，旧probe拆卸不能清除更新后的窗口关联。

## 12. 复建与验收

按主题→公共组件→菜单→窗口骨架→总览→模型表→请求详情→会话→设置顺序实现，直接使用数据设计给出的模型与Store状态。不实现额外Provider、订阅账单/余额、OAuth、日期选择器或B样式切换；参考金额依下述派生指标契约实现。

| 验收层 | 方法 | 能证明 / 不能证明 |
|---|---|---|
|数字契约|`Scripts/test-token-display.sh`|三种locale一致格式；不证明hover交互|
|当前页面|`Scripts/render-ui-previews.sh`|合成数据原生深浅色布局；不证明真实日志匹配|
|窄菜单|`Scripts/render-ui-previews.sh`（menu输出）|加载/空态/未知字段等合成状态布局|
|窗口机制|`Scripts/test-menu-lifecycle.sh`|owned AppKit窗口关闭顺序/驻留callback；不等于实际鼠标点MenuBarExtra|
|用户验收|安装后点击菜单、打开分析、关闭窗口、切范围/筛选、详情×/Esc、深浅色|真实交互；macOS14实机仍须单独验收|

运行脚本前检查仓库实际名称与参数；历史执行证据见 [VERIFICATION](../VERIFICATION.md)。v0.2.10 已执行原生合成预览和数字检查；这些不产生真实菜单点击或 macOS 14 实机验收声明。系统字体字形、默认Table行高、segmented样式、阴影和窗口外圆角由系统绘制；复建要求结构、数据口径、指定points与交互一致，不承诺跨OS逐像素完全相同。


## 2026-10-15 第一批精修实现记录

v0.2.10/build12 接入 B 菜单及上述中文/字段口径细节，保留分析窗口布局和 360pt 请求侧栏。菜单和总览读取同一个 Store 当前范围摘要，不因展示而分别重做聚合；摘要按报告修订、范围、本地日期及时区失效。真实身份展示与筛选规则见会话部分，详细实现和验证以主设计、数据设计、VERIFICATION 为准。

## 审查修复：已实现（2026-10-15）

用户批准的A01–A06已于v0.2.11/build13纳入源码：计量重发与未知子项（T01/T03/T04/T06/T08）、Turn与会话查询性能（R02/R07/R13/R16、T09–T11）、跨页异常状态（R04/R11）、安全本地替换（R14/R17）。[审查修复设计](audit-fixes-design.md)在实现前获批，契约现已同步本文；133项Core测试、126组合成差分、18项真实交付检查、原生构建及受控基准见[本轮验证](../VERIFICATION.md#v0211--build-13-审查修复2026-10-15)。未安装、提交、推送或发布；静态预览不代表实际点击验收。A07窄窗口布局继续延期。


## 青灰与青绿精修：已实现（2026-10-15）

用户批准的配色 A「Sage + Teal」在当时 v0.2.12/build14 源码实现（该颜色现已被v0.2.13双配色取代）。R01/R06/R07/R12/R17：分层背景、青绿趋势与选中态、原生模型表去除空斑马纹；菜单仍为 B，统计与窗口几何不变。[配色设计](sage-teal-design.md)先于实施，任务见 [10-15-sage-teal-refinement](../.trellis/tasks/archive/2026-10/10-15-sage-teal-refinement/prd.md)。本轮 133 Core 测试、数字格式/Store/菜单宿主、88 张原生合成深浅色预览和优化构建通过，详见 [验证记录](../VERIFICATION.md#v0212--build-14-青灰与青绿精修2026-10-15)。实际系统增强对比度切换、鼠标及 VoiceOver 操作保持待验收；未安装或操作用户 App，未提交、推送或公开发布。

## v0.2.16 派生指标补充（R18/R19）

以下保留v0.2.16指标接入历史；当前总览布局由R21覆盖，独立模型A页已按R22删除。[缓存率与美元估算设计](cache-rate-cost-design.md)的计量与未知边界继续有效。菜单总量卡内补金额，缓存小卡底部补缓存率；总览沿用原总量/缓存卡，不增加大卡排。模型A组的完整金额位于右侧总Token标签下；部分或未知金额使用独立换行区，显示未估Token和原因。输入子区增加缓存率，主Token仍为21pt。会话及会话内模型详情补同口径指标；已接受请求在TokenDetails后显示，原始快照/last_usage不另计价。请求表无新增列。

两套配色均使用现有动态文字角色，部分/未知状态不只靠颜色或悬停表达。金额两位小数、微小非零为“< $0.01”，精确help及AX提供至少8位小数、版本和参考口径；未知金额为“无法估算”，零输入缓存率为“—”，不完整缓存为“未完整记录”。v0.2.16设置提供只读价格版本/日期/来源/不含项；v0.2.17增加下述本地价格管理，仍无联网入口。


## v0.2.17：模型价格管理（R20）

设置中的API参考卡增加“管理模型价格”入口，进入原窗口子页；添加sheet的原生模型Picker为全部历史已用模型减去已有价，已配置行可编辑，内置/自定义同删除保护规则。UI与空态/错误/窄窗验收按[价格管理设计](model-price-management-design.md)，已在v0.2.17实现，其他布局保持不变。


## v0.2.18：总览模型联动（R21/T15）

见[正式新增设计](dashboard-model-filter-design.md)。总览模型选择共同约束指标/趋势/明细，不改已接受记录；新增两个有官方依据的默认价格，保存完整表只通过明确动作补充，不静默覆盖。已实现v0.2.18；四卡、模型下拉、同范围标量查询与显式价格补充以该契约为准，覆盖此前无模型筛选的总览描述。


## v0.2.19：四页导航（R22）

用户明确授权删除独立模型统计页，见[目标契约](remove-model-statistics-design.md)。已覆盖本文第1/7节的旧五页/模型页契约，四页为总览、请求日志、历史会话、设置。总览现有模型筛选/分布与完整Token明细、价格管理和会话拆分保持；不迁移独立模型A列表，也不新增页面。当前实现基线v0.2.19。


2026-10-16批准的R21/T15微调：模型Picker中全部模型固定首项，其他模型按当前范围记录数降序、同数按精确模型ID升序，保持原选择和零记录候选；已实现v0.2.20/build22，验证见VERIFICATION。


## 已实现：R23趋势三指标

总览趋势右上增加原生Token／记录数／API等值金额segmented切换。范围、模型和既有四卡不变；完整目标、布局、未知标记及验证见[趋势设计](overview-trend-design.md)。已实现v0.2.21/build23，本轮测试和原生几何/视觉证据见VERIFICATION。
