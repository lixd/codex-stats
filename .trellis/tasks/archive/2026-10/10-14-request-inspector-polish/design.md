# 设计
遵循父 design.md “请求表格与右侧详情”“显示与发布”。Core 增加可选完整 Turn timing 元数据，按 owner/turn identity 关联，保留 evidence/completeness；模型列表和Token计量不受timing影响。只有解析到可信 task_complete 的字段才显示，纯 item-envelope estimator 已实验失败，禁止使用。

RequestsContent 替换 sheet 为右侧 inspector，表格在 inspector 出现时仍可检索和选行，关闭后不清除查询/排序。合理固定时间/数字列宽，必要横滚可见。side panel 按基本信息、用量、统计来源、Turn 性能分区，性能上下文明确 scope。

复用 abbreviated 与 detailedNumber，main caption 紧凑而原始快照/ID 保持真实可复制；诊断消费typed model，分组与详情不吞项。单请求速度列未知为 —，help解释日志未记录。完整 Turn 均速显示“Turn 平均输出 … tok/s（含工具/等待）”。
