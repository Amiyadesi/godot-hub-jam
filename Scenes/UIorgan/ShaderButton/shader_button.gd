extends Button
class_name ShaderButton
## 着色器风格按钮
##
## 职责：视觉交互（稳定描边、焦点状态、克制的点击反馈）
## 不负责：业务逻辑、对话触发、提示系统

const ButtonShader := preload("res://Scenes/UIorgan/ShaderButton/shader_button.tres")
const HIGHLIGHT_GLOW := 0.22
const HIGHLIGHT_PROGRESS := 1.0

@export var panel_style_box: StyleBox
@export var outline_color: Color = Color(0.45, 0.95, 0.88, 1.0)
@export_group("BBcode")
@export_multiline var bb_text: String

@onready var text_label: RichTextLabel = $Label
@onready var panel: Panel = $Panel

var _feedback_tween: Tween
var _is_mouse_over: bool = false
var _has_keyboard_focus: bool = false
var _original_label_modulate: Color = Color.WHITE


func _ready() -> void:
	if panel_style_box != null:
		panel.add_theme_stylebox_override("panel", panel_style_box)

	text_label.text = bb_text if not bb_text.is_empty() else text
	text_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	text = ""

	material = ButtonShader.duplicate()
	material.set("shader_parameter/time1", 1.0)
	material.set("shader_parameter/time2", 0.0)
	material.set("shader_parameter/center1", Vector2(0.5, 0.5))
	material.set("shader_parameter/center2", Vector2(0.5, 0.5))

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	resized.connect(_sync_shader_geometry)

	_original_label_modulate = text_label.modulate
	_sync_shader_geometry()


func _process(_delta: float) -> void:
	modulate.a = 0.48 if disabled else 1.0


# ─────────────────────────────────────────────
# 公开 API
# ─────────────────────────────────────────────

# Replaces the displayed rich text without rebuilding the authored button scene.
func set_bbtext(bbtext: String) -> void:
	bb_text = bbtext
	if text_label != null:
		text_label.text = bbtext


# Applies an authored panel resource supplied by the owning scene.
func set_panel_box(style_box: StyleBox) -> void:
	panel_style_box = style_box
	if panel != null:
		panel.add_theme_stylebox_override("panel", style_box)


# Returns pooled buttons to their neutral interaction state.
func reset_visuals() -> void:
	_is_mouse_over = false
	_has_keyboard_focus = false
	if _feedback_tween:
		_feedback_tween.kill()
	if material:
		material.set("shader_parameter/time1", 1.0)
		material.set("shader_parameter/time2", 0.0)
		material.set("shader_parameter/glow", 0.0)
	if text_label:
		text_label.modulate = _original_label_modulate
	modulate.a = 1.0


# ─────────────────────────────────────────────
# 信号处理
# ─────────────────────────────────────────────

# Plays a short centered confirmation trace without following the pointer position.
func _on_pressed() -> void:
	_play_press_sound()
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_ignore_time_scale(true)
	_feedback_tween.tween_property(material, "shader_parameter/time1", 1.0, 0.24).from(0.0)


# Marks pointer hover as one source of the shared focus outline.
func _on_mouse_entered() -> void:
	if disabled:
		return
	grab_focus()
	_play_select_sound()
	_is_mouse_over = true
	_update_highlight()


# Removes pointer hover while preserving keyboard/controller focus when present.
func _on_mouse_exited() -> void:
	_is_mouse_over = false
	_update_highlight()


# Marks keyboard/controller focus as the same stable outline used by hover.
func _on_focus_entered() -> void:
	_has_keyboard_focus = true
	_update_highlight()


# Clears keyboard/controller focus while preserving pointer hover when present.
func _on_focus_exited() -> void:
	_has_keyboard_focus = false
	_update_highlight()


# Transitions between neutral and focused outlines without scale, rotation, or text overbrightening.
func _update_highlight() -> void:
	if material == null:
		return
	var highlighted := not disabled and (_is_mouse_over or _has_keyboard_focus)
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_parallel().set_ignore_time_scale(true)
	_feedback_tween.tween_property(
		material,
		"shader_parameter/time2",
		HIGHLIGHT_PROGRESS if highlighted else 0.0,
		0.16
	)
	_feedback_tween.tween_property(
		material,
		"shader_parameter/glow",
		HIGHLIGHT_GLOW if highlighted else 0.0,
		0.16
	)
	text_label.modulate = _original_label_modulate


# Keeps the outline distance field aligned with the authored control bounds.
func _sync_shader_geometry() -> void:
	if material == null or size.y <= 0.0:
		return
	material.set("shader_parameter/size", size)
	material.set("shader_parameter/color", outline_color)
	var normal_style := get_theme_stylebox("normal")
	if normal_style is StyleBoxFlat:
		material.set(
			"shader_parameter/corner_radius",
			(normal_style as StyleBoxFlat).corner_radius_top_left / size.y * 2.0
		)


# 通过全局音频路由播放按钮按下音，确保设置里的音量滑杆生效。
func _play_press_sound() -> void:
	var game_audio: Node = _get_game_audio()
	if game_audio != null and game_audio.has_method("play_ui_button_press"):
		game_audio.call("play_ui_button_press", self)
		return
	var press_audio: AudioStreamPlayer = get_node_or_null("PressAudio") as AudioStreamPlayer
	if press_audio != null and press_audio.stream != null:
		press_audio.bus = "UI"
		press_audio.volume_db = -12.0
		press_audio.play()


# 悬停音效目前只在场景配置了资源时播放。
func _play_select_sound() -> void:
	var select_audio: AudioStreamPlayer = get_node_or_null("SelectAudio") as AudioStreamPlayer
	if select_audio == null or select_audio.stream == null:
		return
	select_audio.bus = "UI"
	select_audio.volume_db = -18.0
	select_audio.play()


# 查找项目全局音频路由。
func _get_game_audio() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("GameAudio")
