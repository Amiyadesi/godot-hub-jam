extends Button
class_name ShaderButton
## 保留旧类名的轻量菜单按钮；视觉完全由 authored Theme 控制。

@export_multiline var bb_text: String


# 连接克制的焦点与音频反馈。
func _ready() -> void:
	if not bb_text.is_empty():
		text = bb_text
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)


# 保留旧弹窗调用接口，当前只接受纯文本。
func set_bbtext(value: String) -> void:
	bb_text = value
	text = value


# 兼容旧调用，将传入样式直接应用到根按钮。
func set_panel_box(style_box: StyleBox) -> void:
	if style_box == null:
		remove_theme_stylebox_override("normal")
		return
	add_theme_stylebox_override("normal", style_box)


# 将复用按钮恢复到 authored 中性状态。
func reset_visuals() -> void:
	self_modulate = Color.WHITE
	if has_focus():
		release_focus()


# 播放全局按钮确认音。
func _on_pressed() -> void:
	_play_press_sound()


# 鼠标经过时使用与键盘一致的反色焦点。
func _on_mouse_entered() -> void:
	if disabled:
		return
	grab_focus()
	_play_select_sound()


# 通过全局音频路由播放按钮按下音。
func _play_press_sound() -> void:
	var game_audio := _get_game_audio()
	if game_audio != null and game_audio.has_method("play_ui_button_press"):
		game_audio.call("play_ui_button_press", self)
		return
	var press_audio := get_node_or_null("PressAudio") as AudioStreamPlayer
	if press_audio != null and press_audio.stream != null:
		press_audio.play()


# 仅在 authored 资源存在时播放悬停音。
func _play_select_sound() -> void:
	var select_audio := get_node_or_null("SelectAudio") as AudioStreamPlayer
	if select_audio != null and select_audio.stream != null:
		select_audio.play()


# 获取全局音频服务。
func _get_game_audio() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("GameAudio")
