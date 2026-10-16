# 技术设计

正式契约见 docs/overview-trend-design.md。现状仅Token趋势，OverviewIndex无时段记录数，ValuationIndex无时段金额。扩展现有标量索引与同一summary，避免新缓存/记录副本/查询时扫描。

OverviewIndex复用日计数，增加绝对小时模型计数，summary暴露按日/小时记录数。ValuationIndex在后台对同一记录只计算一次Decimal金额并存日/小时桶；summary合并当期精确模型，保留CostEstimate完整覆盖，空桶使用当前价格revision。日索引沿用record.day，小时沿用timestamp及注入timezone。Store既有有界缓存、原子重估继续使用。

OverviewContent本地三态、默认Token；原生segmented Picker宽约270pt，标题左控件右。单位/空态/覆盖说明随指标切换；同一日期/小时轴，金额只把已计算Decimal投影Double供Charts，真实值/合计/帮助保留Decimal。

不变：Scanner/统计口径/CLI格式/菜单/侧栏/价表。最小变更预计OverviewIndex、UsageValuation、DashboardView与必要Store时区传递及Core/Store/原生宿主测试；root负责文档/版本/构建。若需要调整先更新本设计及正式契约。

## 原生复核调整

实测30日期标签和逐点“未计价/小计”文字重叠；正式契约增加约6个首尾刻度、>12桶符号+持续图例规则。root第一次构建已结束，此构建不作最终交付依据。修复后再次冻结、原生验证和重建。
