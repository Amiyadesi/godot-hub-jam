# Delay Trace 灰盒接线

显示名为 `Delay Trace`；`EchoChase` 仅作为内部路径和类名。

本页只说明如何把已有 prefab 接进**用户已经搭好的灰盒场景**。它不定义路线、关卡尺寸、出口位置或机关解法，也不要求任何脚本动态生成节点。

## 最小场景树

```text
YourGrayboxRoot (Node2D)
├── World (Node2D, PROCESS_MODE_PAUSABLE)
│   ├── EchoTimelineController   [instance: Prefabs/echo_timeline_controller.tscn]
│   │   ├── PastEcho
│   │   ├── FutureEchoA
│   │   └── FutureEchoB
│   ├── EchoPlayer               [instance: Prefabs/echo_player.tscn]
│   ├── FutureRecorder           [按需 instance]
│   ├── DelayPickup              [按需 instance；语义为可重复延迟台]
│   ├── TemporalPressurePlate    [按需 instance]
│   ├── TemporalDoor             [按需 instance]
│   ├── Terrain                  [作者的 StaticBody2D / TileMapLayer]
│   ├── SpawnPoint               [作者的 Marker2D]
│   └── EchoCheckpoint           [instance: Prefabs/echo_checkpoint.tscn]
├── UI (CanvasLayer)
│   ├── TemporalRecordingHUD
│   ├── PauseScreen
│   └── SettingScreen
└── SceneController (Node, PROCESS_MODE_ALWAYS)
```

`EchoTimelineController` 预制体内部已经带一个过去体和两个未来体。不要在关卡场景中再复制额外的过去体或未来体。

## Inspector 必填引用

所有引用都必须在 Inspector 中直接拖拽，不使用 `get_node_or_null()`、组搜索或脚本补节点。

| 节点 | Inspector 字段 | 指向 |
| --- | --- | --- |
| `EchoTimelineController` | `player` | 同级 `EchoPlayer` |
| `EchoPlayer` | `timeline` | 同级 `EchoTimelineController` |
| `FutureRecorder` | `timeline` | 同级 `EchoTimelineController` |
| `DelayPickup` | `timeline` | 同级 `EchoTimelineController` |
| `TemporalPressurePlate` | `target_door` | 要控制的 `TemporalDoor`，可留空做自定义接线 |
| `TemporalRecordingHUD` | `player/timeline` | 场景内玩家与时间线 |
| `EchoChaseStart` | `player/timeline/gameplay_world/spawn_point/fall_reset_area/pause_screen/setting_screen/reset_audio` | 场景内对应 authored 节点 |
| `EchoChaseStart` | `present_entry_transition/past_entry_transition` | 与菜单满屏颜色一致的 `0.35s` authored 淡出资源 |
| `EchoChaseStart` | `checkpoint_paths` | 本场景全部 `EchoCheckpoint`，ID 必须非空且唯一 |
| `EchoChaseStart` | `delay_switch_paths` | 本场景全部延迟台；ID 唯一且恰好一个默认 `3s` 台 |

漏掉任何一个必填引用会主动报错。这是有意的 authored 场景合同，不要添加静默 fallback。

## 碰撞层合同

`project.godot` 已声明以下 2D 层：

| 层 | 名称 | 用途 |
| --- | --- | --- |
| 1 | `Player` | `EchoPlayer` |
| 2 | `Past Echo` | `PastEcho` |
| 3 | `Future Echo` | `FutureEcho` |
| 4 | `World` | 地面、墙、门、普通地形 |
| 5 | `Temporal Trigger` | 记录器、延迟台、压力板 |

不要修改 prefab 内已有的过去/未来层与 mask，除非同时更新自动碰撞矩阵测试。灰盒地形应在 `World` 层；记录器、拾取物、压力板使用 `Temporal Trigger`。

## 机关接线

### 记录器

实例化 `future_recorder.tscn`，摆在作者选择的录制起点，填入 `timeline`。玩家进入时自动开始录像。录制中按 `L` 或达到 5 秒后提交；玩家回到该记录器起点，未来体从那条路线开始播放。

记录器不需要额外脚本来开始或结束录像。玩家回传后必须先离开区域才能再次触发同一个记录器，这是为了避免起点内循环录制。

### 过去延迟台

实例化 `delay_pickup.tscn`，设置 Inspector 的 `delay_seconds` 为 `1`、`3` 或 `5`，填写唯一 `delay_switch_id` 并绑定 `timeline`。它保留 `DelayPickup` 类名以避免无意义改名，但不会 `queue_free()`：玩家可反复触碰，当前目标显示收束环，切档完成后显示稳定激活环。

同一场景必须恰好一台 `default_active = true` 的 `3s` 台。切档预警中触碰另一台只覆盖最新目标，不重置原 `0.6s`；`EchoChaseStart.delay_switch_paths` 必须列出全部台，供启动校验和 checkpoint 恢复。

### 压力板与门

实例化 `temporal_door.tscn` 和 `temporal_pressure_plate.tscn`，在压力板的 `target_door` 中绑定门。现在体、过去体和未来体都可压板；未来体消散或过去体切档时，碰撞释放会自然让门关闭。

若关卡需要多个板共同控制一扇门，作者应在场景内显式放置一个本地组合节点或写一个小型本关脚本，并保持其输入来自各板的 `pressed_changed` 信号。不要把通用“谜题管理器”提前抽象出来。

## 失败、重置和检查点

场景根节点或现有关卡控制器应连接：

```text
EchoTimelineController.player_caught -> 你的本关失败/重生入口
```

失败和 checkpoint 恢复只还原稳定状态：

```gdscript
# 示例：由你已有的关卡控制器在稳定重生时调用。
player.reset_player(respawn_position)
timeline.reset_timeline(saved_past_delay_seconds, saved_delay_switch_id)
```

先复位玩家，再清时间线。不要保存或恢复在途路径、剩余录像、未来体位置、过去体切档过程或临时压力板占用。

使用 `LevelModule.set_checkpoint(scene_path, checkpoint_id, respawn_position, past_delay_seconds, delay_switch_id)` 写入干净 checkpoint。`past_delay_seconds` 与 ID 必须来自 `timeline.get_selected_past_delay_seconds()` 和 `get_selected_delay_switch_id()`，这样切档预警中的最新选择也能稳定恢复。当前 schema 不保存其他机关状态，也不迁移缺少这两个字段的开发存档。

## 起始施工场景

`Scenes/EchoChase/echo_chase_start.tscn` 已完成机制展台接线：

- 一个 `EchoPlayer`、一个 `EchoTimelineController`、一个 `PastEcho`、两个隐藏 `FutureEcho`。
- 一个 96 格、16px tile 的直平台，仅三种平台 tile 带碰撞。
- 一个 `EchoCheckpoint`、一个 `SpawnPoint`、一个 `FallResetArea`。
- 一个挂在玩家下、zoom 为 `4×` 的 `Camera2D`，只用于当前横向测试走廊。
- `1s/3s/5s` 三个可重复 `DelayPickup` 延迟台、两个 `FutureRecorder`。
- 一个显式连接 `TemporalDoor` 的 `TemporalPressurePlate`。
- 一个固定屏幕的低对比地图背景。
- 一个 `TemporalRecordingHUD`：玩家金色轮廓、屏幕金边、无数字进度条和实时回传键。
- 两套 authored 入场淡出资源：新游戏使用青白，Continue 使用洋红；淡出期间冻结 World，不再摆三人 Overlay。
- `PauseScreen` 与 `SettingScreen`；Hint 永久禁用。
- 没有 Phantom Camera、敌人、正式背景、正式路线或玩法音乐。

用户可以在 Godot Editor 直接编辑这棵树。临时相机和机关位置都可直接替换；继续使用 Inspector 显式绑定，不要把 `echo_chase_start.gd` 改成自动搜索或自动生成内容。

`PastEcho` 与每个 `FutureEcho` 内部都已 authored 一个 `TemporalDepartureVfx`。不要把退场动画重新绑回主体的 `VfxAnimationPlayer`：旧位置快照和新位置实体化必须并行，未来槽也必须在尾效结束前可复用。

## 调试顺序

1. 先只实例化 Timeline 和 Player，确认过去体会在默认 3 秒后沿历史路径出现。
2. 加一个记录器，确认 `L` 回传和一条未来体回放。
3. 加一个压力板与门，确认未来体结束后门立即关闭。
4. 最后才加 `1/3/5s` 延迟台和两个未来槽的组合。

在每一步都从干净检查点重试。若路径回放不对，先检查 Timeline/Player 的 Inspector 引用和关卡的 `World` 碰撞层，不要通过修改路径算法或动态复制节点掩盖场景错误。

## 自动测试夹具

`Tests/EchoChase/fixtures/echo_timeline_fixture.tscn` 是最小 authored 测试场景，包含 Timeline、Player、记录器、拾取物、压力板与门。它不是可交付关卡，也不应被当作起始场景或地图模板。
