# 源码仓库结构与发布边界

目标设计：2026-10-15，关联 R14/R17。状态：源码已提交并推送至公开仓库 [lixd/codex-stats](https://github.com/lixd/codex-stats)，默认分支 main，目录与忽略规则已建立。App 仍为 v0.2.9/build 11，本次不改变运行行为。

## 目录命名决策

Swift 语言没有强制所有目录首字母大写。Swift Package 的标准默认组织使用 `Sources/` 和 `Tests/`，本项目 Package.swift 显式指定了内部 target 路径。保持这两个名称；`Assets/`、`Scripts/` 是与现有脚本一致的可读组织约定，并非编译器强制。`docs/` 使用小写同样正常。不为看起来统一而重命名目录、引入路径兼容或改写所有构建脚本。

```text
codex-stats/
├── Package.swift              Swift Package 清单与目标定义
├── Sources/                   产品 Swift 源码
│   ├── App/                   SwiftUI/Charts/AppKit 界面与状态
│   ├── Core/                  Foundation 日志计量及聚合
│   └── Report/                离线核对 CLI
├── Tests/                     自动测试与原生预览/性能检查宿主
│   └── CodexStatsCoreTests/
│       └── Fixtures/          纳入仓库的合成日志样本
├── Assets/                    Info.plist 和图标源文件
├── Scripts/                   构建、测试、安装、打包脚本
├── docs/                      当前设计、需求与待实现 B 方案
├── .trellis/                  共享开发规范/任务及本地工作状态
├── .agents/skills/            项目共享的 Trellis 工作技能
├── .codex/                    项目共享的代理配置与 hooks
├── AGENTS.md                  项目协作规则
├── CONTRIBUTING.md            开发入口与提交前检查
├── README.md                  使用和构建入口
└── VERIFICATION.md            实际验证历史与限制
```

根目录原有 `Fixtures/` 是空目录，不被 Package.swift 使用；删除空壳，不移动测试数据。测试、脚本、资源与文档属于完整源码工程，但不都是 App 编译源码。Tests 下原型宿主不进入生产 App 目标。

## 本地生成物与个人状态

`.build/` 为 Swift 编译缓存，`dist/` 为 .app、DMG、源码 ZIP 和预览等交付产物，均不进 Git。它们留在磁盘以支持已有构建与下载；不因初始化仓库自动删除。根空目录不进入 Git。

忽略 `.swiftpm/` 本地工作区状态、Xcode 用户状态、.DS_Store、Python缓存、个人 `.env`（允许 `.env.example`）、`.trellis/workspace/` 私人journal；Trellis 的 .developer、.runtime、当前任务指针及缓存继续由自身 .gitignore 排除。共享 spec、workflow、scripts、任务文档和项目代理配置仍保留可版本化。

**不能全局忽略 *.jsonl**：Tests 中的合成 fixture 是统计回归的必要组成。真实 Codex 日志不应放进项目，不允许通过 `git add -f` 绕过产物/个人状态规则。Git ignore 不是隐私扫描或许可证审查，历史任务和验证记录仍应在公开发布前审阅。

## Git 与开源状态

首次本地规范化仅运行 `git init -b main`。用户随后批准公开仓库和 MIT，完成初始提交及 main 推送。未来提交前按当前 Trellis 流程检查任务范围、设计和验证；Git 身份仅配置在当前仓库，不修改全局配置。

上述 Git 初始化描述是首次本地规范化时的操作边界。2026-10-15，用户另行明确授权公开仓库 `lixd/codex-stats`、MIT 和首次提交推送；发布结果见下节，初始化时“无远端”仅为历史状态。

原创 App 源码、测试、资源及项目文档采用根目录 [MIT](../LICENSE)。独立 Trellis 开发工具与模板保留上游 AGPL-3.0-only，完整原文位于 [licenses/Trellis-AGPL-3.0.txt](../licenses/Trellis-AGPL-3.0.txt)，归属与混合文件边界见 [第三方声明](../THIRD_PARTY_NOTICES.md)。发布前仍须审阅历史材料中的本地信息及第三方授权，此文档不代替远端发布验证。

## 验收

- `git rev-parse --show-toplevel` 等于当前项目根，`git symbolic-ref --short HEAD` 为 main。
- `git check-ignore` 确认生成物/个人状态被忽略，Sources/Tests/Assets/Scripts/共享规范未被忽略。
- `xcrun swift package describe --type json` 仍识别原有 Core/App/Report/测试目标；产品文件散列不变。
- 文档链接存在，`git diff --check` 检查已暂存或追踪变更时才有意义；首次未暂存仓库不能把空 diff 当作全部文件通过。


## 首次公开结果（2026-10-15，已验证）

用户确认创建 `https://github.com/lixd/codex-stats` 公开仓库，自有 App 源码使用 MIT，首次提交推送 main。Git author 使用当前仓库局部配置 `lixd <31980412+lixd@users.noreply.github.com>`，不修改全局身份。

已安装 `@mindfoldhq/trellis` 0.6.17 的 package.json 与 LICENSE 明确为 AGPL-3.0-only。随项目保留的独立开发工具/模板沿用原许可证和完整声明；根 MIT 不覆盖第三方材料。Trellis 不进入 App target 或 .app 构建，不能仅因 App 选择 MIT 就重新许可这些工具。具体路径见 [第三方声明](../THIRD_PARTY_NOTICES.md)，完整原文保存于 [licenses/Trellis-AGPL-3.0.txt](../licenses/Trellis-AGPL-3.0.txt)。

本次不发布 DMG/Release，不声称已完成全部平台/UI验收。真实日志、凭证、用户journal、运行缓存和构建产物保持忽略；模式扫描没有找到真实token/private-key候选，路径命中为工具中的通用 Windows 示例。已核验 GitHub 为 PUBLIC、默认分支 main、根许可证识别为 MIT；初始提交 `46c0e5305690190e188b5c57ac8996e074688d2d` 与远端 main 及 GitHub commits API 一致。详细证据见 [VERIFICATION](../VERIFICATION.md)。
