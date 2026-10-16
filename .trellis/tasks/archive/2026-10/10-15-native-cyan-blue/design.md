# 实施设计

权威产品契约为 docs/native-cyan-blue-design.md（实施前已写入），不把原型HTML作为生产实现。

最小改动：Components主题角色/基础表面/连续指标/字体；Dashboard骨架和总览；Sessions分栏与重复总量；Requests只必要的外观间距；阶段A新增Store配色偏好、环境解析和Settings选项；测试宿主覆盖两阶段。Core/Report/AppLifecycle/扫描逻辑保持本轮前散列。

阶段D固定配色，不提前引入晴蓝或选项。D验证完成后记录阶段门禁，再实现ShapeStyle环境颜色与可观察偏好，原生控件不强制全局tint，不用.id重建。

产品构建统一最终v0.2.13/build15；不安装、不启动正式bundle。合成宿主禁止激活，不接触真实日志或标准UserDefaults。
