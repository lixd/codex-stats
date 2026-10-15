# 设计
读取父 design.md 的“计量与诊断”。改动边界 Core Models/CodexLogScanner、Report diagnostics 序列化和对应合成测试；App 仅做 compile 必要适配，分组布局由最后一项完成。

物理索引独立于逻辑 Session 分组，保留原生事件的真实身份及可核验元数据；重复冲突先核对，再累计。旧计数流与原生通知仍遵循现有 coveredCounts，不跨两个 counter 口径差分。不同物理代的原生请求可恢复，旧格式无法证实的重叠仍保守告警。历史引用按本地限制校验；累计消耗不因会话回退被删除。Session 显示元数据选取须有确定规则，不能用 metadata 推断模型。

ScanReport 诊断加入显式 severity/kind/context；CLI 的精确 Token 字段保持原值，新增诊断字段记录文档。可保留便于展示的文本，但类型不能由其反解析。
