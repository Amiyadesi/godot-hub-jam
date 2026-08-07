# Delay Trace authored 地图接线

显示名为 `Delay Trace`；`DelayTrace` 仅作为内部路径和类名。

本页只说明如何把已有 prefab 接进作者在 Godot Editor 中搭建的连续大地图。基础房间规格为 `480×270`，但本文不定义房间数量、路线、出口位置或机关解法，也不要求任何脚本动态生成节点。

## 最小场景树

```text
YourGrayboxRoot (Node2D)
├── World (Node2D, PROCESS_MODE_PAUSABLE)
│   ├── EchoPlayer               [instance: Prefabs/echo_player.tscn]
│   ├── FutureRecorder           [按需 instance；内部自带一个 FutureEcho]
│   ├── FutureCondensationBarrier[按需 instance；显式绑定一台 FutureRecorder]
│   ├── DelayPickup              [按需 instance；语义为可重复延迟台]
│   ├── TemporalPressurePlate    [按需 instance]
│   ├── TemporalDoor             [按需 instance]
│   ├── ProgressionDevice        [支路末端按需 instance]
│   ├── PersistentGate           [终点门/捷径按需 instance]
│   ├── ProgressionShortcut      [支路回 Hub 捷径按需 instance]
│   ├── TemporalCollectible      [可选 instance；槽位持久化收集物]
│   ├── PresentHub               [主场景内联 Area2D；内含 DialogueNpc 与冲击波]
│   ├── Terrain                  [作者的 StaticBody2D / TileMapLayer]
│   ├── SpawnPoint               [作者的 Marker2D]
│   └── EchoCheckpoint           [instance: Prefabs/echo_checkpoint.tscn]
├── UI (CanvasLayer)
│   ├── TemporalRecordingHUD
│   ├── PauseScreen
│   ├── SettingScreen
│   └── MobileControls            [mobile only; authored touch actions]
└── SceneController (Node, PROCESS_MODE_ALWAYS)
```

`EchoTimeline` 已在 `project.godot` 注册为 Autoload，其 authored scene 内部只带一个 `PastEcho`。关卡中不要再实例化 `echo_timeline_controller.tscn`。`EchoPlayer` 与每台 `FutureRecorder` 在进入场景时自行向 Autoload 注册；每台记录器内部 authored 一个独占 `FutureEcho`。

## Inspector 必填引用

所有引用都必须在 Inspector 中直接拖拽，不使用 `get_node_or_null()`、组搜索或脚本补节点。

| 节点 | Inspector 字段 | 指向 |
| --- | --- | --- |
| `DelayPickup` | `delay_seconds/delay_switch_id/default_active` | `1/3/5`、场景内唯一 ID；恰好一个默认 `3s` 台 |
| `TemporalDoor` | `mode/source_plates/latched_door_id` | `MOMENTARY_ALL` 或 `LATCHED_ALL`；锁存门填写唯一 ID；显式拖入最多 4 块板 |
| `MemoryFloorGate` | `memory_item_ids/indicator_fills` | 四个稳定记忆 ID；A-D 亮灯按画面左到右排列 |
| `FutureCondensationBarrier` | `source_recorder` | 唯一负责该屏障的 `FutureRecorder` |
| `ProgressionDevice` | `device_id` | 当前场景稳定且唯一的世界进度 ID；触碰激活后立即写入当前槽位 |
| `PersistentGate` | `required_device_id` | 要监听的 `ProgressionDevice.device_id` |
| `ProgressionShortcut` | `required_device_id` | 要监听的 `ProgressionDevice.device_id`；激活后淡出并关闭碰撞 |
| `DialogueNpc` | `dialogue_resource_zh/dialogue_resource_en/dialogue_title` | 中英文 Dialogue Manager 资源与起始 title |
| `TemporalRecordingHUD` | `player` | 场景内玩家 |
| `DelayTraceStart` | `player/gameplay_world/spawn_point/present_room/pause_screen/setting_screen/reset_audio` | 场景内对应 authored 节点 |
| `DelayTraceStart` | `gameplay_music` | 进入玩法后交给 `GameAudio` crossfade 的独立循环曲 |
| `DelayTraceStart` | `present_entry_transition/past_entry_transition` | 与菜单满屏颜色一致的 `0.35s` authored 淡出资源 |

`DelayTraceStart` 会收集 `gameplay_world` 下实际 authored 的 checkpoint、延迟台和锁存门；Prefab 自己负责向 `EchoTimeline` 注册和注销。漏掉必填资源、ID 或直接引用应主动报错，不要添加静默 fallback。

## 手机控件

`Scenes/DelayTrace/UI/echo_mobile_controls.tscn` 是独立的 authored 手机控件场景：动作键复用参考游戏的 `gdb-xbox-2.png` Atlas，左上暂停键复用 `gdb-keyboard-2.png` 中真实的 ESC normal/pressed 两帧。根节点挂在 `UI` CanvasLayer 下并使用 `PROCESS_MODE_ALWAYS`。每个 `TouchScreenButton` 直接填写现有 Input action，不新增或改写 `InputMap`：

| 手机位置 | 图标 | 现有 action | 桌面对应 |
| --- | --- | --- | --- |
| 左下十字 | 上下左右 | `echo_move_up/down/left/right` | `W/S/A/D` |
| 右下上键 | `Y` | `echo_jump` | `K` |
| 右下左键 | `X` | `echo_dash` | `J` |
| 右下下键 | `A` | `echo_recall` | `L` |
| 右下右键 | `B` | `echo_interact` | `E` |
| 左上 | `ESC` | `pause` | `ESC` |

`visibility_mode = TOUCHSCREEN_ONLY` 和 `OS.has_feature("mobile")` 双重区分平台：桌面不会绘制这些按钮；手机设置页隐藏 Controls tab，不能误改桌面键位。触控按钮支持长按方向和多指组合。暂停菜单、设置页、Keeper 对话、开场和终局演出暂停世界时由 `EchoMobileControls` 自动隐藏，结束后恢复。开场飘字、录像 HUD、NPC 交互提示分别显示手机的 `X/Y`、`A`、`B`，桌面继续读取当前可重绑定按键。

要调位置或大小，直接在 Godot Editor 选中 `DirectionPad`、`ActionPad` 或其中一个 `TouchScreenButton` 修改 `offset_*`、`position`、`scale`；不要在脚本里动态创建按钮，也不要把手机按键写入 `project.godot`。建议至少用 1280×720 和 640×360 横屏预览一次，确认左右两组不重叠且底部留出安全边距。

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

时间锚点只恢复现有时态玩法状态：现在体运动、过去体、延迟选择、所有已有未来体的轨迹与精确播放进度。Momentary 门由恢复后的实体碰撞重新计算；已经锁存的 Latched 门保持当前场景状态。不要把它扩展成通用世界序列化器。

### 过去延迟台

实例化 `delay_pickup.tscn`，设置 Inspector 的 `delay_seconds` 为 `1`、`3` 或 `5`，填写唯一 `delay_switch_id`。它直接调用全局 `EchoTimeline`，不会 `queue_free()`：玩家可反复触碰，当前目标显示收束环，切档完成后显示稳定激活环。现在房内切换立即完成，不播放切档预警。

同一场景必须恰好一台 `default_active = true` 的 `3s` 台。切档预警中触碰另一台只覆盖最新目标，不重置原 `0.6s`；`DelayTraceStart` 从 `gameplay_world` 收集全部延迟台，供 checkpoint 恢复。

### 压力板与门

实例化 `temporal_door.tscn` 和所需数量的 `temporal_pressure_plate.tscn`。压力板只广播状态；在门的 `source_plates` 数组中显式拖入 1–4 块板，并选择模式：

- `MOMENTARY_ALL`：全部板同时按下才保持开启，任一释放立即关闭。
- `LATCHED_ALL`：全部板同时按下一次后保持开启；填写 `latched_door_id` 后先保留在运行态，玩家下一次触碰 `EchoCheckpoint` 时才写入槽位存档，读档直接恢复打开。失败或暂停菜单 Restart 会丢弃尚未提交的锁存。未填写 ID 的原型门只保留运行时锁存。

现在体、过去体和未来体都可压板。门 prefab authored 四个状态格，未接线的格子隐藏，已接线格显示当前缺少哪个输入。不要在关卡脚本中重新组合这些板，也不要用它代替 `PersistentGate`。

### Future 凝固屏障

实例化 `future_condensation_barrier.tscn`，把 `source_recorder` 拖到唯一负责它的记录器。默认竖放是墙；旋转根节点 `90°` 后是平台，整体缩放可调整 authored 长度。

屏障只监听该记录器内部 `FutureEcho.active_changed`。进入 Recorder 或录制中只预留槽位，不会凝固；Future 正式 `start_playback()` 才开启碰撞和结晶动画。Future 自然结束、被 Present/Past 撞散、现在房清线或 timeline reset 时，同帧关闭碰撞并解体。Recall 恢复已有 Future 时也会恢复屏障。多个屏障可以绑定同一 Recorder；不要改成监听全局 `future_slots_changed`。

Future 与屏障共用琥珀金色。Future 自己的出现/消散音作为这组结构的统一音色，屏障不额外叠加一套音效，避免多个同源屏障同时放大音量。

### 收集物

实例化 `temporal_collectible.tscn` 并填写唯一 `item_id`。玩家触碰后记录一次、立即保存、播放 authored 收集动画并移除实例。旧存档缺少该字段时默认为空。终点 `MemoryFloorGate` 只读取四个稳定记忆 ID，按数量点亮 A-D；四枚后清除地块碰撞并进入透明闪烁。

### 支路装置与门

支路末端实例化 `progression_device.tscn` 并填写唯一 `device_id`。本关谜题完成时只调用该实例的 `activate()`；它负责去重、发出激活信号并立即写入当前槽位。终点门或回流捷径实例化 `persistent_gate.tscn`，将 `required_device_id` 设成同一 ID；读档后也会按已激活 ID 恢复。

需要“装置后开回 Hub”的回流口时，实例化 `progression_shortcut.tscn`，填写同一个 `required_device_id`。它初始是实体的青色相位栅；对应装置激活后播放淡出，视觉 alpha 归零并关闭碰撞，读档时按已保存的装置 ID 直接恢复。组件不判断进出方向；单向落差、单向平台或 authored 地形负责让捷径只回 Hub。

### NPC 与中央现在房

普通 NPC 使用 `dialogue_npc.tscn`，赋值 `dialogue_resource_zh`、`dialogue_resource_en` 和可选 `dialogue_title`。`DelayTraceStart` 启动时只判断一次当前 locale，同时锁定 Keeper 的 `present_hub.zh/en.dialogue` 与终局的 `endings.zh/en.dialogue`，整局不再切换或经过 PO 二次翻译。玩家进入范围看到 `E`，按下后复用 `Dialogue/DelayTrace/echo_dialogue_balloon.tscn`；该变体保留 Flow、Animation、TypingSound、CharacterUI 和 Responses，禁用 History、SaveModule 与 Illustration。对话期间 `SceneTree.paused = true`，结束后恢复原状态。

Keeper 的 `askname`、`askheart`、`asktime` 都是玩家主动选择后才写入 `NarrativeSlotModule`。爱心选项要求收集数 `>= 1`，倒计时坦白要求 `run_countdown_expired`；不满足条件的选项完全隐藏。任一未读的一次性选项可用时，NPC 头顶闪烁 `!`；每次写旗标后立即保存。NarrativePresenter 不再自动排队 Keeper 气泡。

中央房直接在连续主场景中 authored 一个 `PresentHub (Area2D)`，不再实例化整房 prefab。其固定子节点为 `RoomShape`、`CurrentRoomCheckpoint`、`DialogueNpc` 和 `RoomDepartureVfx`；作者可在同一场景里调整边界、NPC 与出口，不需要切换房间 scene。玩家位于该 Area2D 内时，`PresentRoom` 把玩家设为 NPC 朝向目标；离开后解除目标并恢复默认朝右。

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

使用 `LevelModule.set_checkpoint(scene_path, checkpoint_id, respawn_position, past_delay_seconds, delay_switch_id)` 写入干净 checkpoint。`past_delay_seconds` 与 ID 必须来自 `EchoTimeline.get_selected_past_delay_seconds()` 和 `get_selected_delay_switch_id()`，这样切档预警中的最新选择也能稳定恢复。延迟台一经选择便同步到 `LevelModule`，倒计时每次变化也同步最新内存值；真正落盘仍只由现有 `SaveSystem.save_slot()` 触发。槽位存档保存 `run_countdown_remaining`、`run_countdown_expired`、当前延迟选择、永久装置、收集物、锁存门和现在房状态。Continue 读取后不会把剩余时间重置为 `30:00`，也不会把 `1s/5s` 支路恢复成 `3s`。

录制中的玩家 Hurtbox 碰到 Trap 时，`DelayTraceStart` 不调用普通 checkpoint 失败：它播放当前金色录像体的退场快照，再由 `EchoTimeline.cancel_future_recording_due_to_failure()` 恢复录像锚点、已有 Future、Past、延迟和倒计时。普通状态碰 Trap 仍走 `0.4s` 死亡复位。

## 起始施工场景

`Scenes/DelayTrace/delay_trace_start.tscn` 已完成机制展台接线：

- 一个 `EchoPlayer`；`EchoTimeline` 与 `PastEcho` 由全局 Autoload 提供。
- 一台 `FutureRecorder`，内部自带一个隐藏 `FutureEcho`。
- 用户 authored 的 16px TileMap 基线；当前镜头测试区按 19 个 `480×270` 触发范围组织（房 A–S），但不锁定正式路线。
- `start_checkpoint` 与 `current_room` 两个 authored `EchoCheckpoint`，以及一个 `SpawnPoint`。
- 一个 `Camera2D + PhantomCameraHost`，每房一台固定 `PhantomCamera2D`（当前 19 台），`zoom=4`，共用 `0.35s QUAD/EASE_IN_OUT` tween。
- 每房一个 authored `Area2D` 房间触发器（当前 19 个），直接使用 Phantom Camera 官方 `2d_trigger_area.gd` 示例脚本；镜头选择、中断和补间全部由 Phantom Camera 插件负责。
- `1s/3s/5s` 三个可重复 `DelayPickup` 延迟台、一个 `FutureRecorder`。
- 一扇 `source_plates` 显式绑定压力板的 `TemporalDoor` 接线样例。
- 主场景内联 `PresentHub`，内含按 `E` 交互的 NPC、`current_room` 自动对话、首次/回访剧情、全房环状冲击波、三座延迟台和 `RoomDepartureVfx`。
- 场景内的 `BranchProgressionDevice` 与 `BranchPersistentGate` 只作为支路进度接线样例；正式谜题仍由本关脚本在条件完成时调用 `activate()`，二者素材与 checkpoint 分离。
- `MemoryShardA/B/C/D` 使用 `TemporalCollectible`；终点 `MemoryFloorGate` 按四枚数量点亮并打开可坠落地块。
- 一个 `TemporalRecordingHUD`：玩家金色轮廓、屏幕金边、无数字进度条和实时回传键。
- 一个 `DelayTraceOnboarding`：新游戏的黑屏红字 `跑/RUN` 结束后，玩家接近 `World/BeforeHub/FloatText` 时读取当前跳跃和方向冲刺绑定，用世界内手写飘字显示一次；Continue 不重复播放。
- 一个 `DelayTraceNarrativePresenter`：开场与记忆共用全黑红字、倾斜字体和 RichText2 抖动序列；普通结局与真结局从 `endings.zh.dialogue` / `endings.en.dialogue` 读取文本，分别使用青白、金色 authored tableau。Keeper 行走播放 `run`，停下说话播放 `idle`；Keeper 对话只由 `DialogueNpc` 主动交互触发。
- 终点下方两个房间保持空白；旧 `true_ending_route` 与 `KnowledgeLock` 已删除，金色全屏演出仍保留。
- 两套 authored 入场淡出资源：新游戏使用青白，Continue 使用洋红；淡出期间冻结 World，不再摆三人 Overlay。
- `PauseScreen` 与 `SettingScreen`；Hint 永久禁用。
- 没有敌人、正式背景或正式路线；`dark_sci_fi_sector.ogg` 只作为施工玩法占位曲。

用户可以在 Godot Editor 直接编辑这棵树。房间边界、PCam 位置和机关位置都可直接替换；继续使用 Inspector 显式绑定，不要把 `delay_trace_start.gd` 改成自动搜索或自动生成内容。

## Phantom Camera 房间接线

每个 `480×270` 房间 authored 一台固定 `PhantomCamera2D` 和一个同尺寸 `Area2D`。Area 直接绑定 `res://addons/phantom_camera/examples/scripts/2D/2d_trigger_area.gd`，PCam 只设置位置、`zoom`、pixel snap、priority、`limit_target` 和共享 tween；不要再写项目级房间切换器、网格坐标计算、Camera2D 插值或切换队列。玩家的 `CameraArea2D` 进入房间时由官方脚本提升对应 PCam priority，离开时释放；进行中的 tween 由 `PhantomCameraHost` 直接中断并转向新 PCam。

当前插件版本为 `0.11.0.3`。场景中的 `Camera2D` 必须保留 `PhantomCameraHost` 子节点，项目必须启用 `addons/phantom_camera/plugin.cfg` 和 `PhantomCameraManager` autoload。缺少任一项应直接报错，不增加备用 Camera 路径。

`PastEcho` 与每个 `FutureEcho` 内部都已 authored 一个 `TemporalDepartureVfx`。不要把退场动画重新绑回主体的 `VfxAnimationPlayer`：旧位置快照和新位置实体化必须并行，未来槽也必须在尾效结束前可复用。

## 调试顺序

1. 先只实例化 Player，确认 Autoload `EchoTimeline` 的过去体会在默认 3 秒后沿历史路径出现。
2. 加一台记录器，确认 `L` 后世界回到锚点且新未来体回放。
3. 加第二台记录器，确认旧未来体恢复锚点进度且两台独立释放。
4. 加两块压力板与一扇门，分别确认 Momentary 释放关闭、Latched 首次全满足后保持开启。
5. 加一个绑定当前 Recorder 的凝固屏障，确认录制不触发、回放触发、Future 释放立即解体。
6. 最后才加 `1/3/5s` 延迟台组合。

在每一步都从干净检查点重试。若路径回放不对，先检查 `EchoTimeline` Autoload、玩家注册和关卡的 `World` 碰撞层，不要通过修改路径算法或动态复制节点掩盖场景错误。

## 音频接线

`GameAudio` 是唯一公开音频入口，Autoload 指向 `Scenes/Autoload/game_audio.tscn`。两台 Music 播放器负责 crossfade，三台固定 UI 播放器负责菜单确认、游戏内确认和取消音；`SettingsModule` 只保存并广播音量值，Bus 应用全部由 `GameAudio` 完成。菜单调用 `play_music("menu", ...)`，玩法入口调用 `play_music("delay_trace_gameplay", ...)`，因此切场景不会继续沿用菜单曲。`ShaderButton` 的 `SelectAudio` 继续负责悬停音，按钮按下只读取 `ui_sound_kind` 元数据，不再注入旧按键音播放器或 fallback。

自动检查只覆盖路径回放、门的多板语义、Future/屏障生命周期、Future 碰撞回 dash 与单格上限、现在房边界、永久进度和明确的行为回归。不要添加把正式地图节点层级、Prefab 数量、颜色、动画时长、房间坐标或 Inspector 参数锁死的测试；这些内容以作者当前的场景与 Inspector 调整为准。
