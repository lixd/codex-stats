# 数据与统计设计：当前实现基线

状态：**已实现，v0.2.9 / build 11**。本页描述 Core 当前行为；视觉方案 B 不改变这里的统计口径。与 [设计总纲](design.md)、[界面设计](ui-design.md) 配套使用。代码依据是 `Sources/Core/Models.swift`、`Sources/Core/CodexLogScanner.swift`；测试是独立复建时的可执行判据。

## 1. 产品计量对象与分层

计量对象是本机保留日志中能够核验的 Token 消耗，包括保留物理日志中后来回退的请求；不是当前对话长度、订阅扣费、请求成功率或服务器完整账单。缺失历史不恢复，未知模型不猜测，无法证明不重叠的旧日志不强行合并。

Core 仅依赖 Foundation / CoreFoundation，不依赖 SwiftUI、Node.js 或 ccusage。唯一扫描入口：

```swift
public final class CodexLogScanner {
    public init(timeZone: TimeZone = .current)
    public func scan(homePath: String) throws -> ScanReport
}
```

Scanner 是有状态文件缓存对象，必须串行调用。App 的后台 actor 调用它；离线 CLI 复用同一个 Core。UI 不解码原始 JSON、不自行推测模型、请求耗时或诊断级别。刷新、偏好及生命周期见设计总纲。

## 2. 输入边界与读取方式

`homePath` 可以是单个目录，也可以是逗号分隔的多个目录；逐项去除首尾空白、展开 `~`。空列表抛出 `invalidLocation`，任一指定目录不存在或不是目录抛出 `missingFolder(path)`。目录名为 `.codex`，或包含 `sessions` / `archived_sessions` 子目录时，识别为 Codex home，**仅**递归枚举这两个子目录；否则按用户明确选择的 JSONL 目录递归读取。

只读取扩展名恰为 `jsonl` 的普通文件，排除符号链接、隐藏文件及包后代；标准化 URL 后按路径去重。路径排序后解析，保证遍历确定性。目录枚举、单文件读取失败产生 `error / unreadableFile`，其他可读日志仍保留。未读取 `auth.json`、配置、SQLite 数据库、账号或网络。

FileHandle 每次读 64 KiB，以 LF 切行；跨块的单行保存在 `pending`，因此最大单行仍可能超过 64 KiB。每次读块和每次 JSON 回调（包括末尾未换行的行）有局部 autoreleasepool。仅保留计量、身份、时间、模型、历史边界及性能元数据；消息内容解析后释放，不进入报告或缓存。

缓存键为标准化文件路径，版本戳为 **文件大小 + 修改时间**。二者都未变化时复用解析元数据；变化时整文件重解析，删除/不再选中的路径移出缓存。每次 scan 仍重建去重和汇总。没有字节级增量、持久缓存或文件监听；同大小且修改时间也相同的改写无法由该戳识别。`cachedFileCount` 仅表示此次复用解析结果的文件数。

## 3. 核心数据结构

| 类型 | 字段及作用 |
|---|---|
| `TokenUsage` | `Int64` 的 `input / cachedInput / output / reasoning`，以及 `cachedInputKnown / reasoningKnown` 两个 Bool |
| `UsageRecord` | 内部 `id`，`sessionID`，可选 `recordedSessionID`，`project / source / fileName`，`timestamp / day / model`，可选 `requestID / turnID`，`usage / evidence / isCompaction`，可选 `cumulativeSnapshot / lastReportedUsage / turnPerformance / requestEstimate` |
| `SessionUsage` | 稳定会话 ID、项目标题、cwd、来源、fork 与去重状态、首末活动、文件名、日模型切片、小时桶、被接受记录 |
| `ModelUsage` | 模型字符串、用量、涉及会话数；ID 就是模型字符串 |
| `DailyModelUsage` | 本地 `yyyy-MM-dd`、模型、用量 |
| `ScanDiagnostic` | `severity / kind / sessionID? / fileName? / message` |
| `ScanReport` | `sessions / fileCount / invalidLineCount / diagnostics / refreshedAt / cachedFileCount`；提供时间筛选和汇总方法 |

`UsageRecord.id` 是 `物理路径#帧序号`，用于行标识，**不能显示成真实请求 ID**。只有原始 response ID 可放入 `requestID`。缺少会话元数据时以去扩展名的文件名作为内部 sessionID，而 `recordedSessionID` 保持 nil。项目来自 cwd 最后一段，cwd 缺失显示“未识别项目”；标题为“项目 · ID 前 8 位”。`originator` 是来源字符串，缺失使用 `Codex`。

`UsageEvidence` 有四种：`responseRecord`（独立请求）、`lastUsage`（最近一次用量）、`cumulativeDelta`（累计增量）、`initialSnapshot`（初始快照）。只有第一种证明独立请求，后两种可能覆盖多次请求。零用量帧可以更新基线，但不生成 UsageRecord。

### Token 数值有效性

JSON 必须有 `input_tokens` 和 `output_tokens`；缺少任一则该 usage 对象无效。数值必须是非 Bool 的 NSNumber、有限、非负、整数且小于 `Double(Int64.max)`。缓存不能超过输入，推理不能超过输出，输入加输出必须不溢出。非法值被跳过并诊断，不借展示需求补齐。

缓存、推理字段缺失时内部暂存 0，同时对应 known=false，发出 `incompleteFields`；该 0 **不是已观测的零**。聚合时 known 使用逻辑 AND，任一参与记录未知，聚合明细也显示“未完整记录”。总量仍是可核验的输入加输出。

```text
Total = Input + Output
Non-cached Input = Input − Cached Input（仅 Cached 完整时对用户作为完整明细展示）
Cached ⊆ Input；Reasoning ⊆ Output
```

`TokenUsage.difference(from:)` 要求输入、输出以及双方已知的子集字段单调不减，否则返回 nil；子集差值仅在前后双方都 known 时计算。构造器会把数值限制在非负/子集范围，但日志入口首先严格验证，不靠限制修复非法日志。Scanner 在接受行前检查全局总量的 Int64 剩余空间；溢出行不进入任何聚合。

## 4. 支持的日志事件形状

下面是合成形状，不是真实用户日志。字段无关项可省略；每行一个 JSON 对象。模型列表来自日志字符串，不写死。

```jsonl
{"timestamp":"2026-10-14T00:00:00Z","type":"session_meta","payload":{"id":"s1","cwd":"/work/demo","originator":"Codex","history_base":null}}
{"timestamp":"2026-10-14T00:00:01Z","type":"turn_context","payload":{"turn_id":"t1","model":"model-A"}}
{"timestamp":"2026-10-14T00:00:12Z","type":"token_usage_record","payload":{"thread_id":"s1","turn_id":"t1","response_id":"r1","usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":600,"reasoning_output_tokens":100},"thread_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":600,"reasoning_output_tokens":100}}}
{"timestamp":"2026-10-14T00:00:12Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":600,"reasoning_output_tokens":100},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":600,"reasoning_output_tokens":100}}}}
```

- 仅接受文件中第一个 `session_meta`。ID 支持 `id` 或 `session_id`；开始时间依次取 payload.timestamp、事件 timestamp、文件修改时间。这个文件时间仅用于会话元信息，绝不用于归属用量。
- 父会话支持 `forked_from_id`、`parent_thread_id`，以及 `source.subagent.thread_spawn.parent_thread_id`；`thread_source == "subagent"` 也标为子会话。
- `turn_context` 更新当前 turn 和 model，缺 model 会清除旧模型并设 `Unknown model`。新模型不回填以前记录。
- `token_count` 支持 `info.total_token_usage / last_token_usage`，模型优先 payload.model、info.model、当时上下文。
- 原生 `token_usage_record` 必须有 response_id 和有效 usage；当前所有权判断实际是显式 thread_id 等于解析后的内部 `log.id`。正常文件的 log.id 来自 session_meta.id；thread_id 缺失或不匹配会排除。模型优先 payload.model；无显式模型时，payload.turn_id 缺失或与当前上下文 turn 相同才可使用上下文模型，否则 Unknown。原始 turn_id 是否显式存在被另行保留，不能以推断 Turn 代替性能成员资格。
- `compacted.payload.compaction_response_id` 标记压缩响应。它的独立用量可计入，模型没有明确 payload 证据时设 Unknown。
- 仅在上述主帧数组完全为空时使用 `turn.completed` 的顶层 usage 或 payload.usage 作为旧格式补充。其顶层 id 不视为 response_id，不产生原生请求性能。没有主帧时才启用，避免两套日志相加。
- 未识别事件忽略；`response_item` 的消息/工具类型仅为请求估算提供时间边界，不保留内容。

**已发现的身份缺口：** 无 session_meta ID 时，log.id 退化为文件名；若原生 thread_id 恰好等于这个文件名，现有 aggregate 判断仍会接受 Token。这不等于真实会话身份已核验，不能据此声称原生计量入口始终要求 session_meta.id。请求估算和 Turn 性能另有真实元数据/候选约束，不因此补齐。目标契约应要求真实会话ID；修复入口或增加专门诊断前，须先在本文及 Trellis 任务明确目标与验收。会话页展示这个归组ID的限制见UI设计。

## 5. 扫描与去重的完整决策顺序

顺序属于契约，不能把“先汇总后去重”替换成另一种实现。

1. 枚举、文件缓存/解析，保留物理文件的帧序列、原始诊断、引用边界、Turn 和请求估算候选。
2. 跨副本归一化正向压缩证据，再比较真实 response 记录。
3. 按稳定 session_meta.id 分组。每组选择帧数量最多的 primary；数量相同优先非归档，再按路径升序。该选择控制**旧格式流**，不意味着丢弃其他原生物理历史。
4. 核验 history_base 链，生成信息或告警。它不恢复远端历史，也不作为另一份累计 Token 加入。
5. 在全部“owner 等于所在会话”的响应帧中按 response_id 找冲突：owner、usage、model、turn、timestamp、compaction 状态任一不同，则该身份所有副本不计入；每个参与物理来源都收到冲突告警。
6. 稳定会话 ID 升序，每组先 primary，再其余路径升序。只有 primary 可接受旧格式计量。若 primary 已接受旧格式行，其他副本无法证明不重叠的原生行也不合并；否则合并不同物理历史的独立原生响应，全局 response_id 去重。
7. 每文件先排除已证实继承前缀，再执行下面的逐帧计量状态机。
8. 从被接受记录同时建立日模型、小时及会话聚合；再附加性能元数据。会话展示元信息取最近活动的副本（同时间按路径）；活动边界跨所有副本取最早/最晚。
9. 诊断按完整结构去重后确定性排序；会话按最近活动降序。可见数据表和图表都来自同一 ScanReport。

### 原生与累计通知配对

先按文件帧序列找每个独立原生 response 的相邻 token_count：优先后一帧，再前一帧。必须同 Turn 且满足“last 相同”或“非压缩且 cumulative 相同”。相邻是计量帧相邻，忽略中间非计量事件。每个 response 只配一次；前置通知另记一项，避免之后再扣减该原生响应。

缺 owner、foreign owner 或冲突原生记录的来源仍参与通知抑制，不能让已拒绝请求经累计通知重新计入。owner 正确但 response_id / usage 损坏的原生帧不压掉独立有效旧计量。

**thread_token_usage 和 token_count.total_token_usage 可能因压缩长期不一致，禁止跨两类计数器作差。** 原生始终计 usage，匹配的通知仅更新旧累计基线，不再增加用量。

### 逐帧旧格式状态机

每文件持有 `previous / previousFrame`、已见累计快照集合、last-only 签名集合、上个累计通知之后已计入的非压缩原生用量以及不可核验原生标志。

| 当前帧/条件 | 被计入用量与动作 |
|---|---|
| 合法 owner、非冲突、尚未见过的原生 response | usage；ID 全局去重；原生 thread 累计不是旧基线 |
| 匹配原生的累计通知 | 不计用量；记录快照、更新 previous、清空间隔原生量与不确定标志 |
| 未匹配累计通知前有归属不明/冲突原生 | 不计通知；告警；重建 previous 并清空间隔状态 |
| total 与 previous 相同 | 跳过 |
| total 在历史已见快照集合中再次出现 | 保守跳过，提示无法区分重复和相同数值重置 |
| total 可与 previous 单调作差 | 默认计差额；如果差额≠last 且模型或事件本地日期变化，仅计 last 并告警 |
| 计数器回退 | 只计有效 last；没有 last 则跳过；告警并重建基线 |
| 首快照 total≠last 且有 last | 只计 last，提示未观察到历史 |
| 首快照存在 history_base 或 fork | 只计 last；没有 last 则不计累计历史 |
| 普通首快照，无以上历史条件 | 计 total，标初始快照；如果数值等于 last，最终证据标签为最近一次用量 |
| 正常累计差额中还包括此前已计原生量 | 用 difference 再扣间隔原生量；不可核对则不计差额并告警，保留原生行 |
| 无 total、只有 last，已匹配或前面有不确定原生 | 抑制重复/不确定通知，必要时告警 |
| 无 total、只有 last，其余情况 | 用 response_id 或 `Turn\|model\|input\|cache\|output\|reasoning` 签名保守去重；重复可能少计并告警 |

最后统一拒绝零值、缺少有效事件时间、溢出用量。没有有效用量时间时不能使用文件修改日期填补。日与小时以**接受该用量的事件时间**归属；累计差额不分摊到未知的过去日期/模型。

## 6. 物理历史、归档、继承与压缩

稳定 Session ID 用于 UI 分组；物理历史 ID 用于不可变引用。名称以 `rollout-` 开头且最后 36 字符是 UUID 的文件，物理 ID 取该 UUID 后缀；可能存在“稳定 thread UUID_物理 UUID”文件名，不能取前一个 UUID。其他文件以内部 sessionID 作为物理 ID。

```json
{"history_base":{"thread_id":"物理 rollout UUID","end_ordinal_exclusive":42,"end_byte_offset":12345}}
```

引用边界使用 Codex 原始 ordinal，不是行数。完整 JSONL 行结束位置（含 LF）到 `ordinal + 1` 的映射用于核验；exclusive byte 必须精确落在该完整行尾，exclusive ordinal 必须一致。目标文件不存在、截断、边界不匹配、引用前缀内损坏、无效 history 元数据或非空循环均为未解决历史告警。边界后的损坏不使已引用前缀失效。byte=0 且 ordinal=0 是空前缀，停止遍历，不引入目标祖先。已核验引用为信息级，不再逐项渲染成计量错误。

子会话旧格式继承前缀必须有父会话，且子首帧可在父流中找到连续最长匹配段。带 response ID 时比较 response 与 owner；无 ID 时必须同时匹配有效时间、model、turn、非空 cumulative、last（last 可以同时为 nil）。相同累计数字本身不是继承证据。已证实前缀跳过，但累计值可建立基线；无原生身份且无法验证继承边界则警告可能含历史。

同会话完整非空计量帧前缀相同，且双方无损坏/部分写入，记录会话、父身份、fork 与 history 一致，可标 `supersededCopy` 信息；独立原生物理历史可标 `mergedPhysicalHistory` 信息。不同旧流无法证明覆盖则为 `divergentAccountingCopies` 警告，保留 primary 而不相加。

压缩标记可以在较长文件尾部才出现。跨所有合法 owner 副本传播正向压缩标记；短归档中没有该标记不算冲突。该响应在所有副本中恰有一个显式 payload.model 值时使用它；无显式模型使用 Unknown；矛盾显式模型仍触发 response 冲突。压缩消耗与一般响应各计一次，不能让压缩累计偏移污染后续计量。

## 7. 时间、筛选与聚合

时间解析使用 Gregorian RFC3339 形状：支持 `T/t`、`Z/z`、有/无小数秒、`±HH:mm` 或 `±HHmm` 偏移。严格检查真实日期/闰日、00…23 小时、00…59 分秒及偏移小时<24/分钟<60；拒绝日期自动进位、24:00、闰秒、非法偏移。超过三位的小数秒截断为毫秒，然后规范为 epoch 毫秒（含负 epoch），保证重复比较与桶归属一致。

Scanner 初始化捕获分桶 timeZone（默认当前系统时区）。用量事件变成本地 `yyyy-MM-dd` 与 Gregorian 小时起点；DST 两个同名小时保留不同 Date。系统时区变化后需重启以统一重新分桶；范围计算默认使用调用时 `.current`，不可混用已经按其他时区扫描的报告。

`UsagePeriod`：今天、本地今天+前 6 个日期、本地今天+前 29 个日期、全部。有限范围排除未来**日期**，当天未来时刻仍落在当天桶；全部不设边界。每次聚合捕获一个 now，范围边界只计算一次，不跨午夜逐行重算。

| `ScanReport` API | 返回契约 |
|---|---|
| `totals(in:now:)` | 有限日切片求和 |
| `models(in:now:)` | 按模型字符串汇总；sessionCount 是期间内贡献该模型的不同会话数；按总量降序 |
| `dailyTotals(in:now:)` | 有用量的日期升序；不自动补无日志日期 |
| `hourlyTotals(on:timeZone:)` | 指定本地日期的全部小时，空小时补 0；DST 为 23/25 桶 |
| `records(in:now:sortedByTime:)` | 默认事件时间倒序，相同时间内部 id 升序；false 返回未作该排序的筛选结果供调用者自行排序 |
| `recentSessions(in:now:)` | 全部范围保留所有会话；有限范围有用量，或首次/末次活动日期落在范围即可显示；因此可有 0 Token 会话 |

全局、会话、模型、日和记录总量来自同一接受记录集合，应一致；小时求和也应一致，除非 `invalidTimeBucket` 已明确报告无法分桶。筛选只改变显示集合，不能重新推测身份、模型或性能分子。

## 8. 请求估算与完整 Turn 性能

这是两个独立可选结构。缺性能永不删除 Token；不存在把前后行间隔直接当生成速度的策略。

### 请求估算 RequestEstimate

`startedAt / completedAt / durationMilliseconds / outputTokens`，计算型 `outputTokensPerSecond?`。起点来自用户/开发者/系统消息、Turn context/start、工具 `_output` 时间边界。第一次 assistant message、reasoning 或工具 `_call` 输出锁定**此前边界**；native usage 到达时结束，包含出首 Token 前等待和可能的重试，不是服务端纯生成时间。

状态机更新规则：边界取当前边界与新时间的较大者；不同 Turn context 重置。无时间的边界/输出清空 pending。输出已锁定后更早的输出也清空。首次输出距前次用量结束≤100 ms 视作同批补充，不启动新请求。finish 清空锁定起点；起点与当前边界相同时清除边界，防止只凭上次 usage 时间启动下一请求；期间已经观察到新的工具返回边界可留给下一响应。

仅 owner 正确、有 response_id / usage、显式 turn_id 与计时上下文一致的 native 请求产生候选。原生 usage、发生变化的有效旧通知、task_started、abort、task_complete、compacted、损坏行会结束或重置 pending；重复不变累计快照不创造下一请求。

持续时间四舍五入为毫秒，必须在 **100…3,600,000 ms**；不截断到阈值。速度必须输出≥200 且持续时间≥1,000 ms；例如 199 Token 可有耗时但没有速度。候选只附加到最终接受的非压缩 `responseRecord`。副本缺候选可由其他有证据副本提供；多个正向候选不一致、该响应候选矛盾、Turn 失败/中止则不附加。匿名 abort 会使该物理文件已有候选失效。

UI 用“≈耗时 / ≈tok/s”，未知显示 `—` 并解释依据不足；不能写成实测速度。事件/项目/模型过滤不会改变估算。

### 完整 Turn 的 TurnPerformance

显式 `event_msg.task_started` 与 `task_complete` 都带 turn_id；结束 payload 的 `duration_ms` 必须是正的、Int64 安全的无符号整数。elapsed 使用该值，而不是时间戳差；时间戳仅用于成员覆盖核验。`time_to_first_token_ms` 可缺失，已记录 0 与缺失不同，必须≤duration。error 非 null、abort、重复矛盾计时或启动、非法结束时间等使该 Turn 性能失效。

至少一个 owner 正确、显式同 Turn、位于 start/end 时间内的原生响应，才能附加计时。完整速率还要求：所有候选生命周期一致且本地完整；所有相关物理副本无部分写入、损坏和 history_base；观察 response 集合等于接受集合；无缺 owner/Turn/时间或身份冲突；Turn 内所有旧通知均已证明由原生响应覆盖。任一不满足时可保留合法 duration / TTFT，但 `outputTokens / responseCount / averageOutputTokensPerSecond` 为 nil。

完整速率 = 全 Turn 去重输出 / 显式秒数，包含工具、等待与多响应。即使跨日/模型/搜索只选中其中一行，也仍附加完整 Turn 分子，不以当前列表裁剪。压缩响应可属于完整 Turn 输出，但不产生单请求估算。

## 9. 诊断与不完整状态

诊断是 typed data，UI 禁止用中文 message 字符串判断类别。`warnings` 是兼容投影，仅包含 warning/error 的 message；information 不在其中。信息不意味着 Token 错误；警告/错误不能被隐藏为成功。

| 级别 | kind 与含义 |
|---|---|
| error | `unreadableFile`：枚举/读取失败 |
| warning | `invalidJSON / partialWrite / invalidUsage / incompleteFields`：损坏、部分写入、非法值、子集不全 |
| warning | `missingIdentity / missingTimestamp / counterAmbiguity / inheritedHistory`：身份/时间不可核验、累计不明确、继承无法证明 |
| warning | `overflow / invalidTimeBucket / unresolvedHistoryReference / divergentAccountingCopies / conflictingResponse`：范围/桶/历史/副本/真实响应冲突 |
| information | `historyReference / supersededCopy / mergedPhysicalHistory`：已核验引用、重复或已合并物理历史 |

完整的坏 JSON 行增加 invalidLineCount；无 LF 的坏末行视为 partialWrite，不增加该计数，下次文件变化重解析可恢复。**无 LF 但内容是完整有效 JSON 的末行仍可解析**，只是不能作为完整换行记录建立 history ordinal 边界。有效行不因同文件其他损坏全部丢弃。

## 10. 可复建示例与验收

仓库固定合成数据 [switch-model.jsonl](../Tests/CodexStatsCoreTests/Fixtures/switch-model.jsonl) 是最小跨日/换模型回归。用 UTC Scanner 扫描该文件所在目录：

| 范围/模型 | Input | Cached | Non-cached | Output | Reasoning | Total |
|---|---:|---:|---:|---:|---:|---:|
| 2026-10-13 / model-A | 100 | 80 | 20 | 10 | 5 | 110 |
| 2026-10-14 / model-B | 150 | 100 | 50 | 20 | 10 | 170 |
| 全部 | 250 | 180 | 70 | 30 | 15 | 280 |

第一累计 `(100,80,10,5)` 被接受；第二累计 `(250,180,30,15)` 差额恰好等于 last `(150,100,20,10)`，归属于第二事件 model-B 与第二日期，不把 280 当第二次消耗。复制到 archived_sessions 后全部仍为 280。一会话使用两个模型，两个模型的 sessionCount 均为 1。

请求估算可复建合成序列：同 Turn 的工具返回 `13:00:45`，随后 assistant 输出，原生 usage 在 `13:01:30`、输出 2,400，得到 ≈45 s / ≈53.3 tok/s；若只有相同 Token 用量而没有边界则性能为空，Token 总量不变。完整 Turn 示例：明确 duration=120,000 ms、覆盖 3,600 输出，得到完整 Turn 30 tok/s，不把此 120 秒复制成每个请求耗时。

```sh
./Scripts/test.sh
swift run codex-stats-report Tests/CodexStatsCoreTests/Fixtures --records
```

CLI 无日期筛选参数，总是输出全部；JSON 含 `total / models / sessions / warnings / diagnostics / files / invalidLines`，`--records` 才含明细。TokenUsage 编码为上述四个整数与 known 标志，total/uncached 是计算属性，不作为 TokenUsage JSON 字段；Date 使用 ISO8601 编码。解析失败输出 stderr 并退出 1。App 不运行 CLI，而是直接使用 Core。

复建必须通过现有测试合同，而不只与截图数字相似：

- [CodexLogScannerTests.swift](../Tests/CodexStatsCoreTests/CodexLogScannerTests.swift)：单模型、缓存/推理、换模型、重复/归档、reset、未知字段、损坏/部分写入、跨日、继承、物理历史、owner、压缩、冲突、缓存失效及汇总相等。
- [DateFilteringTests.swift](../Tests/CodexStatsCoreTests/DateFilteringTests.swift)：精度、偏移、Gregorian、午夜、未来日期、DST。
- [RequestEstimateTests.swift](../Tests/CodexStatsCoreTests/RequestEstimateTests.swift)：边界/工具/同批补充、100 ms/1 h、200 Token/1 s、abort、缺证据、候选冲突，性能未知时 Token 不变。
- [TurnPerformanceTests.swift](../Tests/CodexStatsCoreTests/TurnPerformanceTests.swift)：完整生命周期、全 Turn 输出覆盖、缺 TTFT/0、跨过滤、错误/中止/副本不完整。
- [统计实现规范](../.trellis/spec/backend/token-accounting.md)、[请求估算规范](../.trellis/spec/backend/request-estimates.md)、[Turn 规范](../.trellis/spec/backend/turn-performance.md)、[性能规范](../.trellis/spec/backend/scan-performance.md) 提供修改门禁；历史实际命令结果与环境限制见 [VERIFICATION.md](../VERIFICATION.md)。本次仅更新文档，未重新声称运行测试或完成实机交互验收。
