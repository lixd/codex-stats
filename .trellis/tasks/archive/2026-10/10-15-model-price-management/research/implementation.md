# 模型价格管理实施记录

2026-10-15；实施角色：trellis-implement。用户已批准开始，当前任务的设计/需求先于产品改动。根会话负责文档/规范/版本、最终 Core/CLI/App 编译和交付；本记录仅报告实施者实际执行的工作。未提交/推送、安装/退出/替换用户 App，未读取真实日志或真实价格配置。

## 实现

- 新增 `Sources/Core/PriceCatalog.swift`：完整不可变有效表，schemaVersion=1、revision、按精确模型ID排序的 entries；三项单价使用十进制字符串持久化，校验非负数、有效精度和范围，真实零合法。每行包含内置/自定义来源及内置核验元数据。已经保存的完整表不会与未来默认表合并；空表合法，删除内置价不会重生，历史内置快照保留原价格/日期。
- `PriceCatalogFile` 只在文件确实不存在时采用默认价。明确读取/JSON/权限错误抛出；原子写入完整表。默认路径为用户 Application Support/Codex Stats/prices.json；所有测试显式注入临时 URL。没有网络、数据库、额外运行时依赖或日志写入。
- `UsageValuation` 支持有效 catalog、配置不可用原因、实际 revision 与采用的价格来源集合。现有逐记录覆盖/Decimal算法和未知缓存语义保持。ModelPrice 初始化时缓存不可变 ReferencePrice，避免逐记录重复解析三项价格。
- `UsageStore` 在原有 ScanWorker actor 串行保存与估值。改价不扫描 JSONL，保存成功才更新有效表，后台重算同一个已接受报告；快照同时携带报告、catalog、金额索引和全历史观察模型集合。scan/edit交叠通过 revision/报告代次重试收敛到同一对最新状态。保存失败保留旧表、报告、金额和刷新时间。初次配置错误仍允许扫描 Token，金额明确不可估。
- 设置新增同窗口“模型价格”子页，保留五项主导航。价格行采用三个数值分组，精确模型长名可换行；来源、编辑及删除保护可见。添加为原生 Picker，仅全历史 accepted 模型减已配置模型；不接受自由模型名或 Unknown model 猜价。编辑模型名只读。全部历史中有记录，或尚不能确认历史完整时阻止删除；内置与自定义同规则。动作执行时复核保护条件。
- 共用金额 help 使用实际 revision/来源，历史内置价不再误标当前核验日期，自定义价不冒充官方核验。请求详情使用当前原子快照价表；请求 Table 未增加列。CLI 读取同一 Core/路径，新增只读 `--prices PATH` 注入、参数错误和 help，配置损坏 stderr+exit1；所有层级与空会话 fallback 保留当前 revision。

## 本轮实施者改动范围

以 task-start `implementation-before.json` SHA256 为准，不把整个脏工作区差异归入本轮。新增/修改：

- Sources/Core/PriceCatalog.swift、UsageValuation.swift
- Sources/App/UsageStore.swift、PriceManagementContent.swift、SessionsContent.swift、Components.swift、RequestsContent.swift、DashboardView.swift
- Sources/Report/main.swift
- Tests/CodexStatsCoreTests/PriceCatalogTests.swift、Tests/PriceManagement/main.swift、Tests/UsageStore/main.swift、Tests/TokenDisplay/main.swift、Tests/UIPreview/main.swift
- Scripts/render-price-management.sh

CodexLogScanner.swift 与 Models.swift 计量/文件缓存/时间归属未改。本轮没有对已有安装、生命周期、构建发布脚本做产品改动。既有 UIGPreview/Store 测试所有新 Store 构造均注入临时价格文件。

## 实际验证

所有输出目录：`/tmp/codex-stats-price-management-20261015/`。

1. Core 与全 App 源码 `xcrun swiftc -swift-version 5 -parse-as-library -typecheck ...` 中间版本通过；最终 macOS14 typecheck、142项 Core全量、独立CLI手算和 App构建由根会话负责，见其最终verification，不能以此处中间结果替代。
2. `Scripts/test-usage-store.sh > .../store-verified.log` exit0。覆盖全历史早期模型候选、两种来源删除保护、警告阻删及信息诊断可删、持久删除、加价/改价/0价/重复/非法字段、不触发loading扫描事件、实际扫描/改价交叠、revision与快照配对、真实保存失败保留、坏配置金额不可估、无成功或失败扫描不放行删除；并保留原有扫描状态/摘要/范围/调色/重试回归。该可执行编译在最终不可变价格缓存优化前，价表状态与计算结果不变；根会话对冻结源码再跑最终门禁。
3. `Scripts/test-token-display.sh > .../display-final.log` exit0，en_US/zh_CN/fr_FR实际生产formatter；新增历史内置快照不误标当前日期、自定义来源不冒充官方的断言。
4. `Scripts/render-price-management.sh .../ui-verified > .../ui-verified.log` exit0。四个独立进程 cyan/blue × overlay/legacy，合计40张原生静态PNG；各950/1120、light/dark、长模型、添加/编辑表单、无候选、读取错误。950页document748<=clip748，1120页918<=918；纵向滚动允许，没有隐藏横向滚动来掩盖溢出。生产NSTextField三项输入实际绑定修改微小价格并保留显示。配置不可用明确“暂不能确定候选”，不伪装全部已配置。
5. `Scripts/render-ui-previews.sh .../regression-cyan cyan` 与独立 `.../regression-blue blue` 均exit0。包含原有菜单四范围/未知/加载/宽度288，模型/请求两宽与分界，详情派生字段，五页950警告/失败/信息恢复，生产色彩/对比度，80模型与80请求真实原生程序滚动，以及完整/部分/无价/微小金额价表合成样例。legacy进程也通过。其源码编译早于仅内部价格缓存优化，视觉与数据语义未变。
6. 受控优化对比：复制最终Core到临时目录，仅将 ModelPrice.price 改回旧computed解析作对照；两个 `xcrun swiftc -O -swift-version 5 -parse-as-library ... Tests/ValuationScale/main.swift` 可执行均exit0。固定100,000条accepted记录、100会话、10天、4模型、4,000标量桶；对照build=1.055019833s，缓存后=0.285882375s；单次范围合并分别0.00360525s/0.003827125s；两者精确USD=281.2、覆盖110,000,000 Token一致。日志scale-before.log/scale-after.log。这是同宿主单次时间样本，非RSS、footprint、内存峰值、帧率或用户实时App体验证明。

## 截图

- `ui-verified/cyan/prices-950-light.png`：价格管理浅青窄窗。
- `ui-verified/blue/prices-1120-dark.png`：晴蓝深色宽窗。
- `ui-verified/cyan/add-price-light.png` / `edit-price-light.png`：实际生产表单独立渲染。
- `ui-verified/cyan/unavailable-950-light.png`：配置错误，不显示虚假完整候选。
- `regression-cyan/valuation-menu-light.png`、`valuation-models-950-light.png`、`valuation-request-known-light.png`：关联金额组件/请求原生回归。

## 失败、限制与留待验收

- 初次Store/UI合成fixture跨会话复用了同一个response_id，触发真实扫描去重导致测试预期错误；改为独立ID后通过。未放宽Scanner或计量。
- 一次Debug编译默认ModuleCache路径被沙箱拒绝；改用独立/tmp module cache成功。未改变权限或绕过保护。
- 初次静态配置错误页将nil catalog经空候选显示为“全部已配置”；独立check发现后已修复，最终ui-verified更新。
- 当前离屏宿主无法取得SwiftUI虚拟AX的添加/编辑action。`ui-verified/*/native-sheet-actions.txt`如实标UNVERIFIED；没有伪称实际点击打开sheet、下拉选择、保存/取消/Escape或VoiceOver通过。表单为生产视图的独立静态渲染，字段绑定为真实NSTextField程序编辑，不能替代上述交互验收。
- macOS14/Intel运行、系统高对比度、人工键盘/鼠标/VoiceOver、公证与长期常驻性能仍留根会话说明。没有操作用户正在运行的App。
- 最后内部价格缓存修正前的中间build因源文件变化失效，根会话将重新构建；不要将失败的中间产物视为交付。

最终 Sources/Tests/Scripts 已冻结；此后实施者仅写本research记录。若发现新问题，先通知根会话停下构建再协调修改。
