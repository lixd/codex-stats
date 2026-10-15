# 设计
遵循父 design.md “性能”；边界 Core Models/Scanner 和 App 请求投影/UsageStore/读取占位，性能脚本及测试。

操作级不可变时间边界使用显式 now 和 current zone，直接过滤已有 day，保留未来事件排除规则。重用 Foundation ISO parse style，浮点日期差异不能破坏原生重复或 legacy replay；必要规范化精度应有格式契约，不能无依据截断。UI projection 用报表和筛选为输入，避免每 body 多次筛选/排序，无失效规则不引入额外缓存。

性能基准使用独立 scanner 进程冷启动（非清空系统磁盘缓存），同 scanner warm、控制 append、固定 now 记录筛选。fixtures 保持合成和去敏，计量完整性断言必须先于速度结论。
