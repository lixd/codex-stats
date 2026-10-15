# 统计口径与数据边界

本文说明当前版本如何解释本地日志。实现级契约见 [数据设计](data-design.md)，实际核对结果见 [验证记录](../VERIFICATION.md)。

## 统计规则

**Total = Input + Output。Cached 已包含在 Input，Reasoning 已包含在 Output。**

1. `turn_context.model` 按记录顺序关联请求。模型可以在同一会话中多次切换；使用记录中的原始名称，不写死名单、不根据价格别名猜后台模型。声明之前、模型缺失或请求 Turn 不匹配时显示 `Unknown model`。
2. 新格式的 `token_usage_record` 按 `response_id` 全局去重，要求明确的 `thread_id` 匹配所在会话；缺失所有权或属于其他会话的继承请求排除。和相邻 `token_count` 核对后，同一请求只计一次，无效原生记录也不会通过累计通知重新计入。**压缩后的线程累计与上下文累计可能不同，不能交叉差分。** 未发出 token_count 的已保存请求也可计入。
3. 旧格式的 `total_token_usage` 使用差分，重复快照不相加。首个累计值大于最近请求时，只统计已观察到的最近请求，并提示缺失历史；不会把过去用量分配给当前模型/日期。
4. 计数器回退使用有效的 `last_token_usage`；缺失时跳过、重新建立基线并提示。非连续重现旧快照时保守去重，也提示可能存在相同值重置的歧义。
5. 没有累计值或响应 ID 的重复最近用量，无法可靠区分重发与同大小请求。相同 Turn/模型/用量保守去重，并明确提示可能少计。
6. Session ID 负责归组，物理 rollout UUID 负责历史身份。活动、归档、会话回退后的文件中可独立核验的原生响应均计入历史消耗，同一响应不重复求和。真实响应身份或用量矛盾则排除并提示；旧格式累计流覆盖不明时仍保守选择一个较完整流，**不盲目相加累计历史**。文件同名不是会话相同的证据。
7. 子会话可按父会话中完全相同的时间、Turn、模型和用量前缀去重，或排除外部 thread_id 请求。只有相同累计值不足以证明继承。无法验证的旧 fork 在界面标记风险，不按毫秒时间猜边界。
8. 自动压缩请求使用真实响应记录；无明确压缩模型时显示 `Unknown model`。较短副本缺少后续压缩标记不会形成假冲突，已有明确 payload 模型仍优先。只有压缩标记而没有用量，无法恢复消耗。
9. 每次请求/增量归属到该记录的本地日期。跨模型或跨日期的累计增量若与最近请求不一致，只计可确认部分并提示；无有效时间的用量不会分配到文件修改日期。
10. Input/Output 是必需字段，非法值、负数、布尔值、越界或子集大于父项的记录会跳过并提示。缺失 Cached/Reasoning 时仍统计有效的 Input/Output，但相关模型/会话/总览列显示 **未完整记录**，不假定零；非缓存输入也不假定已知。
11. 损坏行跳过并记录数量；尚未写完的末行下次刷新重试。`turn.completed` 仅在该文件没有常规用量记录时作为保守备用格式。
12. `history_base` 核验本地物理文件及 exclusive byte / ordinal 边界；正常引用、已核验重复副本和独立物理历史合并为信息。缺失或非法边界、非空循环、真实冲突和无法核实的旧累计覆盖保留风险提示；引用前缀之后的损坏不使有效前缀失效。

会话真实身份仅来自 session_meta；原生 thread_id 必须与该真实身份一致。内部归组 ID 不充当真实 Session ID。缺少身份显示“未记录”，不能复制为真实 ID；无法核验所有权的原生请求及对应通知不计入。详见 [数据设计](data-design.md)。

这些数字代表**本机可核验的日志用量**，不是订阅额度、实际扣费或服务器账单。未知/缺失部分会显示提示，统计可能少于实际使用。没有成本估算、登录、多 Provider、在线调用或云同步功能。

## 参考

实现核对使用的源码版本记录在 VERIFICATION.md。

- [Codex 官方 TokenUsage / TokenUsageRecord 协议](https://github.com/openai/codex/blob/2f05c0a71f59fb2f05800846351f3e9926c3e52b/codex-rs/protocol/src/protocol.rs)
- [ccusage Codex 数据源说明](https://ccusage.com/guide/codex/)
- [ccusage Codex 解析器](https://github.com/ccusage/ccusage/blob/57afdc255fcbe031b0ecd7cac487f8fd7c5d531f/rust/adapters/codex/src/parser.rs)

本项目不属于 OpenAI 官方应用。
