# Publication preflight
- gh api user: lixd (public user id 31980412), codex-stats name unused at check.
- Credential-shaped token/private-key scans of prospective files found no candidates; user-home matches were generic cross-platform path comments only. This is bounded scanning, not a proof against all possible sensitive data.
- ./Scripts/test.sh: exit0; 114 tests passed. Build emitted existing CLT search-path linker warnings; build/test completed. Not a new UI click/macOS14 runtime verification.
- Repository-local Git identity lixd, 31980412+lixd@users.noreply.github.com; global config unchanged.
- RootMIT body obtained using gh api licenses/mit; installed @mindfoldhq/trellis0.6.17 package metadata/license AGPL-3.0-only, attribution to preserve separately.


## 2026-10-15：首次公开源码（R14/R17）

- 用户批准公开仓库与 MIT，`gh repo create lixd/codex-stats --public --source . --remote origin` 成功；`git push -u origin main` 成功。
- `gh repo view lixd/codex-stats --json nameWithOwner,url,visibility,defaultBranchRef,licenseInfo`：PUBLIC、main、MIT。
- 初始提交 `46c0e5305690190e188b5c57ac8996e074688d2d`；`git rev-parse HEAD`、`git ls-remote origin refs/heads/main` 和 `gh api repos/lixd/codex-stats/commits/main --jq .sha` 三者一致。
- `./Scripts/test.sh`：114 tests passed，0 failures，exit 0。现有 CLT 搜索路径 linker warnings 未影响编译与测试；不新增 UI 点击或 macOS 14 实机验收结论。
- 初次提交前审阅拟公开文件和忽略规则；凭证形态模式扫描无候选，用户目录匹配为工具中通用 Windows 路径示例。此为限定模式检查，不保证识别所有敏感信息。真实日志、个人 journal、构建产物不提交。
- 原创 App/测试/资源/项目文档 MIT；Trellis 0.6.17 独立开发工具和模板保留 AGPL-3.0-only，原文散列 d8a6cc31abc16b6748c7a21f21611f5a1ec33f67d22ca23d7da1c19b95496bee，路径归属见 THIRD_PARTY_NOTICES.md；工具不进入 App 运行时。
- 独立复核通过，首次导入仍保留 3 个既有文件中的 4 处空白检查提示（两处 Markdown 硬换行及两个 EOF 空行），没有把空 diff 或全量 whitespace 检查记为通过。详见归档任务的 check-result.md。
- 产品 40 个文件散列与整理前一致；App 保持 v0.2.9/build 11，B 方案仍待实现。此次只公开源码，不创建 GitHub Release 或上传 DMG。
