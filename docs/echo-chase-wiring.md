# Delay Trace authored 地图接线

显示名为 `Delay Trace`；`EchoChase` 仅作为内部路径和类名。

本页只说明如何把已有 prefab 接进作者在 Godot Editor 中搭建的连续大地图。基础房间规格为 `480×270`，但本文不定义房间数量、路线、出口位置或机关解法，也不要求任何脚本动态生成节点。

## 最小场景树

```text
YourGrayboxRoot (Node2D)
├── World (Node2D, PROCESS_MODE_PAUSABLE)
│   ├── EchoPlayer               [instance: Prefabs/echo_player.tscn]
│   ├── FutureRecorder           [按需 instance；内部自带一个 FutureEcho]
│   ├── DelayPickup              [按需 instance；语义为可重复延迟台]
│   ├── TemporalPressurePlate    [按需 instance]
│   ├── TemporalDoor             [按需 instance]
│   ├── ProgressionDevice        [支路末端按需 instance]
│   ├── PersistentGate           [终点门/捷径按需 instance]
│   ├── TemporalCollectible      [可选 instance；槽位持久化收集物]
│   ├── PresentHub               [主场景内联 Area2D；内含 DialogueNpc 与冲击波]
│   ├── Terrain                  [作者的 StaticBody2D / TileMapLayer]
│   ├── SpawnPoint               [作者的 Marker2D]
│   └── EchoCheckpoint           [instance: Prefabs/echo_checkpoint.tscn]
├── UI (CanvasLayer)
│   ├── TemporalRecordingHUD
│   ├── PauseScreen
│   └── SettingScreen
└── SceneController (Node, PROCESS_MODE_ALWAYS)
```

`EchoTimeline` 已在 `project.godot` 注册为 Autoload，其 authored scene 内部只带一个 `PastEcho`。关卡中不要再实例化 `echo_timeline_controller.tscn`。`EchoPlayer` 与每台 `FutureRecorder` 在进入场景时自行向 Autoload 注册；每台记录器内部 authored 一个独占 `FutureEcho`。

## Inspector 必填引用

所有引用都必须在 Inspector 中直接拖拽，不使用 `get_node_or_null()`、组搜索或脚本补节点。

| 节点 | Inspector 字段 | 指向 |
| --- | --- | --- |
| `DelayPickup` | `delay_seconds/delay_switch_id/default_active` | `1/3/5`、场景内唯一 ID；恰好一个默认 `3s` 台 |
| `TemporalPressurePlate` | `target_door` | 要控制的 `TemporalDoor`，可留空做自定义接线 |
| `ProgressionDevice` | `device_id` | 当前存档中稳定且唯一的世界进度 ID |
| `PersistentGate` | `required_device_id` | 要监听的 `ProgressionDevice.device_id` |
| `DialogueNpc` | `dialogue_resource/dialogue_title` | Dialogue Manager 资源与起始 title |
| `TemporalRecordingHUD` | `player` | 场景内玩家 |
| `EchoChaseStart` | `player/gameplay_world/spawn_point/present_room/pause_screen/setting_screen/reset_audio` | 场景内对应 authored 节点 |
| `EchoChaseStart` | `gameplay_music` | 进入玩法后交给 `GameAudio` crossfade 的独立循环曲 |
| `EchoChaseStart` | `present_entry_transition/past_entry_transition` | 与菜单满屏颜色一致的 `0.35s` authored 淡出资源 |

`EchoChaseStart` 会收集 `gameplay_world` 下实际 authored 的 checkpoint 与延迟台；Prefab 自己负责向 `EchoTimeline` 注册和注销。漏掉必填资源、ID 或直接引用应主动报错，不要添加静默 fallback。

## 碰撞层合同

`project.godot` 已声明以下 2D 层：

| 层 | 名称 | 用途 |
| --- | --- | --- |
| 1 | `World` | 地面、墙、门、普通地形 |
| 2 | `Player` | `EchoPlayer` |
| 3 | `Past Echo` | `PastEcho` |
| 4 | `Future Echo` | `FutureEcho` |
| 5 | `Temporal Trigger` | 记录器、延迟台、压力板 |
| 6 | `Trap` | 只被玩家 Hurtbox 检测的致死区域 |

不要修改 prefab 内已有的过去/未来层与 mask，除非同时更新自动碰撞矩阵测试。灰盒地形应在 `World` 层；记录器、拾取物、压力板使用 `Temporal Trigger`。

## 机关接线

### 记录器

实例化 `future_recorder.tscn`，摆在作者选择的录制起点。它进入场景时自行注册到 `EchoTimeline`；玩家进入空闲记录器时自动开始录像。录制中按 `L` 或达到 5 秒后提交；系统先恢复开始录像时的时间锚点，再从该记录器的独占未来体播放新轨迹。

全局同时只能录一条。记录器自己的未来体存在时保持 `OCCUPIED`；未来体释放且玩家离开后回到 `READY`。其他空闲记录器仍可继续制造各自的未来体，容量等于 authored 记录器数量。

时间锚点只恢复现有时态玩法状态：现在体运动、过去体、延迟选择、所有已有未来体的轨迹与精确播放进度。压力板和门由恢复后的实体碰撞重新计算。不要把它扩展成通用世界序列化器。

### 过去延迟台

实例化 `delay_pickup.tscn`，设置 Inspector 的 `delay_seconds` 为 `1`、`3` 或 `5`，填写唯一 `delay_switch_id`。它直接调用全局 `EchoTimeline`，不会 `queue_free()`：玩家可反复触碰，当前目标显示收束环，切档完成后显示稳定激活环。现在房内切换立即完成，不播放切档预警。

同一场景必须恰好一台 `default_active = true` 的 `3s` 台。切档预警中触碰另一台只覆盖最新目标，不重置原 `0.6s`；`EchoChaseStart` 从 `gameplay_world` 收集全部延迟台，供 checkpoint 恢复。

### 压力板与门

实例化 `temporal_door.tscn` 和 `temporal_pressure_plate.tscn`，在压力板的 `target_door` 中绑定门。现在体、过去体和未来体都可压板；未来体消散或过去体切档时，碰撞释放会自然让门关闭。

若关卡需要多个板共同控制一扇门，作者应在场景内显式放置一个本地组合节点或写一个小型本关脚本，并保持其输入来自各板的 `pressed_changed` 信号。不要把通用“谜题管理器”提前抽象出来。

### 收集物

实例化 `temporal_collectible.tscn` 并填写唯一 `item_id`。玩家触碰后只保存一次到当前槽位，播放 authored 收集动画并移除实例；旧存档缺少 `collected_item_ids` 时默认为空。它是可选世界进度，不是背包，也不参与主线门条件。

### 永久装置与门

支路末端实例化 `progression_device.tscn` 并填写唯一 `device_id`。本关谜题完成时只调用该实例的 `activate()`；它负责去重、写入当前槽位并发出激活信号。终点门或回流捷径实例化 `persistent_gate.tscn`，将 `required_device_id` 设成同一 ID。门会在读档时直接恢复稳定开启末态，运行中激活时才播放开门反馈。

### NPC 与中央现在房

普通 NPC 使用 `dialogue_npc.tscn`，赋值 `dialogue_resource` 和可选 `dialogue_title`。玩家进入范围看到 `E`，按下后复用 `Dialogue/EchoChase/echo_dialogue_balloon.tscn`；该变体保留 Flow、Animation、TypingSound、CharacterUI 和 Responses，禁用 History、SaveModule 与 Illustration。对话期间 `SceneTree.paused = true`，结束后恢复原状态。

中央房直接在连续主场景中 authored 一个 `PresentHub (Area2D)`，不再实例化整房 prefab。其固定子节点为 `RoomShape`、`CurrentRoomCheckpoint`、`DialogueNpc` 和 `RoomDepartureVfx`；作者可在同一场景里调整边界、NPC 与出口，不需要切换房间 scene。

首次进入时不清线，Past 可以跟着玩家进入；玩家在范围内按 `E`，或在尚未对话时触碰 `checkpoint_id = current_room`，两条路径都会启动同一段 NPC 对话。对话结束后写入 `present_hub_unlocked`，清除时态实体，并在 Hub 原点播放覆盖 `480×270` 的 `TemporalDepartureVfx`，使用与开场一致的环状冲击波素材。之后回访才在进入时调用 `EchoTimeline.enter_present_room()`；房内不推进时间线、不记录路径，延迟台即时生效。离开任意出口调用 `leave_present_room()`，从玩家当前位置重建时间线。`current_room` 仍是玩家触碰才激活的普通 checkpoint。

## 失败、重置和检查点

场景根节点或现有关卡控制器应连接：

```text
EchoTimeline.player_caught -> 你的本关失败/重生入口
```

失败和 checkpoint 恢复只还原稳定状态：

```gdscript
# 示例：由你已有的关卡控制器在稳定重生时调用。
player.reset_player(respawn_position)
EchoTimeline.reset_timeline(saved_past_delay_seconds, saved_delay_switch_id)
```

先复位玩家，再清时间线。不要保存或恢复在途路径、剩余录像、未来体位置、过去体切档过程或临时压力板占用。

使用 `LevelModule.set_checkpoint(scene_path, checkpoint_id, respawn_position, past_delay_seconds, delay_switch_id)` 写入干净 checkpoint。`past_delay_seconds` 与 ID 必须来自 `EchoTimeline.get_selected_past_delay_seconds()` 和 `get_selected_delay_switch_id()`，这样切档预警中的最新选择也能稳定恢复。世界进度另存 `activated_progression_device_ids` 与 `present_hub_unlocked`；旧存档缺少它们时默认空集合和未解锁，不影响现有 checkpoint。

## 起始施工场景

`Scenes/EchoChase/echo_chase_start.tscn` 已完成机制展台接线：

- 一个 `EchoPlayer`；`EchoTimeline` 与 `PastEcho` 由全局 Autoload 提供。
- 一台 `FutureRecorder`，内部自带一个隐藏 `FutureEcho`。
- 用户 authored 的 16px TileMap 基线；当前镜头测试区仍按四个 `480×270` 触发范围组织，但不锁定正式路线。
- `start_checkpoint` 与 `current_room` 两个 authored `EchoCheckpoint`，以及一个 `SpawnPoint`。
- 一个 `Camera2D + PhantomCameraHost`，四台固定 `PhantomCamera2D`，`zoom=4`，共用 `0.35s QUAD/EASE_IN_OUT` tween。
- 四个 authored `Area2D` 房间触发器，直接使用 Phantom Camera 官方 `2d_trigger_area.gd` 示例脚本；镜头选择、中断和补间全部由 Phantom Camera 插件负责。
- `1s/3s/5s` 三个可重复 `DelayPickup` 延迟台、一个 `FutureRecorder`。
- 一个显式连接 `TemporalDoor` 的 `TemporalPressurePlate`。
- 主场景内联 `PresentHub`，内含按 `E` 交互的 NPC、`current_room` 自动对话、首次/回访剧情、全房环状冲击波、三座延迟台和 `RoomDepartureVfx`。
- 场景内的 `BranchProgressionDevice` 与 `BranchPersistentGate` 只作为永久进度接线样例；正式谜题仍由本关脚本在条件完成时调用 `activate()`，二者素材与 checkpoint 分离。
- `MemoryShardA/B/C` 使用 `TemporalCollectible`，只演示槽位持久化收集物，不引入背包。
- 一个 `TemporalRecordingHUD`：玩家金色轮廓、屏幕金边、无数字进度条和实时回传键。
- 两套 authored 入场淡出资源：新游戏使用青白，Continue 使用洋红；淡出期间冻结 World，不再摆三人 Overlay。
- `PauseScreen` 与 `SettingScreen`；Hint 永久禁用。
- 没有敌人、正式背景或正式路线；`dark_sci_fi_sector.ogg` 只作为施工玩法占位曲。

用户可以在 Godot Editor 直接编辑这棵树。房间边界、PCam 位置和机关位置都可直接替换；继续使用 Inspector 显式绑定，不要把 `echo_chase_start.gd` 改成自动搜索或自动生成内容。

## Phantom Camera 房间接线

每个 `480×270` 房间 authored 一台固定 `PhantomCamera2D` 和一个同尺寸 `Area2D`。Area 直接绑定 `res://addons/phantom_camera/examples/scripts/2D/2d_trigger_area.gd`，PCam 只设置位置、`zoom`、pixel snap、priority、`limit_target` 和共享 tween；不要再写项目级房间切换器、网格坐标计算、Camera2D 插值或切换队列。玩家的 `CameraArea2D` 进入房间时由官方脚本提升对应 PCam priority，离开时释放；进行中的 tween 由 `PhantomCameraHost` 直接中断并转向新 PCam。

当前插件版本为 `0.11.0.3`。场景中的 `Camera2D` 必须保留 `PhantomCameraHost` 子节点，项目必须启用 `addons/phantom_camera/plugin.cfg` 和 `PhantomCameraManager` autoload。缺少任一项应直接报错，不增加备用 Camera 路径。

`PastEcho` 与每个 `FutureEcho` 内部都已 authored 一个 `TemporalDepartureVfx`。不要把退场动画重新绑回主体的 `VfxAnimationPlayer`：旧位置快照和新位置实体化必须并行，未来槽也必须在尾效结束前可复用。

## 调试顺序

1. 先只实例化 Player，确认 Autoload `EchoTimeline` 的过去体会在默认 3 秒后沿历史路径出现。
2. 加一台记录器，确认 `L` 后世界回到锚点且新未来体回放。
3. 加第二台记录器，确认旧未来体恢复锚点进度且两台独立释放。
4. 加一个压力板与门，确认未来体结束后门立即关闭。
5. 最后才加 `1/3/5s` 延迟台组合。

在每一步都从干净检查点重试。若路径回放不对，先检查 `EchoTimeline` Autoload、玩家注册和关卡的 `World` 碰撞层，不要通过修改路径算法或动态复制节点掩盖场景错误。

## 音频接线

`GameAudio` 是唯一公开音频入口，Autoload 指向 `Scenes/Autoload/game_audio.tscn`。两台 Music 播放器负责 crossfade，三台固定 UI 播放器负责菜单确认、游戏内确认和取消音；`SettingsModule` 只保存并广播音量值，Bus 应用全部由 `GameAudio` 完成。菜单调用 `play_music("menu", ...)`，玩法入口调用 `play_music("echo_chase_gameplay", ...)`，因此切场景不会继续沿用菜单曲。`ShaderButton` 的 `SelectAudio` 继续负责悬停音，按钮按下只读取 `ui_sound_kind` 元数据，不再注入旧按键音播放器或 fallback。

自动检查只覆盖路径回放、现在房边界、永久进度和明确的行为回归。不要添加把节点层级、Prefab 数量、颜色、动画时长、房间坐标或 Inspector 参数锁死的测试；这些内容以作者当前的场景与 Inspector 调整为准。
