# 执行
1. 上一项通过后 start；记录固定 input 的 correctness + timings 基线。
2. 对 period-bound hoisting 写日期边界测试，修改一次计算的过滤/聚合。
3. 日期 parser 替换写格式和 ordering/replay 测试；清除 UI 二次不必要排序/计算。
4. loading 状态区分尚无报告、正在刷新与真实空数据/错误。
5. ./Scripts/test.sh；性能基准 cold/warm/controlled append/filter；./Scripts/build-macos.sh；check 与父研究数据对照。
6. 若目标未达到，记录瓶颈并测量再决定；不可偷偷添加持久缓存或复杂 incremental reader。更新 R13、design/verification，但不将未做字节增量称已实现。
