class_name PhaseSeamVfx
extends Control
## Dynamic split boundary and nonverbal cross-space transfer pulse.

const OFFSET_OVERLAP: int = 3
const MERGED: int = 4

var _xing_boundary: float = 0.5
var _lu_boundary: float = 0.5
var _layout_mode: int = 0
var _delay_seconds: float = 3.0
var _low_flash_mode: bool = false
var _layout_tween: Tween
var _wave_tween: Tween

@onready var seam_a: ColorRect = $SeamA
@onready var seam_b: ColorRect = $SeamB
@onready var full_interference: ColorRect = $FullInterference
@onready var transfer_wave: ColorRect = $TransferWave


# Connects the boundary to causality sends and the persisted accessibility preference.
func _ready() -> void:
	EntanglementBus.event_queued.connect(_on_event_queued)
	set_low_flash_mode(_read_low_flash_mode())
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	transfer_wave.visible = false
	full_interference.visible = false


# Tracks equal, weighted, overlapping, and merged authored viewport layouts.
func apply_layout(mode: int, xing_boundary: float, lu_boundary: float, duration: float) -> void:
	_layout_mode = mode
	_xing_boundary = xing_boundary
	_lu_boundary = lu_boundary
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if mode == MERGED:
		_fade_seam(seam_a, 0.0, duration)
		_fade_seam(seam_b, 0.0, duration)
		full_interference.visible = true
		_layout_tween.parallel().tween_property(full_interference, ^"modulate:a", _merged_alpha(), duration)
		return
	full_interference.visible = false
	_move_seam(seam_a, xing_boundary, duration)
	_fade_seam(seam_a, 1.0, duration)
	if mode == OFFSET_OVERLAP:
		seam_b.visible = true
		_move_seam(seam_b, lu_boundary, duration)
		_fade_seam(seam_b, 1.0, duration)
	else:
		_fade_seam(seam_b, 0.0, duration)


# Scales merged-space interference down as the authored delay approaches zero.
func set_delay(seconds: float) -> void:
	_delay_seconds = maxf(seconds, 0.0)
	var material := full_interference.material as ShaderMaterial
	material.set_shader_parameter("intensity", clampf(_delay_seconds / 3.0, 0.0, 1.0))
	if _layout_mode == MERGED:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(full_interference, ^"modulate:a", _merged_alpha(), 0.35)


# Switches the seam shader and waves to stable slow pulses.
func set_low_flash_mode(value: bool) -> void:
	_low_flash_mode = value
	for item: ColorRect in [seam_a, seam_b, full_interference]:
		var material := item.material as ShaderMaterial
		material.set_shader_parameter("low_flash_mode", value)


# Moves one horizontal seam in lockstep with the viewport anchor tween.
func _move_seam(seam: ColorRect, ratio: float, duration: float) -> void:
	seam.visible = true
	_layout_tween.parallel().tween_property(seam, ^"anchor_top", ratio, duration)
	_layout_tween.parallel().tween_property(seam, ^"anchor_bottom", ratio, duration)


# Fades one seam while preserving its stable authored thickness.
func _fade_seam(seam: ColorRect, alpha: float, duration: float) -> void:
	if alpha > 0.0:
		seam.visible = true
	_layout_tween.parallel().tween_property(seam, ^"modulate:a", alpha, duration)
	if is_zero_approx(alpha):
		_layout_tween.tween_callback(seam.hide)


# Returns the restrained merged overlay strength for the active delay.
func _merged_alpha() -> float:
	if is_zero_approx(_delay_seconds):
		return 0.0
	return (0.16 if not _low_flash_mode else 0.09) * clampf(_delay_seconds / 3.0, 0.0, 1.0)


# Sends a short source-colored wave across the current split without text or icons.
func _on_event_queued(event: EntanglementEvent) -> void:
	if _wave_tween != null and _wave_tween.is_valid():
		_wave_tween.kill()
	var boundary: float = (_xing_boundary + _lu_boundary) * 0.5
	transfer_wave.anchor_top = boundary
	transfer_wave.anchor_bottom = boundary
	transfer_wave.offset_top = -5.0
	transfer_wave.offset_bottom = 5.0
	transfer_wave.color = Color(0.36, 0.98, 0.9, 0.72) if event.source_side == EntangledEntity.Side.LU_HENG else Color(1.0, 0.42, 0.18, 0.72)
	transfer_wave.modulate.a = 0.55 if _low_flash_mode else 0.9
	transfer_wave.visible = true
	var duration: float = 0.52 if _low_flash_mode else 0.35
	_wave_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wave_tween.parallel().tween_property(transfer_wave, ^"offset_top", -22.0, duration)
	_wave_tween.parallel().tween_property(transfer_wave, ^"offset_bottom", 22.0, duration)
	_wave_tween.parallel().tween_property(transfer_wave, ^"modulate:a", 0.0, duration)
	_wave_tween.tween_callback(transfer_wave.hide)


# Reads the accessibility flag without requiring settings in isolated scene tests.
func _read_low_flash_mode() -> bool:
	return bool(SettingsModule.instance.get_value("low_flash_mode", false)) if SettingsModule.instance != null else false


# Applies live accessibility changes to the active seam presentation.
func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "low_flash_mode":
		set_low_flash_mode(bool(value))
		set_delay(_delay_seconds)
