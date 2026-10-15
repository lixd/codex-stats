# 扫描与时间筛选性能优化

## 目标
承担父 AP03（R13/R02），在上一项计量契约通过后消除测量已发现的日期解析/筛选瓶颈。

## 验收
固定同输入及 release 编译：代表规模冷 scan 目标 <=5s、无变化 warm <=100ms、7000+ 条时间筛选及排序 <=50ms；记录受主机影响的实际时间，不宣称所有 Mac 有保证。单文件追加需测量并报告。所有 four periods、模型、Session、记录、day/hour、warning 均匹配计量基准，AP01 修复差异独立记录。

初次读取显示 loading，占位不伪装零用量；刷新保留成功数据，失败不改变成功刷新时间。today/6/29 日、午夜、DST/timezone、invalid timestamp、小数精度和 replay/order 必须自动覆盖。原缓存的 root/mtime/size 失效不能退化。

## 顺序与边界
依赖 physical-log-accounting 通过后执行。仅算一次边界、复用日期解析、消除 UI 冗余投影/排序；暂不做持久缓存/字节增量/监听。当前 planning，父审阅批准后才实现。
