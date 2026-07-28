# 回声追猎 / Echo Chase

《回声追猎》是 Godot 4.7 制作中的横版时态追逐游戏。现在体留下的路径会在延迟后变成过去体追上自己；玩家还能从记录器回传一段已走过的路线，短暂生成未来可能性。

当前仓库只完成核心机制、独立 prefab、菜单/设置/存档框架和自动测试。关卡灰盒、路线、出口、机关摆位、角色美术和最终试玩由项目作者提供；没有灰盒入口场景时主菜单会禁用开始与继续，不生成替代关卡。

## 操作

| 操作 | 默认键位 |
| --- | --- |
| 移动 | `WASD` |
| 八方向冲刺 | `J` |
| 跳跃 | `K` |
| 结束未来录像并回传 | `L` |
| 暂停 | `Esc` |

移动参数：跑速 `250px/s`，跳速 `400px/s`，冲刺 `600px/s`。地面和空中共享一次冲刺，落地恢复；包含 `0.15s` 土狼时间与跳跃缓冲、墙滑和墙跳。

## 时间规则

- 过去体读取玩家 `1s`、`3s` 或 `5s` 前的路径，默认 `3s`。
- 切换过去延迟有 `0.6s` 相位期，过去体此时不碰撞也不触发机关。
- 进入记录器自动录像，最短 `1s`、最长 `5s`，最多两个未来可能性槽。
- `L` 只提交当前录像并把玩家送回记录器起点，不暂停世界。
- 未来体播放结束即停止机关作用并消散；过去体永久存在。
- 过去体会抓住现在体并消散未来体；现在体也能消散未来体；未来体彼此穿透。

完整术语与边界见 [CONTEXT.md](CONTEXT.md)，设计目标见 [echo-chase-jam-design.md](docs/echo-chase-jam-design.md)。

## 给灰盒作者的接线入口

可直接实例化的场景位于 [Scenes/EchoChase/Prefabs](Scenes/EchoChase/Prefabs)：

- `echo_timeline_controller.tscn`
- `echo_player.tscn`
- `future_recorder.tscn`
- `delay_pickup.tscn`
- `temporal_pressure_plate.tscn`
- `temporal_door.tscn`

接线步骤、碰撞层和检查点调用顺序见 [echo-chase-wiring.md](docs/echo-chase-wiring.md)。不要用脚本动态补节点；每个关卡场景必须显式实例化并绑定所需组件。

## 存档

`LevelModule` 仅保存干净检查点：`checkpoint_scene_path`、`checkpoint_id` 与稳定 `persistent_state`。它故意不兼容 Phase Lag 开发存档，也不保存任何在途时间状态。

## 验证

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://Tests/EchoChase/run_tests.gd
```

当前测试覆盖路径插值/回传断点、玩家输入回传、`1/3/5s` 切档、未来槽位、消散释放、时态碰撞矩阵和时间线重置。

不导出 Windows 版本，直到用户灰盒完成并通过试玩止损门。
