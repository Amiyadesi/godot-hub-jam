# Phase Lag 输入、层级与地图重构 PRD（草案）

> 仓库当前没有 `.trellis/` 或 `task.py`。本文件是在现有 `docs/` 下承载本轮 Trellis brainstorm 的临时 PRD；用户确认范围后再补技术设计与执行清单。

## Goal

让菜单、设置和暂停按钮稳定支持鼠标、键盘与手柄；实体维护焦点继续只使用键盘/手柄；首批将 Ch1 迁移到可精确拼装、具有高低差、不会产生浮空或夹死问题的 TileMap 横版地图结构，并对 Ch2 R3 做局部阻断修复。

## Confirmed Facts

- `InputMap` 已允许单个 action 保存多个事件；P1/P2 默认 action 已同时包含键盘和手柄事件（`project.godot:97-186`）。
- `KeybindingModule` 已提供添加、替换、删除、排序和枚举全部事件的 API（`Scripts/Save/Modules/keybinding_module.gd`）。
- 模板 `KeybindingRow` 已能为每个 action 显示多个绑定并提供“添加”按钮（`addons/enhance_save_system/Components/InputRemapping/keybinding_row.gd:64-124`）。
- 当前 Phase 设置页只显示第一个事件，并始终调用 `rebind_action_primary()`，因此隐藏了同 action 的其他绑定（`Scripts/PhaseLag/UI/phase_keybinding_row.gd:35-40`、`phase_keybinding_ui.gd:49-55`）。
- 冲突弹窗来自共享 `KeyCaptureDialog`，不是 InputMap 必需约束（`addons/enhance_save_system/Components/InputRemapping/key_capture_dialog.gd:93-113`）。
- 实体维护焦点当前只接收 `Vector2i` 方向导航；管线和插槽没有鼠标 hover/click 合同，这是有意保留的世界输入边界（`Scripts/PhaseLag/Circuit/phase_causal_pipeline.gd:317+`、`Scripts/PhaseLag/Gameplay/lu_heng_tool_controller.gd:69-95`）。
- 两个 SubViewport 已各自拥有独立 `Camera2D`，当前相机同时跟随 X/Y 并读取房间 bounds（`Scenes/PhaseLag/Gameplay/world_side.tscn:15-21`、`Scripts/PhaseLag/Gameplay/world_side.gd`、`Scripts/PhaseLag/Rooms/phase_room_side.gd`）。
- Ch1 已有 authored `TileMapLayer` 三层结构与 32px TileSet；Ch2–Ch5 暂时保留显式房间几何，Ch2 R3 只修复守卫诱导走廊和 physics-space 生命周期（`Scenes/PhaseLag/Rooms/Chapter01/Terrain`、`resources/phase_lag/tilesets/ch1_sci_fi_32.tres`）。
- Ch1 使用由 verified Ansimuz atlas 派生的 nearest 32px TileSet；背景和独立道具仍由原 authored 场景提供（`assets/phase_lag/environment/tiles/ch1_sci_fi_atlas_32.png`、`resources/phase_lag/tilesets/ch1_sci_fi_32.tres`）。
- 门当前将左柱/顶梁放在后层，将右柱、右半门槛和门板放在前层；门根节点固定在 TileMap 地面基准（`Scenes/PhaseLag/Devices/powered_door.tscn`）。
- Ch1 R3 的检修升降台首次到顶后使用 `latch_effective_state = 1`，移除电池不会回落（`Scenes/PhaseLag/Rooms/Chapter01/ch1_r3_lu.tscn`）。
- Ch2 R3 的守卫诱导走廊使用抬高甲板、压力板右侧 backstop 和 physics-space 生命周期保护，不迁移为 TileMap（`Scenes/PhaseLag/Rooms/Chapter02/ch2_r3_lu.tscn`、`Scripts/PhaseLag/Enemies/facility_guard.gd`）。
- 暂停按钮已移到独立 authored `PhasePauseCommandLayer`（CanvasLayer 30）；转场、对白、失败层和暂停菜单会显式禁用其鼠标命中（`Scenes/PhaseLag/UI/phase_pause_command_layer.tscn`）。

## Requirements

### R1. 鼠标与焦点一致

- 菜单和设置中的鼠标 hover 必须立即成为当前选中项；点击执行同一命令。
- 键盘/手柄导航后继续自动滚动；鼠标移动后选中框跟随鼠标，不保留旧键盘行。
- 实体维护焦点保留 `WASD`/方向键和手柄导航；鼠标不进入角色移动、管线插槽或总闸输入。
- 鼠标坐标只服务于菜单、设置、键位页和暂停命令层，不换算到 SubViewport 世界。

### R2. 一行动多绑定

- 每行显示该 action 的全部绑定，不再只显示 primary。
- 每个绑定可单独替换或删除；行末提供 authored “添加绑定”图标按钮。
- 捕获支持键盘键、鼠标键、手柄按钮和手柄轴。
- 删除冲突弹窗和冲突文字；共享输入是否同时触发多个 action 由最终输入策略决定。
- 重置默认、保存、加载后保留完整事件数组和显示顺序。

### R3. 设置页滚动条

- `VScrollBar` 使用 authored Theme：窄轨道、明显 grabber、hover/drag 状态、无默认灰条。
- 滚动条不得覆盖内容；鼠标滚轮、拖动、键盘 focus 自动滚动全部可用。

### R4. 暂停交互层

- 游戏内 HUD 命令进入独立 authored `CanvasLayer`。
- 世界 < HUD < 暂停菜单 < Dialogue < 章节转场；不可见层必须不接收鼠标。
- 右上暂停按钮必须有稳定点击区域、hover/pressed 反馈，并与 `pause` action 共用入口。

### R5. 门与遮挡层

- 左柱及左侧门槛全部位于角色后方。
- 右柱、右侧门槛及需要遮住角色的门叶位于角色前方。
- 关闭门碰撞与打开后的实际通道严格对齐地形格，不再浮空。

### R6. TileMapLayer 房间结构

- Ch1 使用 32px authored TileSet，包含地面、平台边缘、墙体和碰撞 terrain。
- Ch1 每个房间侧使用独立 TileMapLayer：`TerrainBack`、`TerrainCollision`、`TerrainFront`；设备、敌人、门和管线继续用独立场景节点。
- Ch1 的 TileSet collision 成为地板/平台/墙体主要碰撞来源；Ch2–Ch5 的既有特殊几何不在本轮迁移范围内。
- 未来/过去保持同地点骨架，但允许损伤、断层、平台状态和前景层不同。

### R7. 每侧独立二维相机

- 保留现有每侧一台 `Camera2D`，不重复新增。
- 相机同时跟随 X/Y，使用 dead zone、平滑和 TileMap bounds；允许真正的上下层路线。
- 分屏仍为 Ch2 `1:1`，相机不能暴露地图外空白。

### R8. Ch1 R3 安全重做

- 检修升降台首次到达上层后锁存，取回电池不会让平台砸回玩家。
- 电池、保险丝、最终双输入与 wire tee 因果链保留。
- 关卡改为清晰的下层取电池、上层取保险丝、右侧组合管线三段空间；不把全部机关挤在同一平面。
- 任意错误操作可复位，不产生夹死、道具吞失或无法返回状态。

## Acceptance Criteria

- 鼠标经过任意菜单按钮或键位行时，选中态在同一帧移动；点击可执行。
- 菜单、设置和暂停 action 可同时保存并显示键盘、鼠标、手柄绑定；P1/P2 gameplay action 至少保留键盘与手柄绑定，退出设置并重进后不丢失。
- 不再出现冲突提示弹窗。
- 右侧滚动条具有完整 authored 状态并可拖动。
- 右上暂停按钮在正常游玩时可点击；转场、Dialogue、失败层打开时不可点击。
- 门左下结构不再遮住位于左侧的玩家；门底与 TileMap 地面无可见缝隙。
- 两侧相机可跟随玩家进入上下层，保持各自 SubViewport 边界。
- Ch1 R3 无平台压人死锁；完整因果链仍可单人和双人通关。
- 迁移后的房间不再使用手摆矩形 StaticBody 作为主要地形。

## Out Of Scope

- 本轮不重画主角、敌人或门的最终素材。
- 不更改迟相事件、`CircuitRunPlan`、Dialogue Manager、Ch4 Boss 和 Ch5 finale 的核心流程。
- 不恢复旧网格墙板或全屏解谜 modal。

## Scope Lock

- 本轮只迁移 Ch1 六个房间侧；Ch2 R3 采用局部 authored 几何修复，避免把阻断修复扩大成全章重做。
