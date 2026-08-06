# 《延迟追迹》Agent 交接

项目显示名为 `Delay Trace`；`EchoChase` 仍是内部开发代号、资源路径和类名。

## 作者权边界

- 用户负责正式地图、路线、机关位置、出口、最终 Phantom Camera 房间参数、角色成稿和最终试玩删改。
- Agent 可以负责脚本、prefab wiring、资源替换接口和 debug。
- 未经用户提供或明确确认灰盒，不新增房间、关卡路线、Boss、背景叙事或替代地图。

## 当前施工入口

入口：`res://Scenes/EchoChase/echo_chase_start.tscn`

```text
EchoChaseStart
├── Backdrop [CanvasLayer]
├── World [PAUSABLE]
│   ├── Platform [用户 authored TileMapLayer]
│   ├── SpawnPoint
│   ├── EchoPlayer
│   ├── RoomCamera
│   │   └── Camera2D
│   │       └── PhantomCameraHost
│   ├── RoomCameras
│   │   └── RoomPcamA / B / … / S
│   ├── RoomCameraTriggers
│   │   └── RoomAreaA / B / … / S
│   ├── EchoCheckpoint
│   ├── PresentHub [主场景内联；内含 CurrentRoomCheckpoint / DialogueNpc / RoomDepartureVfx]
│   ├── DelayPickup1s / 3s / 5s
│   ├── FutureRecorderA [内部一个 FutureEcho]
│   ├── BranchProgressionDevice → BranchPersistentGate
│   ├── TemporalCollectible × 4
│   ├── MemoryFloorGate [终点 A-D 爱心灯与可坠落地块]
│   └── TemporalPressurePlate → TemporalDoor
├── UI
│   ├── TemporalRecordingHUD
│   ├── PauseScreen
│   └── SettingScreen
└── SceneController [ALWAYS]
	└── ResetAudio
```

场景已按用户要求接入一组 `480×270` Phantom Camera 测试房（当前 19 房 A–S）和完整机制展台。TileMap、机关顺序与房间参数只用于逐项测试，不代表作者的正式灰盒或路线；用户可以直接在 Editor 中移动、替换或删除。

## 可替换素材

- 三种时态 Core 共用 `assets/echo_chase/character/echo_character_frames.tres`，保留角色原始像素，不再使用双色 shader 重画内部细节。
- 时态轮廓共用 `assets/echo_chase/character/echo_character_outline_frames.tres`：每帧为 `24x24px`，原 `16x16px` 内容四周各有 `4px` 透明边，避免 atlas 串帧和轮廓裁切。
- 动画名合同：`idle/run/jump/fall/wallslide/climb/dash/hit/death`。
- 玩家、过去体和未来体的 `Visual` 都是无材质 `AnimatedSprite2D`；洋红、青白、琥珀仅由独立 Outline/Halo 层表达。
- 平台使用 `assets/echo_chase/tilemap/echo_platform_tileset.tres`，逻辑格为 `16x16`。
- checkpoint 临时图来自同一 Kenney atlas 的 `(7,2)`。
- 菜单地图与三时态剪影只存在于 `MenuWorld/WorldParallax`，由 `WorldCamera` 产生轻微世界视差；三体使用更深的红/青/金 Core、较高 fill，并各自带低密度 `temporal_particle.svg` 粒子。标题、按钮、设置、感谢、转场和 `TemporalFrame` 位于固定 `MenuUi`。改地图、道路、剪影或其动画时只编辑 `menu_world.tscn`；不得在 `menu.tscn` 重建副本。
- 音效节点已 authored：玩家冲刺/落地、过去体出现、失败复位、checkpoint 激活。
- 菜单音乐为 Frenchyboy 的 CC0 `Mysterious2.wav` 转码版本：`assets/echo_chase/audio/music/mysterious_futuristic_loop.ogg`；来源与 SHA256 见 `docs/asset-attributions.md`。
- 施工玩法音乐为 SRG774 的 CC0 `sector.ogg`，进入玩法时由 `GameAudio` 从菜单曲 crossfade；支路装置激活使用同包 `victory.ogg`。
- 首次进入中央房允许 Past 进入；NPC 复用 `ModularBalloon` 变体，范围内显示 `E`，或触碰 `current_room` 时自动开始同一段对话。首次剧情结束触发覆盖整房的环状 `TemporalDepartureVfx` 并清线；之后回访才在入房时清除时态实体、让延迟台即时生效，并改用短 `return` 对话。
- Keeper 使用 `delay_trace_mystery_sprite.png` 的 `idle/run` 两行序列；默认朝右，在 `PresentHub` 内持续面向玩家，离房后恢复朝右。普通结局进场/离场与真结局汇聚移动播放 `run`，停下说话播放 `idle`。
- Past/Future prefab 的 `OutlineVisual`、`PixelBurst`、`VfxAnimationPlayer`、`DepartureVfx` 是 authored 合同；`DepartureVfx` 是 `top_level` 旧位置快照，主体移动或槽位复用都不能带走它。
- 主菜单是严格三等分固定剪影。Start 使用现在体青白径向转场，Continue 使用过去体洋红径向转场；玩法场景只负责同色淡出，不再包含三人入场 Overlay。

替换角色时保持动画名和约 `10x15px` 碰撞合同；替换地图时由用户在 Editor 重画 TileMapLayer，不用脚本批量生成正式路线。

## 存档与复位

`LevelModule` 只保存：

```text
checkpoint_scene_path
checkpoint_id
checkpoint_position: {x, y}
past_delay_seconds
delay_switch_id
activated_progression_device_ids
collected_item_ids
opened_latched_door_ids
present_hub_unlocked
run_countdown_expired
run_countdown_remaining
```

延迟台是可重复机关，类名仍为 `DelayPickup`。每个场景必须恰好一个默认 `3s` 台，所有台使用唯一 ID；`EchoChaseStart` 从 authored `gameplay_world` 收集它们。倒计时剩余秒数与当前延迟台选择是槽位级状态，不依赖是否刚触碰 checkpoint；任意后续 `SaveSystem.save_slot()` 都会写入最新内存值，Continue 再恢复。MemoryShard、BranchProgressionDevice 和倒计时归零都会立即保存；Latched ALL 状态仍随现有存档流程持久化。触碰 `current_room` 且尚未完成对话时会启动中央 NPC 剧情。被过去体抓到后，玩家冻结 `0.4s`，随后先恢复坐标，再用保存的延迟和台 ID 调用 `EchoTimeline.reset_timeline()`。Continue 同样建立干净时间线。

终点 `World/Finnal/StaticBody2D` 使用 `MemoryFloorGate`。它只统计四个稳定记忆 ID，按数量从左到右点亮 A-D；四枚齐全后禁用地块碰撞，播放一次红色闪光并持续透明闪烁，读档直接恢复。地块下方两个房间保持用户当前空白，不包含 agent 生成谜题或路线。

Keeper 只在玩家主动交互时提供条件选项：爱心数 `>= 1` 且无 `askheart`、倒计时已归零且无 `asktime`、无 `askname`。失败条件选项完全隐藏；任一未读选项可用时头顶闪烁 `!`。问完写入 `NarrativeSlotModule` 并立即保存。`EchoChaseStart` 只判断一次启动 locale，并同时锁定 Keeper 的 `present_hub.zh/en.dialogue` 与 NarrativePresenter 的 `endings.zh/en.dialogue`，不经过 PO 二次翻译。NarrativePresenter 不再拥有自动 Keeper 气泡；旧 `true_ending_route` 与 `KnowledgeLock` 已删除，金色全屏真结局演出仍保留供后续 authored 路线调用。

未来录像可在第一帧提交；短路径保持末帧补足到 `1s`。录制中接触过去体会提交/回传；录制中碰到 Trap 则只让金色 Future 播放退场并取消本次录像，玩家、其他 Future、Past、延迟和倒计时回到录像锚点，不进入 checkpoint 死亡流程。`TemporalRecordingHUD` 监听时间线与 `KeybindingModule.bindings_changed`，禁止把按键文本硬编码回 `L`。

过去体切档时，`DepartureVfx` 在旧历史位置播放洋红裂解，PastEcho 主体同时移到新历史位置播放 `0.6s` 轮廓收束。未来体结束时先禁用碰撞并发出 `slot_released`，再由琥珀快照完成尾效；`dissipated` 只表示视觉尾段结束。

## Future 与时间锚点

`EchoTimeline` 是 Autoload；关卡不要再实例化控制器。每台 `FutureRecorder` 进入树时自行注册，并自带一个独占 `FutureEcho`；Future 容量随 authored 记录器数量变化，全局同时仍只允许一条录像。

开始录像时捕获现在体、过去体、延迟选择和所有已有 Future 的精确播放状态。提交后恢复锚点状态，再启动新 Future；录制期间已经结束的旧 Future 也按锚点恢复。录像期间 checkpoint 不激活。不要恢复固定 `FutureEchoA/B` 槽，也不要引入通用世界快照框架。

## Phantom Camera

插件固定为官方 `v0.11.0.3`。起始场景的每房一台 PCam 保留用户当前 Inspector 调整，均为固定位置、`zoom=4`、pixel snap，使用 `0.35s QUAD/EASE_IN_OUT` tween；不要用文档坐标覆盖场景值。

每个 authored `Area2D` 房间触发器直接使用 Phantom Camera 官方 `2d_trigger_area.gd` 示例脚本调整 PCam priority；真实 Camera2D 变换、转场中断和补间完全由 `PhantomCameraHost` 处理。不要增加 `PhantomRoomSwitch`、`RoomCameraController`、网格扫描、手写 camera tween 或备用相机逻辑。

## 验证命令

```powershell
$godot = (Get-Command godot).Source
$env:APPDATA = Join-Path $env:TEMP 'echo-chase-test-appdata'
& $godot --headless --editor --path . --quit
& $godot --headless --path . --scene res://Tests/EchoChase/run_tests.tscn
& $godot --headless --path . --scene res://Tests/echo_chase_architecture_smoke.tscn
& $godot --headless --path . --scene res://Scenes/EchoChase/echo_chase_start.tscn --quit-after 5
```

自动检查覆盖路径插值、回传断点、永久进度、倒计时 round-trip、四压板门、终点爱心门、现在房延迟切换和连续冲刺残影回归。不要添加把节点层级、Prefab 数量、颜色、动画时长、房间坐标或 Inspector 参数锁死的测试；这些内容以作者当前的场景与 Inspector 调整为准。

人工只检查 `1920x1080` 与同比例 `1280x720`。不做超宽屏批量截图。

当前 Windows 试玩版导出到 `D:\Hopes_and_Dream\ExportGame\EchoChase\EchoChase.exe`。Preset 使用嵌入式 PCK，因此交付物是单个 exe；导出后已用 `--headless --quit-after 5` 启动验证。

## 尚未实现

- 终点下方两个空房间的谜题、真结局触发条件与玩家 authored 路线。
- 正式玩法背景、怪物、正式角色稿、正式选曲和完整剧情。菜单、施工玩法与中央 NPC 目前都只是 CC0/初稿占位。
