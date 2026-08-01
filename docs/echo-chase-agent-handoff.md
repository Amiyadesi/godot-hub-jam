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
│   │   └── RoomPcamA / B / C / D
│   ├── RoomCameraTriggers
│   │   └── RoomAreaA / B / C / D
│   ├── EchoCheckpoint
│   ├── PresentHub [主场景内联；内含 CurrentRoomCheckpoint / DialogueNpc / RoomDepartureVfx]
│   ├── DelayPickup1s / 3s / 5s
│   ├── FutureRecorderA [内部一个 FutureEcho]
│   ├── BranchProgressionDevice → BranchPersistentGate
│   ├── TemporalCollectible × 3
│   └── TemporalPressurePlate → TemporalDoor
├── UI
│   ├── TemporalRecordingHUD
│   ├── PauseScreen
│   └── SettingScreen
└── SceneController [ALWAYS]
	└── ResetAudio
```

场景已按用户要求接入四个横向 `480×270` Phantom Camera 测试房和完整机制展台。TileMap、机关顺序与房间参数只用于逐项测试，不代表作者的正式灰盒或路线；用户可以直接在 Editor 中移动、替换或删除。

## 可替换素材

- 三种时态 Core 共用 `assets/echo_chase/character/echo_character_frames.tres`，保留角色原始像素，不再使用双色 shader 重画内部细节。
- 时态轮廓共用 `assets/echo_chase/character/echo_character_outline_frames.tres`：每帧为 `24x24px`，原 `16x16px` 内容四周各有 `4px` 透明边，避免 atlas 串帧和轮廓裁切。
- 动画名合同：`idle/run/jump/fall/wallslide/climb/dash/hit/death`。
- 玩家、过去体和未来体的 `Visual` 都是无材质 `AnimatedSprite2D`；洋红、青白、琥珀仅由独立 Outline/Halo 层表达。
- 平台使用 `assets/echo_chase/tilemap/echo_platform_tileset.tres`，逻辑格为 `16x16`。
- checkpoint 临时图来自同一 Kenney atlas 的 `(7,2)`。
- 菜单地图与三时态剪影只存在于 `MenuWorld/WorldParallax`，由 `WorldCamera` 产生轻微世界视差；标题、按钮、设置、感谢、转场和 `TemporalFrame` 位于固定 `MenuUi`。改地图、道路、剪影或其动画时只编辑 `menu_world.tscn`；不得在 `menu.tscn` 重建副本。
- 音效节点已 authored：玩家冲刺/落地、过去体出现、失败复位、checkpoint 激活。
- 菜单音乐为 Frenchyboy 的 CC0 `Mysterious2.wav` 转码版本：`assets/echo_chase/audio/music/mysterious_futuristic_loop.ogg`；来源与 SHA256 见 `docs/asset-attributions.md`。
- 施工玩法音乐为 SRG774 的 CC0 `sector.ogg`，进入玩法时由 `GameAudio` 从菜单曲 crossfade；支路装置激活使用同包 `victory.ogg`。
- 首次进入中央房允许 Past 进入；NPC 复用 `ModularBalloon` 变体，范围内显示 `E`，或触碰 `current_room` 时自动开始同一段对话。首次剧情结束触发覆盖整房的环状 `TemporalDepartureVfx` 并清线；之后回访才在入房时清除时态实体、让延迟台即时生效，并改用短 `return` 对话。
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
present_hub_unlocked
```

延迟台是可重复机关，类名仍为 `DelayPickup`。每个场景必须恰好一个默认 `3s` 台，所有台使用唯一 ID；`EchoChaseStart` 从 authored `gameplay_world` 收集它们。激活 checkpoint 不清理当前时间线，但会记录当前选择；触碰 `current_room` 且尚未完成对话时会启动中央 NPC 剧情。被过去体抓到后，玩家冻结 `0.4s`，随后先恢复坐标，再用保存的延迟和台 ID 调用 `EchoTimeline.reset_timeline()`。Continue 同样建立干净时间线。

未来录像可在第一帧提交；短路径保持末帧补足到 `1s`。录制中接触过去体会提交/回传，不会触发失败。`TemporalRecordingHUD` 监听时间线与 `KeybindingModule.bindings_changed`，禁止把按键文本硬编码回 `L`。

过去体切档时，`DepartureVfx` 在旧历史位置播放洋红裂解，PastEcho 主体同时移到新历史位置播放 `0.6s` 轮廓收束。未来体结束时先禁用碰撞并发出 `slot_released`，再由琥珀快照完成尾效；`dissipated` 只表示视觉尾段结束。

## Future 与时间锚点

`EchoTimeline` 是 Autoload；关卡不要再实例化控制器。每台 `FutureRecorder` 进入树时自行注册，并自带一个独占 `FutureEcho`；Future 容量随 authored 记录器数量变化，全局同时仍只允许一条录像。

开始录像时捕获现在体、过去体、延迟选择和所有已有 Future 的精确播放状态。提交后恢复锚点状态，再启动新 Future；录制期间已经结束的旧 Future 也按锚点恢复。录像期间 checkpoint 不激活。不要恢复固定 `FutureEchoA/B` 槽，也不要引入通用世界快照框架。

## Phantom Camera

插件固定为官方 `v0.11.0.3`。起始场景的四台 PCam 保留用户当前 Inspector 调整，均为固定位置、`zoom=4`、pixel snap，使用 `0.35s QUAD/EASE_IN_OUT` tween；不要用文档坐标覆盖场景值。

四个 authored `Area2D` 直接使用 Phantom Camera 官方 `2d_trigger_area.gd` 示例脚本调整 PCam priority；真实 Camera2D 变换、转场中断和补间完全由 `PhantomCameraHost` 处理。不要增加 `PhantomRoomSwitch`、`RoomCameraController`、网格扫描、手写 camera tween 或备用相机逻辑。

## 验证命令

```powershell
$godot = (Get-Command godot).Source
$env:APPDATA = Join-Path $env:TEMP 'echo-chase-test-appdata'
& $godot --headless --editor --path . --quit
& $godot --headless --path . res://Tests/EchoChase/run_tests.tscn
& $godot --headless --path . res://Tests/echo_chase_architecture_smoke.tscn
& $godot --headless --path . --quit-after 300 res://Scenes/EchoChase/echo_chase_start.tscn
```

自动检查覆盖路径插值、回传断点、永久进度、现在房延迟切换和连续冲刺残影回归。不要添加把节点层级、Prefab 数量、颜色、动画时长、房间坐标或 Inspector 参数锁死的测试；这些内容以作者当前的场景与 Inspector 调整为准。

人工只检查 `1920x1080` 与同比例 `1280x720`。不做超宽屏批量截图。

## 尚未实现

- 用户灰盒 A、灰盒 B 和任何正式路线。
- 正式 Phantom Camera 房间边界、位置与 tween 调参。
- 记录器、压力板、门在正式场景中的谜题和最终摆位。
- 正式玩法背景、怪物、正式角色稿、正式选曲和完整剧情。菜单、施工玩法与中央 NPC 目前都只是 CC0/初稿占位。
- Windows 导出。
