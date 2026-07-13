# Godot Hub Jam

Godot 4.7 GDScript-only jam starter with reusable menu, settings, dialogue, save, and transition foundations.

## Included

- Main menu: `Scenes/UI/Menu/menu.tscn`
- Settings modal: display, audio, accessibility, and key rebinding
- Credits modal: same glass/scan-line style as settings
- Pause modal: reusable full-screen glass panel
- UI components: `ShaderButton`, `ButtonEffectModule`, `floating_text`
- Autoload audio router: `Scenes/Autoload/game_audio.gd`
- Audio buses: `Master`, `SFX`, `Music`, `Ambient`, `UI`
- Plugins: Dialogue Manager 3.10.4, RicherTextLabel 1.14, Enhanced Save System 2.0.0, SceneManager, Simple GUI Transitions, SoundManager, Phantom Camera
- Common shaders and transitions under `resources/`

## Start Scene

Open `Scenes/UI/Menu/menu.tscn`, select the root `Menu`, and set `start_scene_path` in the Inspector.

The template does not include a gameplay scene. Until `start_scene_path` is set, the Start button is disabled and the menu shows a short hint.

## Audio

UI confirm and cancel sounds are already wired through `GameAudio`.

To add menu music, assign an `AudioStream` to `Menu.menu_music` or call:

```gdscript
GameAudio.play_music("menu", your_stream)
```

Settings sliders write through `SettingsModule` and immediately update Godot audio buses.

## Settings

The settings modal has two pages:

- `通用设置`: fullscreen, `1280x720`, `1600x900`, `1920x1080`, VSync, master/music/SFX/UI/ambient volumes, and screen shake.
- `按键设置`: the common input actions below. Its reset button only resets bindings.

`恢复默认` on `通用设置` restores only display, sound, and accessibility values. Every setting is applied immediately and saved globally.

The keybinding page shows these common actions by default:

- `left`, `right`, `up`, `down`
- `attack`
- `sprint`
- `pause`

Edit `SettingScreen.GAMEPLAY_ACTIONS` and `GAMEPLAY_ACTION_LABELS` if your game needs a different input set.

## Dialogue And Saves

- Official third-party code stays under `addons/` without local patches.
- Project-owned dialogue runtime, effects, save modules, and reusable balloon examples live under `Dialogue/`.
- Use `Dialogue/Examples/modular_balloon.tscn` as the starting point for portraits, history, typing sound, and modular dialogue UI.
- Enhanced Save System registers `SaveSystem` automatically. Its core loads `Config/save_modules.cfg`; project modules live in `Scripts/Save/Modules/` and dialogue progress modules live in `Dialogue/SaveModules/`.
- Upgrade an addon by replacing its directory under `addons/`; preserve `Dialogue/`, `Scripts/Save/`, and `Config/save_modules.cfg`.

## Feedback Overlay

`FeedbackOverlay` is a project autoload with one top-right toast and one authored confirmation panel. It intentionally does not queue messages or use layout strings.

```gdscript
FeedbackOverlay.toast(2.0, "已保存", "进度已写入存档。")
await FeedbackOverlay.popup_confirm("提示", "继续后将进入下一段剧情。")

if await FeedbackOverlay.ask("退出游戏", "确定要退出吗？", "退出", "取消"):
	get_tree().quit()
```

Dialogue Manager can call the same methods directly, for example `do! FeedbackOverlay.toast(2.0, "提示", "内容已更新。")`.

## Scene Transitions

Use the included SceneManager fades for scene changes. Start the exit fade, wait for it, change scene, then start the enter fade from the next scene's `_ready`.

```gdscript
const EXIT_FADE := preload("res://resources/scene_transitions/stage_exit_fade_to_black.tres")
const ENTER_FADE := preload("res://resources/scene_transitions/stage_enter_fade_to_black.tres")

func leave_scene() -> void:
	var tween := SceneManager.transition_start(EXIT_FADE)
	if tween:
		await tween.finished
	SceneManager.change_scene_to_file("res://Scenes/Game/game.tscn")

func _ready() -> void:
	SceneManager.transition_start(ENTER_FADE, true)
```

## Notes

- This template intentionally excludes the original gameplay, growth screen, combat assets, C# project files, and project-specific music.
- `resources/` is normalized from the source project's old `reousrces/` folder name.
- This project intentionally has no root license. Each third-party addon retains its own license.
