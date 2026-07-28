class_name PhaseBossAvatar
extends Node2D
## Single visual body that physically reparents between the two SubViewports.

signal core_struck(attack_kind: StringName, break_power: int)

@export var chase_speed: float = 115.0

var active: bool = false
var stunned: bool = false
var core_exposed: bool = false
var _stun_timer: float = 0.0
var _bob_time: float = 0.0
var _low_flash_mode: bool = false
var _telegraph_tween: Tween
var _final_decay_tween: Tween
var _visual_tweens: Array[Tween] = []

@onready var pixel_body: Sprite2D = $PixelBody
@onready var warning_halo: Line2D = $WarningHalo
@onready var attack_charge: Polygon2D = $AttackCharge
@onready var phase_shards: Node2D = $PhaseShards
@onready var armor_plates: Array[Line2D] = [
	$ArmorPlates/PlateOne,
	$ArmorPlates/PlateTwo,
	$ArmorPlates/PlateThree,
]
@onready var trap_clamps: Array[Node2D] = [
	$TrapClamps/ClampOne,
	$TrapClamps/ClampTwo,
	$TrapClamps/ClampThree,
]
@onready var core_cold: Polygon2D = $FinalCore/CoreCold
@onready var core_warm: Polygon2D = $FinalCore/CoreWarm
@onready var core_hit_area: Area2D = $CoreHitArea
@onready var armor_break_audio: AudioStreamPlayer2D = $ArmorBreakAudio
@onready var clamp_audio: AudioStreamPlayer2D = $ClampAudio
@onready var core_open_audio: AudioStreamPlayer2D = $CoreOpenAudio
@onready var defeat_audio: AudioStreamPlayer2D = $DefeatAudio


# Animates idle phase drift and temporary stun feedback.
func _process(delta: float) -> void:
	if not active:
		return
	_bob_time += delta
	pixel_body.position.y = sin(_bob_time * 2.4) * 4.0
	if _stun_timer > 0.0:
		_stun_timer = maxf(_stun_timer - delta, 0.0)
		stunned = _stun_timer > 0.0
		if not stunned:
			pixel_body.modulate = Color.WHITE
	warning_halo.rotation += delta * 1.8


# Restores the single boss body for a new timeline attempt.
func reset_avatar() -> void:
	_kill_visual_tweens()
	active = true
	visible = true
	stunned = false
	core_exposed = false
	_stun_timer = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	pixel_body.position = Vector2.ZERO
	pixel_body.flip_h = false
	pixel_body.modulate = Color.WHITE
	warning_halo.visible = false
	attack_charge.visible = false
	phase_shards.visible = false
	core_hit_area.monitorable = false
	armor_break_audio.stop()
	clamp_audio.stop()
	core_open_audio.stop()
	defeat_audio.stop()
	clear_boss_event_visuals()


# Moves the boss horizontally toward the player while not stunned or teleporting.
func chase(target_position: Vector2, delta: float) -> void:
	if not active or stunned:
		return
	position.x = move_toward(position.x, target_position.x, chase_speed * delta)
	position.y = 375.0
	pixel_body.flip_h = target_position.x < position.x


# Starts stable pixel dissolution while a target-space preview materializes.
func begin_telegraph(seconds: float = 3.0) -> void:
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	warning_halo.visible = true
	warning_halo.modulate.a = 0.55 if _low_flash_mode else 0.9
	phase_shards.visible = true
	phase_shards.modulate.a = 0.35
	phase_shards.scale = Vector2(0.8, 0.8)
	_telegraph_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_telegraph_tween.parallel().tween_property(pixel_body, ^"modulate:a", 0.18, seconds)
	_telegraph_tween.parallel().tween_property(phase_shards, ^"scale", Vector2(1.45, 1.45), seconds)
	_telegraph_tween.parallel().tween_property(phase_shards, ^"modulate:a", 0.85 if not _low_flash_mode else 0.55, seconds)


# Stops the teleport warning and restores the solid body silhouette.
func end_telegraph() -> void:
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	warning_halo.visible = false
	phase_shards.visible = false
	pixel_body.modulate = Color.WHITE


# Shows anticipation for the boss's guard-breaking strike.
func show_attack_charge(value: bool) -> void:
	attack_charge.visible = value
	if value:
		attack_charge.scale = Vector2(0.35, 0.35)
		attack_charge.modulate.a = 0.58 if _low_flash_mode else 0.9
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(attack_charge, "scale", Vector2.ONE, 0.32 if _low_flash_mode else 0.22)


# Applies a short readable hard-stun when delayed support reaches the boss.
func apply_stun(seconds: float) -> void:
	_stun_timer = maxf(seconds, 0.0)
	stunned = _stun_timer > 0.0
	pixel_body.modulate = Color(0.45, 1.0, 0.92, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "rotation", -0.12, 0.08)
	tween.tween_property(self, "rotation", 0.12, 0.12)
	tween.tween_property(self, "rotation", 0.0, 0.1)


# Reveals or conceals the phase core for the final two-event closure.
func set_core_exposed(value: bool) -> void:
	var became_exposed := value and not core_exposed
	core_exposed = value
	core_cold.visible = value
	core_warm.visible = value
	core_hit_area.monitorable = value
	if value:
		core_cold.modulate.a = 0.35
		core_warm.modulate.a = 0.35
	if became_exposed:
		core_open_audio.play()


# Accepts only Xing Yao's heavy-family sword hits while the arrived power window exposes the core.
func receive_attack(payload: Dictionary) -> void:
	if not active or not core_exposed:
		return
	var attack_kind := StringName(payload.get("kind", &""))
	var break_power := int(payload.get("break_power", 0))
	if attack_kind not in [&"heavy", &"counter"] or break_power < 3:
		return
	core_struck.emit(attack_kind, break_power)


# Switches the body ornaments to the active round's purely visual grammar.
func set_round_visual(round_index: int) -> void:
	for plate: Line2D in armor_plates:
		plate.visible = round_index == 1
		plate.modulate = Color.WHITE
		plate.scale = Vector2.ONE
		plate.rotation = 0.0
	for clamp: Node2D in trap_clamps:
		clamp.visible = false
		clamp.modulate = Color.WHITE
		clamp.scale = Vector2(1.55, 1.55)
	core_cold.visible = round_index == 3
	core_warm.visible = round_index == 3
	core_cold.position = Vector2(-8, 28)
	core_warm.position = Vector2(8, 28)
	core_cold.modulate.a = 0.35
	core_warm.modulate.a = 0.35


# Starts a restrained crack motion on one armor layer while its event is in flight.
func begin_armor_crack(index: int, duration: float) -> void:
	if index < 1 or index > armor_plates.size():
		return
	var plate := armor_plates[index - 1]
	plate.visible = true
	plate.modulate = Color(1.0, 0.62, 0.32, 0.92)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_rotation := (0.06 if index % 2 == 0 else -0.06)
	tween.parallel().tween_property(plate, ^"rotation", target_rotation, maxf(duration, 0.05))
	tween.parallel().tween_property(plate, ^"scale", Vector2(1.08, 0.96), maxf(duration, 0.05))
	_track_visual_tween(tween)


# Breaks one armor layer exactly when its delayed destruction reaches the boss.
func break_armor_plate(index: int) -> void:
	if index < 1 or index > armor_plates.size():
		return
	var plate := armor_plates[index - 1]
	armor_break_audio.play()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(plate, ^"scale", Vector2(1.45, 0.38), 0.34 if _low_flash_mode else 0.22)
	tween.parallel().tween_property(plate, ^"modulate:a", 0.0, 0.34 if _low_flash_mode else 0.22)
	tween.tween_callback(plate.hide)
	_track_visual_tween(tween)


# Reveals the next symbol-matched clamp around the boss before its event arrives.
func show_trap_target(index: int) -> void:
	if index < 1 or index > trap_clamps.size():
		return
	var clamp := trap_clamps[index - 1]
	clamp.visible = true
	clamp.scale = Vector2(1.55, 1.55)
	clamp.modulate = Color(1, 1, 1, 0.28)


# Closes one trap clamp on success or visibly fractures it on a missed window.
func resolve_trap(index: int, success: bool) -> void:
	if index < 1 or index > trap_clamps.size():
		return
	var clamp := trap_clamps[index - 1]
	clamp.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if success:
		clamp_audio.play()
		clamp.modulate = Color(0.58, 1.0, 0.92, 0.95)
		tween.tween_property(clamp, ^"scale", Vector2.ONE, 0.28)
	else:
		clamp.modulate = Color(1.0, 0.24, 0.14, 0.95)
		tween.parallel().tween_property(clamp, ^"scale", Vector2(1.8, 0.35), 0.28)
		tween.parallel().tween_property(clamp, ^"modulate:a", 0.0, 0.28)
		tween.tween_callback(clamp.hide)
	_track_visual_tween(tween)


# Begins cold-half charging while Lu Heng's final power event is still travelling.
func begin_final_power_charge(duration: float) -> void:
	core_cold.visible = true
	core_cold.modulate.a = 0.28
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(core_cold, ^"modulate:a", 0.78 if not _low_flash_mode else 0.58, maxf(duration, 0.05))
	_track_visual_tween(tween)


# Marks Lu Heng's arrived power half as complete before Xing Yao's strike.
func complete_final_power_half() -> void:
	_complete_core_half(core_cold)


# Marks Xing Yao's heavy-strike half as complete before both halves close.
func complete_final_strike_half() -> void:
	_complete_core_half(core_warm)


# Applies the shared completed-half pose to one authored core visual.
func _complete_core_half(half: Polygon2D) -> void:
	half.visible = true
	half.modulate.a = 1.0
	half.scale = Vector2(1.12, 1.12)


# Fades the first arrived half over the real four-second pairing window.
func show_final_window(has_power: bool, has_core: bool, seconds_left: float) -> void:
	if _final_decay_tween != null and _final_decay_tween.is_valid():
		_final_decay_tween.kill()
	var first_half := core_cold if has_power and not has_core else core_warm
	first_half.modulate.a = 1.0
	_final_decay_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_final_decay_tween.tween_property(first_half, ^"modulate:a", 0.2, maxf(seconds_left, 0.05))


# Pulls both charged halves together when the paired arrival succeeds.
func close_final_core() -> void:
	if _final_decay_tween != null and _final_decay_tween.is_valid():
		_final_decay_tween.kill()
	core_cold.modulate.a = 1.0
	core_warm.modulate.a = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core_cold, ^"position", Vector2(0, 28), 0.24)
	tween.parallel().tween_property(core_warm, ^"position", Vector2(0, 28), 0.24)
	tween.parallel().tween_property(core_cold, ^"scale", Vector2(1.2, 1.2), 0.24)
	tween.parallel().tween_property(core_warm, ^"scale", Vector2(1.2, 1.2), 0.24)
	_track_visual_tween(tween)


# Applies stable, slower peaks to every boss effect when accessibility mode is enabled.
func set_low_flash_mode(value: bool) -> void:
	_low_flash_mode = value
	warning_halo.modulate.a = 0.55 if value else 0.9


# Clears queued-event ornaments without changing the boss state machine.
func clear_boss_event_visuals() -> void:
	_kill_visual_tweens()
	if _final_decay_tween != null and _final_decay_tween.is_valid():
		_final_decay_tween.kill()
	for plate: Line2D in armor_plates:
		plate.visible = false
		plate.modulate = Color.WHITE
		plate.scale = Vector2.ONE
	for clamp: Node2D in trap_clamps:
		clamp.visible = false
		clamp.modulate = Color.WHITE
		clamp.scale = Vector2.ONE
	core_cold.visible = false
	core_warm.visible = false
	phase_shards.visible = false


# Removes the visual body after the final causal closure succeeds.
func defeat() -> void:
	active = false
	core_hit_area.monitorable = false
	warning_halo.visible = false
	attack_charge.visible = false
	defeat_audio.play()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2(1.8, 0.1), 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hide)


# Tracks one disposable visual tween so a timeline reset can stop it immediately.
func _track_visual_tween(tween: Tween) -> void:
	_visual_tweens.append(tween)


# Stops every tracked boss ornament tween before authored state is restored.
func _kill_visual_tweens() -> void:
	for tween: Tween in _visual_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_visual_tweens.clear()
