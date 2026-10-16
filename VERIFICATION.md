# Codex Stats v0.2 验证记录

历史记录自2026-10-14起；最新v0.2.17验证见文末。工作环境：macOS 27.0.1、Apple Silicon、Apple Swift 6.4、macOS SDK 27.0；构建部署目标为 macOS 14.0。

## 初始源码评审

原型具有基本 SwiftUI 界面和独立 Core，但存在明确准确性问题：首次模型回填会猜测归属；回退快照整段重加；last-only 重发无去重；按 basename 筛选会误删同名文件；活动副本无条件优先可能丢失更完整归档；继承前缀仅匹配累计数可能误判；缺失 Token 字段按零显示；更新日志目录时旧扫描结果可能覆盖新选择。Package 只编译 Core，菜单栏没有时间筛选、推理明细或刷新时间，路径错误还会阻止用户打开设置。

初始原生构建确实失败于 SDK 的 State 宏/包装器重名解析；初始 XCTest 测试因当前 CLT 未提供 XCTest 模块而失败。已改用无宏歧义的属性包装器别名与系统 Swift Testing。CLT 的增量解析还可能遗漏 TestingMacros，测试脚本显式传入已安装插件位置，未下载框架。

## 自动化验证

实际执行：

```bash
./Scripts/test.sh
```

最终结果：**38 tests passed，0 failures**。同一测试构建也编译 Core、核对 CLI 和 macOS App 目标。

覆盖单模型、Cached/Reasoning 子集、模型切换、未知模型不回填、模型字段缺失、活动/归档身份去重、同名不同会话、更完整归档、重置有/无 last、缺失历史基线、last-only 重发、损坏行与追加修复、非法/缺失字段、UTC/上海跨天、7/30 天边界、缓存命中/变更/删除、父历史前缀、错误继承匹配、请求记录去重、先通知/后请求、外部 thread_id、远程/本地压缩、缺失时间、零用量会话、exec 备用格式、仅归档目录、多目录重复、JSONL 符号链接、空路径、未知子集字段、重复请求与同大小新请求、Int64 汇总溢出、未通知请求后切回旧通知格式，以及仓库合成 fixture。

为测试生成的临时目录会在结束后清理；检入的 fixture 不包含用户提示词。

## 真实日志对照

读取本机 sessions/archived_sessions 中 35 个 JSONL。为保证输入不再变化，在临时目录冻结仅包含 Token 事件、模型、会话身份、时间和必要 fork/compaction 元数据的日志，删除提示词、正文、指令和账户字段，按 Session ID 选取完整副本后得到 29 个会话。真实日志未放入交付源码。

实际对照命令：

```bash
CODEX_HOME=/tmp/codexpulse-frozen npx ccusage@20.0.31 codex session --json --offline --no-cost --speed standard
# 使用 Swift Package 构建的同一核心
# 当时使用改名前的 CLI；新版对应命令为 codex-stats-report
codex-pulse-report /tmp/codexpulse-frozen
```

29 个会话中 **28 个会话总 Token 完全相同**。本工具总量为 **890,273,713**，ccusage 为 **890,139,088**，差额为 **134,625**。差额完全等于最后一条已保存但没有后续 token_count 通知的请求：Input 133,442 + Output 1,183。请求还有 Cached 128,512 和 Reasoning 516，但这两项不重复加入 Total。

对照按冻结文件中的 session_meta.id 关联，未按文件名最后一个 UUID 猜 ID：部分分页日志名同时含两个 UUID。ccusage 的 inputTokens 是非缓存输入，需加 cacheReadTokens 才对应本应用 Input。其 compaction 模型会使用 fallback，本应用保留 Unknown model，因此没有宣称模型标签完全一致。

此次真实对照发现并修复了合成测试最初遗漏的问题：压缩后 thread_token_usage 与 total_token_usage 存在持续偏移，交叉差分会重复计量。已增加专门回归测试，不以“测试绿”代替真实核对。

核对过的上游源码：

- Codex：`2f05c0a71f59fb2f05800846351f3e9926c3e52b`，protocol TokenUsage、TokenUsageRecord，以及子会话历史记录策略。
- ccusage：`57afdc255fcbe031b0ecd7cac487f8fd7c5d531f`，Codex parser/replay 与说明。

ccusage 的输出只作为独立交叉证据，不作为计费权威或固定 oracle。两者都无法恢复未保留的日志。

## 原生构建与安装产物

实际执行：

```bash
./Scripts/build-macos.sh
./Scripts/make-dmg.sh
codesign --verify --deep --strict "dist/Codex Stats.app"
plutil -lint "dist/Codex Stats.app/Contents/Info.plist"
hdiutil verify dist/CodexStats.dmg
```

交付包含源码 ZIP、ad-hoc 签名的 Apple Silicon `.app` 和 DMG。App 使用系统 SwiftUI、AppKit、Charts、Foundation，没有第三方运行时。Info.plist 设置 LSUIElement，二进制最低部署版本为 macOS 14.0。

已通过 LaunchServices 打开 App 并确认本机进程存在。没有将程序自动安装到用户的 Applications，也没有更改 Gatekeeper、系统主题或登录项。

## 初次交付的未验证与限制

**本机 UI 自动化服务在读取 App 和系统状态时连续超时。** 无法通过点击完成菜单栏、Overview、Models、Sessions、排序/搜索、设置错误恢复及深浅色布局验收，也没有截图证明。原生编译和进程启动不等于上述交互已验证。建议在该版本上完成以下人工验收后再作为稳定版使用：

1. 点击菜单栏图标，切换四档时间，检查准确数字和刷新状态。
2. 打开三个分析页面；确认模型排序、会话搜索、详情各模型之和一致。
3. 切换浅/深色、缩放窗口，检查长模型名及宽表格。
4. 设置无效目录，确认错误提示与设置入口可用，再恢复正确目录。
5. 执行一条 Codex 请求并刷新；对照离线 JSON CLI。

尚未实机验证 macOS 14、Intel Mac、正式 Developer ID 签名/公证、Linux Core 构建；未测试超大规模目录的长期使用。未验证旧 fork 会显示风险；缺失历史、损坏/部分日志、无身份 last-only 事件等会造成明确标注的少计或不确定性。详见 README 的统计规则。

## v0.2.1 名称修正

2026-10-14：将产品名统一为 **Codex Stats**，同步菜单栏、分析窗口、辅助功能标签、App 包、可执行文件、图标资源、Swift Package 目标、安装脚本与源码 ZIP/DMG 名称。保留原 bundle identifier 和 UserDefaults 键，继续使用已有设置。

再次实际执行 `./Scripts/test.sh`，38 项测试全部通过；`./Scripts/make-dmg.sh` 构建成功；新版 App 的签名与 Info.plist 验证通过，显示名称为 Codex Stats，可执行文件为 CodexStats。此修改不代表此前未完成的 UI 交互或 macOS 14 验收已通过。

## v0.2.2 退出入口与重复实例修复

用户提供的截图显示菜单弹窗、总览与会话详情已由用户实际打开。截图中的菜单退出文字太淡，分析窗口缺少退出入口。已将菜单退出替换为带边框的「退出应用」，在分析窗口侧栏底部增加同一按钮，并明确注册 ⌘Q 退出命令。关闭分析窗口仍保留菜单栏应用。

新实例启动时按 bundle identity 检查已有实例，激活先前运行的实例并退出新实例。用户更新前仍需退出旧版：新版本无法让已启动的旧进程自动具备新功能。另为趋势图补上 PointMark，使今日仅有一个日期时有可见标记。

实际执行 `./Scripts/test-app-lifecycle.sh`，结果为 **PASS: real app launch, duplicate-instance rejection, normal AppKit termination**。该测试通过 LaunchServices 强制再次启动真实 App，确认原 PID 保留且新副本退出，再通过 AppKit 正常终止；没有使用模拟进程。测试结束无 Codex Pulse/Stats 应用实例运行。

这项检查验证的是进程生命周期，不代表实际点击退出按钮、⌘Q、修正后布局、深色模式或 macOS 14 已完成验收。

## v0.2.3 刷新间隔与总览布局

默认自动刷新间隔改为 30 秒，可选择 1 分钟、5 分钟、15 分钟或关闭自动刷新。已有关闭偏好保留；没有保存过间隔的用户使用 30 秒。菜单、分析窗口顶部与设置页同步显示间隔，成功刷新时间显示到秒；扫描失败不会产生虚假的成功时间。

总览参考用户提供的 CC Switch 截图，调整为四张紧凑指标卡、集中刷新/筛选栏、全宽柱状趋势、模型排行与完整明细。按用户选择保留四档时间，不增加自定义日期选择器。今天按小时展示，其余范围按日。小时桶在原有去重逻辑之后聚合，未改变 Token 计量口径。

实际验证：

- `./Scripts/test.sh`：**41 tests passed，0 failures**。新增三项小时汇总测试，覆盖小时之和与原汇总一致、重复快照不重复进图、本地跨午夜、夏令时 23/25 小时及重复小时。
- 临时原生 AppKit 运行检查直接实例化 `UsageStore`，读取合成 fixture，不修改用户应用设置；确认默认自动间隔为 30 秒，并在等待 32 秒后观察到另一次成功扫描。结果保存在 `dist/refresh-results.txt`。
- 同一冻结输入再次运行 `xcrun swift run codex-stats-report /tmp/codexpulse-frozen`：Input 886,003,220 + Output 4,270,493 = **890,273,713**，与之前验证结果一致。
- `./Scripts/render-ui-previews.sh`：真实 NSHostingView 渲染总览/菜单四张深浅色 PNG，已查看并修正横轴时间格式。图片仅含合成数据；不依赖超时的 UI 自动化服务，不捕获用户屏幕、不更改系统主题。
- `./Scripts/make-dmg.sh`：原生构建及新版 DMG 生成成功。

本轮补齐的是总览/菜单的静态深浅色渲染检查。菜单栏真实点击、交互、其他页面的深浅色验收及 macOS 14 实机验证仍未完成。

## v0.2.4 请求日志与可核对详情

新增「请求日志」页面，支持四档时间、动态模型筛选、项目/模型/会话/请求/Turn ID 搜索，以及时间、总 Token、模型排序。点击行或「查看」打开详情，展示真实身份、六项 Token 明细、统计依据、压缩标记与可展开的原始用量/累计快照；只复制存在的真实 ID。

记录在原有计量逻辑完成去重、有效时间和溢出检查后产生，未改变汇总口径。独立 response_id、最近一次用量、累计增量和初始快照分别标注；累计记录可能覆盖多次请求，不显示为已确认请求数量。exec 的通用事件 ID、缺失 session_meta 时的文件归组名称不会伪装成真实请求或会话 ID。缺失缓存/推理字段仍明确显示未完整记录，没有增加费用、缓存写入、状态码、速度或耗时估算。

实际执行与结果：

- `./Scripts/test.sh`：**48 tests passed，0 failures**。新增七项测试覆盖真实请求身份、旧格式计量依据、跨日及模型切换、未知字段、exec 事件身份、归档重放与压缩、缺失会话身份。测试辅助函数还检查每份扫描结果的逐条记录之和与总量及会话模型明细一致、内部记录标识唯一。
- `xcrun swift run codex-stats-report /tmp/codexpulse-frozen --records`：29 个冻结会话输出 **6,714 条唯一独立请求记录**。Python 核对四项 Token 数值与 known 标志在全局、每个会话、每个模型均一致；真实会话身份和 ISO 8601 时间有效。总量仍为 **890,273,713**，与此前独立对照一致；未将真实冻结日志加入源码包。结果保存在 `dist/records-verification.txt`。
- `./Scripts/render-ui-previews.sh`：生成总览、菜单、请求列表、请求详情共八张原生深浅色图片，使用合成日志。已查看请求列表与详情并修正背景和筛选控件的渲染。
- `./Scripts/make-dmg.sh`：v0.2.4 / build 6 的 Apple Silicon App 和 DMG 构建成功。`codesign --verify --deep --strict`、`plutil -lint`、`hdiutil verify` 均成功。源码 ZIP 不包含真实日志、导出数据或构建缓存。

静态图片验证不等同于真实点击：新页面的点击/筛选/搜索/关闭详情与复制操作尚待安装后人工确认。未重启用户正在运行的旧版本，也未将本轮新增交互记为已通过 UI 自动化。macOS 14、Intel 和正式签名/公证限制仍然存在。

## v0.2.5 Token 单位与 Trellis 文档追踪

2026-10-14：修复趋势纵轴与 TokenDetails 的数字显示。App 共用固定 en_US_POSIX 的 K/M 格式，不使用科学计数法或中文「万 / 亿」，十亿以上仍显示 M；M 最多两位小数，K 最多一位。999,950 起提升为 1M，避免舍入显示 1000K。明细提供精确数字 help，卡片保留精确副标题；未知字段仍为未完整记录。

实际执行与审查结果：

- `./Scripts/test.sh`：**48 tests passed，0 failures**。
- `./Scripts/test-token-display.sh`：**en_US、zh_CN、fr_FR 均通过**。检查 16 个整数边界（包含科学计数法截图中的 400,000,000、十亿及临近百万晋级）、小数 Double 轴刻度、Int64.max、未知字段和精确原值。脚本编译 App 的真实 formatter，未复制一套测试实现。独立 check 角色再次运行该脚本通过。
- `./Scripts/render-ui-previews.sh`：生成 **10 张**原生浅 / 深色图，包括今日、7 天总览、菜单、请求列表和详情。仅使用合成日志；放大到数亿及超过十亿以验证 50M / 200M / 400M 轴刻度和 1606.4M 周总量。实现和独立审查均目视查看相关页面。
- `bash -n Scripts/test-token-display.sh Scripts/render-ui-previews.sh`：通过。未配置额外 Swift linter；Swift 原生编译承担类型检查。Swift Package 仍有 CLT 搜索目录警告，没有以警告消失作为测试结果。
- Core 两文件和 CLI 源码与 v0.2.4 源码 ZIP 逐字节相同，没有修改统计或 JSON 协议；本轮无需再次运行同一真实日志的 ccusage 对照。
- `./Scripts/make-dmg.sh`：v0.2.5 / build 7 原生构建成功；App ad-hoc 签名、Info.plist、DMG 校验通过。最低部署版本由 vtool 确认为 14.0。

项目需求与设计保存于 docs/requirements.md、docs/design.md，并关联 Trellis 父 / 子任务。数字格式的实际代码契约进入 .trellis/spec/frontend/token-display.md；其他初始化占位未被宣称完成。根目录没有 Git 仓库，因此本轮没有 commit，也未自动初始化 Git。

UI 原生静态图片不代表真实悬停或点击验收，macOS 14 实机及正式签名 / 公证仍待完成。本轮未关闭或替换用户正在运行的旧实例；安装时应先退出旧版，再替换 App。

## v0.2.6 扫描、物理历史与请求侧栏

本轮按 Trellis 父任务及三个顺序子项实施，并分别进行独立检查。根目录仍没有 Git；未初始化仓库或生成虚假 commit。需求 / 设计、实际计量、扫描性能、Turn 性能与显示契约已同步。

### 根因与最终行为

- 原先只取较长物理副本会漏掉回退前确实发生的原生消耗。现在核验显式 owner / response_id，保留所有可证明的历史消耗并全局去重；身份 / 用量矛盾排除并为受影响来源诊断。旧格式无身份累计流仍保守选择，不盲目求和。
- `history_base` 按物理 rollout UUID 和 exclusive byte / ordinal 边界核验。正常引用 / 副本处理为 information，缺失引用、无效边界、冲突等仍为风险。界面按级别 / 类型分组摘要，全部详情可查。
- 首读不再显示伪零值。刷新失败保留成功数据和时间；日期格式复用、每次筛选只计算一次本地日期边界、只做一次排序。严格拒绝旧 Foundation 自动纠正的非法日期 / 时钟 / 偏移，合法输入保持毫秒精度。
- 菜单底注、卡片副标题、会话标题和列表合计补齐共享 K/M；精确数字仍能从 help、原始计量详情与 CLI 核对。
- 原生请求表格恢复可见时间，详情在右侧展开。单请求耗时 / 速度无日志字段，显示 —。另列完整 Turn 的明确 duration / TTFT，只有全 Turn 响应集合覆盖确认才计算均速；分子不受日期 / 模型 / 搜索截断，明确包含工具及等待。

### 固定数据准确性

独立 Python oracle 只读取 Token 身份与计量元数据，不复用 Swift 差分算法。固定捕获窗口保留 41 个物理日志的 69,915 行、405,813,861 字节位置，用空 payload / 尾部空白替换正文，保持历史引用边界。源日志捕获期间有增长，因此这不是单一时刻的在线总量；对同一固定输入的对照有效。私有快照仅用于本机验证，不进入源码、DMG 或 fixture。

最终 release CLI 与 oracle 核对：**8,229 个原生响应、1,089,263,663 Tokens**；无遗漏、多计、重复、所有权 / Turn / 四项用量差异，全局 / Session / model 四项合计一致。此前 29 个冻结会话仍为 **6,714 条记录、890,273,713 Tokens**。统计较旧选择单副本的结果增长可由真实响应身份解释，不要求错误旧算法的总量不变。

### 固定合成性能

串行前后基准输入为 39 个文件、65,000 行、349,964,213 字节、7,020 条已计入记录、9,043,780 Tokens。基线是计量修复后、性能优化前的 Core。输出完整快照逐字段比较四档筛选、记录 / 排序 / 身份 / 模型 / 原始快照、Session、日期 / 小时及诊断，完全一致。

| 操作 | 优化前 | 独立性能检查 |
|---|---:|---:|
| 新进程冷扫描 | 8.265 秒 | 3.472 秒 |
| 未变更重扫 | 64.20ms | 54.64ms |
| 单文件追加重解析 | 323.05ms | 122.39ms |
| 今天筛选与排序 | 1538.04ms | 11.87ms |
| 7 天 | 4901.44ms | 17.76ms |
| 30 天 | 2625.66ms | 16.63ms |
| 全部 | 35.98ms | 17.37ms |

cold 表示新进程解析缓存为空，未清空 OS 磁盘缓存。5 秒 cold / 100ms warm / 50ms 筛选是本机 workload 目标，不是所有 Mac 的保证。增长文件仍全文重解析，尚无持久缓存或字节级追加。

### 验证边界

26 张原生 NSHostingView 合成深浅色预览覆盖总览 / 菜单 / 请求列表及 1120 与 950 宽度的侧栏、已知 / 未知性能、分组诊断、首次读取、真实空和错误状态；预览使用独立 UserDefaults suite，不污染安装偏好。已查看时间列、侧栏、单位、诊断和错误布局。

尝试的 offscreen 原生表格程序选行没有触发 SwiftUI selection，AX 树也未暴露可操作按钮；该实验未通过，已移除失败实验 harness，没有记录成点击成功。真实鼠标选行、Esc / 关闭、搜索 / 排序、复制与菜单点击仍需安装后人工验收。当前宿主 macOS 27.0.1；macOS 14、Intel、Developer ID 和公证仍未验证。

### 本轮实际命令与结果

- `./Scripts/test.sh`：最终独立检查 **100 tests passed，0 failures**；新增覆盖非法完成副本、无法归属且无时间的响应、全部物理副本的未配对累计帧等真实失败回归。实施阶段 96、检查中间阶段 98 的数字仅为历史 gate。
- `./Scripts/test-token-display.sh`：en_US / zh_CN / fr_FR 的 16 个边界、Double 轴刻度、unknown 和 exact 原值检查全部通过。
- `./Scripts/test-usage-store.sh`：真实异步扫描、首次 pending、失败保留数据与成功时间、根目录切换、真实空报告及过期结果排除通过。
- `./Scripts/build-macos.sh /tmp/codex-stats-inspector-check-build`：独立原生构建、ad-hoc 严格签名验证通过；vtool 确认最低部署目标 14.0。这不是 macOS 14 实机运行证明。
- `./Scripts/render-ui-previews.sh /tmp/codex-stats-inspector-previews`：最终 **26 张**合成原生预览通过；未更改系统主题或安装偏好。
- `xcrun swift build -c release --product codex-stats-report`：最终 Core 的 release CLI 构建通过。临时独立 Python oracle 对同一固定元数据快照核对身份、四项用量及全层合计通过；只保存聚合结果到 `dist/native-oracle.json`，私有快照不分发。
- Shell 语法检查与 Swift 原生类型检查通过。没有配置额外 Swift linter；工具链仍报告 CLT 库搜索目录警告，没有将它们伪装为已消除。

最终集成版串行执行 `./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed Sources/Core final check-baseline`：完整计量快照再次完全一致，cold **2.778 秒**、warm **52.63ms**、追加 **118.80ms**；今天 / 7 天 / 30 天 / 全部筛选分别 **10.18 / 17.07 / 16.99 / 17.88ms**，仍满足本机目标。该合成 fixture 没有完整 Turn 生命周期，证明基础扫描 / 筛选无回退，不代表所有真实 Turn 数量规模的独立性能保证。

发布执行 `./Scripts/make-dmg.sh`：**v0.2.6 / build 8** 的 Apple Silicon App 和 DMG 构建成功。`codesign --verify --deep --strict`、`plutil -lint`、vtool minOS14.0、`hdiutil verify` 均通过。`./Scripts/test-app-lifecycle.sh "dist/Codex Stats.app"` 实际 LaunchServices 启动、拒绝新副本、保留原 PID、AppKit 正常退出 **PASS**，结束无测试应用残留。仅操作测试自身启动的实例，没有替换安装应用；生命周期 PASS 不等于真实按钮点击。

额外只读挂载 DMG，确认其中 Info.plist 为 v0.2.6 / build 8，实际可执行文件与已校验 App 逐字节一致，再卸载自身挂载。完成任务归档和无 Git journal 后刷新源码 ZIP，校验完整性、脚本执行权限、文档 / 任务链接和 SHA256；源码包不包含 dist、真实日志、私有元数据、运行缓存或个人 journal。


## v0.2.7 请求估算、扫描内存与模型表格

版本 0.2.7 / build 9。按 Trellis 批准范围实施并独立检查，没有 Git commit。Token 计量逻辑保持不变。

- 单条已接受原生响应关联有效事件边界后，显示 ≈耗时和 ≈输出 tok/s；时长取 100ms 到 1 小时，速度要求输出至少 200 Tokens 且耗时至少 1 秒。包含首字等待及可能的重试，不是实测纯生成速度。累计 / 初始快照、压缩、缺失或冲突边界仍显示 —。请求估算与完整 Turn 的明确计时分开。
- JSON 行解析和 FileHandle 分块读取都有局部 autoreleasepool，释放扫描临时对象。模型表格使用原生 Table 统一滚动；模型列 150 点，数值列 76 点，名字单行，完整名字可查看 help。
- ./Scripts/test.sh：独立检查 114 tests passed、0 failures。新增 14 个请求估算测试覆盖身份、延迟、重复、切换、损坏、压缩、阈值和中断等边界。
- ./Scripts/test-token-display.sh：三个 locale、16 个数字边界通过。./Scripts/test-usage-store.sh：真实扫描、首次加载、失败保留、切换根目录、零值和过期结果通过。
- ./Scripts/render-ui-previews.sh /tmp/codex-stats-v027-final-previews：30 张原生合成深浅色预览通过，含模型 950/1120 点、请求与侧栏、已知 / 未知估算。harness 断言请求为 45 秒、53.3 tok/s；已查看渲染的完整 Turn 为 120 秒、30 tok/s。静态预览不代表真实点击 / 滚动验收。

固定 349,964,213 字节 / 39 文件基准：./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed Sources/Core v027 final。7,020 条记录、9,043,780 Tokens，完整计量快照与 v0.2.6 基准逐字段一致。新扫描器峰值 footprint 61.45 MiB，最大 RSS 83.53 MiB；原基线 footprint 788–795 MiB。cold 3.185 秒、warm 75.18ms、追加 123.17ms；今天 / 7天 / 30天 / 全部筛选 11.25 / 22.37 / 21.10 / 22.94ms。cold 是新进程，不清空系统磁盘缓存。

实际原生 App 同输入单独验证：./Scripts/measure-app-memory.sh <built-app> /tmp/codex-stats-performance-fixed/fixture <output>。测试复制实际已构建 App，使用唯一临时 bundle ID，10 秒与 35 秒以 vmmap 采样，并仅正常退出自身实例。二进制不替换，未关闭用户运行的旧 App。

| App | 10 秒当前 / 生命周期峰值 | 35 秒当前 / 生命周期峰值 |
|---|---:|---:|
| v0.2.6 build 8 | 117.2 / 746.6 MiB | 44.0 / 746.6 MiB |
| v0.2.7 build 9 | 26.4 / 30.7 MiB | 28.0 / 35.5 MiB |

峰值下降约 95.2%。这些是指定日志与采样窗口的 App footprint，不能保证任意规模或长时间运行的峰值，也没有自动断言界面扫描完成。RSS 与 footprint 分开报告。测量脚本的失败路径测试也确认只退出自身测试实例。

一次只读真实日志元数据审计有 8,520 条计入记录，其中 6,754 条有请求时长、4,651 条符合速度阈值；不是所有行都能补出估算。真实日志会增长，该次审计不是固定输入前后计量等价证明。

当前宿主 macOS 27.0.1 / Apple Silicon；macOS 14 实机、Intel、实际鼠标菜单 / 选行 / 滚动、正式签名与公证仍未验证。默认刷新保持 30 秒，完全离线，不读取 auth.json。安装时先退出旧版，再替换 App。

发布 ./Scripts/make-dmg.sh 完成 v0.2.7 / build 9；codesign --verify --deep --strict、plutil、vtool minOS14.0 和 hdiutil verify 通过。发布 App 可执行文件与实际内存测量的 build 9 二进制逐字节一致。Trellis 独立全范围 gate PASS，任务已归档。源码 ZIP 排除真实日志、dist、运行缓存及个人 journal。


## v0.2.8 紧凑菜单与常驻策略

版本 0.2.8 / build 10。菜单宽度从 368 降为 320 points，正常预览约 399 points 高。压紧标题、Token两列指标、两个主要模型和底栏；去掉重复总量底注，诊断采用单行摘要，完整详情转到分析窗口。

MenuWindowProbe 只弱关联自己所在的 NSWindow，打开分析前关闭该菜单窗口，不关闭 NSApp.keyWindow。旧探针移除不会擦掉新宿主引用；分析窗口聚焦后菜单仍能再次打开。后台策略采用 NSSupportsAutomaticTermination=true 配合 launch 时 disableAutomaticTermination，最后窗口关闭明确不退出。不是开机自启、不禁止睡眠、不添加重启守护，也不能阻止崩溃或 OS 强制终止。

实测 / 命令：
- ./Scripts/test.sh：114 Core tests passed、0 failures，计量代码未改。
- ./Scripts/test-menu-lifecycle.sh：真实 LaunchServices 测试 bundle，生产 AppDelegate 的启动通知、准确宿主关闭顺序、分析窗口不受影响、重复 / 替换宿主及过时探针移除、关窗后保留进程、显式正常退出全部通过。它验证原生 AppKit 宿主和策略，不是实际 SwiftUI MenuBarExtra 鼠标点击证明。
- ./Scripts/test-token-display.sh：独立三 locale、16 边界检查通过。
- ./Scripts/render-ui-previews.sh：原生合成明暗预览通过；已看 /tmp/codex-stats-v028-menu-previews/menu-light.png 和 menu-dark.png，320×399 points，无指标 / 底栏裁剪。
- ./Scripts/make-dmg.sh：原生 arm64 App / DMG 构建；strict codesign、Info.plist lint、minOS14.0 和 hdiutil verify 通过。未完成正式 Developer ID 签名或公证。
- ./Scripts/measure-app-memory.sh：实际发布 App 的独立 bundle identity、固定350 MB输入，10s当前26.3MiB / 峰值30.5MiB，35s当前27.8MiB / 峰值35.5MiB；仅终止测试自身实例。实际进程70990的 AppKit 日志为 TAL eligibility=0。采样不能当作长期不退出或 UI 完成刷新的证明。
- ./Scripts/test-app-lifecycle.sh /tmp/codexstats-v028-lifecycle.iNnNUe/Codex\ Stats.app：实际发布 App 临时独立 bundle ID，保留原 PID、重复实例退出、显式 AppKit 终止通过。没有操作用户原来的实例。

此前运行的 v0.2.7 App 出现过 TAL eligibility=1，但没有找到对应 CodexStats 崩溃或当日15:47 Jetsam记录；这是可能被空闲自动终止的线索，不能据此确诊用户先前自行消失的原因。本轮 CUA 关闭按钮操作超时，未当作成功，真实菜单点击 / 再次展开和长期后台驻留仍需安装后观察。macOS 14 实机 / Intel 尚未验证。当前用户仍从挂载 DMG运行旧版；建议先退出旧版，将新 App 拖入 Applications 后启动。

独立全范围 gate PASS，任务归档；只读挂载核对 DMG v0.2.8/build10、resident Info键及可执行文件与发布 App 一致，已卸载自身挂载。源码包完整性和脚本执行权限校验通过，不包含真实日志或个人journal。


## v0.2.9 窄版菜单与设计对比

正式菜单从320缩至288 points，时间选择器固定292导致的溢出通过适配菜单260points修复；分析窗口仍使用默认292。未知缓存/推理完整可读，长模型名省略并保留help。Token计量、菜单窗口关闭和常驻逻辑未变。

- ./Scripts/test.sh：114 Core tests、0 failures。
- ./Scripts/render-ui-previews.sh /tmp/codex-stats-v029-width-previews：生产窄菜单及空、错误、未知字段、深浅色原生合成预览通过；已查看正常浅色、错误深色和空状态，没有数字/退出裁剪。
- ./Scripts/render-menu-designs.sh：两套独立SwiftUI布局A288×420、B288×469points，同一合成306.08M数据，不读取日志或偏好。4张单方案和2张并排明暗图通过，已查看。原型不进入Sources/App或Package运行时目标。docs/menu-design-comparison.html只展示原生截图，可切换浅/深色。项目无Git，原型清楚标记保存在独立测试目录，不虚构临时分支。
- 独立 token-display 三locale检查、menu-lifecycle原生宿主关闭/关窗驻留回归通过。新增/变更Shell脚本语法通过。未配置通用Swift formatter；默认swift-format与现有风格不符，不宣称lint通过。
- ./Scripts/build-macos.sh /tmp/codex-stats-v029-release：实际arm64原生App0.2.9/build11构建通过；DMG从该临时构建目录制作，避免在dist留下额外可被启动台识别的App副本。未替换用户安装或运行实例。

A/B尚未选定，正式版只缩窄现有设计。静态原生预览不证明真实菜单点击或悬停；长期驻留、macOS14/Intel、正式签名/公证仍待验证。源码包排除真实日志、运行缓存和个人journal。

发布严格签名、Info lint、minOS14.0、DMG校验通过。已只读挂载核对v0.2.9/build11与实际构建可执行文件逐字节一致，卸载自身挂载。

独立质量检查PASS、任务归档，源码ZIP包含设计对比HTML和可重现原生原型源码，完整性/脚本权限检查通过。尚未选择A或B，不将方案评选视为已完成正式全App改版。


## 2026-10-15 文档驱动重建基线（产品仍为 v0.2.9 / build 11）

用户在原生 A/B 比较后选择 B。前节“尚未选择”是当时状态；当前 B 为已批准待实现方向，生产 App 尚未改为 B。本次只同步文档与治理规则，没有发布新的 App 或再次声称 UI 实机通过。

- 新增 docs/ui-design.md、docs/data-design.md、docs/ui-design-b.md；重写 docs/design.md 为可重建入口，记录当前布局数值、数据协议、计量状态机、刷新偏好、生命周期、构建和验收边界。需求与 README / 比较页同步选择状态。
- AGENTS.md managed block 外及 .trellis/spec/guides/design-first.md 规定：以后先更新需求和设计再实现；批准目标与已实现基线分开。
- 本次最终机械核对 57 个本地链接和 Markdown 代码块闭合，0 错误；Sources / Tests / Scripts / Assets 的 40 个文件 SHA256 与本次修改前一致。未重新运行 Core、原生构建、安装或 UI 自动化，历史结果见前节。
- 独立源码复核指出两个边界：会话详情缺 session_meta 时仍显示/复制内部文件名 ID；原生 owner 判断对比内部归组 ID，理论上缺元数据但 thread_id 等于文件名时可通过。当前文档明确这些差距，不冒称完整满足真实身份目标；本次没有改产品行为。

本轮不清理用户安装、不修改日志或个人 memory、不完成仍在初始化的 bootstrap task；项目没有 Git，未虚构 commit。

独立 Trellis 全范围文档复核 **PASS**；补正 owner 判断、会话身份展示及 compact 诊断高度等源码事实。对比页两张内嵌 PNG 解码有效，均为 1280×1076。


## 2026-10-15 本地 Git 与目录规范（App 仍为 v0.2.9）

按用户要求执行 `git init -b main`，仓库根为当前 codex-stats 目录；main 尚无首次提交，未暂存文件、未配置远端，未公开发布。先编写 docs/repository-layout.md，再更新忽略规则与贡献指南。保留 Sources/Tests 的 Swift Package 命名以及现有 Assets/Scripts 路径；仅用 rmdir 移除确认为空的根 Fixtures，Tests 内合成数据不变。

- `xcrun swift package describe --type json` 成功：Core/App/Report/测试四个目标仍可识别。
- 12 项生成物/个人状态忽略断言、7 项源码/合成 JSONL/共享规范保留断言通过；Git root/main/无提交/无暂存/无远端断言通过。
- 本次检查 59 个项目文档本地链接有效；40 个产品文件与之前基线 SHA256 及文件清单一致。仅仓库元数据、规则及文档变化，未重复执行无关 App 构建/计量测试。

本地测量 `.build` 约 581 MB、dist 约 18 MB，是构建/交付产物，并非产品源码体积或 App 运行内存。未删除这些产物。新增 CONTRIBUTING；许可证仍待维护者选择，历史任务和验证记录尚需公开前审阅，不将 Git 初始化等同于开源发布完成。

独立 Trellis 全范围仓库规范复核 **PASS**，无阻塞项；未创建首次提交。


## 2026-10-15：首次公开源码（R14/R17）

- 用户批准公开仓库与 MIT，`gh repo create lixd/codex-stats --public --source . --remote origin` 成功；`git push -u origin main` 成功。
- `gh repo view lixd/codex-stats --json nameWithOwner,url,visibility,defaultBranchRef,licenseInfo`：PUBLIC、main、MIT。
- 初始提交 `46c0e5305690190e188b5c57ac8996e074688d2d`；`git rev-parse HEAD`、`git ls-remote origin refs/heads/main` 和 `gh api repos/lixd/codex-stats/commits/main --jq .sha` 三者一致。
- `./Scripts/test.sh`：114 tests passed，0 failures，exit 0。现有 CLT 搜索路径 linker warnings 未影响编译与测试；不新增 UI 点击或 macOS 14 实机验收结论。
- 初次提交前审阅拟公开文件和忽略规则；凭证形态模式扫描无候选，用户目录匹配为工具中通用 Windows 路径示例。此为限定模式检查，不保证识别所有敏感信息。真实日志、个人 journal、构建产物不提交。
- 原创 App/测试/资源/项目文档 MIT；Trellis 0.6.17 独立开发工具和模板保留 AGPL-3.0-only，原文散列 d8a6cc31abc16b6748c7a21f21611f5a1ec33f67d22ca23d7da1c19b95496bee，路径归属见 THIRD_PARTY_NOTICES.md；工具不进入 App 运行时。
- 独立复核通过，首次导入仍保留 3 个既有文件中的 4 处空白检查提示（两处 Markdown 硬换行及两个 EOF 空行），没有把空 diff 或全量 whitespace 检查记为通过。详见归档任务的 check-result.md。
- 产品 40 个文件散列与整理前一致；App 保持 v0.2.9/build 11，B 方案仍待实现。此次只公开源码，不创建 GitHub Release 或上传 DMG。

## v0.2.10 / build 12 第一批精修（2026-10-15）

最终代码已原生构建为 arm64、macOS 14.0 部署目标，宿主仍为 macOS 27.0.1 / Apple Swift 6.4 / SDK27。B 菜单生产接入、真实会话身份隔离、单个当前范围摘要缓存和中文指标文案已实现。设计先于实施，Trellis独立检查发现的未知归档副本重复计量及内部键误匹配父引用均已修正；时区变化需重启的限制明确保留。

实际执行与结果：

| 命令 / 检查 | 结果及证据边界 |
|---|---|
| `./Scripts/test.sh` | 最终121项通过、0失败，包含7项新增身份回归；同时编译App目标。CLT已有链接搜索路径警告不影响成功结果 |
| `./Scripts/test-usage-store.sh` | 真实扫描状态、单摘要复用与报告/范围/日期/根路径失效、未知字段、一致性通过；时区仅检查缓存键，未验证运行中重新分桶 |
| `./Scripts/test-token-display.sh` | en_US/zh_CN/fr_FR 各16边界、图表共享格式、未知与完整值通过 |
| `./Scripts/test-menu-lifecycle.sh` | 独立AppKit harness精确窗口关闭顺序、复用/替换、驻留和正常终止通过；不是生产MenuBarExtra鼠标点击 |
| `./Scripts/render-ui-previews.sh /tmp/codexstats-v0.2.10-previews` | 原生明暗渲染通过；16个菜单状态，正常288×466pt、首次加载288×270、真实空288×409、错误288×306、单一Unknown model且已知十亿指标288×415；无固定高度。另含950/1120表格与详情、诊断、已知/未知计时。所用数据均为合成 |
| `./Scripts/build-macos.sh /tmp/codexstats-v0.2.10-release` | 最终父引用修复后构建成功；0.2.10/build12，codesign严格验证通过；vtool确认minOS14.0 |
| `hdiutil create` / `verify` / 只读挂载 | DMG校验成功，内含App签名/版本/最低系统核对，二进制SHA256与最终构建相同，Applications链接正确。宿主hdiutil有弃用提示，命令仍成功 |
| `git diff --check` / 当前文档相对链接 / README行数 | 通过；README保持70行以内 |

固定输入性能使用 `benchmark-performance.sh`。baseline Core在修改前单独保存，release为最终父引用修复后代码，均由同一脚本生成约349,964,213字节、39文件、7,020记录，总量9,043,780。精确快照（记录/顺序/模型/会话切片/日/小时/诊断/四档范围）前后完全一致。新身份反例的有意排除由单独回归测试断言。

| 指标 | 修改前 | 最终代码 |
|---|---:|---:|
| 新进程冷扫描 | 3.167s | 4.577s |
| 未变文件重扫 | 58.91ms | 79.30ms |
| 单文件受控追加 | 132.47ms | 161.44ms |
| 扫描峰值footprint | 59.75MiB | 60.42MiB |
| 最大RSS | 80.30MiB | 79.92MiB |

最终四档筛选18.23–33.20ms。以上为单次受控运行，宿主存在并发编译负载；没有清除系统磁盘缓存，也不据此声称扫描器提速。本轮减少的是界面重复聚合，原生Store通过同键对象身份与失效断言证明复用；没有量化真实界面帧耗时。冷扫描≤5s、warm≤100ms、筛选≤50ms目标本次通过。

`./Scripts/measure-app-memory.sh` 对最终构建的临时UUID身份App及同一合成fixture执行：10秒当前footprint25.4MiB、峰值30.0MiB；35秒当前26.8MiB、峰值34.3MiB，正常终止仅自己的实例。系统输出一次sandbox extension权限提示，进程启动/两次vmmap/正常退出均成功。采样不证明所有页面已打开、扫描完成时刻或长期运行；不是用户真实日志的实时占用。完整UI内存与CLI扫描峰值不可混用。

未新增实际MenuBarExtra鼠标操作、macOS14/Intel实机、睡眠唤醒/长期常驻、VoiceOver验收、Developer ID签名或公证。系统时区切换后需重启重建扫描日期桶。分析窗口布局大改、详情自适应、持久/追加缓存均未实施。无安装新副本，交付临时构建App与dist中的DMG/源码包。


## v0.2.11 / build 13 审查修复（2026-10-15）

先更新需求与设计，再按用户批准的A01–A06实施：配对通知重发去重、异常子项差分标unknown、完整Turn索引、批量会话投影、跨页统一状态与详情、构建安装暂存校验和原子替换。A07窄窗口布局延期。当前源码与临时原生构建为v0.2.11/build13；未安装、退出或替换用户App，未提交、推送、制作发布包或公开发布。

本轮全部使用合成数据，与历史测试分开。宿主macOS27.0.1 / arm64 / Apple Swift6.4 / SDK27。完整命令、原始证据、异常尝试与限制见[集成验证](.trellis/tasks/archive/2026-10/10-15-small-beautiful-fixes/verification.md)，设计契约见[修复设计](docs/audit-fixes-design.md)。

| 当前执行 | 结果 |
|---|---|
| `Scripts/test.sh` | 133 Core tests、0 failures；含新增计量/Turn/日期边界，App目标编译成功 |
| 数字格式 / 真实Store / 菜单宿主 harness | 3×16格式边界及unknown/exact、重试保留错误与旧数据、信息级恢复、准确宿主关闭与驻留均通过 |
| 独立计量复现 / 全JSON差分 | 原审查总量与unknown问题修正；126组pre-index/current明细、身份、诊断及可选计时完全相同 |
| `Scripts/test-app-delivery.sh` | 18项真实检查通过；含v1→v2进程内回执、失败保留旧包、运行实例拒绝、嵌套预检零写入和受控中断 |
| `Scripts/render-ui-previews.sh` | 82张原生合成预览，重点深浅色/异常/恢复样本目视复核；不是点击证明 |
| 优化原生构建、签名、部署目标、依赖检查 | v0.2.11/build13；strict codesign、plist、minOS14.0、仅系统框架/Swift运行库通过 |
| 独立UUID实际产品生命周期 | LaunchServices启动、拒绝重复实例保留原PID、正常AppKit退出通过；仅合成路径 |

串行同输入受控基准，baseline为Git `11f2a937971c40b29a2b4d69ff6bb79c5eaec91f`，并非已安装App。完整Turn每组3次warm取中位数；会话投影每组5次中位数。

| 指标 | 修改前 | 当前 |
|---|---:|---:|
| 2,000完整Turn重复扫描 | 4,110.49ms | 15.49ms |
| 5,000会话“今天”底层投影+排序 | 1,568.90ms | 4.58ms |
| 350MB常规新进程扫描 | 2.654s | 2.679s |
| 同常规输入未变重扫 / 追加重读 | 55.32 / 120.21ms | 56.09 / 122.39ms |
| 同常规输入最大RSS / 峰值footprint | 83.70 / 59.56MiB | 83.80 / 59.69MiB |

常规349,964,213字节、39文件、7,020记录、9,043,780Tokens的完整计量快照前后相同，当前四档筛选10.03–18.56ms；该形状没有完整Turn，作为无回退对照。常规为单次配对，新进程不清系统磁盘缓存，不能据此声称普通冷扫描提速。Turn规模250/500/1000/2000均断言完整计量、身份与计时；126组差分另核对否决边界。会话数值是主线程底层计算耗时，不是实际SwiftUI帧耗时。完整scale harness最大RSS85.92→29.41MiB、峰值footprint80.16→19.45MiB，含投影数据构造，不能当成完整App当前内存。

实际优化App的UUID副本在相同350MB合成输入下：10秒当前footprint25.2MiB、生命周期峰值29.8MiB；35秒当前26.6MiB、峰值34.2MiB。vmmap与正常退出成功，保留一次sandbox-extension警告。未用RSS、虚拟地址空间或生命周期峰值冒充当前footprint；也未断言所有页面已打开或长期稳定性。

独立复核发现并修复安装预检前会临时写入嵌套旧App的问题，增加目录mtime与内容散列回归，最终18项交付检查重新通过。静态索引复核确认保留frame/Turn/time/unknown-time的OR覆盖规则及全部物理证据。

当前Mac锁定，CUA无法取得原生目标；详情sheet实际点击/Esc/搜索保留、真实菜单鼠标与VoiceOver仍待验收。macOS14/Intel、睡眠唤醒/长期驻留、正式签名/公证未执行。安装验证仅限当前宿主同卷原语，不承诺外部启动竞态锁或断电持久性；生产版本没有额外IPC就绪握手。用户应用未操作，独立测试实例均已退出。


## v0.2.12 / build 14 青灰与青绿精修（2026-10-15）

先更新需求/设计并记录用户批准，再实现青灰底、内容卡分层、青绿趋势/导航/选中态、独立白字操作底和模型原生表格去空斑马纹。菜单保持B，统计、刷新、窗口几何与生命周期不变。当前源码及独立临时构建v0.2.12/build14；没有安装、退出或替换用户App，没有提交、推送或公开发布。

本轮使用合成日志、独立偏好域，宿主macOS27.0.1/arm64/AppleSwift6.4/SDK27。完整过程与失败尝试见 [任务验证](.trellis/tasks/archive/2026-10/10-15-sage-teal-refinement/verification.md)，独立复核见 [review](.trellis/tasks/archive/2026-10/10-15-sage-teal-refinement/review.md)，当前颜色契约见 [设计](docs/sage-teal-design.md)。

| 本轮执行 | 结果 |
|---|---|
| Core及App编译 | 133tests通过、0失败；初次受限环境SwiftPM失败/运行器未结束，完整宿主重跑通过 |
| 数字格式、真实Store、UUID菜单宿主 | 三区域设置各16边界；summary/unknown/诊断/失败重试恢复；准确菜单关闭、复用/替换、驻留和显式退出通过 |
| 原生深浅色预览 | 88张，覆盖五页/菜单/950与1120点/未知/空/失败/恢复；已目视复核关键样本 |
| 真实NSTableView | 3行和80行均无交替底纹、保留原生NSScrollView；80行程序滚动到末行通过；请求仍保留原生交替行色 |
| 实际动态颜色对比 | 普通自有文字角色最低4.511:1，白字操作4.563:1，风险半透明底最低4.858:1 |
| 优化App构建与包检查 | v0.2.12/build14、arm64、macOS14.0目标、strict codesign、仅系统框架/Swift运行库通过 |
| 独立Trellis复核 | 未发现本轮新增产品缺陷；统计/Store/生命周期/交付脚本与任务起点散列相同 |

构建：`/tmp/codex-stats-sage-teal-20261015/native/Codex Stats.app`；可执行文件SHA256 `13f8d57d85fc634d6fb86c057b0b3499f9c4902b527749719fabcdc298ae8977`。包检查与原始日志保留在同目录上层。本轮没有重新测量性能或内存，不将旧基准写成新配色的收益。

增强对比度的预设描边色数学对比最低3.660:1，**不是系统增强对比度验收**：SDK明确HC名称仅用于bestMatch，不能通过appearanceNamed构造有效外观。已移除误导性HC截图，未改变用户系统偏好。实际系统增强对比度切换/重绘、VoiceOver、鼠标/键盘筛选排序复制与sheet关闭仍待人工验收；macOS14/Intel、正式签名/公证亦未完成。原生表格程序滚动和静态预览不等于上述实际交互。A07全面窄窗口布局保持延期。


## v0.2.13 / build 15 D 布局与双配色（2026-10-15）

按用户要求先完成并验证D布局固定浅青，再加入A晴蓝配色。两种颜色共用D布局，默认浅青、外观跟随系统，设置选择保存。菜单B几何、真实身份/未知字段/风险提示和计量保持。设计先于实现，[阶段与完整验证](.trellis/tasks/archive/2026-10/10-15-native-cyan-blue/verification.md)、[独立复核](.trellis/tasks/archive/2026-10/10-15-native-cyan-blue/review.md)、[当前契约](docs/native-cyan-blue-design.md)。

| 本轮执行 | 结果 |
|---|---|
| Core及App/CLI编译 | 最终133 tests通过、0失败 |
| Store / 数字格式 / 菜单生命周期 | 两配色默认/未知/恢复/切换无扫描或摘要失效，三区域格式、阶段D临时菜单宿主均通过 |
| 两色原生矩阵 | 各120张PNG（88状态/页面矩阵+32同宿主图），浅/深色、1120/950及原生3/80行Table检查通过 |
| 同宿主状态/重绘 | 实际编辑原生文本字段，搜索结果/选中请求/目录草稿保留；Store绑定浅青→晴蓝→浅青使Dashboard/Menu背景像素同步变化；摘要身份/成功时间/路径/范围不变 |
| 对比度 | 自有文字最低4.605:1，白字操作5.418:1，风险合成底4.792:1；预期HC描边数学3.366:1，非实际系统HC验收 |
| 优化构建与包检查 | v0.2.13/build15、arm64、minOS14、strict codesign、仅系统框架/Swift库通过 |
| 独立复核及范围 | 修复旧菜单原型两处Color→ShapeStyle兼容调用；Core/Report/AppLifecycle/交付脚本起始hash未变 |

App：`/tmp/codex-stats-native-cyan-blue-20261015/native/Codex Stats.app`；可执行SHA256 `daf704d1b2c6d774eedcaa20ba264d1701458aeda41cd9f46d3499f8625eb9ef`。本轮全用合成日志/隔离偏好；未安装、启动、退出或替换用户App，未提交、推送或公开发布。没有重新测内存/性能。

自动化通过Store绑定切换，不代表实际鼠标操作了配色Picker、非默认模型/排序Picker或非首项会话；跨进程产品偏好恢复、打开的sheet换色/关闭、复制、系统按钮激活着色和VoiceOver仍待人工验收。macOS14/Intel/长期驻留/实际增强对比度/正式签名公证未执行。初次沙箱失败、像素色彩空间测试修正及不成立的NSPopUpButton尝试均记录在任务验证中，没有当作通过或产品收益。

同目录 `CodexStats-v0.2.13-source.zip` 为本轮更新的源码包（474文件，CRC检查通过，排除个人journal/运行状态/构建缓存/认证文件）。Trellis任务已无提交归档，journal session13已记录；此前脏工作保留。

## v0.2.14 / build 16 请求日志紧凑布局（2026-10-15）

本轮仅针对请求页留白和横向滚动。先更新需求/[紧凑设计](docs/request-density-design.md)，后实现请求页单行头部、16/12边距、8pt间距、原生十列/七列自适应；全部十项字段保留。详情统一为420×600原生sheet，不再挤压列表。其他页/颜色/计量/扫描/生命周期未改。

| 本轮原生测量 | 修改前 | 修改后 |
|---|---:|---:|
|1120×760表文档宽/可视宽|962/887（横向超出75）|903/903|
|950×630表文档宽/可视宽|962/717（横向超出245）|733/733|
|1120表格top/高度|254/459|189/538|
|950表格top/高度|254/329|189/408|
|常显纵向条80行：950 /1117 /1120|本轮未测旧版|文档与可视宽均分别716 /883 /886|

表格上移65pt、可用高度增加79pt。950/1050/1116/1117/1118/1120/1280普通尺寸和950/1116/1117/1118/1120常显条均无横向溢出，实际末列可见。宽度900pt为界十列/七列组合；未知缓存、真实身份和≈含义保留。两配色各147张原生PNG、33请求几何文件；每套9次真实80行末行可达。真实NSPanel的sheetParent为自身宿主，配色切换保留查询/选中行/sheet且无扫描/摘要失效。测试未更改用户系统滚动条/主题偏好。

本轮Scripts/test.sh：133 Core tests通过；App/CLI编译、三个区域真实格式测试、两个独立完整App macOS14 typecheck及优化构建通过。签名/plist/minOS14/仅系统依赖核验通过；最终可执行SHA256为`c1827ce141e7e474f4949f8168b8d0210dbd5421e763ba6902913cd5993e7ac2`。新App路径`/tmp/codex-stats-compact-requests-20261015/native/Codex Stats.app`；未安装、启动、退出或替换用户App，未提交推送。原始日志和PNG在相同/tmp根目录。

[任务最终证据](.trellis/tasks/archive/2026-10/10-15-compact-request-layout/verification.md)与[独立复核](.trellis/tasks/archive/2026-10/10-15-compact-request-layout/review.md)保留本轮范围与中间失败。修复了测试宿主presenter/尺寸及合成NSPanel外观设置；不能把宿主失败算产品缺陷。离屏AX关闭按钮查找失败，未弱化为假成功：实际close/Esc/复制、非默认Picker、鼠标/触控板/VoiceOver与系统增强对比度仍需人工；原生几何/程序滚动不代替这些验收。无本轮内存/帧时间基准，旧性能结果不作为本轮收益。

另用临时真实原生宿主验证请求空态：950×630、浅青/晴蓝×深浅色4图通过，真实Store为空成功报告；所有控件、空提示和底注同屏。证据在同根empty-requests/和empty-requests.log。

## v0.2.15 / build 17 模型 A 分组列表（2026-10-15）

用户选择[A分组列表](docs/model-layout-proposals.md)，先更新需求和原生契约，后将模型八列Table替换为纵向LazyVStack分组。模型名/会话/总量与输入输出/从属缓存推理分层；完整字段、现有六种排序/搜索、共享范围/错误和两配色保持。没有Core/Store/其他页面/生命周期变更。

本轮133 Core测试、三个区域设置各16格式边界、独立完整App和UIPreview macOS14 typecheck、优化构建/strict签名/plist/minOS14/仅系统依赖均通过。最终构建v0.2.15/build17，可执行SHA256 `055eea77f6f6f9da21ab7a9026728b6f032854b266becdbc724a213693f3d42a`；构建后Sources/Assets hash匹配。

| 本轮原生模型测量 | 950×630 document/clip | 1120×760 document/clip |
|---|---:|---:|
|普通样式，两配色×明暗|717/717|887/887|
|legacy启动样式，每配色浅色|700/700|870/870|

cyan/blue各159PNG、14模型几何记录，两脚本均exit0并含普通/legacy两PASS。28份几何均无横向溢出；每配色6张80模型底图独立复核，synthetic-model-0完整可见。192字符模型名、大Token、known0/unknown完整；真实原生输入框搜索→无匹配→恢复与配色往返状态通过。legacy只测两个浅色尺寸，不冒充其深浅色全矩阵。

[本轮任务证据](.trellis/tasks/archive/2026-10/10-15-model-layout-preview/verification.md)、[独立复核](.trellis/tasks/archive/2026-10/10-15-model-layout-preview/research/review.md)记录范围、几何及失败校准。原始产物在`/tmp/codex-stats-model-groups-20261015/`，新App为`native/Codex Stats.app`。用户运行中的App未安装/启动/退出/替换，无真实日志修改、Git提交或推送。

受限SwiftPM manifest/运行器和iconutil分别失败后，在完整宿主重跑通过；没有把失败当通过。滚动条须通过独立测试进程启动参数创建preferred legacy，挂载后强改样式不是同一场景。虚拟AX树不可枚举，精确值语义仅源码复核；实际悬停/非默认Picker键盘/VoiceOver、触控板流畅度、实际增强对比度、macOS14/Intel实机与公证仍待人工。本轮未测内存或帧时间，不声称性能收益。

本轮Trellis已无提交归档，journal session15。相同/tmp目录的`CodexStats-v0.2.15-source.zip`为最终源码包，CRC及产品hash核验通过，排除个人journal/运行态/构建缓存；未覆盖旧dist。

## v0.2.16 / build18：缓存率与离线美元参考估算（2026-10-15）

用户确认官方API标准参考价等值口径并授权自行review后执行。先更新R18/R19、T12/T13设计，主Agent复核后将金额聚合放入后台标量索引，先完成缓存率门禁再接金额，独立checker最终未发现阻塞缺陷。设计见[当前指标契约](docs/cache-rate-cost-design.md)，[本轮任务与完整证据](.trellis/tasks/archive/2026-10/10-15-cache-rate-usd-estimate/research/verification.md)。

**本轮实际执行**：最终宿主`Scripts/test.sh` exit0，**138 tests passed**；真实App格式器en_US/zh_CN/fr_FR、Store扫描/快照原子配对/范围/失败保留/路径重置检查均通过。独立macOS14目标全App typecheck通过。全部输入为合成数据，无真实日志扫描。

根会话另建6条已接受日志作手算核对：输入2800、输出340、总量3140，USD精确**0.00693**，已估1830/未估1310Token。最终源码重编译的Report CLI在总量、模型、会话、会话模型与逐条记录上求和一致；无价格金额null，非完整缓存的计数和比例null，output-only估算USD0.00005且比例状态noInput。预期值先手算，不从产品算法生成。记录与脚本保留在任务research。

原生检查分清时点：缓存阶段双配色完整矩阵、金额双配色完整矩阵均exit0；金额最后移动到模型总量下后，冻结源码再执行**64张专项PNG**，覆盖两配色深浅色、950/1120、overlay/legacy、完整/部分/全未知/微小非零金额及420×600请求详情底部。16份最终模型几何document==clip（717/887或700/870pt），无横向溢出；前面完整矩阵的44份几何由checker独立复核。请求表本轮不改列，纵滚保留。

优化合成100000已接受记录、100会话/10天/4模型：4000桶，新索引构建一次**0.318323583s**，全范围合并一次**0.003881917s**，USD281.2。只测索引时间，**未测本轮RSS、footprint、峰值、虚拟内存或滚动帧耗时**，不能据此宣称完整App内存/流畅度改善。

最终独立构建`Scripts/build-macos.sh /tmp/codex-stats-cache-usd-20261015/native` exit0；Info.plist=0.2.16/build18、arm64、最低macOS14；codesign strict/deep验证通过，链接仅系统库。构建前后15份Sources/Assets哈希一致；可执行SHA256：`9b98a4ade44aa2c9c6e71b1199a5fe0611880f58179f8ab92def7af80bb16b27`。初次构建遇到最后AX修改并发，exit1；冻结后重建结果才是最终成功证据。受限Core runner曾停滞并终止自身进程，不计通过；宿主最终138测试为实际通过结果。

产物：`/tmp/codex-stats-cache-usd-20261015/native/Codex Stats.app`，完整源码包`/tmp/codex-stats-cache-usd-20261015/CodexStats-v0.2.16-source.zip`。未安装、启动、退出或替换用户App，未提交推送；ad-hoc签名不是Developer ID/公证。实际鼠标/悬停、VoiceOver、Picker键盘、系统增强对比度、macOS14/Intel运行和长期驻留仍需人工验收。


## v0.2.17 / build19：离线模型价格管理（2026-10-15）

需求R20/T14及R19/T13/R17，设计先于实现获批。设置内子页管理三项USD/百万Token价格，添加候选来自当前根全部历史已接受记录减已有价。内置/自定义同样可编辑；有历史记录或扫描不确定时禁止删除。完整表原子持久化到`~/Library/Application Support/Codex Stats/prices.json`，默认只在无文件时使用，删除内置行重启不补回。App/CLI同Core/配置，价格变更后台重估而不重扫日志，不改Token。源码计量/Scanner/Models哈希与任务开始一致；大量既有脏改动保留，未归入本轮。

**最终冻结源码实际执行**：宿主`Scripts/test.sh` exit0，**142 tests passed**（`validation/core-frozen.log`）；`Scripts/test-usage-store.sh`和真实App格式器`Scripts/test-token-display.sh`均exit0（`validation/store-frozen.log`、`display-frozen.log`）。后者覆盖en_US/zh_CN/fr_FR。Store验证全历史候选、两种来源保护删除、警告阻删/信息可删、持久删除、添加/改价/0价/非法输入、不重扫、扫描与改价交叠、修订配对、真实保存失败保留及坏配置金额不可估。独立trellis-check复核数据流并对最终Sources进行macOS14 arm64优化typecheck，exit0无诊断、前后哈希一致；脚本语法与diff检查通过。

**独立手算CLI**：使用8条合成请求加metadata-only空会话，不读真实日志或价表。初始USD0.00686625（已估1830/未估3870 Token）；给`new-local-model`添加3/0.3/12后USD0.01280625（4980/720）；改sol为4/0.2/20后USD0.01428625（4980/720）；持久空表金额null、5700全部未估。四种情况输入5300/输出400/总5700不变，逐记录/模型/会话/会话模型/总量精确相等；空会话带本次revision。坏JSON、缺少--prices参数及未知参数均非零stderr，无成功输出。最终优化Core和CLI重新编译后重复此oracle通过；fixture/预期/结果保留在任务research/oracle。

**原生布局和资源边界**：价格专属40张生产SwiftUI静态PNG，cyan/blue×light/dark×950/1120及原生legacy滚动进程均exit0；950页document748<=clip748，1120页918<=918，允许纵滚且无横向溢出。真实NSTextField程序编辑验证表单绑定；无候选与坏配置状态有明确说明。现有完整原生UI回归cyan/blue分别exit0，含288菜单、模型/请求两宽、分界/80条滚动、详情、扫描状态/恢复及派生金额。UI编译早于最后仅内部Decimal缓存调整，视觉和状态语义未变；冻结后Core/Store/formatter/CLI/typecheck/build重新核验。一次100k合成accepted记录受控对比：逐记录重解析价的索引构建1.0550s，价表行初始化缓存Decimal后0.2859s；均4000标量桶、精确USD281.2；合并约0.0038s。仅同宿主一次时间样本，非内存/RSS/当前或峰值footprint/虚拟内存、帧率或完整App体验证据。

**交叉复核修复**：历史内置快照help不再误标当前核验日期；空会话CLI fallback携带当前价表修订；坏配置不再误报所有模型已配置。全历史已用模型集合随快照保存，候选对模型集合做小规模差集/排序；未测得瓶颈，不增加额外候选缓存。正式设计已记录此简化。独立review无遗留确认缺陷。

**最终交付**：`Scripts/build-macos.sh /tmp/codex-stats-price-management-20261015/native` exit0，Info.plist=0.2.17/build19，arm64/macOS14最低目标，codesign strict/deep有效，链接仅系统库。16份Sources/Assets输入构建前后哈希一致。可执行SHA256=`63c648b34ad030d626d6f4a1e7c327c0dfcfcb0be0cb5cebf4581b20c3df37f5`。一次中间构建因最后缓存修正并发改输入而exit1，不计成功；最终重新冻结构建才是交付依据。产物App、App ZIP及完整源码ZIP均在`/tmp/codex-stats-price-management-20261015/`；源码按Git跟踪与非忽略文件收集，包含本轮和此前保留的源码改动，不包含.git/构建缓存/会话运行态/用户日志。归档字节核验见`validation/packages.json`。

**未执行**：离屏AX不能取得价格页添加/编辑action，native-sheet-actions.txt明确UNVERIFIED；独立生产表单渲染不证明真实打开sheet、下拉选择、保存/取消/Escape。实际鼠标/键盘/VoiceOver、系统增强对比度、macOS14/Intel实机、公证与长期驻留保持待验收。未安装、启动、退出或替换用户App，未提交/推送；ad-hoc签名不等于Developer ID/公证。

复验建议：在独立测试版本的设置进入模型价格，添加一条无价历史模型并核对金额和Token不变；编辑后取消、重开确认未保存，再保存确认重算；检查有历史记录行禁止删除、无历史内置行可删且重启不复活；在可丢弃价表副本下测试坏JSON与保存失败；分别在950宽、两配色深浅色中检查表单键盘和读屏。不要为了验证修改真实日志或替换正在运行的版本。

任务记录：[模型价格管理](.trellis/tasks/archive/2026-10/10-15-model-price-management/prd.md)，[实施记录](.trellis/tasks/archive/2026-10/10-15-model-price-management/research/implementation.md)，[独立review](.trellis/tasks/archive/2026-10/10-15-model-price-management/research/review.md)。完整本轮日志/图：`/tmp/codex-stats-price-management-20261015/`。


## v0.2.18 / build 20 清爽总览与模型筛选（2026-10-15）

本轮R21/T15、R19/R20按先设计后实现完成：总览近白底/四张独立卡，原生模型下拉与范围联动；趋势、模型分布和完整Token明细同口径；查看记录带入模型。两套配色保留，窄窗允许纵滚而无横向溢出。新增gpt-5.6-sol与gpt-6-sol官方Standard短上下文默认价，codex-auto-review经用户确认保留未计价。已有完整价表只由“补充新增内置价”明确增加缺失新两行，不覆盖自定义或复活其他删除项。正式契约见[设计](docs/dashboard-model-filter-design.md)。

**本轮实际门禁**：host `Scripts/test.sh`145tests通过；Store独立缓存/无重扫/原子重估/导入保留与失败通过；共享格式三区域设置通过；浅青/晴蓝原生完整矩阵及最终总览/价格页四进程矩阵通过（950/1120、深浅、启动legacy、长名/极大金额/未知/空/旧数据刷新失败）。独立预声明8条合成日志6case手算与真实CLI核对精确金额/Token/覆盖/日小时一致；全部5550Token的USD已估算小计0.0113，未估640Token，不以缺价补零。独立Trellis代码审查与macOS14目标typecheck通过，无阻塞确认缺陷。

优化arm64独立App成功：v0.2.18/build20、macOS14+、ad-hoc严格深签名校验通过，仅系统动态依赖；57构建输入散列冻结前后一致。Scanner/Models/lifecycle对任务开始散列不变。App可执行文件SHA256：`31058b98219941c24b7d77d13b0d45ab7b026e5631049f02e11b04491e24ec2d`。工作区原有未提交修改保留，无提交推送，无用户日志/配置改写，无用户App安装/启动/退出/替换。

证据：[最终核验](.trellis/tasks/archive/2026-10/10-15-dashboard-model-filter/research/final-verification.md)、[独立review](.trellis/tasks/archive/2026-10/10-15-dashboard-model-filter/research/review.md)、[手算fixture与检查](.trellis/tasks/archive/2026-10/10-15-dashboard-model-filter/research/oracle/check.py)。本机产物根目录`/tmp/codex-stats-dashboard-filter-20261015`：native/Codex Stats.app、overview-final、price-ui-final及日志；App ZIP与源码ZIP见[最终交付包记录](.trellis/tasks/archive/2026-10/10-15-dashboard-model-filter/research/delivery.md)。

**未验收边界**：真实鼠标选择模型/导航点击、菜单/window行为、VoiceOver、系统增强对比度切换、Intel/macOS14实机、DeveloperID/公证仍未验证。本轮没有持续资源或延迟基准，不能声称测得内存/速度收益；离屏截图和注入状态不冒充真实交互。所有数据与价表为隔离合成fixture。


## v0.2.19 / build 21 删除重复模型统计页（2026-10-16）

用户明确授权R22，先更新[需求与设计](docs/remove-model-statistics-design.md)再删除。分析侧栏现在为总览、请求日志、历史会话、设置；独立模型入口/路由/私有搜索排序与A卡片完全移除，不留隐藏兼容页。总览模型筛选/分布/完整Token明细、请求模型筛选、会话内模型拆分与设置价格管理保留。

**本轮实际执行**：实现者两配色完整四页原生矩阵各exit0，共298PNG/70TXT，保留80条请求表/最末行/宽度分界、搜索/草稿/配色状态、金额断言及诊断恢复；root总览专属四组进程矩阵exit0（两配色×启动overlay/legacy，深浅、950/1120、模型已价/缺价/空/长名/大金额/刷新失败）。独立审查无阻塞确认缺陷，单独macOS14目标typecheck exit0无诊断，55源码/脚本/测试散列前后一致。`git diff --check`、shell语法、Trellis上下文检查通过。

优化arm64独立App v0.2.19/build21构建和严格深签名校验通过；57输入冻结前后不变。可执行SHA256：`63cbfa00b873cefbdf73a6a1ac235fb1faaa9fe783f3ef38361bb3d9d498b0c3`。相对任务开始仅DashboardView、UIPreview、render-ui-previews及Info版本四个产品/测试/脚本/资源文件变化；Core/Store/CLI/其他页面/计量测试字节不变，因此未重跑未变Core/Store全套，**上轮145Core不是本轮新结果**。

本机产物`/tmp/codex-stats-remove-model-statistics-20261016`：native/Codex Stats.app、两套UI与总览预览、App/sourceZIP及validation/delivery.json。[实施记录](.trellis/tasks/archive/2026-10/10-16-remove-model-statistics/research/implementation.md)、[独立review](.trellis/tasks/archive/2026-10/10-16-remove-model-statistics/research/review.md)、[最终验证](.trellis/tasks/archive/2026-10/10-16-remove-model-statistics/research/final-verification.md)。真实鼠标/键盘/VoiceOver、系统增强对比度、macOS14/Intel实机仍待验收；未做新资源基准或承诺速度/内存收益。无用户App安装/启动/退出/替换，无真实日志/价表改写，无提交推送；既有脏工作区保留。


## v0.2.20 / build 22 模型下拉按记录数排序（2026-10-16）

R21/T15：全部模型固定首项，其余候选按当前时间范围的已接受记录数降序，同数按精确模型ID升序，缺键0；保留全部历史候选及当前选择。变更仅私有Picker排序与Info版本，Core/Store/测试/脚本/价格/生命周期字节未动，不重扫、不重置筛选。

本轮独立代码审查无确认缺陷，单独macOS14 arm64 typecheck exit0/无诊断、55文件散列一致；root现有总览四进程原生矩阵exit0（两配色、启动overlay/legacy、950/1120深浅及筛选/空/未知/长名/大金额/刷新失败；请求带入8行），优化独立App构建/严格签名通过，57冻结输入未变。可执行SHA256 `f6fb872431ebc00c3765d5f7a67963564a15e7efa3043cbc7b9c6d90f6066e10`。没有重跑或宣称本轮Core/Store全套；无镜像排序实现的额外测试。

[实施](.trellis/tasks/archive/2026-10/10-16-overview-model-count-order/research/implementation.md)、[独立review](.trellis/tasks/archive/2026-10/10-16-overview-model-count-order/research/review.md)、[最终验证](.trellis/tasks/archive/2026-10/10-16-overview-model-count-order/research/final-verification.md)。产物 `/tmp/codex-stats-model-order-20261016`。静态视图不证明真实弹出菜单/鼠标键盘/VoiceOver操作，目标平台实机仍待验收。无用户App安装/启动/退出/替换，无真实日志/价表操作，无提交推送。


## v0.2.21 / build23：总览趋势三指标（2026-10-16）

R23/T16按[正式设计](docs/overview-trend-design.md)先文档后实现：原生Token／记录数／API等值金额切换、日/小时后台标量桶与同模型/范围筛选；记录非确认请求、金额非扣费。部分金额是已估算小计，未知用△/◇和文字区别，零价仍为已知零。密集30日期仅6刻度且保留全部柱、微额美元刻度可区分。

本轮146Core、隔离Store、三区域格式测试通过；独立手算40断言、最终macOS14arm64优化typecheck、空白/脚本语法检查通过。双配色/深浅色/950与1120/普通和启动legacy四进程最终320PNG与320几何TXT通过；独立审查和root目视修复了密集日期/注释重叠。中间编译参数错误及仅ticks未生效保留为失败证据，不算最终结果。

优化App v0.2.21/build23、arm64/macOS14+、严格深签名验证成功，57输入冻结前后一致，可执行SHA256 `fe4af9713c1c86e74edd744642255dad4bf41e89b3b60c8cbccc62b27f4c1519`。产物 /tmp/codex-stats-trend-20261016/release-native/Codex Stats.app 及 App ZIP；源码继续由Git管理，本轮未生成源码包。

[最终验证](.trellis/tasks/archive/2026-10/10-16-overview-trend-metrics/research/final-verification.md)、[独立review](.trellis/tasks/archive/2026-10/10-16-overview-trend-metrics/research/review.md)、[手算fixture](.trellis/tasks/archive/2026-10/10-16-overview-trend-metrics/research/review-oracle.swift)。原生静态图/注入模式不等于真实鼠标、键盘、VoiceOver实测；增强对比度、macOS14/Intel实机和公证仍待验收。无本轮资源基准、无用户App安装/启动/退出/替换、无真实日志/价表修改、无提交推送；先前脏工作区保留。


## v0.2.21 提交前回归（2026-10-16）

用户授权将现有本地改动提交到 GitHub。此前各节的“未提交/推送”描述的是各历史任务结束时的状态；本节记录整合后的提交前检查，不覆盖历史证据与人工验收边界。

本次重新执行且全部 exit 0：

- `Scripts/test.sh`：146 项 Core 测试通过。
- `Scripts/test-usage-store.sh`：隔离 Store 的模型/范围查询、价格增删改/导入/持久化、失败保留、并发快照及刷新状态测试通过。
- `Scripts/test-token-display.sh`：en_US、zh_CN、fr_FR 格式测试通过。
- `Scripts/test-app-delivery.sh`：18 项交付检查通过，使用测试身份和隔离路径。
- `Scripts/build-macos.sh <isolated-output>`：arm64/macOS14+ 原生 App v0.2.21/build23 构建通过；产物通过严格深签名校验。
- `git diff --check`、`bash -n Scripts/*.sh`：通过。

本次未重新运行完整原生截图矩阵或人工交互验收；相关证据及限制沿用上文各任务记录。没有安装、启动或替换用户 App，没有修改真实日志和价格配置。现有产品/设计/测试整合为一个提交，任务归档与验证证据另作一个提交，保留既有远端历史。
