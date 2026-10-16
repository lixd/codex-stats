# 原生模型 A 分组列表

用户于2026-10-15选择 A，授权实现。预览证据保留在research/verification.md；产品当前基线v0.2.14/build16，目标v0.2.15/build17。

目标：R04/R06/R12/R17；保持T01/T02/T06/T07。每模型独立分组，名称/总量突出，输入/输出分区，缓存/非缓存/推理从属。完整信息、搜索、六种排序、共享范围/错误和浅青/晴蓝保持。950pt不横滚，正常纵滚。

范围：Sources/App/DashboardView.swift仅ModelsContent及私有模型视图；Tests/UIPreview/main.swift替换过时Table断言并补充模型布局边界；Scripts/render-ui-previews.sh受控测试子进程调用；Assets/Info.plist版本；必要设计、验证、Trellis文档。不改Core/Store/其他页面/安装脚本。预览脚本只为legacy场景在进程启动参数中传入AppleShowScrollBars Always，不写用户或系统偏好。不安装、启动、退出或替换用户App，不提交推送。

验收：原生950×630和1120×760，两配色深浅色；常显滚动条无横向溢出，80个真实合成模型最后项可达；长名、大值、零、unknown、空/搜索/切配色状态；精确help/AX。Core/格式测试及原生构建通过；截图不能声称证明真实鼠标/VoiceOver。独立App与源码包可供用户验收。
