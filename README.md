# Codex Stats

当前发布：**v0.2.9 / build 11**。当前生产菜单宽 288 points；用户已选择 B 视觉方向，尚待实现，不是运行时样式选项。

原生 macOS Codex Token 使用分析工具。macOS 14+，完全离线、本地只读，零第三方运行时依赖。

项目追踪：[产品需求与状态](docs/requirements.md) · [设计与统计契约](docs/design.md) · [实际验证记录](VERIFICATION.md)。后续需求通过 Trellis 追踪，**先更新设计文档，再实现**。设计入口包含可重建的布局、数据、状态和构建契约，区分已实现与待实现。

开发入口：[参与开发](CONTRIBUTING.md) · [仓库结构与开源准备](docs/repository-layout.md)。`Sources/`、`Tests/` 保留 Swift Package 的标准目录名；编译缓存和 `dist/` 分发产物不属于待提交源码。

## 许可证与仓库

源码已发布至公开仓库 [lixd/codex-stats](https://github.com/lixd/codex-stats)，默认分支为 `main`。原创 App 源码、测试、资源和项目文档采用 [MIT](LICENSE)，允许在保留版权及许可声明的条件下使用、修改和商业分发。

随项目保留的 Trellis 开发工具及模板保留上游 **AGPL-3.0-only**，不由根 MIT 重新许可，也不进入 App 运行时。具体授权边界与上游来源见 [第三方声明](THIRD_PARTY_NOTICES.md)。

## 菜单设计方案

[打开两套原生菜单方案对比](docs/menu-design-comparison.html)。浅色 / 深色截图使用同一份合成数据，B 已选定为后续方向，见 [B 目标设计](docs/ui-design-b.md)，尚未进入生产 App。运行 `./Scripts/render-menu-designs.sh` 可重新生成原生 PNG；正式版只先缩窄现有菜单。

## 安装与运行

已有构建产物时，将 `dist/CodexStats.dmg` 中的 **Codex Stats.app** 拖入 Applications，或直接打开 `dist/Codex Stats.app`。启动后从顶部菜单栏的波形图标打开总览，再点击「打开完整分析」。关闭分析窗口不会退出菜单栏应用；点击菜单栏弹窗底部的「退出」或分析窗口左下角的「退出应用」，或在应用获得焦点时按 ⌘Q，可结束整个应用。重复打开同一 bundle identifier 的副本时，新实例退出并激活先前运行的实例；更新前仍需退出旧版本。

开发构建使用本机 ad-hoc 签名，尚未使用 Developer ID 签名或 Apple 公证。分发给其他 Mac 时可能被 Gatekeeper 拦截。本次二进制为 Apple Silicon；Intel Mac 请在本机从源码构建。本次在 macOS 27.0.1 上构建和启动，macOS 14 最低系统尚未实机验证。

从源码安装（需要 Xcode 或 Apple Command Line Tools）：

```bash
./Scripts/install-local.sh
```

安装位置为 `~/Applications/Codex Stats.app`。更新前请先从菜单栏退出旧版本。

进程生命周期检查（macOS，先退出所有已运行副本）：`./Scripts/test-app-lifecycle.sh`。该检查实际启动 App、强制再次打开副本、确认只保留原实例，再通过 AppKit 正常退出；不代替退出按钮的点击验收。

只构建、试运行或生成 DMG：

```bash
./Scripts/build-macos.sh
open "dist/Codex Stats.app"
./Scripts/make-dmg.sh
```

若没有编译工具，运行 `xcode-select --install`。App 打包脚本直接使用系统 Swift 编译器；Swift Package、测试和核对 CLI 需要 **Swift 6.0+**。Shell 中的 `swift` 可能是同名 Python 命令，macOS 下使用 `xcrun swift`。

## 功能

- 菜单栏：今天、近 7 天、近 30 天、全部；输入、输出、缓存输入、推理、总量，前两个模型和最近成功刷新时间。
- Overview：紧凑 Token 指标、趋势、模型排行和按级别分组的数据质量提示；精确数字可查。
- Requests（请求日志）：按时间、总 Token 或模型排序；按模型筛选，搜索项目、模型、Session ID、请求 ID 或 Turn ID；选择记录在右侧打开详情，复制已有 ID，并展开原始用量与累计快照。关闭侧栏保留查询和排序；表格保留时间列及原生滚动。
- Models：动态识别模型；输入、缓存、非缓存输入、输出、推理、总量、会话数；搜索和排序。宽表格可以横向滚动，缩写悬停显示精确数值。
- Sessions：按项目、Session ID、模型搜索，按最近活动、总量或项目排序；会话详情显示 Token 缩写及会话内各模型明细，悬停可查看精确数字。全部时间包含没有 Token 记录的会话。
- 手动刷新；顶部和设置中可选择自动刷新，间隔可选 30 秒（默认）、1 分钟、5 分钟、15 分钟，并可关闭自动刷新。间隔选择会保存，切换后立即重新计时；升级时未选择过间隔的自动刷新用户使用 30 秒，原先关闭自动刷新的用户仍保持手动刷新。刷新时间精确到秒，只记录成功扫描。日志路径出错时仍可打开分析窗口进入设置。

总览采用紧凑指标卡与全宽柱状图：今天按本地小时汇总，其他范围按日汇总；下方提供模型排行与完整 Token 明细。小时趋势使用与总量相同的已去重增量，不重新累加原始快照。当天没有已计入事件的小时以零显示，不代表能恢复缺失日志；遇到夏令时，按实际的 23 或 25 个小时显示。

Token 显示统一使用国际单位：百万以上使用 M（十亿以上也保留 M），万以上不足百万使用 K，较小数字显示原值；M 最多两位小数、K 最多一位，去掉多余尾零。临近百万的舍入边界会显示 1M，避免 1000K。趋势图不使用科学计数法或「万 / 亿」。总览及会话、请求的 Token 明细缩写可悬停查看精确值；菜单底注、指标卡副标题、会话和列表合计也使用共享 K/M；精确数字可通过悬停和原始计量详情核对，CLI 仍输出整数。缺失字段继续显示「未完整记录」。

可运行 `./Scripts/render-ui-previews.sh` 在 `dist/ui-previews` 生成原生 SwiftUI 总览、菜单、模型 / 请求列表（950 / 1120 宽度）、右侧详情及加载 / 空 / 错误状态的深浅色 PNG。预览仅使用脚本生成的合成日志，不读取真实 Codex 会话、不更改系统主题；这些图片验证页面渲染，不验证真实菜单栏点击。

请求日志显示的是**已纳入统计的用量记录**，不是所有成功或失败的网络请求清单。独立请求来自真实 `response_id`；旧日志的最近一次用量、累计增量、初始快照会分别标注，累计记录可能包含多次请求，不能当作一次请求或直接计数。零用量、已去重、无法计量的事件不进入该列表。记录之和与同一范围的汇总一致；加上搜索或模型筛选后，底部合计仅包含当前列表。

缺少真实 Session ID、response_id 或 Turn ID 时显示「未记录」，内部行标识或文件名不充当真实 ID；缺少缓存/推理字段时显示「未完整记录」。详情区展示已计入的六项 Token 数字，并明确区别独立请求的 `thread_token_usage` 与旧格式的 `total_token_usage`。没有 API 等值费用、定价、缓存写入或状态码。单请求耗时没有实测日志字段；v0.2.7 根据可匹配到真实 response_id / Turn 的日志事件边界估算，耗时及输出速度均标注 **≈**。开始取首个模型输出之前的用户 / 上下文 / 工具结果边界，结束取原生 usage 记录时间，包含首次 Token 等待及可能的重试。缺少或矛盾边界、压缩、累计与初始快照仍显示 —；估算耗时须在 100 ms 至 1 小时之间，输出至少 200 tokens 且耗时至少 1 秒才显示 tok/s。不能把它当作实测生成速度，也不使用单个 item 包络或无边界的相邻请求时间差。详情另列可核验的完整 Turn 耗时 / TTFT；覆盖确认后才计算全 Turn 去重输出 / 耗时的平均 tok/s。这个指标包含工具与等待，不能解释为纯生成速度；其分子不受日期、模型或搜索筛选截断。缺失、失败、中止或矛盾的生命周期不产生假性能。

菜单栏弹窗采用紧凑布局；点击“打开完整分析”或统计提示，会先关闭菜单自身的弹窗，再显示分析窗口。关闭分析窗口后菜单栏进程继续运行；仅明确退出或 ⌘Q 结束应用。应用主动禁用空闲自动终止，不阻止系统睡眠，也不保证抵御崩溃或系统强制终止。请将 App 拖入 Applications 后运行，避免长期从挂载 DMG 启动。

菜单栏与分析窗口共享时间筛选。7 天包含今天及之前 6 个本地日历日；30 天同理。日趋势最多显示最近 30 个有记录的日期，不推算缺失日志的消耗。

## 数据来源与隐私

默认仅扫描：

```text
~/.codex/sessions/**/*.jsonl
~/.codex/archived_sessions/**/*.jsonl
```

首次启动可继承 `CODEX_HOME`；Finder 启动不一定继承 Shell 环境。设置中可指定 Codex home，也可显式选择单独的 JSONL 文件夹。多个路径用英文逗号分隔。

应用不读取 `auth.json`、账户凭证、API Key、模型配置或数据库；不调用账户接口，不上传日志，不保存提示词或响应正文，不跟随 JSONL 符号链接。扫描过程中 JSON 对象短暂存在于内存，仅 Token、模型、目录、会话身份和时间元数据进入缓存。UserDefaults 仅保存目录与自动刷新偏好。

解析器在后台 actor 串行执行，不阻塞 UI 主线程。文件按大小与修改时间缓存；未变更文件不重读，变更文件以 64 KiB 分块重新解析；每次读取和每行 JSON 解析分别使用自动释放池，及时释放 Foundation 临时对象，避免扫描中积压。首次读取显示加载状态，后续刷新保留成功数据，失败保留成功时间并显示错误。日期解析复用不可变格式，筛选每次只计算一次本地日期边界。当前是文件级缓存，尚未实现字节级追加解析、文件监听或持久缓存。

## 内存验证

`./Scripts/benchmark-performance.sh` 同时记录扫描速度、最大 RSS 和峰值 footprint，并核对固定合成日志的计量快照。`./Scripts/measure-app-memory.sh "dist/Codex Stats.app" LOG_ROOT OUTPUT` 用临时独立 bundle identity 启动同一个 App 可执行文件，采样启动后 10 / 35 秒的实际进程占用，再正常退出测试自身的实例；不关闭你正在使用的版本。它测量进程内存，不自行证明界面刷新成功。具体数值、输入和限制见 [VERIFICATION.md](VERIFICATION.md)，扫描器数值不能当作完整 App 数值。

## 统计规则

**Total = Input + Output。Cached 已包含在 Input，Reasoning 已包含在 Output。**

1. `turn_context.model` 按记录顺序关联请求。模型可以在同一会话中多次切换；使用记录中的原始名称，不写死名单、不根据价格别名猜后台模型。声明之前、模型缺失或请求 Turn 不匹配时显示 `Unknown model`。
2. 新格式的 `token_usage_record` 按 `response_id` 全局去重，要求明确的 `thread_id` 匹配所在会话；缺失所有权或属于其他会话的继承请求排除。和相邻 `token_count` 核对后，同一请求只计一次，无效原生记录也不会通过累计通知重新计入。**压缩后的线程累计与上下文累计可能不同，不能交叉差分。** 未发出 token_count 的已保存请求也可计入。
3. 旧格式的 `total_token_usage` 使用差分，重复快照不相加。首个累计值大于最近请求时，只统计已观察到的最近请求，并提示缺失历史；不会把过去用量分配给当前模型/日期。
4. 计数器回退使用有效的 `last_token_usage`；缺失时跳过、重新建立基线并提示。非连续重现旧快照时保守去重，也提示可能存在相同值重置的歧义。
5. 没有累计值或响应 ID 的重复最近用量，无法可靠区分重发与同大小请求。相同 Turn/模型/用量保守去重，并明确提示可能少计。
6. Session ID 负责归组，物理 rollout UUID 负责历史身份。活动、归档、会话回退后的文件中可独立核验的原生响应均计入历史消耗，同一响应不重复求和。真实响应身份或用量矛盾则排除并提示；旧格式累计流覆盖不明时仍保守选择一个较完整流，**不盲目相加累计历史**。文件同名不是会话相同的证据。
7. 子会话可按父会话中完全相同的时间、Turn、模型和用量前缀去重，或排除外部 thread_id 请求。只有相同累计值不足以证明继承。无法验证的旧 fork 在界面标记风险，不按毫秒时间猜边界。
8. 自动压缩请求使用真实响应记录；无明确压缩模型时显示 `Unknown model`。较短副本缺少后续压缩标记不会形成假冲突，已有明确 payload 模型仍优先。只有压缩标记而没有用量，无法恢复消耗。
9. 每次请求/增量归属到该记录的本地日期。跨模型或跨日期的累计增量若与最近请求不一致，只计可确认部分并提示；无有效时间的用量不会分配到文件修改日期。
10. Input/Output 是必需字段，非法值、负数、布尔值、越界或子集大于父项的记录会跳过并提示。缺失 Cached/Reasoning 时仍统计有效的 Input/Output，但相关模型/会话/总览列显示 **未完整记录**，不假定零；非缓存输入也不假定已知。
11. 损坏行跳过并记录数量；尚未写完的末行下次刷新重试。`turn.completed` 仅在该文件没有常规用量记录时作为保守备用格式。
12. `history_base` 核验本地物理文件及 exclusive byte / ordinal 边界；正常引用、已核验重复副本和独立物理历史合并为信息。缺失或非法边界、非空循环、真实冲突和无法核实的旧累计覆盖保留风险提示；引用前缀之后的损坏不使有效前缀失效。

已知身份边界缺口：缺少 session_meta ID 且原生 thread_id 恰好等于文件名时，当前内部归组判断仍可能接受该用量；会话页也尚未区分文件名归组 ID 和真实 Session ID。请求详情/CLI 保留真实 ID 的缺失状态。详见 [数据设计](docs/data-design.md) 和 [UI设计](docs/ui-design.md)，不能把这些内部标识解释为已核验真实身份。

这些数字代表**本机可核验的日志用量**，不是订阅额度、实际扣费或服务器账单。未知/缺失部分会显示提示，统计可能少于实际使用。没有成本估算、登录、多 Provider、在线调用或云同步功能。

## 测试与核对

```bash
./Scripts/test.sh
# App 数字格式与三个区域设置的回归检查（macOS）
./Scripts/test-token-display.sh
# 实际 UsageStore 加载 / 失败保留 / 目录切换回归
./Scripts/test-usage-store.sh
```

使用系统自带 Swift Testing，无额外测试依赖。脚本在 macOS CLT 中显式提供已安装的 Testing 宏路径，解决当前工具链增量构建可能漏掉插件的问题；不下载编译器或测试框架。普通 Swift 6 / Xcode 环境也可运行 `xcrun swift test --disable-xctest`；Linux 使用 `swift test --disable-xctest`（本次没有运行 Linux 验证）。

离线 JSON 核对工具和 App 共用统计核心：

```bash
xcrun swift run codex-stats-report "$HOME/.codex"
# 也可对测试数据核对
xcrun swift run codex-stats-report Tests/CodexStatsCoreTests/Fixtures
# 增加可核对的已计入记录（可选，默认不导出逐条记录）
xcrun swift run codex-stats-report "$HOME/.codex" --records
```

JSON 包含四项 Token、`cachedInputKnown`/`reasoningKnown`、模型、会话、typed `diagnostics`（severity / kind / 会话 / 文件 / message）及 warning/error 的 `warnings` 投影；总 Token 用 `input + output` 计算。当 known=false 时，对应的数值仅是内部已知部分的汇总，不应当解释为完整 Cached/Reasoning 数字；Non-cached Input 也不可据此推断。

`--records` 增加 `records` 数组，包含真实 ID（存在时）、时间、模型、Session ID、项目、已计入用量、统计依据及原始用量快照，可选 `turnPerformance` 的 durationMilliseconds / firstTokenMilliseconds / outputTokens / responseCount。后两项只在全 Turn 输出覆盖完整时提供，不能按当前列表的输出替代。JSON 的 `id` 是内部行标识，真实请求标识位于 `requestID`；`sessionID` 是本地归组标识，真实会话标识位于可选的 `recordedSessionID`。缺少真实 ID 时不导出该可选字段，不能把内部标识用于推断真实 ID。时间使用 ISO 8601 格式。导出仍为本地操作，请自行保管包含会话元数据的文件。

开发时可用 ccusage 单独对照（仅验证使用，App 不依赖 Node）：

```bash
CODEX_HOME=/path/to/frozen/logs npx ccusage@20.0.31 codex session --json --offline --no-cost --speed standard
```

请使用同一份不再变化的日志。ccusage 的 `inputTokens` 是非缓存输入，对照本应用 Input 时需加上 `cacheReadTokens`。它的模型 fallback、副本策略和未通知请求处理可能不同，不能将差异一律判为应用错误。实际结果见 [验证记录](VERIFICATION.md)。

## 工程结构

```text
Sources/Core/     Foundation 解析、聚合和日期筛选
Sources/App/      SwiftUI + Charts + AppKit
Sources/Report/   可选离线 JSON CLI
Tests/            自动化测试和脱敏的合成 JSONL 数据
Scripts/          构建、测试、安装与 DMG 打包
Assets/           原生图标与 Info.plist
```

Package 同时包含 Core、核对 CLI、测试以及 macOS App 可执行目标。分发 `.app` 仍使用 `Scripts/build-macos.sh`，自动生成图标和 ad-hoc 签名。

## 性能复测

```bash
# 生成约 350 MB 合成 fixture；WORK 只能使用专用空目录
./Scripts/benchmark-performance.sh /tmp/codex-stats-performance
```

脚本输出 cold / warm / 单文件追加 / 四档筛选的时间和完整计量快照。仅修改自行生成的合成 fixture，随后恢复追加长度；不能指向真实日志。cold 表示新进程解析缓存为空，不表示清空系统磁盘缓存。目标及本机前后结果见 VERIFICATION.md。

## 已知限制

- Codex 日志不是稳定的计费协议；更新 CLI 后应复测。已删除的历史、分页中缺失的部分、其他设备/云端未保留日志无法补齐。
- 未验证的旧 fork/重写历史可能偏高；保守去重、字段缺失、损坏日志和缺失基线也可能少计。界面警告是结果的一部分。
- 无真实身份的旧累计流无法证明不重叠时不会合并，可能少计；原生请求的真实身份冲突会排除该身份并明确提示。
- 文件级缓存仍需枚举目录；增长中的大文件会重新解析。系统时区改变后请重启应用重新分桶。
- 本次完成原生编译、签名检查和进程启动验证，以及总览、菜单、请求列表和详情的原生深浅色静态渲染检查；UI 自动化服务超时，真实菜单点击、页面交互及其他页面的视觉验收仍待人工完成。
- 没有 Developer ID、公证、Intel 二进制或 macOS 14 实机验证；提供源码供目标 Mac 本机构建。

## 参考

实现核对使用的源码版本记录在 VERIFICATION.md。

- [Codex 官方 TokenUsage / TokenUsageRecord 协议](https://github.com/openai/codex/blob/2f05c0a71f59fb2f05800846351f3e9926c3e52b/codex-rs/protocol/src/protocol.rs)
- [ccusage Codex 数据源说明](https://ccusage.com/guide/codex/)
- [ccusage Codex 解析器](https://github.com/ccusage/ccusage/blob/57afdc255fcbe031b0ecd7cac487f8fd7c5d531f/rust/adapters/codex/src/parser.rs)

本项目不属于 OpenAI 官方应用。
