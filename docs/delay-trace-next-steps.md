# 《延迟追迹》接下来做什么

## 当前可验证基线

- 新档出生在教学房，入场淡出后直接恢复操作；玩家依次接近 `World/BeforeHub/FloatText`、`FloatText2`、`FloatText3` 后，世界内手写飘字分别显示跳跃/爬墙、冲刺、下穿平台键位。首次触碰 checkpoint 才播放当前语言的黑屏红字 `跑/RUN`，红色虚影从门左侧跑到存档点；Continue 已有 checkpoint 时跳过。
- 主场景现有 22 组 authored Phantom Camera 区域：教学房 + A–U；下方 T/U 两房只补了相机，仍保持空白。
- `DelayTraceStart` 启动时只判断一次 locale，同时锁定 `present_hub.zh/en.dialogue` 与 `endings.zh/en.dialogue`，整局不再重新选择或经过 PO 二次翻译；现在房内 NPC 持续面向玩家，离开后恢复朝右。
- 四段记忆使用黑屏、红色倾斜字与 RichText2 抖动，不显示说话者；不满足条件的 Keeper 选项完全隐藏，`askname/askheart/asktime` 任一新选项可用时头顶闪烁 `!`。
- 倒计时更大、更清晰，归零只保存状态；玩家再次主动询问 Keeper 时才出现一次坦白选项，不失败、不清档。
- Continue 会恢复保存时的倒计时剩余秒数和当前 `1s/3s/5s` 延迟选择；录制 Future 时碰 Trap 只取消录像并回到锚点，不杀死真实玩家。
- 爱心数 `>= 1` 时出现一次主动问题；终点 A-D 按数量点亮，四枚后地块闪光、透明闪烁并允许落入下方。
- 下方两个房间保持空白，旧真结局路线与 KnowledgeLock 已删除；金色全屏真结局演出仍保留。
- `ProgressionShortcut`、Future 凝固结构、Past/Future 移动拖尾、全局时间尘埃和双结局粒子已接入；`low_flash_mode` 会抑制密集爆发并降低持续粒子密度。
- 触屏版已接入参考项目素材：左下虚拟摇杆、右下 `X/Y/A/B`、左上 `ESC`；显示、提示和设置页统一使用 `DisplayServer.is_touchscreen_available()`，不再依赖 `OS.has_feature("mobile")`。无触屏桌面继续使用 `WASD/J/K/L/E/ESC`。
- 当前导出 preset 已统一到 `D:\Hopes_and_Dream\ExportGame\DelayTrace\Windows\DelayTrace.exe`、`D:\Hopes_and_Dream\ExportGame\DelayTrace\Web\index.html` 与 `D:\Hopes_and_Dream\ExportGame\DelayTrace\Android\DelayTrace.apk`；旧 Windows 包曾通过启动检查，当前工作树仍需重新导出后才是发布候选。

## 自己修改这些内容

- **冲刺/跳跃音效**：打开 `Scenes/DelayTrace/Prefabs/echo_player.tscn`，修改 `DashAudio` 与 `JumpAudio` 的 `stream`。当前分别是 `phaserDown2.ogg` 和 `phaseJump2.ogg`；这里只换资源，不改 `Scripts/DelayTrace/echo_player.gd`。
- **对话打字音**：打开 `Dialogue/DelayTrace/echo_dialogue_balloon.tscn`，修改 `typing_sound` 和 `sound_interval`。真正播放由同场景继承的 `TypingSoundModule` 完成。
- **Keeper 对话与 RichText2 特效**：中文改 `Dialogue/DelayTrace/present_hub.zh.dialogue`，英文改 `Dialogue/DelayTrace/present_hub.en.dialogue`。在台词中使用 `[sway]...[]`、`[sparkle]...[]`、`[jit2]...[]`；两份文件要保持同一分支结构。
- **黑底红字记忆与开场 `Run/跑`**：布局和字体在 `Scenes/DelayTrace/UI/delay_trace_narrative_presenter.tscn` 的 `MemoryText`，当前使用项目已有的 `SmileySans-Oblique`，字号为 `88`。内容和逐句节奏在 `Scripts/DelayTrace/delay_trace_narrative_presenter.gd` 的 `MEMORY_*` 调用与 PO key 中调整。
- **两个终局文本**：中文改 `Dialogue/DelayTrace/endings.zh.dialogue`，英文改 `Dialogue/DelayTrace/endings.en.dialogue`；title 名必须保持一致。它们仍由 RichText2 全屏演出显示，不使用普通气泡。播放顺序和人物移动在 `Scripts/DelayTrace/delay_trace_narrative_presenter.gd`，演出节点和坐标在同名 `.tscn`。
- **Keeper 朝向与动画**：常驻 NPC 的朝向逻辑在 `Scripts/DelayTrace/dialogue_npc.gd`，房间绑定在 `Scripts/DelayTrace/present_room.gd`。帧序列在 `Scenes/DelayTrace/Prefabs/dialogue_npc.tscn` 的 `AnimationPlayer`；终局 Keeper 的 `idle/run` 在 `Scenes/DelayTrace/UI/delay_trace_narrative_presenter.tscn`。
- **普通结局触发**：玩家进入当前地图的 `World/Finnal/NormalExit` 后，由 `Scripts/DelayTrace/delay_trace_story.gd` 检查三条支路是否完成，再进入“玩家束缚 → Keeper 左入说话 → 右侧离开 → 身份交接 → 画面变暗 → 裂隙台词 → 普通结局与爱心提示”。不要把触发器改成新地图或新路线。
- **系统语言**：`Scripts/Save/Modules/settings_module.gd` 的 `_get_system_language()` 将中文系统 locale 映射为 `zh_CN`，其他系统映射为 `en`；已有存档中的手动语言设置优先于系统检测。

## P0：先做三次无提示试玩

找三名没看过设计文档的玩家，从新存档开始。测试者不要解释操作或谜底，只记录：

1. 玩家能否在教学房内自然看见飘字，并在 30 秒内完成跳跃和一次带方向冲刺。
2. 首次 checkpoint 的 `跑/RUN` 是否紧接玩家路线出现，红色虚影是否清楚跑到存档点，而不是像重新播放开场。
3. 第一次被 Past 抓到后，玩家能否说出“它在重走我刚才的路线”。
4. 到 Hub 时，玩家是否注意到倒计时、三条支路和 Keeper，而不会把倒计时误读成真实失败条件。
5. 每条支路首题的首次错误假设、失败次数、解开时间，以及解开后能否复述该支路的新规则。
6. 到终点时，玩家是否自然看见普通出口；全碎片玩家是否注意到 A-D 全亮、地块透明闪烁，并理解可以主动落到下方。
7. 在 `1s` 或 `5s` 支路存档后 Continue，确认倒计时与延迟不变；录制 Future 主动撞一次 Trap，确认只看到金色退场并回到 Recorder。

停止条件：若两名玩家在同一处卡住超过三分钟，下一轮只改那一处的构图、落点或反馈，不继续加谜题和说明文字。

## P1：判断关卡是否好玩

优先观察玩家是否主动做这些事：绕路骗 Past、为了未来体重录路线、看见更短路线后愿意重试。若玩家只是机械执行唯一答案，先给空间增加可比较的路线选择；若玩家理解答案却反复操作失败，放宽平台、门窗和时间裕量，不加新机制。

三条支路应保持不同节奏：`1s` 强调贴身追逐，`3s` 强调三态会合，`5s` 强调提前布置。若试玩者无法从体验区分它们，优先删掉支路内重复题，再强化各自第一题。

`docs/delay-trace-puzzle-atlas.md` 末段新增六个候选题。它们不是待办清单：先完成三次无提示试玩，每条支路只在“节奏不清楚或现有题重复”时替换或增加一个候选，绝不把六题全部塞进 Jam 版本。

## P2：剧情与本地化验收

- 分别以 `zh_CN` 和 `en` 新建存档，检查开场、Keeper 首次/返回对话、爱心与倒计时条件选项、四枚碎片和普通结局。
- 按至少两种不同顺序收集碎片，确认单片可理解且终局排序固定。
- 普通结局重点测试“玩家与 Keeper 是同一人”能否仅靠演出理解；若看不懂，先调人物位置、颜色过渡和镜头停留，不追加解释台词。
- 真结局路线暂不纳入正式试玩；先单独检查保留的金色全屏演出文本与中英文一致性。下方房间的路线由用户定案后，再测试 Future Trace 与 Lia 的信息是否能被复述。

## P3：Jam 前最后收尾

1. 试玩通过后再补记忆出现、Past 接近和 Future Trace 的声音，不新增音频系统。
2. 在 `1920x1080`、`1280x720` 和手机横屏 `640x360` 各检查一次长中文、长英文、倒计时、按钮和手机控件是否越界。
3. 手机端确认方向十字可长按，`X+方向` 能冲刺，`Y` 跳跃，`A` 回传，`B` 交互，`ESC` 打开暂停；暂停、对话和终局期间触控按钮不应抢输入。
4. 两种分辨率分别检查机关散射/凝聚切换、Past/Future 拖尾、普通结局身份替换和真结局四色汇聚；再以低闪模式复查一次。
5. 跑完整导入、现有 headless 测试和 Windows/Web 导出启动检查；有 Android export template 后再做一次真实移动导出。
6. 最后只修阻塞通关、误导玩家或破坏双语一致性的问题；其余视觉想法留到 Jam 后。
