# 迟相 / Phase Lag

《迟相》是一款 30–40 分钟的横版双空间合作解谜游戏，使用 Godot 4.7 制作。

陆衡与星遥身处同一座星际设施的两个纠缠空间。角色操作即时发生，电源、形变与摧毁状态则延迟传到另一侧。核心不是输入延迟，而是提前安排另一个空间的未来。

## 当前实现

- 五章 authored 流程：Ch1–Ch3 为九个普通解谜房，Ch4 只有“相位猎手”Boss 场，Ch5 只有结尾演出。
- 新游戏先选择 `solo` 或 `local_coop`；模式写入存档并在局内锁定。
- 继续游戏直接读取已保存模式和最近干净检查点，不再次询问。
- 双人模式缺少 P2 手柄时等待连接；断线立即暂停，任意可用 P2 手柄重连后恢复。
- 第一章首门使用 `PoweredDoor.latch_open`，首次开启后保持打开，直到房间显式重置。
- 第二章始终使用上下 `1:1` 分屏；第三章让星遥承担更多执行段，但不改变房间的可读分屏结构。
- 电路不再打开独立墙板小游戏；模块、导管、闸刀和输出都是世界中的实体因果管线，操作时显示手持纹理和方向。
- 陆衡在总闸入口按 `J` 进入“实体维护焦点”，再用 `WASD` 沿真实导管选择模块、插槽或总闸；世界与角色始终可见。
- 可移动电路件和近距离磁力物体使用 authored ShaderMaterial 描边提示。
- 章首、章末和房间对白通过 Dialogue Manager 的中线 story/radio balloon 播放；章节间使用约 `1.4s` 的中线合拢/展开转场。
- 设置控件、下拉菜单和按键行共用 authored Theme；按键行具有独立 hover/focus/selected 状态。
- 环境、敌人、门、UI、音乐与音效已接入正式 CC0 素材，来源见 [素材来源表](docs/phase-lag-asset-sources.md)。

## 角色素材状态

两只机器人占位已经删除。当前先使用可替换的人形 CC0 过渡素材，后续可直接换成自绘角色，不改玩家碰撞与玩法接口。

- 陆衡：Ansimuz `Cyberpunk Detective`，当前 `5x` 显示。
- 星遥：LuizMelo `Huntress`，当前 `2.5x` 显示。
- 替换入口：`resources/phase_lag/characters/lu_heng_visual.tres`、`xing_yao_visual.tres`
- 保留合同：动画名、`PhaseCharacterVisualConfig`、碰撞、交互范围、视觉偏移和当前可读轮廓。
- 玩家碰撞约 `110×180px`；以后重画时保持相近视觉高度，不缩回原来的小人尺寸。

详细动画名和锚点要求见 [美术资产规格](docs/phase-lag-art-spec.md)。

## 操作

### 单人 / P1

| 操作 | 默认键位 |
| --- | --- |
| 移动 / 跳跃 | `WASD` |
| 主要行动 | `J` |
| 辅助行动 | `K` |
| 闪避 | `L` |
| 切换角色 | `Q` |
| 暂停 | `Esc` |

陆衡靠近管线底部总闸后按 `J` 进入实体维护焦点。焦点内用 `WASD` / 方向输入沿导管选目标，`J` 插拔模块或拉闸，`K` 旋转，`L` 退出；焦点外 `L` 仍是冲刺。单人模式一名角色离场后自动切到另一名角色，并锁定本房间的 `Q`，下一房间或复位后恢复。星遥使用 `J` 快斩、`K` 蓄力破甲/反击、`L` 冲刺。

### 本地双人

P1 固定陆衡，P2 固定星遥。P2 使用第二只手柄；进入关卡后模式固定。断线层可等待重连，也可返回主菜单。

## 存档

`LevelModule.play_mode` 持久化稳定字符串：

```text
solo
local_coop
```

旧存档缺少字段时按 `solo` 读取，并在下次保存补齐。Phase Lag 检查点只保存章节、房间、检查点 ID 和已经抵达的持久设备状态；不保存事件队列、电路倒计时、Boss 轮次、当前血量、临时敌人状态或角色即时位置。

## 运行与验证

启动项目：

```powershell
godot.cmd --path .
```

代码改动只执行 Godot 导入、脚本解析和主场景短启动；完整流程通过人工游玩验收。

```powershell
godot.cmd --headless --editor --path . --import
godot.cmd --headless --path . --editor --quit
godot.cmd --headless --path . --quit-after 5
```

当前阶段不执行 Windows 导出。
