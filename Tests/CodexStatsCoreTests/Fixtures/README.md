# 合成测试数据

`switch-model.jsonl` 不含真实用户日志或提示词。它模拟 model-A → model-B，且第二个增量跨到下一天。

预期累计：Input 250、Cached 180、Output 30、Reasoning 15、Non-cached 70、Total 280。

model-A：Input 100、Cached 80、Output 10、Reasoning 5、Total 110。

model-B：Input 150、Cached 100、Output 20、Reasoning 10、Total 170。

其他场景由测试中的固定字典生成，写入独立临时目录，测试结束后删除。日期固定；时区边界测试显式指定 UTC 或 Asia/Shanghai。
