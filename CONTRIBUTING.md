# 参与开发

当前工程使用 Swift Package，目标 macOS 14+；Package 和 Swift Testing 需要 Swift 6.0+ 工具链，源码当前使用 Swift 5 语言模式。macOS 请安装 Xcode 或 Apple Command Line Tools，使用 `xcrun swift`，避免调用到其他同名命令。

先阅读 [设计总纲](docs/design.md)、[产品需求](docs/requirements.md) 和 [仓库结构](docs/repository-layout.md)。项目通过 Trellis 跟踪需求，遵循 [AGENTS.md](AGENTS.md) 与 [设计优先流程](.trellis/spec/guides/design-first.md)：**先更新受影响的设计和验收条件，再修改实现**，任务中关联 R/T 需求编号。已实现基线和待实现方案分开记录；B 菜单方案已选定，但尚未进入生产版本。

## 本地开发与验证

在项目根目录执行：

```bash
# 核心计量与回归测试
./Scripts/test.sh
# 数字显示和 UsageStore 状态回归（macOS）
./Scripts/test-token-display.sh
./Scripts/test-usage-store.sh
# 构建并试运行原生 App（macOS）
./Scripts/build-macos.sh
open "dist/Codex Stats.app"
```

按改动范围补充必要验证。界面改动可运行 `./Scripts/render-ui-previews.sh` 生成合成数据的深浅色预览；静态预览不证明菜单点击或窗口交互正常。生命周期改动使用 `./Scripts/test-app-lifecycle.sh`，运行前退出其他 App 副本。统计变更必须添加能复现问题的合成日志测试，不使用真实会话或凭证作为 fixture。

App 使用本机 ad-hoc 签名，构建架构跟随当前 Mac，尚无 Developer ID 签名或 Apple 公证。`./Scripts/make-dmg.sh` 生成本地分发包，不代表完成跨设备、Intel 或 macOS 14 实机验收。各次实际执行结果及限制见 [VERIFICATION.md](VERIFICATION.md)。

## 提交与公开发布前

- 保持变更与任务一致，更新设计状态、验证命令和未验证事项；不要把未执行检查写成通过。
- 检查 `git status --short` 和拟提交内容。`Sources/`、`Tests/`、资源、脚本及共享开发规范可纳入版本管理；`.build/`、`dist/` 和个人 Trellis journal 等本地产物不提交。
- 不提交真实 Codex 日志、提示词、账户文件或个人 `.env`，不通过强制添加绕过忽略规则。合成 JSONL 测试数据需要保留。
- 原创 App 代码、测试、资源和项目文档采用 [MIT](LICENSE)。提交原创贡献时应确保你有权按相应许可证提供该内容。
- Trellis 开发工具和模板中的上游部分保留 AGPL-3.0-only；修改或再分发时保留许可证与声明，不将其重新标为 MIT。详见 [第三方声明](THIRD_PARTY_NOTICES.md)。
- 源码仓库为 [lixd/codex-stats](https://github.com/lixd/codex-stats)，默认分支 `main`。公开提交前审阅历史任务和验证记录中的本地信息，并确认新增第三方代码、资源和工具的授权来源。
