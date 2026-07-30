# 当前保留资源归因

Delay Trace 已接入 CC0 占位角色、施工平台、菜单地图、机关图块、五个动作/状态音效、一首菜单循环音乐与一套 OFL 中文像素字体；它们不是正式美术方向。内部路径仍使用 `EchoChase`，部分通用 UI 音频仍临时引用旧目录资源；目录名 `assets/phase_lag` 是历史路径，不代表它们属于当前玩法。

下列条目分别记录可确认的下载日期或“原始日期未保留”，不伪造来源链。SHA256 用于确认当前仓库中实际保留的文件。未来候选素材必须先放入隔离目录，并记录下载日期、修改内容、来源 URL、作者、许可证与 SHA256；正式接入前由项目作者确认。

## pixelgearz: Pixel Art Platformer Character

- 作者：pixelgearz
- 来源：https://pixelgearz.itch.io/pixel-art-platformer-character
- 许可证：CC0 1.0 Universal
- 下载日期：2026-07-28
- 原始 ZIP SHA256：`881BA925131BBEB772BA55EF5D0BF4F713514F6AA38D2170548C07F7B8C5C987`
- 修改：只解压九张 PNG 动画表并建立 Godot `SpriteFrames`；完整 ZIP 不进仓库。现在体、过去体和未来体共用原图，由 shader 换色。

| 文件 | SHA256 |
| --- | --- |
| `assets/echo_chase/character/idle.png` | `057ABD77AB9BA8BF570AEE93054622644D8F3F2C04032B63D84A59D29AE9F13B` |
| `assets/echo_chase/character/run.png` | `3FC5C639CDF5A7257185963796FCE8FB95FEA387946A7AFDE5B6D973ED22FAE8` |
| `assets/echo_chase/character/jump.png` | `924CDE6099E1F947615E9642B5DA0291EFEF983E806604FDD57840403113A3A0` |
| `assets/echo_chase/character/fall.png` | `DDC59C0489903FFEC8610DA579C6B96A794F236CD94B6CCE0595811433012B80` |
| `assets/echo_chase/character/wallslide.png` | `6A20A8F36A856266D0EA6227F00D3CD30625B540B34EA674C79137FB5BD2029B` |
| `assets/echo_chase/character/climb.png` | `19972333E792F867E7346D0EFB5639D6B3BB8739D6541C5A1CAD272B085BC1AD` |
| `assets/echo_chase/character/dash.png` | `674756DA16332D1C2BD7E3BABC9F93965CBA0DF6D1BB7CFEE13CE678A648E489` |
| `assets/echo_chase/character/hit.png` | `3BE1CD59704BAAFAD8EEB21A9652F62B0714275AD915E46CDA96C7B5E2FD6347` |
| `assets/echo_chase/character/death.png` | `693EA8F9E9572EE7AB739C1B4583D305F0DB51AEED40453C848E2CB4DA6B1DAA` |

## Kenney: Echo Chase 施工素材

- 作者：Kenney
- 许可证：CC0
- 1-Bit Platformer Pack：https://kenney.nl/assets/1-bit-platformer-pack
- Digital Audio：https://kenney.nl/assets/digital-audio
- Impact Sounds：https://kenney.nl/assets/impact-sounds
- 原始下载日期：未保留；从用户本地 CC0 素材库复制到仓库日期：2026-07-28

| 当前用途 | 文件 | 来源包与修改 | SHA256 |
| --- | --- | --- | --- |
| 施工 TileMap、checkpoint 与机关图标 | `assets/echo_chase/tilemap/monochrome_tilemap_transparent_packed.png` | 1-Bit Platformer Pack；未改源像素，碰撞与 Terrain 数据保存在项目 TileSet。 | `497C68067960694C11D1D678CF04E0E8A4778CC40BCEFAD822FE398364E0E204` |
| 仓库保留、当前运行时未引用 | `assets/echo_chase/ui/menu_map_backdrop.png` | 旧主菜单合成图；现菜单改用 authored `MenuWorld` TileMap 与网格。 | `C3B11CC3DF111C0D4408F7A4B6B5109CFC768AD6C7B5BC9E62BD4EE302799E2C` |
| 冲刺 | `assets/echo_chase/audio/phaseJump2.ogg` | Digital Audio；原文件直接接入。 | `5D85717CFCA231F7DA7887CEF5F44B2131BBE3308EB0C1FEE0B4F9E61D59B571` |
| 过去体出现 | `assets/echo_chase/audio/phaserUp4.ogg` | Digital Audio；原文件直接接入。 | `A64A69368AF9D85DFCE8DD38432FD6C9935A7766621782193102C9CB276571FC` |
| 失败/复位 | `assets/echo_chase/audio/phaserDown2.ogg` | Digital Audio；原文件直接接入。 | `0EAADBBC5C259CC89A1DFBB0C99B61CA07E08710D035CC9BFC805B68CB0BDC9E` |
| checkpoint 激活 | `assets/echo_chase/audio/powerUp5.ogg` | Digital Audio；原文件直接接入。 | `528E7245A1B61C6FD94BCB8DF1D747E6E9B76DCE58A36E44BE992CF9E09884F8` |
| 落地 | `assets/echo_chase/audio/impactGeneric_light_001.ogg` | Impact Sounds；原文件直接接入。 | `C3CD1C073D186AE8FA35788BA94DE581F1826E7427A7BB26490B2695FAC18EFA` |

## TakWolf: Fusion Pixel Font

- 作者：TakWolf
- 来源：https://github.com/TakWolf/fusion-pixel-font
- 版本：`v2026.07.20`
- 许可证：SIL Open Font License 1.1
- 下载日期：2026-07-29
- 修改：使用简体中文比例字宽 TTF；源字体未修改，Godot 导入时自动关闭像素字体的次像素定位与 hinting。

| 当前用途 | 文件 | SHA256 |
| --- | --- | --- |
| 菜单、设置、感谢、暂停与通用 UI | `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf` | `FFA464AAE492ED7A8526367DEBCCE62603CEC8157F59548CC50CEBF1ED81A53F` |
| 许可证副本 | `assets/echo_chase/licenses/fusion_pixel_font_ofl.txt` | 见仓库文件 |

## Frenchyboy: Mysterious, Futuristic 8-bit Music Loop

- 作者：Frenchyboy
- 来源：https://opengameart.org/content/mysterious-futuristic-8-bit-music-loop
- 许可证：CC0 1.0 Universal
- 下载日期：2026-07-29
- 原始附件：`Mysterious2.wav`
- 原始 WAV SHA256：`17BCB5EA58B67F150AF802D159F8B00F87CD27381876775CB96D4CD97071E1BB`
- 修改：使用 FFmpeg 8.0.1、Vorbis quality 5 转为单声道 `44.1kHz` OGG；未裁切音频内容；Godot 导入设为循环。

| 当前用途 | 文件 | SHA256 |
| --- | --- | --- |
| 主菜单循环音乐 | `assets/echo_chase/audio/music/mysterious_futuristic_loop.ogg` | `A8CF299AA1F2C703EA5DE249DFA864254DE8AC76571A9DA70F7D33873AD08CCB` |
| 来源与许可记录 | `assets/echo_chase/licenses/frenchyboy_mysterious_futuristic_cc0.txt` | 见仓库文件 |

## Ansimuz: Sideview Sci-Fi - Patreon Collection

- 作者：ansimuz
- 来源：https://opengameart.org/content/sideview-sci-fi-patreon-collection
- 许可证：CC0

| 保留状态 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 仓库保留、当前运行时未引用 | `assets/phase_lag/environment/facility_corridor_strip.png` | 历史 Phase Lag 菜单设施带；Echo Chase 菜单已替换。 | `34D83E00581BF05CC954361AB65926A8A6CD44440111B8B80ABF69A6455F52F4` |

## Kenney: 历史菜单资源

- 作者：Kenney
- 许可证：CC0
- UI 来源：https://kenney.nl/assets/ui-pack-sci-fi
- 界面音效来源：https://kenney.nl/assets/interface-sounds

| 当前用途 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 历史设置页面板 | `assets/phase_lag/ui/kenney/settings_panel.png` | 仓库保留，当前黑白 UI 已停止引用。 | `CB8FCBAB73B709BAC176ACB59E44E121FC336BBBC93DD1E33753808ADCCB4C8E` |
| UI 选择 | `assets/phase_lag/audio/sfx/ui_select.ogg` | 重命名后用于菜单 hover。 | `B44550FA8D3276C072CE7C3C1315D949F7A28A95BC22B3618AD4EEA62EAC8ABE` |
| UI 返回 | `assets/phase_lag/audio/sfx/ui_cancel.ogg` | 重命名后用于返回。 | `07DB973F79F6AE0F2EDC34561E7592E24D0577455919FB602CB8ECC0DA991DCF` |
| 菜单确认 | `assets/phase_lag/audio/sfx/ui_confirm_menu.ogg` | 重命名后用于菜单确认。 | `063564703B6094D70718A3E787A55CC9141611E4ECD6B6637F8828F79B4A8C3A` |
| 局内确认 | `assets/phase_lag/audio/sfx/ui_confirm_ingame.ogg` | 重命名后保留给通用确认。 | `3091BF0BE0497F825769EE0733CA7BDC3BCD59BD6C6E8F2BA8F93D580FF38022` |

## HaelDB: 历史 Tragic ambient main menu

- 作者：HaelDB
- 来源：https://opengameart.org/content/tragic-ambient-main-menu
- 许可证：CC0（原页面也提供 OGA-BY 3.0 选项；项目按 CC0 使用）

| 当前用途 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 仓库保留、当前运行时未引用 | `assets/phase_lag/audio/music/tragic_ambient_main_menu.ogg` | 历史导入时裁去首尾长静音并设置 loop；Echo Chase 菜单已替换。 | `0831A5EE293E24A3ACA183CB066D1D461C81D1A0C166F580DCA07F9AC7003DB6` |

## 引擎与插件

- Godot Engine：https://godotengine.org/
- Dialogue Manager：https://github.com/nathanhoad/godot_dialogue_manager
