# 原生 A 实现设计

已批准产品契约：docs/model-layout-proposals.md的A原生实现与验收契约。资料状态：HTML只作布局方向，v0.2.14为旧基线，本轮验证为独立证据。

数据流保持 ScanWorker→UsageStore→summary(period).models→现有筛选排序→LazyVStack。改变仅渲染，不新增聚合/缓存/选择/定时器。现有abbreviated/detailedNumber与known标志逐项使用。

替换旧模型Table与断言，不修改请求Table。通过实际NSScrollView宽度及80个合成数据末项可达验证滚动；稀疏/空/未知/长名/大值与切配色校验状态。重用原生控件及主题角色，无第三方依赖。回退只撤销本任务模型布局改动，不回滚已有dirty工作。

原生测试启动参数的必要范围：预览脚本增加独立legacy-only调用，传入-AppleShowScrollBars Always，宿主断言preferred样式，再创建SwiftUI根；不强改已挂载滚动条模拟首选项，不修改用户偏好。记录这一测试差异后再修改脚本。
