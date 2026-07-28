class_name PhaseLagHUD
extends Control
## Low-chrome split-screen HUD with transient controls and authored overlays.

signal return_to_menu_requested
signal finale_confirmed

@onready var chapter_label: Label = %ChapterLabel
@onready var lu_status: HBoxContainer = %LuStatus
@onready var xing_status: HBoxContainer = %XingStatus
@onready var lu_control_label: Label = %LuControlLabel
@onready var xing_control_label: Label = %XingControlLabel
@onready var lu_health_fills: Array[ColorRect] = [%LuHealthOne, %LuHealthTwo]
@onready var xing_health_fills: Array[ColorRect] = [%XingHealthOne, %XingHealthTwo, %XingHealthThree]
@onready var timeline_overlay: ColorRect = %TimelineOverlay
@onready var timeline_title: Label = %TimelineTitle
@onready var timeline_text: Label = %TimelineText
@onready var disconnect_panel: ColorRect = %DisconnectPanel
@onready var disconnect_title: Label = %DisconnectTitle
@onready var disconnect_text: Label = %DisconnectText
@onready var disconnect_return_button: Button = %DisconnectReturnButton
@onready var finale_panel: ColorRect = %FinalePanel
@onready var finale_title: Label = %FinaleTitle
@onready var finale_text: Label = %FinaleText
@onready var finale_button: Button = %FinaleButton

var _lu_health: int = 2
var _xing_health: int = 3
var _mode: GameMode.Mode = GameMode.Mode.SOLO
var _active_side: int = EntangledEntity.Side.LU_HENG
var _chapter_tween: Tween


# Connects authored overlay buttons and hides transient surfaces at startup.
func _ready() -> void:
	disconnect_return_button.pressed.connect(_on_disconnect_return_pressed)
	finale_button.pressed.connect(_on_finale_pressed)
	_update_health_pips()


# Briefly presents chapter identity, then returns both viewports to unobstructed play.
func set_chapter(number: int, title: String) -> void:
	chapter_label.text = "第%s章 · %s" % [_chapter_number_text(number), title]
	if _chapter_tween != null and _chapter_tween.is_valid():
		_chapter_tween.kill()
	chapter_label.visible = true
	chapter_label.modulate.a = 0.0
	_chapter_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_chapter_tween.tween_property(chapter_label, ^"modulate:a", 1.0, 0.18)
	_chapter_tween.tween_interval(1.45)
	_chapter_tween.tween_property(chapter_label, ^"modulate:a", 0.0, 0.28)
	_chapter_tween.tween_callback(chapter_label.hide)


# Shows ownership beside each role instead of aggregating it in a screen-wide status card.
func set_mode(mode: GameMode.Mode, active_side: int) -> void:
	_mode = mode
	_active_side = active_side
	if mode == GameMode.Mode.LOCAL_COOP:
		lu_control_label.text = "P1"
		xing_control_label.text = "P2"
		lu_status.modulate.a = 1.0
		xing_status.modulate.a = 1.0
	else:
		var lu_active := active_side == EntangledEntity.Side.LU_HENG
		lu_control_label.text = "P1 · 操作中" if lu_active else "待命"
		xing_control_label.text = "P1 · 操作中" if not lu_active else "待命"
		lu_status.modulate.a = 1.0 if lu_active else 0.66
		xing_status.modulate.a = 1.0 if not lu_active else 0.66


# Updates one role's health pips in the shared status block.
func set_health(side: int, value: int) -> void:
	if side == EntangledEntity.Side.LU_HENG:
		_lu_health = value
	else:
		_xing_health = value
	_update_health_pips()

# Shows the timeline collapse reason without advertising a retired shortcut.
func show_timeline_collapse(reason: String) -> void:
	timeline_title.text = "时间线崩溃"
	timeline_text.text = reason
	timeline_overlay.visible = true
	timeline_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	timeline_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(timeline_overlay, "modulate:a", 1.0, 0.35)


# Removes the failure surface before a rebuilt room becomes interactive again.
func hide_timeline_collapse() -> void:
	timeline_overlay.visible = false
	timeline_overlay.modulate.a = 0.0
	timeline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Pauses play behind the authored initial-connect or reconnect surface.
func show_player_two_waiting(reconnecting: bool) -> void:
	disconnect_title.text = "玩家 2 已断开" if reconnecting else "等待玩家 2"
	disconnect_text.text = (
		"时间线已暂停。连接任意手柄后自动继续。"
		if reconnecting
		else "P1 使用键盘。连接任意手柄后自动开始。"
	)
	disconnect_panel.visible = true
	disconnect_return_button.grab_focus()


# Hides the controller layer after P2 has a live device again.
func hide_player_two_waiting() -> void:
	disconnect_panel.visible = false


# Presents the final reveal and the post-accident hope signal.
func show_finale(title: String, text: String) -> void:
	finale_title.text = title
	finale_text.text = text
	finale_panel.visible = true
	finale_button.grab_focus()


# Emits the only authored escape from locked local co-op.
func _on_disconnect_return_pressed() -> void:
	return_to_menu_requested.emit()


# Emits the final confirmation before returning to the title timeline.
func _on_finale_pressed() -> void:
	finale_confirmed.emit()


# Converts chapter numbers into the short Chinese labels used by the HUD.
func _chapter_number_text(number: int) -> String:
	var labels: Array[String] = ["零", "一", "二", "三", "四", "五"]
	return labels[number] if number >= 0 and number < labels.size() else str(number)


# Shows only the authored fills that belong to each role's current health.
func _update_health_pips() -> void:
	for index in lu_health_fills.size():
		lu_health_fills[index].visible = index < _lu_health
	for index in xing_health_fills.size():
		xing_health_fills[index].visible = index < _xing_health
