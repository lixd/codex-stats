# 本轮最终验证

仅合成JSONL、UUID UserDefaults和独立原生测试宿主；不读取真实日志、不安装/启动/退出/替换用户App，不提交推送。对照本任务起始hash，未把之前测试当本轮结果。

## 已执行

- Scripts/test.sh：133 Core tests，0失败；同轮App/CLI编译通过。初次受SwiftPM嵌套sandbox限制，在相同命令受控权限重跑通过。后续UI源编译由最终优化构建及两个独立macOS14typecheck再次验证。
- Scripts/test-token-display.sh：en_US/zh_CN/fr_FR各16边界、unknown/exact及真实App格式通过。
- 独立Trellis check：完整App/Core的macOS14typecheck通过；git diff --check及范围hash通过。发现compact自定义AX标签覆盖数字的问题，已补充精确accessibilityValue。
- 最终优化构建：v0.2.14/build16、arm64、minOS14、严格ad-hoc签名、plist和仅系统框架检查通过。Sources/Assets与构建时hash一致。
- 当前可执行SHA256：c1827ce141e7e474f4949f8168b8d0210dbd5421e763ba6902913cd5993e7ac2。
- 1120与950的真实原生quick测量：默认Table.document/clip903/903；最小733/733，末列可见；top189（旧254）与表格高538/408（旧459/329），可用表高+79pt。真实原生sheet420×600已呈现，parent为所属测试窗口，不挤压列表。

原始日志在 /tmp/codex-stats-compact-requests-20261015/validation、before.log及quick5.log，前后PNG分别before、quick5。最终cyan/blue两个完整矩阵均exit0 PASS，各147PNG、33请求几何文件，详情见implementation-measurement.md和独立review.md。

## 验证边界

原生NSView几何和程序滚动不等于鼠标/触控板/VoiceOver实操。真实close/Esc/复制、非默认筛选和系统偏好操作等若无直接成功证据仍列人工。不为测量改变用户系统滚动条/主题偏好，不以隐藏水平滚动条代替修复宽度。

## 最终原生门禁

- 每色四种普通80行状态与五种legacy状态共9次真实末行/回首验证；每个请求表要求唯一存在，不能nil时跳过断言。1120/950、1050、1116/1117/1118切换边界和1280全通过。
- 常显滚动条占17pt后doc/clip：950为716/716，1116为882/882（七列），1117为883/883（十列），1118为884/884，1120为886/886；没有用隐藏横向滚动条消除表象。
- 同宿主查询/选中行/原生sheet保持与颜色重绘测试通过；实际sheet确认isSheet且sheetParent为自身宿主，420×600，无列表挤压。NSHostingController创建后需显式setContentSize，测试NSPanel显式继承父窗口的合成appearance。
- 最终完整预览日志：after-cyan.log、after-blue.log；各目录147PNG。独立review无未解决的已确认产品缺陷。Core/Store/Menu/Appearance/生命周期/格式/交付脚本与任务起始hash一致。
- 旧top原始日志47是下缘距，转换为760−47−459=254pt；新top189。默认/最小可用表高均+79pt（不声称实测滚动流畅度或内存收益）。

## 失败尝试与范围

原生sheet在裸NSHostingView宿主中呈现/尺寸不可靠（Code43），改NSHostingController和显式宿主尺寸后通过。合成深色NSPanel未继承父窗口强制appearance导致一次像素失败（Code32），修正测试宿主而非产品。离屏SwiftUI虚拟AX关闭控件不可定位（Code50），删除不成立的测试假设，保留生产close/Esc/复制人工验收；程序endSheet仅用于测试清理，不能当按钮通过。完整手工鼠标/触控板/VoiceOver、实际系统增强对比度、macOS14/Intel实机与公证未执行。

用户本轮沿用不提交/不推送约束，故Trellis归档/journal均使用--no-commit，不提出提交批准流程。独立App仅构建与检查；源码包更新后保留在同一/tmp目录，不修改旧dist。

补充针对请求空态的临时原生验证：真实Store成功空报告、无错误、records为空，950×630两配色×深浅色共4张PNG和宿主尺寸断言通过；控件/空提示/底注同屏。证据empty-requests.log及empty-requests/，没有新增产品/仓库测试代码。

交付收尾：Trellis已--no-commit归档，journal session14；本轮相关Markdown本地链接与git diff --check通过。独立源码包CodexStats-v0.2.14-source.zip（489文件）包含当前代码/设计/任务及许可证，排除个人workspace、运行状态、认证与构建缓存，CRC核验通过；不覆盖旧dist。
