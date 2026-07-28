# 《迟相 / Phase Lag》主角与敌人美术交付清单

本文档是陆衡、星遥及四类敌人最终素材的实际交付清单。完整环境色板、镜头和替换流程见 `docs/phase-lag-art-spec.md`。

## 1. 当前状态

- 当前陆衡的 Ansimuz `Cyberpunk Detective` 和星遥的 LuizMelo `Huntress` 都只是可替换过渡素材。
- 它们只用于验证碰撞、移动、实体管线和战斗时序，不是最终角色设计。
- 当前地行异形、舰载无人机、设施守卫和相位猎手也只是同一 Ansimuz 包内的统一风格过渡素材，不是最终怪物设计。
- 最终版本必须是清楚的成年男女主角，不能再画成小机器人、Q 版吉祥物或两套互不相干的素材。
- 两人要像来自同一设施、同一组织，但分别处于未来事故后与过去事故中的不同年代。
- 最终敌人必须服务于攻击预警和延迟因果玩法，不能只换一张静态图后继续依赖夸张光圈解释行为。

## 2. 一眼必须读出的角色差异

### 陆衡

- 身份：未来侧设施检修/因果工程人员。
- 轮廓：身形收束、站姿克制、重心略后；外套、工具带或肩部检修结构形成纵向轮廓。
- 核心道具：磁束检修枪，必须和普通手枪区分；枪口有稳定的冷青发光块。
- 配色：深蓝灰、冷青、低饱和灰绿，脸和手保留暖色，避免整个人融入未来侧冷背景。
- 性格动作：谨慎、精确、先观察再操作；`idle` 不能像拔枪帧定格。

### 星遥

- 身份：过去侧事故现场的救援/安保人员。
- 轮廓：动作前倾、重心积极；长刀形成大而明确的对角线。
- 核心道具：工业救援长刀或热切割刃，厚背、有机械结构，不能画成细剑或纯奇幻武器。
- 配色：焦橙、暗红、暖灰，内部使用深色块和事故背景分离。
- 性格动作：果断、直接、带保护欲；攻击不能出现脚底跳位、人物瞬移或刀光与命中区错拍。

### 共同识别物

- 两人制服上保留同一个设施徽记、编号条或双菱形相位标识。
- 未来侧版本更旧、更修补、更个人化；过去侧版本更完整但有现场烧蚀和警报反光。
- 默认都朝右绘制，左向由 Godot `flip_h` 完成。

## 3. 尺寸与锚点

- 游戏内可见的头顶到鞋底高度目标为 `160–180px`，允许范围 `150–190px`。
- 当前玩家碰撞保持约 `110×180px`，不能为了迁就画面移动或缩小碰撞体。
- 推荐原生角色身体高度 `80–90px`，在 Godot 中以整数 `2x` 显示；不要依赖 `2.5x`、`5x` 等非统一倍率补救过小素材。
- 推荐普通动作单帧画布 `128×128px`；星遥的大范围攻击可使用 `192×160px` 或 `192×192px`。
- 同一动画的每一帧画布尺寸必须一致，脚底基线必须落在同一像素行。
- 可见脚底要和玩家原点保持稳定；最终通过 `PhaseCharacterVisualConfig.sprite_offset` 微调，不能逐动画移动 Sprite 节点。
- 头发、外套和武器可以越出碰撞包络，但身体躯干不能在动画中横向漂移。
- 透明留白要克制。角色实际可见高度不得少于单帧画布高度的 `60%`。

## 4. 动画交付

### 通用动画

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `idle` | 4 | 稳定呼吸循环，脚底不动，不能使用攻击准备帧冒充。 |
| `run` | 6 | 完整接触、下沉、经过、抬腿节奏；两人步态不同。 |
| `jump` | 3 | 起跳压缩、离地、上升姿势。 |
| `fall` | 2 | 下落与落地准备，不能和起跳完全相同。 |
| `dash` | 4 | `0.16s` 位移段清楚，整体动画约 `0.22s`。 |
| `hurt` | 3 | 清楚显示受击方向，脚底只允许很小位移。 |
| `collapse` | 5 | 倒地后有稳定终帧，不和敌人尸体混淆。 |
| `revive` | 5 | 从倒地终帧连贯恢复。 |
| `defend` | 3 | 能解释单人模式下未操控角色的自动防御。 |

### 陆衡专属动画

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `aim` | 4 | 抬起磁束枪并锁定目标，枪口方向稳定。 |
| `grab` | 4 | 磁束建立、受力、确认三个阶段；当前操作窗口约 `0.18s`。 |
| `rotate` | 4 | 枪口或手腕产生明确的 `90°` 旋转动作，不能只换一帧文字提示。 |

`primary`、`secondary`、`dodge` 可以在资源中复用以上动作，但动画名仍必须存在。

### 星遥专属动画

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `slash_1` | 7 | 快速横斩；和第一段移动方向一致。 |
| `slash_2` | 7 | 改变高度或斩击方向，不能只是第一段换色。 |
| `slash_3` | 8 | 明确的终结动作、击退感和后摇。 |
| `charge` | 4 | 可循环；前 `0.18s` 必须读得出反击架势。 |
| `heavy` | 8 | 释放后 `0.16s` 有效、约 `0.24s` 恢复，视觉重心稳定。 |
| `counter` | 7 | 格挡转反击，一眼区别于 `heavy`。 |
| `air_slash` | 5 | 总时长约 `0.28s`，水平追击动作。 |
| `dive` | 6 | 总时长约 `0.28s`，向下砸落并保留落地冲击姿势。 |

`primary`、`secondary`、`dodge` 也必须存在，可分别映射到 `slash_1`、`heavy` 和 `dash`。

## 5. 星遥攻击有效帧

当前战斗逻辑以固定时间窗驱动，美术必须按这个节奏绘制：

| 动作 | 启动 | 有效 | 恢复 | 画面要求 |
| --- | ---: | ---: | ---: | --- |
| `slash_1–3` | `0.16s` | `0.12s` | `0.08s` | 刀刃真正穿过目标的中间帧必须落在有效段。 |
| `heavy` | 玩家蓄力 | `0.16s` | `0.24s` | 蓄力循环和释放动画分开；释放首帧不能提前命中。 |
| `counter` | 最长 `0.18s` 判定窗 | `0.14s` | `0.24s` | 格挡成立后再进入反击有效帧。 |
| `air_slash` | — | `0.28s` | — | 视觉刀路覆盖前方命中区。 |
| `dive` | — | `0.28s` | — | 刀路与向下动作一致，不能横向挥砍却向下判定。 |

- 斩击轨迹、命中火花和落地冲击应作为独立 VFX，不烘焙进所有角色帧。
- 星遥当前攻击区约 `280×190px`，中心位于角色前方约 `145px`；最终贴图的主刀路要覆盖这个方向，但不要用巨大空白画布伪造范围。
- 三段普攻必须拥有不同的起手和收势，让玩家能凭动作判断连段位置。

## 6. 文件与导入格式

- 交付格式：透明背景 `PNG RGBA`；可同时保留 `.aseprite`、调色板和分层源文件。
- Sprite strip 默认横向排列，帧顺序从左到右。
- 推荐命名：`lu_heng/idle.png`、`lu_heng/grab.png`、`xing_yao/slash_1.png`。
- 每个 strip 记录单帧宽高、帧率和脚底基线；不要只交一张没有切帧说明的大图。
- Godot 导入必须使用 nearest filtering，关闭 mipmap，禁止线性缩放和有损 JPG。
- 不需要制作左向整套动画；需要独立方向细节时，单独标明不能镜像的徽记或文字。
- 不把磁束、斩击光、受击火花和全屏闪光永久画进角色本体。

## 7. 验收清单

- [ ] 在 `1920×1080` 下，两人的可见身高均处于 `150–190px`。
- [ ] 在 `1280×720` 的 `1:1` 分屏下，仍能认出脸部朝向、磁束枪、长刀和当前动作。
- [ ] 两人脚底在 `idle`、`run`、攻击、受击和倒地之间没有跳位。
- [ ] 陆衡 `idle` 是呼吸循环，不是单张拔枪帧。
- [ ] 星遥三段普攻的刀路、声音和有效帧同步。
- [ ] 角色轮廓不依赖大面积发光环才能从背景中读出。
- [ ] 不改变玩家碰撞、出生点、门和机关坐标来迁就新贴图。
- [ ] 两人看起来属于同一个世界，也能一眼看出不同年代和职责。

## 8. 敌人与 Boss 交付规格

### 共通规则

- 四类敌人必须共享同一像素密度、轮廓粗细、暗部处理和金属高光方向。
- 每类敌人都要有独立轮廓：寄生体贴地、无人机横向悬浮、守卫直立厚重、Boss 宽体低重心；缩成纯黑剪影仍能区分。
- 普通敌人在 `1280×720` 的 `1:1` 分屏里仍要读得出朝向、预警、攻击和受击状态。
- 地面单位统一使用脚底中心锚点；飞行单位使用机体质心锚点。所有帧不得因为透明留白变化而跳位。
- 角色本体、武器、可拆甲片和永久残骸要分层交付；警告圈、子弹、刀光、爆炸和命中火花作为独立 VFX。
- 不把碰撞形状画进贴图，也不能用巨大空白画布暗示攻击距离。

### 相位寄生体

- 定位：过去事故产生的贴地生物/机械寄生体，负责爬行、附着和清楚的跳扑预警。
- 游戏内可见尺寸目标：宽 `130–180px`、高 `80–120px`。
- 推荐单帧画布：`96×64px`，Godot 中整数 `2x` 显示。
- 锚点：脚部/腹部接地点中心；跳跃全过程保持身体质心连续。

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `idle` | 4 | 触须或外壳轻微呼吸，不得像死亡帧。 |
| `crawl` | 6 | 清楚显示抓地与推进方向。 |
| `warn` | 4 | 原地收缩、蓄力，必须在 `0.45s` 预警内读清。 |
| `leap` | 5 | 起跳、腾空、扑击、回弹四段明确。 |
| `attach` | 4 | 能看出正在夹住设备或角色，而不是悬空。 |
| `hurt` | 3 | 外壳受击方向清楚。 |
| `death` | 6 | 收缩或碎裂，终帧不再像活体。 |

### 舰载无人机

- 定位：设施自动安保飞行器；视觉上必须是机器，不与寄生体或 Boss 小型分身混淆。
- 游戏内可见尺寸目标：宽 `150–210px`、高 `90–140px`。
- 推荐单帧画布：`128×96px`，Godot 中整数 `2x` 显示。
- 锚点：机体质心；喷口、机翼和武器可以越出碰撞圆，但不能造成质心漂移。

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `hover` | 6 | 推进器或悬浮机构循环，机体上下位移由代码处理。 |
| `track` | 4 | 炮口或传感器明确朝向玩家。 |
| `warn` | 4 | `0.38s` 内从稳定悬停转入蓄冲，不能只靠外部方框。 |
| `dash` | 4 | 前冲姿态收束，轮廓朝攻击方向拉长。 |
| `shoot` | 5 | 若后续启用射击，枪口闪光独立交付。 |
| `hurt` | 3 | 失稳角度清楚但质心不瞬移。 |
| `death` | 7 | 失控、破裂、爆炸前姿态；爆炸本身独立。 |

### 设施守卫

- 定位：未来加固后的直立安保机，负责巡逻、预警、冲锋、近战和留下可压住压力板的残骸。
- 游戏内可见高度目标：`170–220px`；宽度目标 `120–170px`。
- 推荐单帧画布：`128×128px` 或 `160×128px`。
- 锚点：双脚中心；死亡终帧的残骸接地点必须稳定，不能改变压力板解谜位置。

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `idle` | 4 | 装甲待机与传感器扫描。 |
| `walk` | 6 | 重型步态，和寄生体爬行速度感区分。 |
| `alert` | 4 | 抬头、锁定或武器上电。 |
| `charge` | 6 | 冲锋准备和推进阶段分开。 |
| `attack` | 7 | 命中有效帧和当前近战区同步。 |
| `armor_break` | 5 | `4s` 破甲窗口一眼可见，不只换颜色。 |
| `stagger` | 4 | 清楚的硬直与恢复。 |
| `death` | 7 | 倒下并进入稳定残骸终帧。 |
| `corpse` | 1 | 单独导出的永久残骸，不带呼吸或闪烁。 |

### 相位猎手 Boss

- 定位：过去事故的直接制造者；不是普通坦克放大版，要体现时空扰乱、可拆甲片、磁夹控制和核心暴露。
- 游戏内可见尺寸目标：宽 `300–420px`、高 `180–280px`。
- 推荐单帧画布：`256×192px` 或 `320×224px`。
- 锚点：履带/足部接地中心；主体、三块甲片、磁夹受力点、双色核心必须分层。

| 动画名 | 最低帧数 | 交付要求 |
| --- | ---: | --- |
| `idle` | 6 | 核心和机械结构有低频循环。 |
| `move` | 8 | 重量感明确，不能像普通敌人平移。 |
| `attack_a` | 8 | 第一阶段主攻击，预警和发射分离。 |
| `attack_b` | 8 | 过去侧引位攻击，方向明确。 |
| `clamp_stun` | 6 | 被磁夹控制后有稳定受力姿态。 |
| `armor_break_1–3` | 每段 5 | 每块甲片独立脱落，主体锚点不变。 |
| `core_open` | 7 | 核心窗口从封闭到完全暴露。 |
| `death` | 12 | 三阶段终结演出，可拆件与主体按既定顺序失效。 |

### 敌人验收

- [ ] 不显示外部预警图形时，仅凭动作仍能判断即将发生的攻击。
- [ ] 寄生体、无人机、守卫和 Boss 的轮廓、色块和运动节奏完全不同。
- [ ] 守卫死亡残骸可稳定压住 Ch2 R3 / Ch3 R2 的压力板。
- [ ] Boss 三块甲片、磁夹状态和核心窗口在分屏中仍可读。
- [ ] 受击、死亡和远端延迟崩解不会让 Sprite 原点跳出碰撞体。
- [ ] 新素材可直接替换现有 authored Sprite/AnimatedSprite，不改关卡坐标和战斗判定。

## 9. 本轮公开素材筛选结论

- OpenGameArt `80x64 Male and Female Sprites Character Template`：CC0，成年男女风格统一，适合作为造型和比例参考；只有 idle、walk、fire 等少量动作，无法覆盖星遥近战与完整受击/倒地流程，因此未导入。
- OpenGameArt `Platform Shmup Hero: Warpgal`：CC0 分支可用，科幻动作较完整，但只有单一女性射击角色，轮廓和玩法职责都不匹配，因此未导入。
- OpenGameArt `3 Cyberpunk Characters`：男女同风格且有攻击、攀爬、死亡动作，但为 OGA-BY 3.0，视觉偏卡通小人，仍不符合最终主角方向，因此未导入。
- OpenGameArt `Residents of the City Pixel Art Sprite sheets`：角色数量多，但偏市民 NPC、动作不足且为 OGA-BY 3.0，因此未导入。
- OpenGameArt [`Space Sara!`](https://opengameart.org/content/space-sara)：OGA-BY 3.0，科幻女性轮廓和移动动画明显优于现过渡素材，但以射击为核心、没有星遥所需的长刀连段，因此仅作为比例和头发动态参考。
- OpenGameArt [`Space Police Hero`](https://opengameart.org/content/space-police-hero)：CC-BY 4.0 / OGA-BY 4.0，男角色移动和八向射击完整，但重甲头盔仍会读成小机器人，也缺少陆衡的磁束操作动作，因此未导入。
- OpenGameArt [`2D Game Character Pack - Slim Version`](https://opengameart.org/content/2d-game-character-pack-slim-version)：CC0、动作量大，但整体为 Q 版大头和面罩造型，男女辨识与项目气质都不合格，因此未导入。
- OpenGameArt [`Space War Man: platform shmup set`](https://opengameart.org/content/space-war-man-platform-shmup-set) 与 [`Platform Shmup Hero: Warpgal`](https://opengameart.org/content/platform-shmup-hero-warpgal)：同属低分辨率横版科幻射击方向，但角色高度只有约 `34px`，两人都被全覆盖装甲和头盔包住，放大后仍会读成小机器人；动作也围绕射击而不是磁束检修和长刀，因此未导入。
- OpenGameArt [`Tasen soldiers for Mugen, MK style`](https://opengameart.org/content/tasen-soldiers-for-mugen-mk-style-male-and-female)：CC0，确实提供同画风男女和大量动作，但设定是巨型异形士兵，采用 `Mortal Kombat` 式预渲染，像素密度、轮廓和现有场景完全不匹配，因此只证明“成对素材”本身仍不足以满足项目要求。
- OpenGameArt [`2D female and male bone-based sprites`](https://opengameart.org/content/2d-female-and-male-bone-based-sprites) 与 [`Male Female Characters Split`](https://opengameart.org/content/male-female-characters-split)：CC0，提供男女拆件和骨骼拼装基础，但不是完成角色，也没有本项目需要的横版动画。若使用它们仍需重新设计服装、武器、轮廓和全部动画，工作量等同自绘，因此仅可作人体比例参考。
- OpenGameArt [`Space soldiers / characters`](https://opengameart.org/content/space-soldiers-characters)：CC-BY 3.0，只提供骨骼动画拆件，角色仍偏全甲士兵，没有陆衡和星遥的身份差异，未导入。
- OpenGameArt [`Female Character Sidescrolling / Fiona`](https://opengameart.org/content/female-character-sidescrolling)：CC-BY-SA 4.0，成年女性横版轮廓比小机器人清楚，但只有观察和行走，原图极小；没有长刀、受击、倒地、防御和对应男主，因此未导入。
- OpenGameArt [`Male Sci-Fi Character`](https://opengameart.org/content/male-sci-fi-character)：CC-BY 3.0，机械手概念可参考陆衡工具义肢，但资源是未绑定高面数 3D 模型和渲染图，不属于当前 2D 像素管线。
- OpenGameArt [`Scavenger Character Sprites`](https://opengameart.org/content/scavenger-character-sprites)：CC-BY 3.0，有多角度女性角色与武器动作，但采用俯视/等距预渲染，透明边缘、锚点和像素密度都无法与横版 Ansimuz 环境一致。
- OpenGameArt [`Sci-Fi Brawler Character`](https://opengameart.org/content/sci-fi-brawler-character)：OGA-BY 3.0，动作量较多，但本体是低分辨率绿头异形格斗者，既不是人类主角，也不能承担陆衡或星遥的身份与装备差异。
- OpenGameArt [`Super Dead Gunner: Dregfly`](https://opengameart.org/content/super-dead-gunner-dregfly)：OGA-BY 3.0，拥有悬浮、展开、射击和搬运动画，轮廓比普通飞船更像独立敌人；但单帧仅约 `40×30px`，骷髅飞虫造型会让无人机更抽象，并与 Ansimuz 场景产生明显像素密度冲突，因此未替换当前过渡无人机。
- OpenGameArt [`small animated alien creature. 64x64`](https://opengameart.org/content/small-animated-alien-creature-64x64)：CC-BY-SA 3.0，横版轮廓清楚，但本质是持枪人形异形且动作很少，无法承担贴地寄生、飞行无人机或重装守卫中的任何一个完整合同，因此未导入。
- OpenGameArt [`Robot Enemy Pack`](https://opengameart.org/content/robot-enemy-pack)：CC0，五类机器人和动画量充足，但为 3D 模型与骨骼资源，不是可直接接入的像素横版素材，未导入。
- OpenGameArt [`Little Angry Robot Drone`](https://opengameart.org/content/little-angry-robot-drone)：GPL 2.0，红/绿状态一眼可见，但本质是极小的可爱圆顶图标，只提供待机变化；没有追踪、预警、俯冲、攻击、受击和死亡，视觉也会重新落回机器人吉祥物问题。
- itch.io `Static Modular Sci-Fi Courier`、`17 sci-fi characters`、`Static Pixel Character`：均为静态图或禁止把原始素材随仓库再分发，无法作为本项目可提交的角色素材。
- `FREE - 2D Pixel Art Male and Female Character`：造型统一，可作风格参考；许可证不允许把原始素材作为公开源码仓库内容再次分发，因此不能导入。

结论：当前没有找到同时满足“成年男女同风格、横版科幻、完整近战/工具动画、允许随公开仓库再分发、明显优于现占位”的现成组合。现有两名主角只允许作为开发过渡，不得作为最终发布美术。当前四类敌人已经使用互不相同的地行异形、舰载机、双足守卫和坦克过渡图，解决了早期所有敌人共用同一贴图的问题，但它们仍不是最终设计；最终主角与四类敌人应按本清单自绘或委托定制。

## 10. 自绘交付包结构

每个角色或敌人独立一个目录，源文件、导出图和说明不能混在同一张无法追踪的大图里。推荐交付结构：

```text
phase_lag_art/
  palette/
    phase_lag_master_palette.aseprite
    phase_lag_master_palette.png
  lu_heng/
    source/lu_heng.aseprite
    export/idle.png
    export/run.png
    export/jump.png
    export/fall.png
    export/dash.png
    export/aim.png
    export/grab.png
    export/rotate.png
    export/hurt.png
    export/collapse.png
    export/revive.png
    export/defend.png
    manifest.md
  xing_yao/
    source/xing_yao.aseprite
    export/idle.png
    export/run.png
    export/jump.png
    export/fall.png
    export/dash.png
    export/slash_1.png
    export/slash_2.png
    export/slash_3.png
    export/charge.png
    export/heavy.png
    export/counter.png
    export/air_slash.png
    export/dive.png
    export/hurt.png
    export/collapse.png
    export/revive.png
    export/defend.png
    manifest.md
  parasite/
  drone/
  guard/
  phase_hunter/
```

每个 `manifest.md` 必须记录：

- 单帧宽高、总帧数、播放 FPS、是否循环。
- 脚底基线或飞行单位质心坐标。
- 启动帧、有效帧、恢复帧；敌人同时标明预警结束帧。
- 武器、甲片、残骸、刀光、枪口光是否为独立层或独立文件。
- 不能镜像的文字、徽记、机械结构和受伤方向。

## 11. 色板、轮廓与年代差异

- 使用一套共享主色板，建议角色本体不超过 `24–32` 个有效颜色；特效色单独管理。
- 陆衡和星遥的肤色、设施徽记、金属暗部和高光方向一致，证明两人属于同一世界。
- 未来侧使用更冷、更旧、更修补的材质；过去侧使用更暖、更完整但受事故警报照明影响的材质。
- 年代差异依靠服装结构、磨损和色温表达，不靠随意加发光线、外框、裂纹贴纸或几何装饰。
- 缩成纯黑剪影时，陆衡的工具枪、星遥的长刀、寄生体的贴地轮廓、无人机的横向机身、守卫的直立重甲和 Boss 的宽体低重心仍必须互不混淆。
- 角色脸部、武器和攻击方向在 `1280×720` 的 `1:1` 分屏中仍需可读；不能依赖全屏光效弥补本体辨识度。

## 12. 分批制作与接入顺序

为了避免画完整套后才发现比例或锚点不合适，按以下顺序交付：

1. **轮廓样张**：两名主角和四类敌人各一张默认站姿/待机帧，放进 Ch1、Ch2 和 Boss 场验证尺寸、色温和背景分离。
2. **移动样张**：陆衡与星遥的 `idle/run/jump/fall`，寄生体 `crawl`，无人机 `hover`，守卫 `walk`，Boss `idle/move`。
3. **核心玩法动作**：陆衡 `grab/rotate`，星遥 `slash_1/heavy/counter`，三类普通敌人的 `warn/attack/hurt/death`。
4. **完整合同**：补齐本文件列出的其余动画、残骸、可拆甲片和独立 VFX。
5. **最终接入**：只替换 `SpriteFrames`、纹理和 `sprite_offset`；未经专门复核不得改玩家碰撞、敌人攻击区、门位置或谜题坐标。

每一批都需要通过以下最低检查后再继续：

- [ ] 默认站姿没有机器人/Q 版吉祥物观感。
- [ ] 两名主角看起来是清楚的成年男女，并属于同一美术体系。
- [ ] 脚底或质心在所有已交付帧中稳定。
- [ ] 角色可见高度和当前约 `110×180px` 玩家碰撞相容。
- [ ] 攻击动作不靠外部警告框才能读懂方向和时机。
- [ ] 贴图没有烘焙碰撞框、键位文字、状态灯或关卡专用 UI。
- [ ] 导出 PNG 使用透明背景、nearest filtering 友好的整数像素边缘。
