# 请求侧栏、性能口径与单位补齐

## 目标
承担父 AP04/AP05/AP06，消费已通过的计量和性能数据；参考 CC Switch 表格与详情侧栏，信息准确且可读。

## 验收
菜单 footer、卡片 subtitle、会话标题、列表合计使用共享 K/M，exact 原值可 help/复制，CLI 整数不动，unknown 不伪装 0。默认 time 可见，搜索/筛选/排序保留。右侧详情关闭/Esc/切换记录不丢列表状态。

请求耗时/速度无可靠字段时为 —；详情另列完整 Turn 的 duration、TTFT、覆盖确认后的平均 output tok/s。明确包含工具和等待，不标成纯生成速度；分子使用全 Turn 去重输出而非当前日期筛选部分。多响应、缺失/中止/invalid timings、跨 day/physical lineage、不完整 history、重复 response、外来 owner 和 cumulative 行不得产生假请求性能。

诊断按级别/类型分组摘要，查看所有细节；history_base 正常信息不橙色刷屏，真实影响用量的 warning 仍醒目。light/dark、loading/empty/error/多响应/unknown 合成静态预览；真实交互另验收。

## 顺序与边界
依赖前两子项通过；父最终方案批准前 planning。只参考布局，不增加 provider、cost/定价/网络请求或日期选择器。原单位规范的 exact-card-subtitle 约定需同步变更。
