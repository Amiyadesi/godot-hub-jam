extends Node2D
## Floating damage text that supports configurable color, scale, and decimals.

@export var auto_start_text := ""
@export_range(0.0, 10.0, 0.1) var hold_seconds := 1.2

@onready var label: Label = $Label

var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_label_modulate := Color.WHITE
var _float_tween: Tween


# Starts authored one-shot labels such as the spawn-point Run cue.
func _ready() -> void:
	_base_position = global_position
	_base_scale = scale
	_base_label_modulate = label.modulate
	label.hide()
	if not auto_start_text.is_empty():
		start(tr(auto_start_text))

# Starts the floating label with raw text for existing callers.
func start(text: String) -> void:
	label.modulate = _base_label_modulate
	scale = _base_scale
	show_float(text)


# Starts a formatted numeric damage label with up to two decimals.
func start_damage(amount: float, tint: Color = Color(1.0, 0.87, 0.48, 1.0), scale_boost: float = 1.0) -> void:
	label.modulate = tint
	scale = _base_scale * scale_boost
	show_float(_format_damage(amount))


# Holds the authored text in world space, then lets it drift away.
func show_float(text: String) -> void:
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	global_position = _base_position
	modulate.a = 1.0
	label.text = text
	label.show()
	_float_tween = create_tween()
	_float_tween.tween_property(self, "global_position", _base_position + Vector2(0.0, -20.0), 0.28)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_float_tween.tween_interval(hold_seconds)
	_float_tween.tween_property(self, "global_position", _base_position + Vector2(0.0, -64.0), 0.55)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_float_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.55)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_float_tween.tween_callback(label.hide)


# Formats floating damage with at most two decimal places and no tail zeroes.
func _format_damage(amount: float) -> String:
	var rounded: float = snappedf(amount, 0.01)
	if is_zero_approx(rounded - roundf(rounded)):
		return str(int(round(rounded)))
	var text: String = "%.2f" % rounded
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
