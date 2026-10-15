# 开发、构建与验证

所有命令均在仓库根目录执行。协作流程见 [参与开发](../CONTRIBUTING.md)，统计口径见 [统计说明](statistics.md)。

当前发布：**v0.2.9 / build 11**。当前生产菜单宽 288 points；用户已选择 B 视觉方向，尚待实现，不是运行时样式选项。

原生 macOS Codex Token 使用分析工具。macOS 14+，完全离线、本地只读，零第三方运行时依赖。

项目追踪：[产品需求与状态](requirements.md) · [设计与统计契约](design.md) · [实际验证记录](../VERIFICATION.md)。后续需求通过 Trellis 追踪，**先更新设计文档，再实现**。设计入口包含可重建的布局、数据、状态和构建契约，区分已实现与待实现。

开发入口：[参与开发](../CONTRIBUTING.md) · [仓库结构与开源准备](repository-layout.md)。`Sources/`、`Tests/` 保留 Swift Package 的标准目录名；编译缓存和 `dist/` 分发产物不属于待提交源码。


产品 Core、App 和 Report 均为 Swift，App 运行不依赖 Python。仓库中的 Trellis 工作流、Codex hooks 以及部分合成测试工具使用 Python；开发脚本的语言不会改变 App 的技术栈，详见 [仓库结构与语言统计](repository-layout.md)。

## 许可证与仓库

源码已发布至公开仓库 [lixd/codex-stats](https://github.com/lixd/codex-stats)，默认分支为 `main`。原创 App 源码、测试、资源和项目文档采用 [MIT](../LICENSE)，允许在保留版权及许可声明的条件下使用、修改和商业分发。

随项目保留的 Trellis 开发工具及模板保留上游 **AGPL-3.0-only**，不由根 MIT 重新许可，也不进入 App 运行时。具体授权边界与上游来源见 [第三方声明](../THIRD_PARTY_NOTICES.md)。

## 菜单设计方案

[打开两套原生菜单方案对比](menu-design-comparison.html)。浅色 / 深色截图使用同一份合成数据，B 已选定为后续方向，见 [B 目标设计](ui-design-b.md)，尚未进入生产 App。运行 `./Scripts/render-menu-designs.sh` 可重新生成原生 PNG；正式版只先缩窄现有菜单。

## 内存验证

`./Scripts/benchmark-performance.sh` 同时记录扫描速度、最大 RSS 和峰值 footprint，并核对固定合成日志的计量快照。`./Scripts/measure-app-memory.sh "dist/Codex Stats.app" LOG_ROOT OUTPUT` 用临时独立 bundle identity 启动同一个 App 可执行文件，采样启动后 10 / 35 秒的实际进程占用，再正常退出测试自身的实例；不关闭你正在使用的版本。它测量进程内存，不自行证明界面刷新成功。具体数值、输入和限制见 [VERIFICATION.md](../VERIFICATION.md)，扫描器数值不能当作完整 App 数值。

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

## 性能复测

```bash
# 生成约 350 MB 合成 fixture；WORK 只能使用专用空目录
./Scripts/benchmark-performance.sh /tmp/codex-stats-performance
```

脚本输出 cold / warm / 单文件追加 / 四档筛选的时间和完整计量快照。仅修改自行生成的合成 fixture，随后恢复追加长度；不能指向真实日志。cold 表示新进程解析缓存为空，不表示清空系统磁盘缓存。目标及本机前后结果见 VERIFICATION.md。
