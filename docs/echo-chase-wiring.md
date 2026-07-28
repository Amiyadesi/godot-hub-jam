# Echo Chase 灰盒接线

本页只说明如何把已有 prefab 接进**用户已经搭好的灰盒场景**。它不定义路线、关卡尺寸、出口位置或机关解法，也不要求任何脚本动态生成节点。

## 最小场景树

```text
YourGrayboxRoot (Node2D)
├── EchoTimelineController   [instance: Prefabs/echo_timeline_controller.tscn]
│   ├── PastEcho
│   ├── FutureEchoA
│   └── FutureEchoB
├── EchoPlayer               [instance: Prefabs/echo_player.tscn]
├── FutureRecorder           [按需 instance]
├── DelayPickup              [按需 instance]
├── TemporalPressurePlate    [按需 instance]
├── TemporalDoor             [按需 instance]
├── Terrain                  [作者的 StaticBody2D / TileMapLayer]
├── SpawnPoint               [作者的 Marker2D]
└── Checkpoint               [作者的 Marker2D 或已有检查点节点]
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

漏掉任何一个必填引用会主动报错。这是有意的 authored 场景合同，不要添加静默 fallback。

## 碰撞层合同

`project.godot` 已声明以下 2D 层：

| 层 | 名称 | 用途 |
| --- | --- | --- |
| 1 | `Player` | `EchoPlayer` |
| 2 | `Past Echo` | `PastEcho` |
| 3 | `Future Echo` | `FutureEcho` |
| 4 | `World` | 地面、墙、门、普通地形 |
| 5 | `Temporal Trigger` | 记录器、延迟拾取物、压力板 |

不要修改 prefab 内已有的过去/未来层与 mask，除非同时更新自动碰撞矩阵测试。灰盒地形应在 `World` 层；记录器、拾取物、压力板使用 `Temporal Trigger`。

## 机关接线

### 记录器

实例化 `future_recorder.tscn`，摆在作者选择的录制起点，填入 `timeline`。玩家进入时自动开始录像。录制中按 `L` 或达到 5 秒后提交；玩家回到该记录器起点，未来体从那条路线开始播放。

记录器不需要额外脚本来开始或结束录像。玩家回传后必须先离开区域才能再次触发同一个记录器，这是为了避免起点内循环录制。

### 过去延迟拾取物

实例化 `delay_pickup.tscn`，设置 Inspector 的 `delay_seconds` 为 `1`、`3` 或 `5`，填入 `timeline`。它是一次性节点：当前玩家触碰后启动 `0.6s` 切档相位期并 `queue_free()`。

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
player.reset_player(spawn_point.global_position)
timeline.reset_timeline()
```

先复位玩家，再清时间线。不要保存或恢复在途路径、剩余录像、未来体位置、过去体切档过程或临时压力板占用。

使用 `LevelModule.set_checkpoint(scene_path, checkpoint_id, persistent_state)` 写入干净 checkpoint；`persistent_state` 只能包含已经稳定成立的 authored 世界状态。

## 调试顺序

1. 先只实例化 Timeline 和 Player，确认过去体会在默认 3 秒后沿历史路径出现。
2. 加一个记录器，确认 `L` 回传和一条未来体回放。
3. 加一个压力板与门，确认未来体结束后门立即关闭。
4. 最后才加 `1/3/5s` 拾取物和两个未来槽的组合。

在每一步都从干净检查点重试。若路径回放不对，先检查 Timeline/Player 的 Inspector 引用和关卡的 `World` 碰撞层，不要通过修改路径算法或动态复制节点掩盖场景错误。

## 自动测试夹具

`Tests/EchoChase/fixtures/echo_timeline_fixture.tscn` 是最小 authored 测试场景，包含 Timeline、Player、记录器、拾取物、压力板与门。它不是可交付关卡，也不应被当作起始场景或地图模板。
