class_name PhaseParasite
extends CharacterBody2D
## Small phase parasite that attaches through explicit equipment-interference contracts.

signal attached(target: Node, mode: StringName)
signal detached(target: Node)
signal defeated(parasite: PhaseParasite)
signal remote_collapse_changed(collapsed: bool)
signal leap_warning_started(seconds: float, direction: float)
signal leap_launched(direction: float)

enum State {
	CRAWL,
	LEAP_WARNING,
	LEAP,
	ATTACHED,
	HIT,
	DEAD,
}

@export_range(1, 5, 1) var max_health: int = 2
@export_range(20.0, 240.0, 1.0, "suffix:px/s") var crawl_speed: float = 78.0
@export var default_interference_mode: StringName = &"cut"
@export var destroyed_link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.XING_YAO
@export var destroyed_delay_override: float = -1.0
@export_range(0, 4, 1) var required_break_power: int = 0
@export var auto_hunt_player: bool = false
@export_range(48.0, 600.0, 1.0, "suffix:px") var leap_range: float = 375.0
@export_range(120.0, 520.0, 1.0, "suffix:px/s") var leap_speed: float = 280.0
@export_range(120.0, 520.0, 1.0, "suffix:px/s") var leap_height: float = 290.0
@export_range(0.4, 4.0, 0.1, "suffix:s") var leap_cooldown: float = 1.2
@export_range(0.2, 1.2, 0.05, "suffix:s") var leap_warning_time: float = 0.45
@export_range(-1, 2, 1) var pair_marker_variant: int = -1

var health: int = 2
var state: State = State.CRAWL
var interference_target: Node
var _interference_mode: StringName = &""
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var _leap_cooldown_left: float = 0.0
var _leap_warning_left: float = 0.0
var _leap_direction: float = 1.0
var _target_player: PhasePlayer
var _warning_tween: Tween

@onready var visual_group: Node2D = $VisualGroup
@onready var ground_alien_sprite: AnimatedSprite2D = $VisualGroup/GroundAlienSprite
@onready var attach_ring: Line2D = $VisualGroup/AttachRing
@onready var armor_shell: Line2D = $VisualGroup/ArmorShell
@onready var pair_markers: Array[Polygon2D] = [$VisualGroup/PairMarker/Triangle, $VisualGroup/PairMarker/Diamond, $VisualGroup/PairMarker/Bars]
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sight_ray: RayCast2D = $SightRay
@onready var attack_area: Area2D = $AttackArea
@onready var leap_warning: Node2D = $LeapWarning
@onready var warning_arrow: Polygon2D = $LeapWarning/Arrow
@onready var core_light: PointLight2D = $CoreLight
@onready var hit_particles: GPUParticles2D = $HitParticles
@onready var block_particles: GPUParticles2D = $BlockParticles
@onready var collapse_particles: GPUParticles2D = $CollapseParticles
@onready var move_audio: AudioStreamPlayer2D = $MoveAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio
@onready var block_audio: AudioStreamPlayer2D = $BlockAudio
@onready var warning_audio: AudioStreamPlayer2D = $WarningAudio
@onready var leap_audio: AudioStreamPlayer2D = $LeapAudio
@onready var collapse_audio: AudioStreamPlayer2D = $CollapseAudio


# Initializes the reusable enemy at full health and acquires its local role target.
func _ready() -> void:
	health = max_health
	_target_player = _find_target_player()
	attach_ring.visible = false
	armor_shell.visible = required_break_power > 0
	leap_warning.visible = false
	attack_area.body_entered.connect(_on_attack_body_entered)
	_update_pair_marker()
	_update_animation()


# Runs only compact crawl and gravity behavior while not attached or defeated.
func _physics_process(delta: float) -> void:
	if state in [State.ATTACHED, State.DEAD]:
		velocity = Vector2.ZERO
		_update_animation()
		_update_move_audio()
		return
	if state == State.HIT:
		velocity.x = move_toward(velocity.x, 0.0, crawl_speed * 4.0 * delta)
	elif state == State.LEAP_WARNING:
		_advance_leap_warning(delta)
	elif auto_hunt_player:
		_update_hunt(delta)
	if absf(velocity.x) > 1.0:
		ground_alien_sprite.flip_h = velocity.x > 0.0
	if not is_on_floor():
		velocity.y += _gravity * delta
	move_and_slide()
	if state == State.LEAP:
		_resolve_leap_overlap()
	_update_animation()
	_update_move_audio()
	if state == State.LEAP and is_on_floor() and velocity.y >= 0.0:
		state = State.CRAWL


# Attaches only to an object that exposes the authored parasite-interference interface.
func attach_to_target(target: Node, mode: StringName = &"") -> bool:
	if state == State.DEAD or target == null or not target.has_method("set_phase_interference"):
		return false
	detach_from_target()
	interference_target = target
	_interference_mode = default_interference_mode if mode.is_empty() else mode
	interference_target.call("set_phase_interference", true, _interference_mode)
	state = State.ATTACHED
	attach_ring.visible = true
	attached.emit(interference_target, _interference_mode)
	return true


# Clears the target override while keeping the parasite body available for combat feedback.
func detach_from_target() -> void:
	if interference_target == null:
		return
	var previous_target := interference_target
	previous_target.call("set_phase_interference", false, _interference_mode)
	interference_target = null
	_interference_mode = &""
	attach_ring.visible = false
	if state != State.DEAD:
		state = State.CRAWL
	detached.emit(previous_target)


# Applies one sword payload and permanently clears interference on death.
func receive_attack(payload: Dictionary) -> void:
	if state == State.DEAD:
		return
	var damage := maxi(int(payload.get("damage", 1)), 0)
	var break_power := maxi(int(payload.get("break_power", 0)), 0)
	if break_power < required_break_power:
		block_particles.restart()
		block_particles.emitting = true
		block_audio.play()
		visual_group.modulate = Color(0.42, 0.9, 1.0, 1.0)
		var blocked_tween := create_tween()
		blocked_tween.tween_property(visual_group, ^"modulate", Color.WHITE, 0.14)
		return
	if damage <= 0:
		return
	_stop_leap_warning()
	hit_particles.restart()
	hit_particles.emitting = true
	hit_audio.play()
	core_light.energy = 1.1
	var light_tween := create_tween()
	light_tween.tween_property(core_light, ^"energy", 0.46, 0.18)
	health = maxi(health - damage, 0)
	if health == 0:
		_defeat()
	else:
		state = State.HIT
		velocity.x = float(payload.get("direction", 1.0)) * 150.0
		visual_group.modulate = Color(1.0, 0.35, 0.28, 1.0)
		var tween := create_tween()
		tween.tween_property(visual_group, ^"modulate", Color.WHITE, 0.14)
		tween.tween_callback(_resume_after_hit)


# Reports whether this reusable enemy has reached its terminal corpse state.
func is_defeated() -> bool:
	return state == State.DEAD


# Returns the current compact FSM state for authored encounters and tests.
func get_state() -> State:
	return state


# Collapses this counterpart from a remote destroyed event without sending another event.
func apply_remote_destruction(_event: EntanglementEvent) -> void:
	if state == State.DEAD:
		return
	detach_from_target()
	_stop_leap_warning()
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)
	collapse_particles.restart()
	collapse_particles.emitting = true
	collapse_audio.play()
	core_light.energy = 1.25
	remote_collapse_changed.emit(true)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_group, ^"scale", Vector2(0.2, 1.4), 0.22)
	tween.parallel().tween_property(visual_group, ^"modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(core_light, ^"energy", 0.0, 0.28)
	tween.tween_callback(visual_group.hide)


# Leaves hit-stun only when no attachment or death transition replaced it.
func _resume_after_hit() -> void:
	if state == State.HIT:
		state = State.CRAWL


# Chases the matching local role and launches one readable contact leap.
func _update_hunt(delta: float) -> void:
	_leap_cooldown_left = maxf(_leap_cooldown_left - delta, 0.0)
	if not _target_is_valid():
		_target_player = _find_target_player()
	if _target_player == null:
		velocity.x = 0.0
		return
	if not _has_line_of_sight_to_target():
		velocity.x = move_toward(velocity.x, 0.0, crawl_speed * 4.0 * delta)
		return
	var offset := _target_player.global_position - global_position
	if state in [State.LEAP_WARNING, State.LEAP]:
		return
	if absf(offset.x) <= leap_range and _leap_cooldown_left <= 0.0 and is_on_floor():
		_begin_leap_warning(signf(offset.x))
		return
	velocity.x = signf(offset.x) * crawl_speed


# Starts one stationary warning window before the parasite commits to its leap direction.
func _begin_leap_warning(direction: float) -> void:
	state = State.LEAP_WARNING
	velocity = Vector2.ZERO
	_leap_direction = 1.0 if is_zero_approx(direction) else direction
	_leap_warning_left = leap_warning_time
	leap_warning.visible = true
	leap_warning.modulate.a = 0.3
	warning_arrow.scale.x = _leap_direction
	warning_audio.play()
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_property(leap_warning, ^"modulate:a", 1.0, leap_warning_time)
	leap_warning_started.emit(leap_warning_time, _leap_direction)


# Launches the committed leap only after the full authored warning duration has elapsed.
func _advance_leap_warning(delta: float) -> void:
	_leap_warning_left = maxf(_leap_warning_left - delta, 0.0)
	if _leap_warning_left > 0.0:
		return
	leap_warning.visible = false
	state = State.LEAP
	velocity = Vector2(_leap_direction * leap_speed, -leap_height)
	leap_audio.play()
	leap_launched.emit(_leap_direction)


# Cancels a pending leap when damage, death, or a remote collapse replaces it.
func _stop_leap_warning() -> void:
	_leap_warning_left = 0.0
	leap_warning.visible = false
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()


# Finds the matching authored role inside this parasite's own SubViewport.
func _find_target_player() -> PhasePlayer:
	var fallback: PhasePlayer
	var target_role := PhasePlayer.Role.LU_HENG if side == EntangledEntity.Side.LU_HENG else PhasePlayer.Role.XING_YAO
	for candidate: Node in get_tree().get_nodes_in_group("phase_players"):
		var player := candidate as PhasePlayer
		if player == null or player.role != target_role or player.get_viewport() != get_viewport() or player.departed:
			continue
		if fallback == null:
			fallback = player
		if player.controlled:
			return player
	return fallback


# Rejects crawl pursuit and leap windup while solid room geometry blocks sight.
func _has_line_of_sight_to_target() -> bool:
	if _target_player == null:
		return false
	var origin := global_position + Vector2(0.0, -48.0)
	var space_state := get_world_2d().direct_space_state
	# Two samples prevent a low wall or raised platform from being ignored by a
	# ray that only checks the target's upper silhouette.
	for target_position: Vector2 in [
		_target_player.global_position + Vector2(0.0, -54.0),
		_target_player.global_position + Vector2(0.0, -10.0),
	]:
		var query := PhysicsRayQueryParameters2D.create(origin, target_position, 4, [get_rid()])
		if not space_state.intersect_ray(query).is_empty():
			return false
	return true


# Keeps a cached parasite target valid after a room exit or ownership change.
func _target_is_valid() -> bool:
	return (
		_target_player != null
		and is_instance_valid(_target_player)
		and _target_player.get_viewport() == get_viewport()
		and not _target_player.departed
	)


# Samples players who entered the attack area during the warning rather than the leap.
func _resolve_leap_overlap() -> void:
	for body: Node2D in attack_area.get_overlapping_bodies():
		if _try_leap_attack(body as PhasePlayer):
			return


# Damages or gets countered when a leap reaches the authored player body.
func _try_leap_attack(player: PhasePlayer) -> bool:
	if player == null or player.departed or player.get_viewport() != get_viewport() or state != State.LEAP:
		return false
	if player.try_counter_incoming_attack():
		receive_attack({"damage": 4, "break_power": 4, "kind": &"counter"})
	else:
		player.take_damage(1)
		_recoil_from_player(player)
	return true


# Bounces away after a completed leap so blocked and damaging hits both read clearly.
func _recoil_from_player(player: PhasePlayer) -> void:
	if state == State.DEAD:
		return
	var retreat_direction := -signf(player.global_position.x - global_position.x)
	if is_zero_approx(retreat_direction):
		retreat_direction = 1.0
	state = State.HIT
	_leap_cooldown_left = leap_cooldown
	velocity = Vector2(retreat_direction * crawl_speed * 3.2, -80.0)
	visual_group.modulate = Color(0.52, 1.0, 0.84, 1.0)
	var tween := create_tween()
	tween.tween_property(visual_group, ^"modulate", Color.WHITE, 0.22)
	tween.tween_callback(_resume_after_hit)


# Routes a newly entered body through the same overlap-safe leap attack.
func _on_attack_body_entered(body: Node2D) -> void:
	_try_leap_attack(body as PhasePlayer)


# Displays one of three non-text pair shapes shared by both entangled parasites.
func _update_pair_marker() -> void:
	for index in pair_markers.size():
		pair_markers[index].visible = index == pair_marker_variant


# Maps the sourced ground-alien walk frames onto the compact parasite FSM.
func _update_animation() -> void:
	var next_animation: StringName = &"crawl"
	match state:
		State.LEAP:
			next_animation = &"leap"
		State.ATTACHED:
			next_animation = &"attached"
		State.HIT:
			next_animation = &"hit"
		State.DEAD:
			next_animation = &"dead"
	if ground_alien_sprite.animation != next_animation:
		ground_alien_sprite.play(next_animation)


# Plays the sourced movement loop only while the parasite is actively mobile.
func _update_move_audio() -> void:
	var should_play := state in [State.CRAWL, State.LEAP_WARNING, State.LEAP] and (auto_hunt_player or absf(velocity.x) > 1.0)
	if should_play and not move_audio.playing:
		move_audio.play()
	elif not should_play and move_audio.playing:
		move_audio.stop()


# Clears the target, disables further collision, and emits one optional destroyed event.
func _defeat() -> void:
	detach_from_target()
	_stop_leap_warning()
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)
	collapse_particles.restart()
	collapse_particles.emitting = true
	collapse_audio.play()
	var collapse_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	collapse_tween.parallel().tween_property(visual_group, ^"scale", Vector2(1.35, 0.18), 0.24)
	collapse_tween.parallel().tween_property(visual_group, ^"modulate:a", 0.0, 0.28)
	collapse_tween.parallel().tween_property(core_light, ^"energy", 0.0, 0.28)
	collapse_tween.tween_callback(visual_group.hide)
	if not destroyed_link_id.is_empty():
		EntanglementBus.emit_event(
			destroyed_link_id,
			EntanglementBus.DESTROYED,
			{"value": true, "enemy": &"phase_parasite"},
			side,
			destroyed_delay_override
		)
	defeated.emit(self)
