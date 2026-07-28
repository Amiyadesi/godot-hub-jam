# 《迟相 / Phase Lag》音频制作与采购需求

## 当前可用素材

项目已有四首 CC0 音乐、工厂底噪，以及 UI、Dialogue 打字、脚步、刀刃、冲刺、电路拿取/放置/旋转、门、护盾、激光、金属命中、爆炸、无人机引擎和寄生体移动音。当前还接入了成对的相位发送/抵达提示，以及 Boss 拆甲、磁夹、核心开启和死亡的 CC0 过渡音。来源与许可证见 `docs/phase-lag-asset-sources.md`。

这些素材已经让“远端事件已入队—真正抵达”具备基础听觉区分，但同属现成素材拼配，不代表最终声音身份。正式版本仍缺四类敌人、完整 Boss 声音族、两年代环境分层，以及能共享同一双音动机的定制 send/arrival 组合。

## 当前过渡接入

| 事件 | 当前文件 | 接入位置 | 后续替换重点 |
| --- | --- | --- | --- |
| 远端事件入队 | `phase_send.ogg` | authored `RemoteArrivalVfx/SendAudio` | 更短、更干，并明确保留双音起点。 |
| 远端事件抵达 | `phase_arrival.ogg` | authored `RemoteArrivalVfx/ArrivalAudio` | 与 send 共享动机，但增加折叠和落点重量。 |
| Boss 拆甲 | `boss_armor_break.ogg` | 每片甲板真实拆除时刻 | 三片应有轻微递进，不能完全同响。 |
| Boss 磁夹 | `boss_magnetic_clamp.ogg` | 正确磁夹闭合时刻 | 增加大型电磁机构的低频吸合层。 |
| Boss 核心开启 | `boss_core_open.ogg` | 核心首次暴露 | 需要和普通激光彻底区分。 |
| Boss 死亡 | `boss_defeat.ogg` | 最终相位闭合后 | 制作分层崩解而非普通爆炸。 |
| Dialogue 打字 | `dialogue_blip_1–4.ogg` | story/radio authored `AudioStreamRandomizer` | 当前每两字最多一次；后续可为两名角色制作同族不同音色。 |

## 核心声音语法

### Send / Arrival 成对声音

- `phase_send_local`：事件在本地成立时播放，短、干、靠近声源，尾部带一个可辨认的双音动机。
- `phase_arrival_remote`：远端结果抵达时播放，复用相同双音动机，但音色更宽、更低，并带短暂反向吸入或相位折叠。
- 两者必须能在不看 HUD 的情况下被辨认成同一事件的起点与终点。
- 基础跨时空延迟为 `3s`；声音文件本身不烘焙三秒静音。
- 低闪烁模式不改变声音信息，只降低过强高频和瞬态峰值。

### 实体延迟模块

- `relay_1s`、`relay_3s`、`relay_6s` 共享同一机械音色族，但节拍和尾音长度不同。
- 模块只在信号进入和离开时发声，不持续滴答制造错误的倒计时压力。
- 三格蓄能器需要 `cell_1`、`cell_2`、`cell_3` 递进音，以及独立的 `latch_lock` 确认音。

## 缺失清单

| 类别 | 必需文件/变体 | 可读目标 |
| --- | --- | --- |
| 因果事件 | send、arrival、cancel/reset | 不看画面也能分辨“已发生、已抵达、被清空”。 |
| 实体管线 | breaker、relay 1/3/6、inverter、splitter、AND、latch | 每种机制有共同材质感和一个独有瞬态。 |
| 压力与平台 | plate down/up、platform start/stop、shield collapse | 声音长度与真实运动一致。 |
| 陆衡 | grab beam start/hold/end、rotate、hurt、collapse、revive | 磁束不像枪声；操作反馈清楚但不刺耳。 |
| 星遥 | slash 1/2/3、heavy charge/release、counter、hurt、collapse、revive | 三段刀声在音高、重量和尾音上递进。 |
| 寄生体 | warn、leap、attach、hurt、death | 先有可反应的收缩预警，再有扑击。 |
| 无人机 | track lock、warn、dive、shot、hurt、death | 与持续引擎层分离，俯冲方向清楚。 |
| 设施守卫 | alert、charge、attack、armor restore、armor break、corpse impact | `4s` 破甲窗口开始和结束都可听见。 |
| 相位猎手 | tread loop、phase shift、armor break ×3、clamp、core open、core hit、death | 不能继续用普通坦克/爆炸音冒充三阶段 Boss。 |
| Finale | era converge、anchor strain、send-home impact、new signal stinger | 结尾情绪由空间和动机回归建立，不靠大爆炸。 |

## 两个时代的环境层

当前只有一条通用 `factory.ogg`。正式版本至少拆成以下可独立混音的无缝循环：

- 共同底层：远处大型设备、低频结构共振，证明是同一设施。
- 未来侧：冷却风道、老化伺服、稀疏继电器、远处金属收缩声；整体更空、更冷。
- 过去侧：警报残响、短路、电弧、蒸汽泄漏、远处火势；不能持续占满中高频。
- 时空重合：两侧底层先互相抵消，再只留下锚点应力和角色对白。

环境循环不得包含明显一次性撞击或固定节拍，否则循环点会暴露。建议提供 `60–120s` 无缝版本和分层 stem。

## 音乐使用

- 菜单：`tragic_ambient_main_menu`，低音量建立主题，不随 hover 反复重启。
- Ch1–Ch2：`life_in_corrupted_binary`，保持观察和预演空间。
- Ch3：`menacing_otherworld`，增加不稳定感但不压过机制声音。
- Ch4：`open_warfare`，Boss 三阶段通过 stem、滤波或音量层变化区分；如果无法合法取得 stem，后续制作专用 Boss 曲。
- Ch5：低音量菜单主题回归，工厂底噪逐步减少；新信号出现时使用独立短动机，不突然转为胜利音乐。

### 当前循环处理

| 文件 | 保留区间 | 运行规则 |
| --- | --- | --- |
| `tragic_ambient_main_menu.ogg` | `0.504–96.117s` | import `loop=true`；菜单 hover 不重启。 |
| `life_in_corrupted_binary.ogg` | `0–228.397s` | import `loop=true`。 |
| `menacing_otherworld.mp3` | `0–242.390s` | import `loop=true`。 |
| `open_warfare.mp3` | `0–114.015s` | import `loop=true`。 |
| `factory.ogg` | 原始有效区间 | import `loop=true`。 |

四首 BGM 已裁掉检测到的首尾长静音。`GameAudio` 只在当前活动播放器自然结束时重新播放，避免旧 crossfade 播放器被错误拉回；关卡音乐与工厂底噪使用 `PROCESS_MODE_ALWAYS`，story 对话暂停玩法时仍持续播放。本轮不主动压低 BGM 音量。

## 交付格式

- 源文件：`48kHz / 24-bit WAV`；循环文件标明 loop start/end。
- 游戏文件：OGG Vorbis；极短 UI/瞬态可保留 WAV，避免压缩前沿模糊。
- 峰值建议不高于 `-1 dBFS`；同类素材保留合理响度余量，由 Godot bus 完成最终混音。
- 文件名使用小写 snake_case，并附作者、来源 URL、许可证、原文件名和处理记录。
- 不接受带背景音乐、口播水印、不可确认许可证或禁止随仓库再发布的文件。
