# 执行计划

- [x] 留存当前原生请求页几何/截图，记录十列原生额外空间。
- [x] 只改Dashboard请求页头和RequestsContent布局/列宽/响应式字段组合与详情sheet；需要时最小调整尺寸方案并先更新目标设计。
- [x] UIPreview增加真实请求表几何检查及多行到达验证，完整运行cyan/blue矩阵；比较1120与950均不得横向溢出，含详情/空/未知；关闭详情保留筛选/排序。
- [x] 运行 Scripts/test.sh（Core+App/CLI编译）、必要格式测试；trellis-check独立复核所有本轮差异。
- [x] bump v0.2.14/build16，独立优化构建并检查签名/系统依赖；同步docs/VERIFICATION/spec和任务证据。
- [x] 对照before-hashes确认Core/Store/菜单/交付脚本未改；归档和journal，不提交推送。

父会话负责文档/版本/交付；implement子Agent负责Sources/App/DashboardView.swift、RequestsContent.swift、Tests/UIPreview/main.swift及任务中的测量证据。不要回滚已有脏工作树。代码回退只使用本任务前副本，不能git reset/checkout全文件历史。
