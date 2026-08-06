# 延迟追迹 / Delay Trace

《延迟追迹》是 Godot 4.7 制作中的横版时态追逐游戏。现在体留下的路径会在延迟后变成过去体追上自己；玩家还能从记录器回传一段已走过的路线，短暂生成未来可能性。

内部资源路径、类名和存档键继续使用 `EchoChase` 作为开发代号。

当前仓库完成核心机制、独立 prefab、黑白时间轨迹菜单、设置/存档框架，以及一个可直接试玩全部时间机关的施工入口。入口已接入 Phantom Camera 房间镜头，但正式灰盒、路线、出口、最终机关摆位、镜头参数、角色成稿和最终试玩仍由项目作者决定。

## 操作

| 操作 | 默认键位 |
| --- | --- |
| 移动 | `WASD` |
| 八方向冲刺 | `J` |
| 跳跃 | `K` |
| 结束未来录像并回传 | `L` |
| 暂停 | `Esc` |

移动手感参数直接在 `EchoPlayer` Inspector 调整；地面和空中共享一次冲刺，落地恢复，并支持土狼时间、跳跃缓冲、墙滑和墙跳。

## 时间规则

- 过去体读取玩家 `1s`、`3s` 或 `5s` 前的路径，默认 `3s`。
- 延迟台可重复使用；切换有 `0.6s` 相位期，过去体此时不碰撞也不触发机关。连续选择只替换目标，不延长相位期。
- 每台 authored 记录器自带一个独占 `FutureEcho`；记录器数量就是未来体容量。进入空闲记录器自动录像，最长 `5s`；首帧即可提交，短录像保持末帧补足到 `1s`。
- `L` 只提交当前录像并把玩家送回记录器起点，不暂停世界。
- 开始录像时会捕获时间锚点；提交后现在体、过去体、延迟选择和已有未来体回到该锚点，新未来体保留刚录下的路径。
- 录制中接触过去体也会走同一提交/回传路径；普通状态接触仍会失败复位。
- 未来体播放结束即停止机关作用并消散；过去体永久存在。
- 过去体会抓住现在体并消散未来体；现在体也能消散未来体；未来体彼此穿透。

完整术语与边界见 [CONTEXT.md](CONTEXT.md)，设计目标见 [echo-chase-jam-design.md](docs/echo-chase-jam-design.md)，黑白地图界面规则见 [echo-chase-ui-design.md](docs/echo-chase-ui-design.md)。

## 给灰盒作者的接线入口

可直接实例化的场景位于 [Scenes/EchoChase/Prefabs](Scenes/EchoChase/Prefabs)：

- `echo_timeline_controller.tscn`
- `echo_player.tscn`
- `future_recorder.tscn`
- `delay_pickup.tscn`
- `temporal_pressure_plate.tscn`
- `temporal_door.tscn`
- `echo_checkpoint.tscn`

施工入口是 [echo_chase_start.tscn](Scenes/EchoChase/echo_chase_start.tscn)：包含一个玩家、一组 `480×270` 测试房（当前 19 房 A–S）、Phantom Camera Host 与每房固定 PCam、一个 checkpoint、`1/3/5s` 延迟台、一台自带未来体的记录器、已接线压力板与时间门、支路进度与收集样例、录制 HUD、同色时态淡入、出界复位和暂停/设置 UI。它是机制展台，不代表正式路线。

接线步骤、碰撞层和检查点调用顺序见 [echo-chase-wiring.md](docs/echo-chase-wiring.md)。不要用脚本动态补节点；每个关卡场景必须显式实例化并绑定所需组件。

## 存档

`LevelModule` 保存干净检查点、当前延迟选择、整局倒计时剩余值，以及已有的装置、收集物、锁存门和中央房状态。它不保存任何在途时间线或录像路径；主菜单的“继续游戏”会恢复保存时的倒计时和 `1/3/5s` 延迟选择。它故意不兼容 Phase Lag 的旧玩法语义；已有 checkpoint 时点“开始游戏”会先确认是否覆盖。

## 验证

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --scene res://Tests/EchoChase/run_tests.tscn
godot --headless --path . --scene res://Scenes/EchoChase/echo_chase_start.tscn --quit-after 5
```

原型阶段只保留路径插值与回传断点两项算法检查。关卡结构、Prefab 数量、资源、视觉、UI、相机和 Inspector 调参均以编辑器中的当前 authored 内容为准，不用硬测试锁死。

Windows 试玩导出由当前 Jam 交付流程单独验证，正式路线仍以用户 authored 灰盒和试玩止损门为准。
