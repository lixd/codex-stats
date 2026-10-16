# 开发、构建与验证

所有命令均在仓库根目录执行。协作流程见 [参与开发](../CONTRIBUTING.md)，统计口径见 [统计说明](statistics.md)。

当前源码与本地验证构建：**v0.2.17 / build 19**，尚未自动安装或发布；本轮不操作用户正在运行的版本。当前菜单宽288 points，固定B结构；分析窗口使用D布局，设置可切换浅青/晴蓝配色。

原生 macOS Codex Token 使用分析工具。macOS 14+，完全离线、本地只读，零第三方运行时依赖。

项目追踪：[产品需求与状态](requirements.md) · [设计与统计契约](design.md) · [实际验证记录](../VERIFICATION.md)。后续需求通过 Trellis 追踪，**先更新设计文档，再实现**。设计入口包含可重建的布局、数据、状态和构建契约，区分已实现与待实现。

开发入口：[参与开发](../CONTRIBUTING.md) · [仓库结构与开源准备](repository-layout.md)。`Sources/`、`Tests/` 保留 Swift Package 的标准目录名；编译缓存和 `dist/` 分发产物不属于待提交源码。


产品 Core、App 和 Report 均为 Swift，App 运行不依赖 Python。仓库中的 Trellis 工作流、Codex hooks 以及部分合成测试工具使用 Python；开发脚本的语言不会改变 App 的技术栈，详见 [仓库结构与语言统计](repository-layout.md)。

## 许可证与仓库

源码已发布至公开仓库 [lixd/codex-stats](https://github.com/lixd/codex-stats)，默认分支为 `main`。原创 App 源码、测试、资源和项目文档采用 [MIT](../LICENSE)，允许在保留版权及许可声明的条件下使用、修改和商业分发。

随项目保留的 Trellis 开发工具及模板保留上游 **AGPL-3.0-only**，不由根 MIT 重新许可，也不进入 App 运行时。具体授权边界与上游来源见 [第三方声明](../THIRD_PARTY_NOTICES.md)。

## 菜单设计方案

[打开两套原生菜单方案对比](menu-design-comparison.html)。浅色 / 深色截图使用同一份合成数据，生产已采用 B，见 [B 设计](ui-design-b.md)；此对比仍是原型参考。运行 `./Scripts/render-menu-designs.sh` 可重新生成原生 PNG；正式视图状态预览使用 `./Scripts/render-ui-previews.sh`。

## 内存验证

`./Scripts/benchmark-performance.sh` 同时记录扫描速度、最大 RSS 和峰值 footprint，并核对固定合成日志的计量快照。`./Scripts/measure-app-memory.sh "dist/Codex Stats.app" LOG_ROOT OUTPUT` 用临时独立 bundle identity 启动同一个 App 可执行文件，采样启动后 10 / 35 秒的实际进程占用，再正常退出测试自身的实例；不关闭你正在使用的版本。它测量进程内存，不自行证明界面刷新成功。具体数值、输入和限制见 [VERIFICATION.md](../VERIFICATION.md)，扫描器数值不能当作完整 App 数值。

## 测试与核对

```bash
./Scripts/test.sh
# App 数字格式与三个区域设置的回归检查（macOS）
./Scripts/test-token-display.sh
# 实际 UsageStore 加载 / 失败保留 / 目录切换 / 双配色偏好回归
./Scripts/test-usage-store.sh
# 价格管理页/表单与950/1120、双配色明暗、原生滚动几何
./Scripts/render-price-management.sh /tmp/codexstats-price-preview
# 合成日志原生界面、同宿主配色重绘与搜索/选择保留
./Scripts/render-ui-previews.sh /tmp/codexstats-cyan-preview cyan
./Scripts/render-ui-previews.sh /tmp/codexstats-blue-preview blue
# 构建 / 安装失败保护及真实隔离 App 启动检查（macOS）
./Scripts/test-app-delivery.sh
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

v0.2.16增加`derived.cacheRate`（状态、分子分母和fraction）与`derived.cost`（精确十进制USD字符串、版本、覆盖及原因）；`--records`增加`recordDerived`。无法估价金额为null，零输入/不完整缓存比例为null且保留明确状态，详见[派生设计](cache-rate-cost-design.md)。

JSON 包含四项 Token、`cachedInputKnown`/`reasoningKnown`、模型、会话、typed `diagnostics`（severity / kind / 会话 / 文件 / message）及 warning/error 的 `warnings` 投影；总 Token 用 `input + output` 计算。当 known=false 时，对应的数值仅是内部已知部分的汇总，不应当解释为完整 Cached/Reasoning 数字；Non-cached Input 也不可据此推断。

`--records` 增加 `records` 数组，包含真实 ID（存在时）、时间、模型、Session ID、项目、已计入用量、统计依据及原始用量快照，可选 `turnPerformance` 的 durationMilliseconds / firstTokenMilliseconds / outputTokens / responseCount。后两项只在全 Turn 输出覆盖完整时提供，不能按当前列表的输出替代。JSON 的 `id` 是内部行标识，真实请求标识位于 `requestID`；`sessionID` 是本地归组标识，真实会话标识位于可选的 `recordedSessionID`。缺少真实 ID 时不导出该可选字段，不能把内部标识用于推断真实 ID。时间使用 ISO 8601 格式。导出仍为本地操作，请自行保管包含会话元数据的文件。

开发时可用 ccusage 单独对照（仅验证使用，App 不依赖 Node）：

```bash
CODEX_HOME=/path/to/frozen/logs npx ccusage@20.0.31 codex session --json --offline --no-cost --speed standard
```

请使用同一份不再变化的日志。ccusage 的 `inputTokens` 是非缓存输入，对照本应用 Input 时需加上 `cacheReadTokens`。它的模型 fallback、副本策略和未通知请求处理可能不同，不能将差异一律判为应用错误。实际结果见 [验证记录](../VERIFICATION.md)。

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

构建先在输出目录的唯一暂存目录中完成编译、资源和严格签名校验；目标 App 正在运行时拒绝覆盖。安装脚本在目标卷暂存，拒绝任何同 bundle identifier 的运行实例，保留用户手动退出的控制权。`Scripts/app-delivery.swift` 是仅供开发脚本使用的系统框架帮助程序，不进入 App 包或运行时。

已存在目标使用 macOS `renameatx_np(RENAME_SWAP)` 原子交换，首次发布使用 `RENAME_EXCL`。不支持该原语或跨卷时直接失败，不降级为先删后复制。发布前失败时目标保持原样；交换后启动失败则明确报告“已替换但启动未确认”，并打印旧副本路径供恢复。成功后清理自身暂存目录，清理失败另行警告，不改变已经发布的结果；进程被强制终止可能留下暂存目录，原子交换不会留下因删除旧目录而产生的目标空档。这不承诺断电后的磁盘持久性或自动恢复服务。

启动核验绑定 LaunchServices 返回的新 PID / 启动时间 / bundle 与可执行文件路径，核对目标版本及可执行文件 SHA256。它不是应用内版本握手，也不证明长期驻留；检查与启动之间用户仍可独立启动副本，因此不能把运行实例检查解释为全系统互斥锁。交付测试只用临时目录和 UUID 身份的原生 App，另由测试 App 自身写入版本回执，覆盖真实编译/复制/签名失败、旧副本散列、运行实例拒绝、原子交换和成功/失败启动。中断检查只对独立测试构建进程组在发布前发送 SIGKILL，证明旧副本保留且暂存残留可见，不代表测试了断电或交换系统调用内部的中断。

## 性能复测

```bash
# 生成约 350 MB 合成 fixture；WORK 只能使用专用空目录
./Scripts/benchmark-performance.sh /tmp/codex-stats-performance
```

脚本输出 cold / warm / 单文件追加 / 四档筛选的时间和完整计量快照。仅修改自行生成的合成 fixture，随后恢复追加长度；不能指向真实日志。cold 表示新进程解析缓存为空，不表示清空系统磁盘缓存。目标及本机前后结果见 VERIFICATION.md。


v0.2.17支持本地模型价表，默认App/CLI读取`~/Library/Application Support/Codex Stats/prices.json`，CLI只读，不写文件。可用`codex-stats-report LOG_ROOT --prices /tmp/synthetic-prices.json --records`注入独立测试表。JSON包含schemaVersion/revision/entries（model、input/cachedInput/output十进制字符串、source与可选来源日期）；输出priceCatalog与每层priceVersion/priceSources。缺文件用默认表，空表合法，损坏表返回非零stderr。测试必须注入临时价表路径，避免读取开发者真实配置。详见[价格管理设计](model-price-management-design.md)。


v0.2.18总览筛选使用后台OverviewIndex标量桶与独立单项摘要缓存；新增`Scripts/render-overview.sh /tmp/synthetic-overview`验证真实生产视图的筛选状态、长名、大金额及document/clip几何。该脚本使用临时价表/日志及隔离偏好；不要以离屏预览替代鼠标Picker、导航和VoiceOver验收。查询契约见[overview-query](../.trellis/spec/backend/overview-query.md)。
