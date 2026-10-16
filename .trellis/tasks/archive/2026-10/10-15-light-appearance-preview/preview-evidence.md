# 本轮预览检查（2026-10-15）

范围：独立 HTML 视觉原型，不是原生 App 的实现或功能验收。任务维持 planning，等待用户选择。

- 使用已安装的 Playwright 1.59.1 与隔离配置的 Chrome 无界面实例；没有安装依赖。浏览器只访问 127.0.0.1:8753，原型没有外部网络请求。
- 三种方向 × 总览/请求/模型/会话 = 12 个页面，等待系统字体和两帧绘制后截图。窗口框 1120×760 CSS px，浏览器 viewport 1280×1000、DPR 2。
- 三个总览均无垂直截断；1120 下内容区和明细表无水平溢出。请求列表自然纵向滚动，不声称它证明原生 Table 滚动。
- 实际检查方案切换保持页面、URL 参数、刷新后保留方向、左右方向键、输入框方向键不切换、模型及会话文字搜索。控制台无 pageerror。
- 目视核对三套总览、A 请求、B 模型、C 会话；发现快速连续截图偶发未完成绘制，改为等待字体/双帧后重新生成。最终截图保留风险条、Unknown model 与未完整记录。
- 检查结果：[preview-checks.json](preview-checks.json)。产品 Sources / Assets / Scripts 的文件集合和 SHA-256 前后一致，见 product-before.json / product-after.json。
- 没有运行本轮产品测试、构建或统计基准；产品代码未变，不能引用此前测试为本轮通过结果。没有安装、退出、替换用户 App，也没有提交/推送。

预览 HTML：docs/prototypes/light-appearance/index.html；设计比较：docs/light-appearance-proposals.md。截图位于当前 Codex 视觉产物目录的 light-appearance 子目录；可重新运行文档中的本地服务恢复预览。临时截图和自动检查脚本位于 /tmp/codex-stats-light-preview-20261015。

本轮不证明原生菜单、inspector、深色、增强对比度、VoiceOver、复制、全部键盘操作和统计正确性。选定后需先完善并批准这些目标契约，再实现和验证。

## 补充 D 浅青（同日用户追加）

新增淡青色 D，与 A/B/C 共四套切换。D 采用 A 的连续指标条结构以直接比较蓝与青的配色；近白青底、白色内容面、柔和浅青柱形，不使用深色峰值柱。

实际重新渲染四个方向总览及 D 的请求/模型/会话，共 7 页，无 pageerror；总览不截断、没有内容区横向溢出。检查 D→A / A→D 键盘循环、页面保留、刷新后 D 参数以及四个切换按钮。见 [cyan-checks.json](cyan-checks.json)。生成四方案并排图，目视检查 D 总览与对比图。

再次核对 Sources / Assets / Scripts 全部 27 个文件集合与 SHA-256 均未变化。没有产品测试/构建/安装、用户 App 操作或提交推送。用户仍未选择最终方向，任务保持 planning。
