# 当前保留资源归因

Echo Chase 尚未接入正式角色、关卡背景、敌人、音乐或音效。本表只记录重构后菜单、设置页和通用 UI 仍临时引用的旧目录资源；目录名 `assets/phase_lag` 是历史路径，不代表它们属于当前玩法。

原始下载发生在 Echo Chase 重构前，精确下载日期未保留，因此不伪造日期。下列 SHA256 用于确认当前仓库中实际保留的文件。未来下载的候选素材必须放入隔离目录，并额外记录下载日期、修改内容、来源 URL、作者、许可证与 SHA256；正式接入前由项目作者确认。

## Ansimuz: Sideview Sci-Fi - Patreon Collection

- 作者：ansimuz
- 来源：https://opengameart.org/content/sideview-sci-fi-patreon-collection
- 许可证：CC0

| 当前用途 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 主菜单设施带 | `assets/phase_lag/environment/facility_corridor_strip.png` | 从原走廊层裁成横向设施带；菜单动画只改色和轻微位移。 | `34D83E00581BF05CC954361AB65926A8A6CD44440111B8B80ABF69A6455F52F4` |

## Kenney

- 作者：Kenney
- 许可证：CC0
- UI 来源：https://kenney.nl/assets/ui-pack-sci-fi
- 界面音效来源：https://kenney.nl/assets/interface-sounds

| 当前用途 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 设置页面板 | `assets/phase_lag/ui/kenney/settings_panel.png` | 作为 authored `NinePatchRect` 使用。 | `CB8FCBAB73B709BAC176ACB59E44E121FC336BBBC93DD1E33753808ADCCB4C8E` |
| UI 选择 | `assets/phase_lag/audio/sfx/ui_select.ogg` | 重命名后用于菜单 hover。 | `B44550FA8D3276C072CE7C3C1315D949F7A28A95BC22B3618AD4EEA62EAC8ABE` |
| UI 返回 | `assets/phase_lag/audio/sfx/ui_cancel.ogg` | 重命名后用于返回。 | `07DB973F79F6AE0F2EDC34561E7592E24D0577455919FB602CB8ECC0DA991DCF` |
| 菜单确认 | `assets/phase_lag/audio/sfx/ui_confirm_menu.ogg` | 重命名后用于菜单确认。 | `063564703B6094D70718A3E787A55CC9141611E4ECD6B6637F8828F79B4A8C3A` |
| 局内确认 | `assets/phase_lag/audio/sfx/ui_confirm_ingame.ogg` | 重命名后保留给通用确认。 | `3091BF0BE0497F825769EE0733CA7BDC3BCD59BD6C6E8F2BA8F93D580FF38022` |

## HaelDB: Tragic ambient main menu

- 作者：HaelDB
- 来源：https://opengameart.org/content/tragic-ambient-main-menu
- 许可证：CC0（原页面也提供 OGA-BY 3.0 选项；项目按 CC0 使用）

| 当前用途 | 文件 | 修改 | SHA256 |
| --- | --- | --- | --- |
| 主菜单循环音乐 | `assets/phase_lag/audio/music/tragic_ambient_main_menu.ogg` | 历史导入时裁去首尾长静音并设置 loop。 | `0831A5EE293E24A3ACA183CB066D1D461C81D1A0C166F580DCA07F9AC7003DB6` |

## 引擎与插件

- Godot Engine：https://godotengine.org/
- Dialogue Manager：https://github.com/nathanhoad/godot_dialogue_manager
