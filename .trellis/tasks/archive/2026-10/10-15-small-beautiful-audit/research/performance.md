# 性能与资源独立审查

审查对象：v0.2.10 / build 12，任务基线 HEAD `11f2a93`。本笔记只修改本审查任务的 research 文件；未修改产品代码、测试或构建脚本，未启动或终止用户 App，未读取真实日志。动态基准由主审查者串行执行，本笔记已读取本轮 `evidence/scale-results.jsonl`、`scale-memory.txt` 与 `benchmark1.txt`。下面明确区分代码推导、实际同步计算测量和未进行的 UI 帧测量。

## 当前数据流和生命周期

- `UsageStore` 为 `@MainActor` 唯一共享 Store（`UsageStore.swift:40–48`），`ScanWorker` actor 独占扫描器（20–23）；解析/重建报告通过 `await worker.scan` 离开主 actor，成功后在主 actor 发布（132–155）。所以“JSON 解析在后台”属实，但“主线程只发布状态”不完全准确：摘要首次计算、会话/请求投影都在视图同步访问路径执行。
- 每 30 秒（用户可改 60/300/900 秒或关闭）一个重复 Timer；更改设置会 invalidate 旧 Timer，回调弱引用 Store（108–115）。刷新在飞时仅置一个 Bool，结束最多排队一次（132–155），不存在按 tick 无限堆积的任务队列。未见额外每秒 Timer 或持续动画。若单次扫描超过周期，pendingRefresh 会令下一次立即执行，但不是已测得的常态。
- 每次扫描重新枚举 JSONL 和 stat；路径+size+mtime 命中缓存后复用 ParsedLog（`CodexLogScanner.swift:68–120`），删除文件移出缓存。随后所有缓存元数据仍经过归组、去重、累计计算、Turn / 请求估算关联及排序，生成新 ScanReport（123–237）。文件缓存不等于整个报告缓存。
- 每个变化文件全读；64 KiB 分块及每行 autoreleasepool 已实现（920–937），不能再把历史 Foundation 临时对象积压列为当前缺陷。扫描器缓存保留 frames / 身份 / 时间 / 边界等证据（269–292）；发布报告另保留可接受 records / 日模型 / 小时桶（Models.swift:158–172）。正文不保留，元数据内存随事件数增长是准确性所需的现有代价，不能称固定内存。
- `UsageSummary` 单键缓存已实现，命中不重聚合，不保留 raw records（`UsageStore.swift:25–38, 85–95`）。成功刷新（即便未改变文件）更换报告并失效摘要，失败保留旧成功报告和摘要（140–148）。会话比较器已不再聚合；请求页已只有一次最终排序与底部合计。不要重复建议这些已修复项。

## 确认 1：完整 Turn 关联重复扫描整份会话，未变化的1.15MB日志刷新仍需4秒

- 分类：**已确认性能缺陷，P1**。本轮精确计量和完整 Turn 断言均通过，冷/warm测量已确认重复计算成本。
- 文件证据：`CodexLogScanner.swift:578–628`。每个完成 Turn 都筛选全会话 rows（590）、重新展开所有 copies.frames（593），每个副本重新调用 `pairedNotifications`（597；函数 684–702 全量遍历 frames），再遍历全 frames 进行覆盖判断（599–604），再次展开检查外来 / 缺 Turn 身份（612–616），最后遍历全部 records 回填（624–628）。另外两个关联函数按每个 session 对全 logs 做 filter（581、635），多会话数也有平方项。
- 触发：一个长会话有 N 个各含一个有效原生响应的完整 Turn。即使仅一个很小的日志且 stamp 全命中，计量后的附加关联仍约有 T×F / T×R 工作；没有正文解析不能规避。
- 用户影响：长会话会拖慢首次读取和每次默认 30 秒刷新，提高 CPU / 后台唤醒期间工作量；等待完整报告期间页面仍显示旧数据。扫描 actor 避免同步卡住主线程，但不消除资源与结果延迟。
- 本轮复现材料：本目录 `generate-scale.py` 创建 250/500/1000/2000 个完整 Turn；`scale-probe.swift` 验证每条的真实 owner/response、120 总 Token、2000ms Turn、100ms TTFT、20 输出及响应数1，再分别计冷扫描和3次全命中 warm。每档字节量随 N 线性增长。生成器不含真实文本，无原文件修改。
- 实测：250/500/1000/2000 Turns，文件144,123 / 288,123 / 576,123 / 1,152,123 bytes；warm中位数85.16 / 322.63 / 1320.51 / 4368.38ms，cold分别133.20 / 546.96 / 1882.83 / 5143.61ms。输入增长8倍时warm约增长51倍，支持代码中的平方项判断。2000档3次warm为5220.78 / 4368.38 / 4210.98ms，并非单次毛刺。不得将wall time直接折算为后台CPU百分比。
- 因果对照：主审另外运行相同2000请求、相同start事件，只删除task_complete的合成输入（820,123bytes）。总Token仍240,000、所有请求身份/行保持正确、Turn性能均nil；cold91.73ms、3次warm9.33–9.84ms，中位9.63ms（`evidence/control-results.jsonl`）。完整Turn版本warm慢约454倍；warm不重新解析文件，因而不能归因于删除完成事件少读了332KB正文。这进一步锁定计量后完整Turn关联路径。
- 最小修复：按 session 预分组 logs；每个会话预先建立 Turn→row indices / 原生 frames，并每个物理文件只计算一次 pairedNotifications。将需要全局否决的 foreign / explicitTurn 缺失 / 未配对 counter 元数据预分类，保留现有时间范围与 frameRange 覆盖规则。不是删除完整覆盖检查，也不是缓存一个未经失效验证的性能值。
- 取舍：额外短生命周期索引换时间；应先实现能去掉明显全量重复的索引，避免数据库/持久缓存/通用查询框架。覆盖含时间范围和无身份 counter，不能单纯按 turn_id 抽样而遗漏否决证据。
- 验证：保留全 Turn 回归矩阵；固定 synthetic 250→2000（必要时5000）规模，比对所有记录及可选 timing；比较 cold/warm 中位数和峰值内存，目标近线性，所有精确计量不变。增加性能数据形状作为基准覆盖即可，不把不稳定墙钟阈值硬塞单元测试。
- 估算：1–2 天实现和边界复核；高收益。

## 确认 2：会话页面仍逐会话创建日期格式器，1000会话同步投影约329ms

- 分类：**已确认同步计算性能缺陷，P2（下一批优先）**。没有声称测得实际窗口帧率或某次用户点击卡顿。
- 文件证据：`SessionsContent.swift:24–45` 每次 body 搜索/选中/排序/Store 更新重算匹配；对每个会话分别调用 `usage(in:period)` 和 `modelUsage(in:period)`（26–27）。这两个 API 各自 `period.bounds`（Models.swift:174–185），在非全部范围每次新建 Calendar/DateFormatter（213–226）。有 N 会话时，此处新建 2N 个格式器；并非“一个操作一次边界”。`recentSessions` 已先筛选且排序（296–299），随后 matching 再次排序（SessionsContent:34–41）。如果没有范围内用量，recentSessions 的两次 `dateString` 又会逐会话创建格式器（Models:233–239,298）。
- 用户影响：在很多会话时，历史会话页选中、输入搜索、切换筛选也可能触发可观的主线程工作；这与已经修复的“在排序比较器中重复聚合”是不同的剩余路径。
- 复现：本目录 `scale-probe.swift` 构造 1000 / 5000 个每会话一条日聚合和一条请求的元数据报告，测实际 UsageSummary、Core requests 和与生产 `matching(now:)` 相同的默认空搜索+recent排序投影，各5次、today/all对照。所有用量/模型/小时合计断言。**这是主 actor 上同步计算的时间，不是真实 SwiftUI 帧耗时或点击证据。**
- 实测中位数：1000会话today投影329.17ms / all投影1.50ms；5000会话today投影2160.80ms / all投影6.44ms。5000 today最短也1584.57ms，排除只有一次慢样本的解释。对照同报告实际UsageSummary首次计算仅5.53ms、Core请求筛选排序5.70ms，支持优先消除逐会话日期边界生成，而不是重做摘要缓存。
- 最小修复：在会话查询入口捕获一次 now/bounds，将同一边界用于筛选、usage、modelUsage；由一个 Core 投影操作返回所需行或扩展内部 API，避免跨层暴露过多实现细节。让调用者拥有最终排序，去掉 recentSessions 的前置排序或允许关闭它。先量化后决定是否还需一次有界投影缓存；不要一开始就增加多键查询缓存。
- 取舍：少量 Core API/视图接线变化；确保日期/未知字段一致，不能用跨午夜全局缓存掩盖成本。
- 验证：today/all 规模比较、各范围边界/跨日/DST与会话-模型-总量一致，搜索/选择/排序保持；另需生产窗口交互或 Instruments 核实实际掉帧改善。
- 估算：0.5–1 天；中高收益，是否入下一批依本轮测量。

## 不单独升格的问题与未验证项

1. **增长文件全读**是设计明示的取舍（design.md 性能节、scan-performance spec）。固定 350 MB 基准分成39份，追加仅改1份约9 MB（Tests/Performance/generate.py:14；main.swift:75–84），因此不能推导“单个350 MB增长日志追加也只需100ms”。建议受控单大文件追加测量；在数据证明用户负担前，不建议字节级增量、数据库、监听或持久缓存。
2. **请求搜索**每次 body 复制/筛选并排序记录，默认先排序后文本过滤（RequestsContent.swift:23–42；Models.swift:313–317），高记录规模有潜在成本，但当前没有真实 UI 大数据重绘测量，不能声称卡顿；先做规模测量，必要时仅调整过滤排序顺序/一个有界投影。
3. **Timer 能耗**：未设置 tolerance，但默认30秒是已批准行为，不凭静态代码将其称为能耗缺陷。现有 coalescing/weak capture 正确；Store 是 App 级单例，缺 deinit invalidate 不是已证实生命周期泄漏。长时间 hide/show、睡眠/唤醒、后台唤醒频率未测；可用隔离实例+Instruments Energy/Time Profiler 观察。
4. **单行内存**：64 KiB 是读块大小而非最大行上限，pending 保留至换行并执行全 JSON decode（920–936）；极长单行时瞬时内存随该行增长。没有用户数据证明此处需引入大规模流式 JSON 重写或任意截断日志上限，现阶段只记录边界。
5. **资源数字**：`time -l` 的 maximum resident set size 是整个基准进程最大 RSS，peak memory footprint 是其生命周期峰值；当前 footprint 需对确定 PID 的 vmmap 采样。AppMemory 10/35秒采样仅 App 进程 footprint，不证明加载完成/各页面打开，也不代表扫描 CLI。虚拟地址空间不可当作 RAM 占用。当前报告必须使用本轮 evidence 的数值，不复用 VERIFICATION 历史测量。
6. **内存与 UI 交互未直接验收**：本独立审查未运行用户 App、Instruments 或 UI 操作；UI 绘制、开窗后内存、长期驻留仍由独立验证补足。未观察到可证明的 cache/Task 永久增长或保留正文问题。

## 本轮对照基准与资源边界

- 原有固定输入：349,964,213 bytes、39文件、7020计入记录、9,043,780总Token。三次独立进程cold2.727 / 2.918 / 3.868s；warm55.42 / 63.35 / 100.02ms，中位63.35ms；追加118.73 / 127.34 / 130.39ms。四档筛选全部9.49–23.29ms。cold≤5s、筛选≤50ms每次均满足；warm≤100ms仅2/3满足，一次超0.02ms，因此不能报告全部严格通过，也不能凭这么小的单次超限宣称实质回归。第一次最大RSS77.81MiB、峰值footprint60.33MiB。该输入缺完整Turn生命周期，不能据此反驳上述小文件Turn成本。
- scale-probe总进程：41.10s real / 34.61s user / 1.00s sys；最大RSS93,405,184bytes（89.08MiB），峰值footprint87,081,608bytes（83.05MiB）。这涵盖所有档位、验证保留的报告和 in-memory projection，**不是单次scanner或完整App的当前占用**，不能拿它与上述CLI扫描峰值直接评判内存回归。
- 主审的实际构建App隔离身份采样：10秒当前footprint25.8M / 生命周期峰值30.3M，35秒当前27.2M / 峰值34.8M（保留 vmmap 原样 M 单位，不是 RSS）（`evidence/app-memory.txt`）。harness仅终止自身测试实例；它未打开全部页面、未用UI状态断言加载完成，也未测长期驻留，不能与CLI峰值直接互比。一次sandbox extension提示不影响进程采样及自身清理PASS；不把该提示单独列成产品故障。
- 所有测量为macOS27.0.1、8逻辑核、Asia/Shanghai、本机优化编译；主机其他进程负载不受本审查控制。重复warm/projection给出多样本，cold每档仅一次；没有清系统磁盘缓存。

## 基准命令（交给主审查者串行执行）

```sh
python3 .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/research/generate-scale.py /tmp/EMPTY-REVIEW-SCALE
xcrun swiftc -O -swift-version 5 -parse-as-library Sources/Core/*.swift Sources/App/UsageStore.swift .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/research/scale-probe.swift -o /tmp/scale-probe
/usr/bin/time -l /tmp/scale-probe /tmp/EMPTY-REVIEW-SCALE
```

stdout为逐行JSON，stderr为time资源统计。各输入目录由显式synthetic manifest标记；如目录非空生成器拒绝覆盖。峰值涵盖全部场景及本验证程序保留对象，不能按单个case归因。

对照另选空目录，生成器加 `--counts 2000 --without-completion`；已编译程序运行该目录并加 `--skip-projections`，只重复计冷/warm，不重复主线程投影测量。

## 对计量审查的交叉复核

读取 `accounting.md`、`accounting-actual.json`、复现脚本和当前aggregate/difference源码后，A1/A2均有足够证据，不是只有合计不一致的推测；现有多层合计一致不能否定它们。未运行额外测试，未改另一审查者的记录。

- A1最小修复需考虑已配对的完整累计companion（817–823）和last-only companion（871）都贡献重发证据；只补后一分支仍遗漏“累计companion之后出现相同last-only重发”。独立response与累计确实增长必须继续计入。
- A2在`difference`核验子集差额后返回nil是局部、安全的起点；同时需把现有848行“计数器回退”提示改为“累计计数无法核对”或细分异常原因，因为该反例各计数都上升，诊断不应虚构回退。是否保留父项增量而仅将子集标未知，应先在设计中决定。
