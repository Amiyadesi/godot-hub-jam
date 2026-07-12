# Godot Hub Jam

Godot 4.7 GDScript-only jam starter with reusable menu, settings, dialogue, save, and transition foundations.

## Included

- Main menu: `Scenes/UI/Menu/menu.tscn`
- Settings modal: audio sliders and key rebinding
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
- `Scripts/Save/save_system.gd` loads `Config/save_modules.cfg`; project modules live in `Scripts/Save/Modules/` and dialogue progress modules live in `Dialogue/SaveModules/`.
- Upgrade an addon by replacing its directory under `addons/`; preserve `Dialogue/`, `Scripts/Save/`, and `Config/save_modules.cfg`.

## Notes

- This template intentionally excludes the original gameplay, growth screen, combat assets, C# project files, and project-specific music.
- `resources/` is normalized from the source project's old `reousrces/` folder name.
- This project intentionally has no root license. Each third-party addon retains its own license.
