extends ComponentBase
class_name ButtonEffectModule

## 按钮轻量交互反馈组件。

## 缓动曲线类型。
@export var ease_type: Tween.EaseType
## 过渡类型。
@export var trans_type: Tween.TransitionType
## 单次动画时长。
@export var anim_duration: float = 0.09
## 按下时的轻微压缩；悬停不改变控件边界。
@export var press_scale: Vector2 = Vector2.ONE * 0.985
## 普通按钮按下时要播放的界面音类型。
@export_enum("none", "confirm", "cancel") var press_sound_kind: String = "confirm"

@onready var button: Button = get_parent()

var tween: Tween

# Connects deterministic press feedback when the component becomes active.
func _component_ready() -> void:
	_on_enable()


# Disconnects only signals owned by this component.
func _on_disable() -> void:
	button.pressed.disconnect(_on_button_pressed)


# Enables a stable press response without hover scaling or random rotation.
func _on_enable() -> void:
	button.pressed.connect(_on_button_pressed)
	button.pivot_offset_ratio = Vector2.ONE / 2


# Compresses and releases the button within a short confirmation window.
func _on_button_pressed() -> void:
	_play_press_sound()
	_reset_tween()
	tween.tween_property(button, "scale", Vector2.ONE, anim_duration).from(press_scale)


# Replaces any in-flight response so repeated input never accumulates transforms.
func _reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(ease_type).set_trans(trans_type)
	tween.set_ignore_time_scale(true)


# 给普通 Button 统一补一个界面确认/取消音，避免和 ShaderButton 自带音频重复。
func _play_press_sound() -> void:
	if press_sound_kind == "none":
		return
	if button is ShaderButton:
		return
	var game_audio: Node = _get_game_audio()
	if game_audio == null:
		return
	match press_sound_kind:
		"confirm":
			if game_audio.has_method("play_ui_button_press"):
				game_audio.call("play_ui_button_press", button)
			else:
				game_audio.call("play_ui_confirm_ingame")
		"cancel":
			game_audio.call("play_ui_cancel")
		_:
			pass


# 在运行时查找全局音频路由节点。
func _get_game_audio() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("GameAudio")
	
