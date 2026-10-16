# 计量独立审查记录

审查日期：2026-10-15。源码 HEAD：`11f2a937971c40b29a2b4d69ff6bb79c5eaec91f`。只读检查 Sources/Tests；新增本记录、经主审授权的最小复现脚本及规范化输出，合成数据及临时编译产物位于 `/tmp/codex-stats-accounting-gbtiukpt`。没有读取真实日志、修改产品代码、运行用户 App、安装、退出、提交或推送。

## 数据流与依据

已阅读 AGENTS、Trellis workflow、当前任务 PRD/design/implement、`docs/design.md`、`requirements.md`、`data-design.md`、相关 UI 计量说明、VERIFICATION 及 backend 计量/请求估算/Turn/性能规范。v0.2.10/build 12 是已实现基线；分析窗口改版仍延期。VERIFICATION 的历史 121 项等结果未被作为本轮测试结果；全量测试由主审执行，本分支不重复运行。

1. `CodexLogScanner.scan` 枚举活动/归档 JSONL，以路径、大小、mtime 复用解析缓存（68–120）。解析只保留元数据、计量帧、历史边界和性能候选（356–565）。
2. 真实 Session ID 与未知归组隔离（123–138）；合法 owner 才能贡献压缩/response 冲突证据（139–166）。按稳定会话选择 legacy 主流，独立原生响应可跨物理历史合并（171–217）。
3. 继承前缀先剔除，再执行累计状态机；原生与旧通知配对，原生按 response 去重，旧累计作差/回退/last-only 保守处理（684–708、749–917）。接受行同步产生日/模型/小时聚合；最后关联两种独立性能数据（232–233）。
4. App 的后台 actor 持有 Scanner，发布同一个 ScanReport；菜单、总览复用有界 summary，请求/会话页使用报告切片。CLI `Sources/Report/main.swift:19–25` 使用相同 Core、输出全部范围。没有发现另一套 UI 计量算法。下面两项错误会一致传播到页、明细和 CLI；聚合合计一致不能证明输入去重和字段真值正确。

## 已确认 A1：已配对 last-only 通知没有进入重发去重状态

- **优先级/收益**：P1；修正总 Token 重复计入，直接影响核心可信度。预计 0.5–1 人日，含设计先行与回归。
- **契约**：T03/T04/T07。无身份 last-only 重发必须保守去重；已知原生响应不能借重复通知再次计量。
- **触发**：同 Turn 内原生 `R`（input=100、output=10）后出现 `last_token_usage=U`，随后原样重发通知。`R,U,R,U` 和更短的 `R,U,U` 均可复现。
- **本轮结果**：单组 `R,U` 输出 1 行/110 Token；两个反例均输出 2 行/220 Token：一条 `responseRecord` 和一条 `lastUsage`，`warnings=[]`。模型/会话/总量都一起翻倍。合成原样重发已知只有一次请求；真实无 ID 的相同值也可能是新请求，当前设计对此本应保守去重并提示不确定。
- **定位**：`Sources/Core/CodexLogScanner.swift:684–702` 只给每个 response 一次邻接配对，692 跳过重复 response；871 在已覆盖 last-only 分支直接 continue，未记入 `lastOnlySignatures`；880–885 后续同值通知首次进入签名集合并被接受。完整累计分支的 `observedSnapshots` 已处理重复，last-only 状态没有共享这份已计量证据。
- **最小方案**：为匹配过的通知登记与现有 last-only 保守签名一致的重发证据；后续没有新累计增长、没有独立新 response 的相同通知不得再次计入，按现有规则报告歧义。不能简单把所有重复 native 邻接通知都压掉：已有测试 `duplicateRequestRecordDoesNotConsumeANewEqualSizedRequest` 刻意保留了**累计确实增长**时的同大小新请求。修复必须同时保留该行为。
- **验证**：覆盖 `R,U,U`、`R,U,R,U`、通知在原生前的重发、先累计 companion 后 last-only 重发、换 Turn 同值、独立 response 同值、累计实际增长，foreign/unknown owner 通知不重新计入，以及活动/归档副本。所有展示聚合与接受记录继续一致。
- **边界**：未读取实际日志，不能报告用户现有总量被多算多少；这是当前实现可确定复现的协议边界缺陷。

## 已确认 A2：非法累计子集增量被静默夹紧成“已知精确值”

- **优先级/收益**：P2；避免错误的缓存/新增输入/推理统计，预计 0.5–1 人日。低频异常输入，但修复局部、无需新增功能。
- **契约**：T01/T06/T08、debug-first。缓存/推理必须是真实子集；不合法或不完整的证据不能经静默修正变为精确值。
- **触发**：两个 individually valid 的累计快照 `(input,output,cached,reasoning)=(100,100,0,0)` → `(110,110,50,50)`。各快照均满足子集不超父项、数字非负；但两帧差值的 cache/reasoning=50，超过对应 input/output 增量=10，不能作为合法的一次累计增量。
- **本轮结果**：第二接受行被改为 `(10,10,10,10)`，`cachedInputKnown=true`、`reasoningKnown=true`，`warnings=[]`。全量输出 `(110,110,10,10)`；原始累计 cache/reasoning=50，结果却在没有诊断的情况下展示 10。总 input/output=220 没变，但“新增输入”也随之产生错误精确值。
- **定位**：`Sources/Core/Models.swift:41–51` 只检查各分量单调性，随后把差值交给 `TokenUsage.init`；16/18 行的 `min` 把 cache/reasoning 差额夹到父项范围。`CodexLogScanner.swift:837–844` 把该值当作成功差分接受。`difference` 也用于 860 的原生抵扣，因此边界应统一解决。
- **最小方案与取舍**：先在设计中确定“计数器无法核对”的处理。最小安全修复是在差分前核验子集增量≤父项增量，失败返回 nil，复用已有回退策略：只计可验证 last，没有 last 则跳过并建立新基线，同时诊断。其代价是在异常输入上可能保守少计 input/output；若要保留已能证明的父项增量，可单独把异常子集标未知并告警，但必须明确这一协议，不能继续夹紧且保留 known=true。不建议为此添加复杂通用数值容错层。
- **验证**：分别覆盖 cache 增长超 input 增长、reasoning 超 output、存在/缺少 last、未知子集前后转换、原生抵扣场景；检查原始快照仍可查，异常有诊断，UI/CLI 不再声称矫正数字是已完整记录。

## 当前源码独立编译与可复现命令

为排除工作目录旧二进制的影响，本轮把 CLI 源复制到临时 `main.swift`，仅删除 `import CodexStatsCore`，与**当前**两个 Core 文件直接编译。产品文件没有变化：

```sh
swiftc -O -swift-version 5 Sources/Core/Models.swift Sources/Core/CodexLogScanner.swift \
  /tmp/codex-stats-accounting-gbtiukpt/main.swift \
  -o /tmp/codex-stats-accounting-gbtiukpt/report
```

编译退出 0。可保留复现入口为 [accounting-repro.py](accounting-repro.py)，本轮规范化输出为 [accounting-actual.json](accounting-actual.json)。脚本默认独立编译当前 Core，临时生成七个合成输入，执行后自动删除临时目录；只用系统 Python、Swift，不安装依赖，不要求保留任何 `/tmp` 绝对路径。

```sh
python3 .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/research/accounting-repro.py
# 如主审已有当前源码构建的 CLI，可省略独立编译：
python3 .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/research/accounting-repro.py --binary .build/debug/codex-stats-report
```

脚本退出 0 仅表明复现执行完成；JSON 的 `correct_total_matches` / `diagnostic_present` 表达产品行为是否达到相应期望。不能把“执行完成”当作产品全部通过。

| 合成用例 | 应有总量/要求 | 本轮输出 | 结论 |
|---|---:|---:|---|
| 单个原生及匹配通知 | 110 | 110 / 1 行 | 对照正确 |
| 原生和 last-only 整组原样重发 | 110 | 220 / 2 行，0 告警 | A1 |
| 原生后仅重复 last-only | 110 | 220 / 2 行，0 告警 | A1，同根因 |
| 重复 native 后累计确实增长 | 220 | 220 / 2 行 | 对照正确，必须保留 |
| 两个不同 response 同样用量 | 220 | 220 / 2 行 | 对照正确，必须保留 |
| foreign owner 及通知整组重发 | 0 | 0 / 0 行 | 对照正确，不能重新计入 |
| 非法累计子集差值 | 不静默声称修正子集已完整记录 | cache/reasoning=10、known=true、0 告警 | A2 |

七个用例由独立编译的当前 Core 实际执行，输出同表。它们不是长期资源基准，也没有测量 RSS/footprint。最初一次运行的中间文件仅用于交叉检查，不是复现依赖。

## 排除误报与其他核查

| 范围 | 判断与边界 |
|---|---|
| 总量/缓存/推理定义 | Total 只 input+output；本轮不建议添加成本或额度。A2 是累计差分边界，不是重新定义总量。 |
| 真实 ID/内部键 | 最近修复已正确隔离缺元数据归组，owner 不再由文件名证明；不重复提出已有修复。 |
| 累计重复/重置 | 完整快照重发、旧快照重现、回退有/无 last 有明确策略和现有测试；A1 是已配对 last-only 与签名状态脱节的独立遗漏。 |
| 模型切换/跨日 | 时间与模型按接受事件归属；已知跨度缺历史时保守用 last。未知模型不回填；没有建议用未来上下文或文件 mtime 补用量。 |
| 归档/子 Agent/历史继承 | 稳定会话分组、物理 UUID 边界、相邻原生通知、可证继承前缀有实际代码和测试；不建议把不明 legacy 副本一律相加。 |
| 压缩 | 跨合法 owner 副本传播正向标记，缺显式模型保持 Unknown；原生/旧累计不交叉作差。近期修复无需重复报告。 |
| JSON/未知字段/时间 | 严格入口及 typed 诊断已经存在。合法无 LF 尾行可读取；损坏尾行保留待下次恢复。 |
| 范围与 UI/CLI 一致性 | App 和 CLI 同 Core，CLI 固定全部范围是已批准协议；不能将默认今日 vs CLI 全部差值误报。默认系统时区变化后需重启是已记录限制，不包装成新发现。 |
| 请求估算 | 事件边界与完整 Turn 是独立结构，估算有阈值/≈，缺失不删除 Token；当前静态追踪未确认另一项必须修复的问题。 |
| 完整 Turn 边界讨论 | 同 turn_id 的区间外原生响应也可显示该 Turn duration/TTFT：623–627 只按显式成员 ID 附加；合成 start 前响应已复现，但全 Turn 输出覆盖会正确退为 nil。数据设计写的是“至少一个”区间内响应即可附计时，可能是有意行为，暂不作为已确认缺陷，也不建议为了数量加入下一批；若希望更严格，先明确全 Turn 计时可显示在哪些成员行。 |
| 测试有效性 | 当前多数测试从合成 JSON 经真实 Scanner 到报告，并非 UI 假成功。现有总和一致断言无法捕获 A1/A2，因为错误从接受记录就开始、各聚合会一致错误；应补独立期望真值。未声称实际日志已独立核账或真实 App 点击已验证。 |

没有使用与本项目相关的持久记忆事实；轻量 MEMORY 查询没有得到本项目条目，所有结论均来自当前仓库与本轮合成执行。

## 性能候选的计量交叉复核

主审已用本轮刚构建的 SwiftPM debug CLI 独立重跑七个计量用例，其规范化输出与本分支直接编译当前 Core 的 release CLI 完全相同。该消息是本轮交叉证据，不是历史测试复用。

随后只读核对 `research/performance.md`、`evidence/scale-results.jsonl`、生成器与 scale-probe，并对照 `attachTurnPerformance` 和现有 Turn 测试。未重跑基准、未修改代码。

- **测量结论成立**：250→2000 Turns 的输入仅增 8 倍，warm 中位数 85.16→4368.38 ms、约 51 倍；与每 Turn 重复扫描完整会话的源码一致。1000/5000 会话的 today/all 对照支持逐会话日期 bounds 成本；计量分支未发现否定这两个性能候选的证据。同步投影耗时仍不等于实际 UI 帧耗时。
- **允许做索引，不能删不确定性证据**：性能优化必须基于完整物理副本中的 frames，不能仅索引已接受 records。foreign/missing owner、缺显式 Turn、无时间 native、被计量拒绝的旧通知仍可能否决完整速率（593–617）。未知 metadata 文件仍不得用内部键混入真实 Session 副本组（581）。
- **配对语义必须原样保留**：完整 Turn 核验使用 `pairedNotifications(log, inherited: 0)`（597），不能复用 aggregate 中已经裁掉继承前缀的配对结果。未配对旧通知是否相关是“物理 frameRange **或**同 Turn **或**区间内时间 **或**无时间”（601–603），不能降为单独 `turn_id` 哈希查询。即使通知后来没有成为计量行，仍须参与这条否决规则。
- **局部/全局否决不能混同**：当前任一真实副本有 incomplete、invalidLines 或 hasHistoryBase，均否决完整速率（608），包括已核验/空 history 引用；任一副本存在 failedTurn 或冲突生命周期则否决整个 timing（585–589）。这些条件不能在优化时“顺手放宽”，也不能把应完全未知的计时变成仅速率未知。不存在候选的副本不自动否决合法 duration/TTFT，但它的帧仍参与覆盖核验。
- **建议按安全程度分步**：先按真实 Session 预分组、每物理文件只配对一次、每会话展开 frames 一次、Turn→rows/回填索引，以及预计算文件级否决标志；这些都是消除重复工作。剩余时间区间查询可按需要再索引，但必须保留 frameRange、inclusive start/end 和 missing-time 的不同含义。不要为了“近线性”目标引入通用查询框架。简单合成形状可验收近线性，不承诺任意大量重叠 Turn/副本都严格线性。
- **实施顺序与验证**：A1 与性能索引同时接触通知配对，应先明确并修正 A1/A2，再冻结该计量版本作为性能对照。索引前后比较完整记录、身份、模型/日期/小时总量、diagnostics、requestEstimate、Turn duration/TTFT/output/count 的值与 nil 状态，不能只对总 Token。保留现有 Turn 回归，并补同 Turn 多物理副本、未完成副本、缺时间/缺 ID/foreign 帧、无 Turn 的区间内通知、边界外 frameRange 通知和已配对继承通知的交叉组合；上述计量数据不得在基准中以删数据提速。
