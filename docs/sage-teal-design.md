# 青灰与青绿视觉精修

> 历史设计：v0.2.12已实现；v0.2.13颜色和分析布局已由[D与双配色](native-cyan-blue-design.md)取代，不作为第三套可选主题。

状态：**已实现 v0.2.12/build14**（2026-10-15），实施前已批准。前一实现基线 v0.2.11/build13；实际系统增强对比度及鼠标/VoiceOver验收仍待完成。用户已在四张当前界面截图和配色参考后批准方向 A「Sage + Teal」。此处的 A 是配色方案，菜单仍采用已实现的 B 布局。

## 问题与边界

请求、模型和会话页缺乏背景层次；模型少量数据下原生表格的空白区域仍绘制斑马纹。总览已有卡片结构，但趋势蓝与排行绿缺乏统一主色。本轮用背景和颜色角色解决层次，不新增功能、主题设置、渐变装饰、阴影或自绘表格。窗口、列宽、菜单 B 尺寸、刷新、搜索、排序、详情、复制和统计契约保留；A07 全面窄窗口布局另行设计。

## 颜色角色

颜色为本应用的显示角色，不以模型名/会话 ID 生成颜色；不参与数据计算。用 AppKit 动态 NSColor 按 NSAppearance 解析，覆盖 aqua/darkAqua 及 accessibilityHighContrast 两种外观。不通过 Timer/Task 查询系统、不增加主题状态缓存。正文继续使用系统 primary/secondary，原生控件保留系统/用户强调色，不统一覆盖为自定义 tint。

| 角色 | 浅色 | 深色 | 使用 |
|---|---|---|---|
| page / viewBackground | #F7F9F8 | #111C18 | 内容底、菜单底 |
| section / sidebarBackground | #EEF1F0 | #18231F | 导航、窗口头部、会话左栏 |
| card / cardBackground | #FFFFFF | #1E2B25 | 卡片、表格内容、详情头部 |
| accent | #007C6B | #5ED3BD | 导航、趋势、排行、应用自有链接/图标 |
| selection | #E0F8F3 | #173F36 | 选中导航和会话卡；文字/字重与边框共同指示选择 |
| cyan（输入辅助色） | #286F96 | #79B8E5 | 输入指标，避免代替主趋势色 |
| purple（输出辅助色） | #7660AD | #B4A3E4 | 输出指标 |
| orange（风险/推理） | #975813 | #EEB370 | 警告与错误，仍有图标、文字；推理保留独立字段标签 |
| actionFill | #008573 | #008573 | 白字主操作底色，与深色亮青绿文字角色分开 |
| stroke | #DDE4E0 | #34463D | 默认卡片/内容边界；增强对比度分别 #708078 / #84988C |
| selectedBorder | accent | accent | 选中会话描边，增强对比度下不降低透明度 |

浅色 Sage/Teal 参考 [Radix 官方中性色搭配](https://www.radix-ui.com/colors/docs/palette-composition/composing-a-palette) 与 [色阶角色](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale)，具体应用角色为本项目设计；深色为本项目配套值。动态语义色与用户偏好依据 [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color)。背景层次依据 [Carbon Color](https://www.carbondesignsystem.com/building-blocks/foundations/color/overview)。不添加这些库为运行时依赖。正文/强调文字与所在不透明背景按 WCAG sRGB 相对亮度测量，普通文本目标 ≥4.5:1，实心白字按钮也 ≥4.5:1；普通装饰边框不作文字对比承诺，增强对比度另行核验。浅色强调文字在 Sage/选中底上使用比参考色阶更深的 #007C6B；输入和风险也加深，避免在非白底低于 4.5:1。

## 页面和状态契约

- 骨架：侧栏与共享头部为 section，页面为 page；导航选中用 selection 加 accent 图标/文字和 semibold，保留现有尺寸。状态摘要保留风险橙与中性信息青绿，不把错误染成成功；详情 sheet 使用 page 底和现有原生关闭行为。DiagnosticSummary 的信息底使用不透明 selection，避免 accent×0.06 叠加后文字对比下降；风险底仍为 orange×0.06。
- 总览：卡片白/深绿灰，趋势条和图例统一 accent，排行同色；输入/输出小图标保留蓝/紫辅助区别。Token 主数值保持中性正文色。
- 请求：筛选与范围说明位于 page 底，原生 Table 位于 card 内容区域，用细边框和圆角区分；Table 自己负责滚动，保留原生行选择与斑马纹。右侧详情为 page 底、card 头部与卡片。
- 模型：筛选位于 page，Table 为 card 区域。使用原生 inset Table 的 `alternatesRowBackgrounds: false` 去除空斑马纹，不伪造行、不以估算行高限制高度、不替换原生滚动。空结果仍使用真实空态。
- 会话：左栏 section，右栏 page，列表未选卡 card；选中卡 selection + accent 边框并声明 selected 无障碍 trait。详情卡片 card。搜索、默认首项和真实 ID 复制规则不变。
- 设置、首扫、空、未知、刷新失败和诊断：复用相同角色与既有状态文案；不填假数、不隐藏诊断。菜单 B 结构/尺寸不变，共享颜色适配深浅色；白字“打开完整分析”使用 actionFill。

## 验收与交付

先原生构建确认 macOS14 API 可用；使用合成日志和独立 UserDefaults suite 渲染五页、菜单、少量/大量模型、空态、未知、风险和恢复，1120/950 点深浅色。增强对比度采用 NSAppearance.bestMatch 的官方命名匹配路径；SDK NSAppearance.h 明确 HC 名只用于匹配，不能用 appearanceNamed 合成该外观。当前系统未开启增强对比度，不修改用户偏好；不得将这种合成截图算作真实 HC 验收，保留人工检查。检查原生 Table 的实际空区域无斑马纹，保留原生滚动/选择；静态截图只证明布局和色彩，不能证明鼠标、复制、sheet Escape 或 VoiceOver 操作成功。

重跑共享数字格式、Core、Store/菜单宿主必要回归。测量正常深浅色动态解析的实际 RGB 及对比度；增强对比度描边值可作色值数学检查，但系统实际切换与重绘需人工验收；不为配色改动重新宣称性能提升。优化构建写入新的独立临时目录，核验版本、签名、最低系统和系统依赖，不安装、退出或替换用户 App，不提交或推送代码。通过后再将本文和主设计推进为已实现；结果写入 VERIFICATION 和 Trellis 任务。


本轮实现、对比度实测、88张原生预览、测试及构建结果见 [VERIFICATION](../VERIFICATION.md#v0212--build-14-青灰与青绿精修2026-10-15)。源码和统计边界保留在 [Trellis任务](../.trellis/tasks/archive/2026-10/10-15-sage-teal-refinement/prd.md)。
