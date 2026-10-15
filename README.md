# Codex Stats

原生 macOS 菜单栏应用，专注本地 Codex Token 使用分析。使用 Swift、SwiftUI 和 AppKit 开发，完全离线、只读日志，零第三方运行时依赖。

## 功能

- 菜单栏快速查看输入、输出、缓存、推理和总 Token。
- 按模型、会话和用量记录分析，支持搜索、排序及详情侧栏。
- 今天、近 7 天、近 30 天、全部时间；默认每 30 秒刷新。
- 自动识别模型，处理模型切换、累计快照及重复日志，未知数据明确标注。

统计基于本机保留的日志，不代表订阅剩余额度或实际账单。性能字段依日志完整程度显示，估算值标记为 ≈。

## 安装

需要 macOS 14+、Xcode 或 Apple Command Line Tools。从源码安装：

```bash
git clone https://github.com/lixd/codex-stats.git
cd codex-stats
./Scripts/install-local.sh
```

安装到 `~/Applications/Codex Stats.app`，从菜单栏波形图标打开。更新前请先退出旧版。当前为本机 ad-hoc 签名，尚未 Apple 公证；macOS 14 与 Intel 实机验收仍待完成。详见 [安装与使用](docs/usage.md)。

## 文档

- [安装与使用](docs/usage.md) · [统计口径与限制](docs/statistics.md)
- [开发、构建与验证](docs/development.md) · [参与开发](CONTRIBUTING.md)
- [产品需求](docs/requirements.md) · [设计基线](docs/design.md) · [仓库结构](docs/repository-layout.md)
- [实际验证记录](VERIFICATION.md)

## 许可证

原创 App 使用 [MIT](LICENSE)。随附的 Trellis 开发工具及模板保留 AGPL-3.0-only，详见 [第三方声明](THIRD_PARTY_NOTICES.md)；它们不进入 App 运行时。

本项目不属于 OpenAI 官方应用。
