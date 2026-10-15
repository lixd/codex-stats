# 执行与验证

状态：completed（实现、独立检查、发布已完成；真实交互与 macOS 14 验收限制见验证记录）。用户已在最终方案后回复“开始吧”，父项与三个子项获批；按顺序执行，验收记录不得将规划写成完成。

- physical-log-accounting：独立 check PASS，70 项 Core 测试及原生构建通过；修复归档前缀缺压缩标记的假冲突和冲突诊断遗漏来源。父集成固定元数据快照已独立核对 8,229 个原生响应；最终 release CLI 复核待完成。
- scan-filter-performance：独立 check PASS，78 项 Core 测试、UsageStore 状态与原生构建通过。串行固定输入冷扫描 8.265 → 3.472 秒，warm 54.64 毫秒，四档筛选 11.87–17.76 毫秒；完整统计快照一致。明确拒绝非法 Gregorian 日期、时钟和偏移，合法输入保持旧毫秒精度。
- request-inspector-polish：最终全范围独立 check PASS，100 项 Core 测试、三地区格式、真实 Store 与原生构建通过；包含右侧详情、真实 Turn 元数据、单位与分组诊断。父项最终性能复测、发布校验及归档均已完成。

1. 顺序启动 physical-log-accounting、scan-filter-performance、request-inspector-polish；每项使用 Trellis implement/check 角色，注入其 curated manifests。先读 trellis-before-dev 与实际项目规范。
2. 第一项先写能复现“最长物理副本漏计”的合成夹具，核对原生所有权、重复/冲突与旧累计覆盖，之后改计量/typed diagnostics。以 independently identified response oracle 核对模型、Session、日/小时和记录合计；不要求错误旧总量保持不变。
3. 第二项冻结无敏感内容的代表规模数据，记录优化前 cold/warm/append/filter；只优化已测瓶颈。使用原计量与第一项通过后的计量基准分别比较，防止混淆 bug 修复与优化。
4. 第三项解析真实 Turn timing，增加缺失/中止/多响应/继承/重复用量测试；完成侧栏、紧凑单位、loading/diagnostic UI，不制造速度数据。
5. 每子项运行适用自动测试和构建；父项执行全范围 Core 回归、单位检查、生命周期检查与静态 light/dark previews，检查表格列和 side panel 有数据/缺失/错误/初次读取状态。
6. 更新 docs/requirements.md、docs/design.md、README.md、VERIFICATION.md 和 relevant .trellis/spec；在无 Git 条件下记录检查结果，不初始化仓库。归档/记录 journal 后刷新源码 ZIP。

验证入口：./Scripts/test.sh；./Scripts/test-token-display.sh；./Scripts/test-app-lifecycle.sh；./Scripts/build-macos.sh；./Scripts/render-ui-previews.sh；./Scripts/make-dmg.sh。新增合成性能/计量 oracle 作为可重复脚本，运行参数及结果写 verification。具体 timing 不能依赖实时增长的日志制造稳定基准。

风险点：CodexLogScanner.swift 的身份/所有权/配对；Models.swift 时间筛选和 public report 契约；UsageStore.swift 结果及缓存失效；RequestsContent.swift inspector 选择状态。因无 Git，编辑前对任务涉及源码做本地临时副本，仅恢复本任务变更；不覆盖其他既有工作。

验收限制：当前主机不是 macOS 14；此前 CUA 超时，static preview 不等于 clicks/hover/Esc 真机验证。尝试可用原生验证方式，失败保留待人工检查记录，不宣称已验收。检查失败先修根因，不通过重试/降级伪造成功。
