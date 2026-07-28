# Phase Lag 素材来源表

## 导入规则

- 下载与验证目录位于仓库外：`D:\AIworkspace\scratch\downloads\phase_lag_verified`。
- ZIP、PNG、OGG、MP3、FLAC 均在导入前检查文件头；仓库只保留实际使用文件。
- 像素图使用 nearest filtering，关闭 mipmap。
- OGA 双授权页面统一选择 `CC0`；未使用需要署名或禁止独立再发布的授权分支。
- Kenney Industrial Expansion 未导入；PeriTune 只作风格参考，未提交原始音乐。

## Ansimuz Sideview Sci-Fi

- 来源：[Sideview Sci-Fi - Patreon Collection](https://opengameart.org/content/sideview-sci-fi-patreon-collection)
- 作者：ansimuz
- 许可证：CC0

| 用途 | 原文件 | 导入路径 | 处理 |
| --- | --- | --- | --- |
| 走廊远景 | `Environments/cyberpunk-corridor-files/PNG/layers/back.png` | `assets/phase_lag/environment/corridor_back.png` | 保留像素尺寸；冷暖空间在 authored scene 中改色。 |
| 设施墙 | `Environments/bulkhead-walls/PNG/bg-wall-with-supports.png` | `assets/phase_lag/environment/bulkhead_wall.png` | 保留原图；scene 内平铺和改色。 |
| 前景遮挡 | `Environments/bulkhead-walls/PNG/foreground.png` | `assets/phase_lag/environment/bulkhead_foreground.png` | 保留原图；只作不遮挡目标的前景层。 |
| 墙体终端 | `Environments/cyberpunk-detective-prop-files/PNG/big-computer.png` | `assets/phase_lag/environment/big_computer.png` | 保留原图；scene 内缩放。 |
| 菜单走廊 | `Environments/cyberpunk-corridor-files/PNG/layers/cyberpunk-corridor.png` | `assets/phase_lag/environment/facility_corridor_strip.png` | 裁成 `1060×176` 横向设施带；同一贴图作为 Background/PhaseEcho 分层，由 authored AnimationPlayer 只做冷暖改色与最多 `8px` 位移，不新增生成式装饰。 |
| 冷冻舱 | `Environments/cyberpunk-detective-prop-files/PNG/cryo-pod.png` | `assets/phase_lag/environment/props/cryo_pod.png` | 重命名；作为远离玩法层的设施道具。 |
| 吊挂终端 | `Environments/cyberpunk-detective-prop-files/PNG/hanging-terminal.png` | `assets/phase_lag/environment/props/hanging_terminal.png` | 重命名；scene 内缩放。 |
| 服务器柜 | `Environments/cyberpunk-detective-prop-files/PNG/server-gabinetes.png` | `assets/phase_lag/environment/props/server_cabinets.png` | 修正文件名后导入；scene 内缩放。 |
| 小型终端 | `Environments/cyberpunk-detective-prop-files/PNG/small-terminal.png` | `assets/phase_lag/environment/props/small_terminal.png` | 用于环境终端、复位杆与独立气闸启动杆；不再冒充可搬运电池。 |
| 相位升降舱 | `Environments/cyberpunk-detective-prop-files/PNG/elevator.png` | `assets/phase_lag/environment/props/elevator.png` | 保留原图；只用于明确需要升降/相位发射语义的设备，不再作为每个房间的共用出口。 |
| 压力板/检查点 | `Environments/sci-fi-interior-paltform/PNG/tile-set-sci-fi-interior-platform.png` | `assets/phase_lag/environment/props/pressure_plate.png` | 裁切 `Rect2(32, 144, 64, 16)`；用于机关压力板与低矮检查点，替换巨型环形锚。 |
| 升降平台 | `Environments/sci-fi-interior-paltform/PNG/tile-set-sci-fi-interior-platform.png` | `assets/phase_lag/environment/props/powered_platform.png` | 裁切 `Rect2(96, 128, 64, 32)`；场景内横向拼接三段，碰撞不变。 |
| 地行寄生体过渡图 | `Sprites/alien-walking-enemy/PNG/alien-enemy-walk.png` | `assets/phase_lag/enemies/ground_alien_walk.png` | 跳过首个预览格，使用后五格 `57×42` 行走帧映射 crawl、warn、leap、hit、death 状态。 |
| 舰载无人机过渡图 | `Sprites/spaceship-unit/PNG/ship-unit-with-thrusts.png` | `assets/phase_lag/enemies/phase_drone_ship.png` | 跳过首个预览格，使用后七格 `106×77` 推进动画；保持 Drone FSM、碰撞和攻击时序。 |
| 设施守卫 | `Sprites/bipedal-Unit/PNG/bipedal-unit.png` | `assets/phase_lag/enemies/facility_guard_biped.png` | 保留七帧图集；Ch2 R2/R3 与 Ch3 R2 使用，按守卫 FSM 切换 walk、charge、attack、stagger、corpse。 |
| 相位猎手 | `Sprites/tank-unit/PNG/tank-unit.png` | `assets/phase_lag/enemies/phase_hunter_tank.png` | 保留图集；替换旧 Boss 占位。 |
| 房间出口地标 | `Environments/cyberpunk-corridor-files/PNG/layers/cyberpunk-corridor.png` | `assets/phase_lag/environment/exit_door.png` | 原图裁切 `Rect2(256, 432, 160, 176)`；只用于房间出口地标，不再作为 `PoweredDoor` 门体。 |

## Ganamoda 190+ Pixel Art Assets

- 来源：[190+ Pixel Art Assets (Sci-fi & Forest)](https://opengameart.org/content/190-pixel-art-assets-sci-fi-forest)
- 作者：Ganamoda
- 许可证：CC0

| 用途 | 原文件 | 导入路径 | 处理 |
| --- | --- | --- | --- |
| 可搬运电源模块 | `PNG/Green Barrel.png` | `assets/phase_lag/environment/props/power_cell_device.png` | 原图 `35x47`；nearest 放大为约 `88x118`，明确呈现带设备头的能源罐。 |
| 第一房间实体断路器 | `PNG/Computer station 1.png` | `assets/phase_lag/environment/props/power_breaker_terminal.png` | 原图 `39x50`；作为地面设施主体，附 authored 开关和双状态灯，不再打开网格墙板。 |
| 地面电池座机柜 | `PNG/Machine 2.png` | `assets/phase_lag/environment/props/battery_dock_machine.png` | 原图 `56x79`；作为可见插槽主体，插入前显示暗色电源模块轮廓。 |
| 未来侧过载电容机柜 | `PNG/Machine 1.png` | `assets/phase_lag/environment/props/ganamoda/machine_1.png` | 原图 `44x107`；成对用于 Ch2 R2 过载站主体，scene 内冷色改色。 |
| 过去侧护甲馈电机 | `PNG/Machine 3.png` | `assets/phase_lag/environment/props/ganamoda/machine_3.png` | 原图 `69x78`；用于 Ch2 R2 护甲馈电站主体，scene 内暖色改色。 |
| 气闸控制台 | `PNG/Wall electric pannel 1.png` | `assets/phase_lag/environment/props/airlock_control_panel.png` | 原图 `47x45`；作为独立启动设施主体。 |
| 气闸与复位开关阵列 | `PNG/Small machine 3-1.png` | `assets/phase_lag/environment/props/airlock_switch_array.png` | 原图 `33x34`；叠在控制台和房间复位终端上提供明确的物理开关读形，替换粗白几何杆。 |
| 未来侧加固门 | `PNG/Door 2.png`, `PNG/Open Door.png` | `assets/phase_lag/environment/doors/future_closed.png`, `future_open.png` | 使用同包完整关闭/打开图；门板从原图中央裁出后向上收起，不再叠加手画护栏或霓虹框。 |
| 过去侧旧式门 | `PNG/door.png`, `PNG/Open Door 2.png` | `assets/phase_lag/environment/doors/past_closed.png`, `past_open.png` | 使用同包旧式门体和开门框；不再叠加手画裂纹、烧焦 Polygon 或破损 Line2D。 |

## 角色

| 角色 | 来源 | 作者 | 许可证 | 原文件 | 导入路径 | 处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 陆衡 | [Sideview Sci-Fi - Patreon Collection](https://opengameart.org/content/sideview-sci-fi-patreon-collection) 中的 `Cyberpunk Detective` | ansimuz | CC0 | `Sprites/cyberpunk-detective/PNG/spritesheets/{walk,draw-gun,punch,death}.png` | `assets/phase_lag/characters/lu_heng/*.png` | 保留原帧；`5x` 显示并映射实体管线、受击、倒地等稳定动画名。 |
| 星遥 | [Huntress](https://luizmelo.itch.io/huntress) | LuizMelo | CC0（包内 `License.txt`） | `Sprites/{Idle,Run,Jump,Fall,Attack1,Attack2,Attack3,Take hit,Death}.png` | `assets/phase_lag/characters/xing_yao/*.png` | 保留 `150×150` 帧；`2.5x` 显示并映射完整战斗动画别名。 |

## 已停用的早期敌人占位

以下文件目前不再被敌人场景引用，保留仅用于后续明确清理，不作为现行美术来源。

| 旧用途 | 来源 | 作者 | 许可证 | 原文件 | 仓库路径 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 相位寄生体 | [Super Dead Gunner: FleaBot Enemy](https://opengameart.org/content/super-dead-gunner-fleabot-enemy) | Emcee Flesher | OGA-BY 3.0（本地下载报告） | `fleabot-sheet-alpha_2.png` | `assets/phase_lag/enemies/fleabot_sheet.png` | 已由 Ansimuz 地行异形替换。 |
| 无人机 | [Pixel Art Drone](https://opengameart.org/content/pixel-art-drone) | RUOK | CC0 | `drone_3.png` | `assets/phase_lag/enemies/drone_idle_a.png`, `drone_idle_b.png` | 已由 Ansimuz 舰载无人机替换。 |

## Kenney UI 与 SFX

| 用途 | 来源 | 作者 | 许可证 | 原文件 | 导入路径 | 处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 设置面板 | [UI Pack - Sci-Fi](https://kenney.nl/assets/ui-pack-sci-fi) | Kenney | CC0 | `PNG/Blue/Default/button_square_header_notch_rectangle.png` | `assets/phase_lag/ui/kenney/settings_panel.png` | 作为 authored `NinePatchRect`。 |
| UI 选择 | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | `select_006.ogg` | `assets/phase_lag/audio/sfx/ui_select.ogg` | 菜单 hover、实体管线交互确认。 |
| 菜单确认 | 同上 | Kenney | CC0 | `confirmation_001.ogg` | `assets/phase_lag/audio/sfx/ui_confirm_menu.ogg` | 全局菜单确认。 |
| 局内确认 | 同上 | Kenney | CC0 | `confirmation_003.ogg` | `assets/phase_lag/audio/sfx/ui_confirm_ingame.ogg` | 局内确认。 |
| UI 返回 | 同上 | Kenney | CC0 | `back_001.ogg` | `assets/phase_lag/audio/sfx/ui_cancel.ogg` | 菜单/设置返回。 |
| Dialogue 打字音 | 同上 | Kenney | CC0 | `click_002.ogg`–`click_005.ogg` | `assets/phase_lag/audio/sfx/dialogue_blip_1.ogg`–`dialogue_blip_4.ogg` | 重命名；authored `AudioStreamRandomizer` 随机播放，跳过空白与大部分标点。 |
| 电路旋转 | 同上 | Kenney | CC0 | `switch_003.ogg` | `assets/phase_lag/audio/sfx/circuit_rotate.ogg` | 实体管线模块旋转。 |
| 双脚步 | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 | `footstep00.ogg`, `footstep03.ogg` | `assets/phase_lag/audio/sfx/footstep_a.ogg`, `footstep_b.ogg` | 玩家移动时交替播放。 |
| 刀刃挥砍 | 同上 | Kenney | CC0 | `knifeSlice2.ogg` | `assets/phase_lag/audio/sfx/blade_slash.ogg` | 星遥攻击反馈。 |
| 电路拿取 | 同上 | Kenney | CC0 | `metalClick.ogg` | `assets/phase_lag/audio/sfx/circuit_pickup.ogg` | 从实体插槽拿起模块。 |
| 电路放置 | 同上 | Kenney | CC0 | `metalLatch.ogg` | `assets/phase_lag/audio/sfx/circuit_place.ogg` | 将模块插入实体插槽。 |
| 终端底噪 | [Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | Kenney | CC0 | `computerNoise_000.ogg` | `assets/phase_lag/audio/sfx/computer_noise.ogg` | 重命名。 |
| 门开 | 同上 | Kenney | CC0 | `doorOpen_000.ogg` | `assets/phase_lag/audio/sfx/door_open.ogg` | 重命名。 |
| 门关/复位 | 同上 | Kenney | CC0 | `doorClose_000.ogg` | `assets/phase_lag/audio/sfx/door_close.ogg` | 重命名。 |
| 爆炸 | 同上 | Kenney | CC0 | `explosionCrunch_000.ogg` | `assets/phase_lag/audio/sfx/explosion_crunch.ogg` | 重命名。 |
| 护盾/供能 | 同上 | Kenney | CC0 | `forceField_000.ogg` | `assets/phase_lag/audio/sfx/force_field.ogg` | 重命名。 |
| 金属命中 | 同上 | Kenney | CC0 | `impactMetal_000.ogg` | `assets/phase_lag/audio/sfx/impact_metal.ogg` | 重命名。 |
| 激光/脉冲 | 同上 | Kenney | CC0 | `laserSmall_000.ogg` | `assets/phase_lag/audio/sfx/laser_small.ogg` | 重命名。 |
| 相位发送提示 | 同上 | Kenney | CC0 | `forceField_001.ogg` | `assets/phase_lag/audio/sfx/phase_send.ogg` | 作为远端事件入队时的低音量过渡提示。 |
| 相位抵达提示 | 同上 | Kenney | CC0 | `forceField_003.ogg` | `assets/phase_lag/audio/sfx/phase_arrival.ogg` | 作为远端事件真正生效时的成对确认音。 |
| Boss 拆甲 | 同上 | Kenney | CC0 | `impactMetal_003.ogg` | `assets/phase_lag/audio/sfx/boss_armor_break.ogg` | 绑定每片甲板的延迟拆除时刻。 |
| Boss 磁夹闭合 | 同上 | Kenney | CC0 | `doorClose_002.ogg` | `assets/phase_lag/audio/sfx/boss_magnetic_clamp.ogg` | 只在正确磁夹抵达并闭合时播放。 |
| Boss 核心开启 | 同上 | Kenney | CC0 | `laserLarge_004.ogg` | `assets/phase_lag/audio/sfx/boss_core_open.ogg` | 绑定最终核心首次暴露。 |
| Boss 死亡 | 同上 | Kenney | CC0 | `lowFrequency_explosion_001.ogg` | `assets/phase_lag/audio/sfx/boss_defeat.ogg` | 低频过渡音；最终版本仍需专用相位猎手死亡设计。 |
| 玩家闪避推进 | 同上 | Kenney | CC0 | `thrusterFire_002.ogg` | `assets/phase_lag/audio/sfx/player_dash.ogg` | 陆衡、星遥闪避共用。 |
| 无人机引擎 | 同上 | Kenney | CC0 | `engineCircular_002.ogg` | `assets/phase_lag/audio/sfx/drone_engine.ogg` | 无人机存活时循环播放，死亡即停。 |
| 寄生体移动 | 同上 | Kenney | CC0 | `slime_001.ogg` | `assets/phase_lag/audio/sfx/parasite_move.ogg` | 只在爬行、预警和跃迁状态播放。 |

## 音乐与环境音

| 用途 | 来源 | 作者 | 许可证 | 原文件 | 导入路径 | 处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 菜单音乐 | [Tragic ambient main menu](https://opengameart.org/content/tragic-ambient-main-menu) | HaelDB | CC0（页面同时提供 OGA-BY 3.0） | `ambientmain_0.ogg` | `assets/phase_lag/audio/music/tragic_ambient_main_menu.ogg` | 保留 `0.504–96.117s`，裁首尾长静音；import `loop=true`。 |
| 解谜音乐 | [Life in corrupted binary](https://opengameart.org/content/life-corrupted-binary) | HaelDB | CC0（页面同时提供 OGA-BY 3.0） | `life_in_corrupted_binary.flac` | `assets/phase_lag/audio/music/life_in_corrupted_binary.ogg` | 转为 OGG Vorbis quality 6；保留 `0–228.397s`；import `loop=true`。 |
| 冷区音乐 | [Menacing Otherworld](https://opengameart.org/content/menacing-otherworld) | Ruskerdax | CC0 | `ruskerdax_-_menacing_otherworld.mp3` | `assets/phase_lag/audio/music/menacing_otherworld.mp3` | 保留 `0–242.390s`，裁尾部长静音；import `loop=true`。 |
| 战斗音乐 | [Open Warfare](https://opengameart.org/content/open-warfare) | Ruskerdax | CC0 | `ruskerdax_-_open_warfare.mp3` | `assets/phase_lag/audio/music/open_warfare.mp3` | 保留 `0–114.015s`，裁尾部长静音；import `loop=true`。 |
| 工厂环境音 | [Factory ambiance](https://opengameart.org/content/factory-ambiance) | yd | CC0 | `Factory.ogg` | `assets/phase_lag/audio/ambience/factory.ogg` | 重命名；import `loop=true`。 |

## 项目内资源

- `assets/phase_lag/ui/*.svg`：项目 authored 控件状态图，不来自第三方包。
- 两名主角和四类敌人当前都是过渡素材；最终自绘替换时遵循 `docs/phase-lag-character-art-requirements.md`，继续复用现有动画与判定合同。

## 已验证但未导入的角色与敌人候选

以下素材已通过 OpenGameArt 页面和下载文件验证，但视觉或动画合同不合格，因此没有复制进仓库：

| 候选 | 许可证 | 可取之处 | 未导入原因 |
| --- | --- | --- | --- |
| [Space War Man](https://opengameart.org/content/space-war-man-platform-shmup-set) | OGA-BY 3.0 | 横版科幻、动作量较大 | 约 `34px` 高的全甲小人，仍会读成机器人，且以射击为核心。 |
| [Tasen soldiers](https://opengameart.org/content/tasen-soldiers-for-mugen-mk-style-male-and-female) | CC0 | 同画风男女、动作量大 | 巨型异形士兵与预渲染风格，不是项目所需的人类像素主角。 |
| [2D female and male bone-based sprites](https://opengameart.org/content/2d-female-and-male-bone-based-sprites) | CC0 | 男女拆件完整 | 只有骨骼拼装零件，没有可直接接入的横版动画。 |
| [Male Female Characters Split](https://opengameart.org/content/male-female-characters-split) | CC0 | 可作为人体比例底稿 | 仍需重画服装、武器和全部动作，不能冒充完成素材。 |
| [Female Character Sidescrolling / Fiona](https://opengameart.org/content/female-character-sidescrolling) | CC-BY-SA 4.0 | 成年女性横版像素轮廓 | 只有观察和行走，原图极小；没有星遥的刀战、受击、倒地和防御动作，也没有同风格男主。 |
| [Male Sci-Fi Character](https://opengameart.org/content/male-sci-fi-character) | CC-BY 3.0 | 成年男性与机械手概念 | 是未绑定的高面数 3D 模型和渲染图，不是可接入的 2D 横版动画。 |
| [Scavenger Character Sprites](https://opengameart.org/content/scavenger-character-sprites) | CC-BY 3.0 | 有多角度女性角色与武器动作 | 俯视/等距预渲染、透明边缘与像素密度都不匹配横版场景，且没有对应男主。 |
| [Sci-Fi Brawler Character](https://opengameart.org/content/sci-fi-brawler-character) | OGA-BY 3.0 | 动作数量较多、使用受限色板 | 低分辨率绿头异形格斗者，不是人类主角，也无法与现有场景比例和角色职责对齐。 |
| [Little Angry Robot Drone](https://opengameart.org/content/little-angry-robot-drone) | GPL 2.0 | 红/绿状态清楚 | 是极小的可爱圆顶图标，仅有待机状态；没有追踪、预警、俯冲、射击、受击和死亡动画，视觉也过于吉祥物化。 |
| [Dregfly](https://opengameart.org/content/super-dead-gunner-dregfly) | OGA-BY 3.0 | 飞行、展开、射击、搬运动画齐全 | `40×30px` 骷髅飞虫过于抽象，像素密度和现有背景不一致。 |
| [small animated alien creature. 64x64](https://opengameart.org/content/small-animated-alien-creature-64x64) | CC-BY-SA 3.0 | 横版持枪异形轮廓清楚 | 动作不足，且不匹配寄生体、无人机或重装守卫的玩法职责。 |
| [Robot Enemy Pack](https://opengameart.org/content/robot-enemy-pack) | CC0 | 五类机器人、六组动画 | 3D 模型与骨骼资源，不是当前 2D 像素管线可直接使用的素材。 |

候选下载和报告保留在仓库外 `D:\AIworkspace\scratch\downloads\phase_lag_verified\`，只用于筛选，不随游戏发布。
