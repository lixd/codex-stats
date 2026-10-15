
## v0.2.10 / build 12 第一批精修（2026-10-15）

最终代码已原生构建为 arm64、macOS 14.0 部署目标，宿主仍为 macOS 27.0.1 / Apple Swift 6.4 / SDK27。B 菜单生产接入、真实会话身份隔离、单个当前范围摘要缓存和中文指标文案已实现。设计先于实施，Trellis独立检查发现的未知归档副本重复计量及内部键误匹配父引用均已修正；时区变化需重启的限制明确保留。

实际执行与结果：

| 命令 / 检查 | 结果及证据边界 |
|---|---|
| `./Scripts/test.sh` | 最终121项通过、0失败，包含7项新增身份回归；同时编译App目标。CLT已有链接搜索路径警告不影响成功结果 |
| `./Scripts/test-usage-store.sh` | 真实扫描状态、单摘要复用与报告/范围/日期/根路径失效、未知字段、一致性通过；时区仅检查缓存键，未验证运行中重新分桶 |
| `./Scripts/test-token-display.sh` | en_US/zh_CN/fr_FR 各16边界、图表共享格式、未知与完整值通过 |
| `./Scripts/test-menu-lifecycle.sh` | 独立AppKit harness精确窗口关闭顺序、复用/替换、驻留和正常终止通过；不是生产MenuBarExtra鼠标点击 |
| `./Scripts/render-ui-previews.sh /tmp/codexstats-v0.2.10-previews` | 原生明暗渲染通过；16个菜单状态，正常288×466pt、首次加载288×270、真实空288×409、错误288×306、单一Unknown model且已知十亿指标288×415；无固定高度。另含950/1120表格与详情、诊断、已知/未知计时。所用数据均为合成 |
| `./Scripts/build-macos.sh /tmp/codexstats-v0.2.10-release` | 最终父引用修复后构建成功；0.2.10/build12，codesign严格验证通过；vtool确认minOS14.0 |
| `hdiutil create` / `verify` / 只读挂载 | DMG校验成功，内含App签名/版本/最低系统核对，二进制SHA256与最终构建相同，Applications链接正确。宿主hdiutil有弃用提示，命令仍成功 |
| `git diff --check` / 当前文档相对链接 / README行数 | 通过；README保持70行以内 |

固定输入性能使用 `benchmark-performance.sh`。baseline Core在修改前单独保存，release为最终父引用修复后代码，均由同一脚本生成约349,964,213字节、39文件、7,020记录，总量9,043,780。精确快照（记录/顺序/模型/会话切片/日/小时/诊断/四档范围）前后完全一致。新身份反例的有意排除由单独回归测试断言。

| 指标 | 修改前 | 最终代码 |
|---|---:|---:|
| 新进程冷扫描 | 3.167s | 4.577s |
| 未变文件重扫 | 58.91ms | 79.30ms |
| 单文件受控追加 | 132.47ms | 161.44ms |
| 扫描峰值footprint | 59.75MiB | 60.42MiB |
| 最大RSS | 80.30MiB | 79.92MiB |

最终四档筛选18.23–33.20ms。以上为单次受控运行，宿主存在并发编译负载；没有清除系统磁盘缓存，也不据此声称扫描器提速。本轮减少的是界面重复聚合，原生Store通过同键对象身份与失效断言证明复用；没有量化真实界面帧耗时。冷扫描≤5s、warm≤100ms、筛选≤50ms目标本次通过。

`./Scripts/measure-app-memory.sh` 对最终构建的临时UUID身份App及同一合成fixture执行：10秒当前footprint25.4MiB、峰值30.0MiB；35秒当前26.8MiB、峰值34.3MiB，正常终止仅自己的实例。系统输出一次sandbox extension权限提示，进程启动/两次vmmap/正常退出均成功。采样不证明所有页面已打开、扫描完成时刻或长期运行；不是用户真实日志的实时占用。完整UI内存与CLI扫描峰值不可混用。

未新增实际MenuBarExtra鼠标操作、macOS14/Intel实机、睡眠唤醒/长期常驻、VoiceOver验收、Developer ID签名或公证。系统时区切换后需重启重建扫描日期桶。分析窗口布局大改、详情自适应、持久/追加缓存均未实施。无安装新副本，交付临时构建App与dist中的DMG/源码包。
