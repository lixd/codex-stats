# 定价研究：初步口径

核验日期：2026-10-15。来源：[OpenAI API Pricing](https://developers.openai.com/api/docs/pricing)，本轮通过 web search + open 实际读取。

网页按每百万 Token 列出输入、缓存输入、缓存写入、输出；区分 Standard/Batch/Flex/Fast/Ultrafast 和长短上下文，并说明部分附加费。由此不能仅凭模型总 Token 反推真实美元扣费。此次只核验计费维度，不将网页多档表格扁平结果直接作为可执行价目表；精确模式、模型和规则需在实施前再确认并固定证据。

本地 TokenUsage 可计算缓存输入占比；已有数据不含服务档位、计费上下文或缓存写入量。非缓存输入、缓存输入、输出三部分的固定价格折算可以作为明示假设的参考指标，不能命名为真实账单或订阅额度。推理已含输出，不额外加一次。

推荐：版本化内置价格快照、记录官方来源及核验日期、仅精确匹配有确认价格的模型；未知项保留未知，混合覆盖明确小计和未覆盖量。禁止读取凭证、运行时联网或通过模型名相似度猜价。

尚未决定：用户是否接受标准参考价；上下文档/写入缺失的展示边界；是否按统一当前快照折算所有历史（推荐作参考价值，而非声称复原历史账单）；各页面首批范围。不输出实际金额或具体费率。

## 2026-10-15 用户口径确认后收敛

用户接受官方API标准参考价折算。设计提案选择Standard短上下文三项参考基准，全部历史使用同一内置快照，不估复原账单。额外缓存写入费、长上下文、其他服务档、地域/税费/工具费不在本指标中，设置说明和金额help必须明确。该更具体基准仍待最终方案审核。

本轮重新通过web open读取官方定价HTML，标准栏及短上下文列明确列出以下每百万USD（顺序 input / cached input / output）：gpt-6.1-sol：2 / 0.10 / 10；gpt-6-astra：10 / 1 / 50；gpt-6-luna：0.10 / 0.01 / 0.50；gpt-5.3-codex：1.75 / 0.175 / 14。实施前核对引用和测试固定此快照，模型ID必须精确匹配；不覆盖Unknown model或codex-auto-review。价表标识建议 openai-standard-short-2026-10-15。以上只是内置设计证据，未有产品可执行价格表。

[官方Reasoning说明](https://developers.openai.com/api/docs/guides/reasoning)本轮web find实际读取：reasoning tokens作为output计费；因此已有output包含reasoning时不能再加一次。

工具证据：web成功读取pricing/guide HTML；pricing.md的web读取不支持text/markdown，urllib尝试因本地证书验证失败，未关闭TLS校验或将失败当成功。以HTML本轮证据为准。此前“尚未决定”的产品含义现由用户答复解决；最终方案以docs/cache-rate-cost-design.md覆盖早期研究建议。
