class_name PhaseDrone
extends CharacterBody2D
## Lightweight airborne wave enemy that preserves the shared attack and delayed-destruction contracts.

signal defeated(drone: PhaseDrone)
signal remote_collapse_changed(collapsed: bool)

enum State {
	HUNT,
	ATTACK_WINDUP,
	ATTACK_DASH,
	HIT,
	DEAD,
}

@export_range(1, 5, 1) var max_health: int = 2
@export_range(40.0, 320.0, 1.0, "suffix:px/s") var hunt_speed: float = 118.0
@export_range(8.0, 80.0, 1.0, "suffix:px") var hover_amplitude: float = 28.0
@export_range(0.5, 4.0, 0.1, "suffix:Hz") var hover_frequency: float = 1.5
@export_range(96.0, 360.0, 1.0, "suffix:px") var attack_range: float = 235.0
@export_range(0.2, 1.0, 0.05, "suffix:s") var attack_windup: float = 0.38
@export_range(240.0, 720.0, 1.0, "suffix:px/s") var attack_dash_speed: float = 480.0
@export_range(0.15, 0.8, 0.05, "suffix:s") var attack_dash_duration: float = 0.34
@export var destroyed_link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.XING_YAO
@export var destroyed_delay_override: float = -1.0
@export var combat_enabled: bool = true

var health: int = 2
var state: State = State.HUNT
var _hover_origin_y: float = 0.0
var _hover_time: float = 0.0
var _hit_time_left: float = 0.0
var _contact_cooldown: float = 0.0
var _attack_time_left: float = 0.0
var _attack_direction: float = 1.0
var _target_player: PhasePlayer

@onready var visual_group: Node2D = $VisualGroup
@onready var sprite: AnimatedSprite2D = $VisualGroup/Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sight_ray: RayCast2D = $SightRay
@onready var contact_area: Area2D = $ContactArea
@onready var contact_warning: Line2D = $ContactWarning
@onready var hit_particles: GPUParticles2D = $HitParticles
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var core_light: PointLight2D = $CoreLight
@onready var engine_audio: AudioStreamPlayer2D = $EngineAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio


# Starts the authored hover, contact callback, and local target at full health.
func _ready() -> void:
	health = max_health
	_hover_origin_y = position.y
	_target_player = _find_target_player()
	sprite.play(&"idle")
	contact_area.body_entered.connect(_on_contact_body_entered)
	contact_area.monitoring = combat_enabled
	contact_warning.visible = false
	engine_audio.finished.connect(engine_audio.play)
	engine_audio.play()


# Chases the matching local role while keeping one readable airborne hover lane.
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		return
	_hover_time += delta
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_hit_time_left = maxf(_hit_time_left - delta, 0.0)
	if state == State.HIT and _hit_time_left <= 0.0:
		state = State.HUNT
	if combat_enabled:
		match state:
			State.HUNT:
				_update_hunt_target()
			State.ATTACK_WINDUP:
				velocity.x = move_toward(velocity.x, 0.0, hunt_speed * 6.0 * delta)
				_attack_time_left = maxf(_attack_time_left - delta, 0.0)
				if _attack_time_left <= 0.0:
					_start_attack_dash()
			State.ATTACK_DASH:
				velocity.x = _attack_direction * attack_dash_speed
				_attack_time_left = maxf(_attack_time_left - delta, 0.0)
				if _attack_time_left <= 0.0:
					_finish_attack()
			_:
				velocity.x = move_toward(velocity.x, 0.0, hunt_speed * 5.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, hunt_speed * 5.0 * delta)
	_update_contact_warning()
	var hover_target := _hover_origin_y + sin(_hover_time * TAU * hover_frequency) * hover_amplitude
	velocity.y = (hover_target - position.y) * 5.0
	move_and_slide()
	_resolve_contact_overlap()
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0


# Accepts Xing Yao attack payloads and enters a short visible hit reaction.
func receive_attack(payload: Dictionary) -> void:
	if state == State.DEAD:
		return
	var damage := maxi(int(payload.get("damage", 1)), 0)
	if damage <= 0:
		return
	health = maxi(health - damage, 0)
	contact_warning.visible = false
	_attack_time_left = 0.0
	hit_particles.restart()
	hit_particles.emitting = true
	hit_audio.play()
	core_light.energy = 1.2
	visual_group.modulate = Color(1.0, 0.38, 0.28, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(visual_group, ^"modulate", Color.WHITE, 0.16)
	tween.parallel().tween_property(core_light, ^"energy", 0.42, 0.2)
	if health == 0:
		_defeat()
		return
	state = State.HIT
	_hit_time_left = 0.22
	velocity.x = float(payload.get("direction", 1.0)) * 180.0


# Reports the terminal state through the same small enemy query used by encounters.
func is_defeated() -> bool:
	return state == State.DEAD


# Collapses a passive counterpart when its matching remote enemy is destroyed.
func apply_remote_destruction(_event: EntanglementEvent) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	contact_warning.visible = false
	_play_collapse()
	remote_collapse_changed.emit(true)


# Updates the horizontal pursuit target without leaving this enemy's SubViewport.
func _update_hunt_target() -> void:
	if not _target_is_valid():
		_target_player = _find_target_player()
	if _target_player == null:
		velocity.x = 0.0
		return
	if not _has_line_of_sight_to_target():
		velocity.x = 0.0
		return
	var offset_x := _target_player.global_position.x - global_position.x
	if absf(offset_x) <= attack_range and _contact_cooldown <= 0.0:
		_begin_attack_windup(offset_x)
		return
	velocity.x = 0.0 if absf(offset_x) < attack_range * 0.72 else signf(offset_x) * hunt_speed


# Commits the drone to one visible attack direction before its contact dash.
func _begin_attack_windup(offset_x: float) -> void:
	if state != State.HUNT:
		return
	_attack_direction = 1.0 if is_zero_approx(offset_x) else signf(offset_x)
	state = State.ATTACK_WINDUP
	_attack_time_left = attack_windup
	velocity.x = 0.0
	contact_warning.visible = true
	contact_warning.scale = Vector2(_attack_direction * 1.18, 1.18)
	contact_warning.modulate.a = 0.9
	core_light.energy = 0.95
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(contact_warning, ^"scale", Vector2(_attack_direction * 0.86, 0.86), attack_windup)
	tween.parallel().tween_property(contact_warning, ^"modulate:a", 0.38, attack_windup)
	tween.parallel().tween_property(core_light, ^"energy", 1.35, attack_windup)


# Launches the drone only after its complete warning window has elapsed.
func _start_attack_dash() -> void:
	if state != State.ATTACK_WINDUP:
		return
	state = State.ATTACK_DASH
	_attack_time_left = attack_dash_duration
	contact_warning.visible = false
	core_light.energy = 1.4


# Returns an unanswered dash to pursuit and starts the shared contact cooldown.
func _finish_attack() -> void:
	if state != State.ATTACK_DASH:
		return
	state = State.HUNT
	_contact_cooldown = 0.72
	velocity.x = 0.0
	core_light.energy = 0.42


# Keeps the authored forward dash cue visible only during the committed windup.
func _update_contact_warning() -> void:
	if not combat_enabled or state != State.ATTACK_WINDUP:
		contact_warning.visible = false
		return
	contact_warning.visible = true


# Finds the matching role inside this drone's authored universe viewport.
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


# Rejects pursuit and attack windup when authored world collision blocks the target.
func _has_line_of_sight_to_target() -> bool:
	if _target_player == null:
		return false
	var origin := global_position
	var space_state := get_world_2d().direct_space_state
	# Air units use two vertical samples too; this stops a catwalk edge from
	# being treated as transparent when the drone is above or below the player.
	for target_position: Vector2 in [
		_target_player.global_position + Vector2(0.0, -54.0),
		_target_player.global_position + Vector2(0.0, -10.0),
	]:
		var query := PhysicsRayQueryParameters2D.create(origin, target_position, 4, [get_rid()])
		if not space_state.intersect_ray(query).is_empty():
			return false
	return true


# Keeps a cached drone target valid after a room exit or ownership change.
func _target_is_valid() -> bool:
	return (
		_target_player != null
		and is_instance_valid(_target_player)
		and _target_player.get_viewport() == get_viewport()
		and not _target_player.departed
	)


# Samples bodies already inside the contact ring when pursuit reaches them.
func _resolve_contact_overlap() -> void:
	if not combat_enabled or state != State.ATTACK_DASH or _contact_cooldown > 0.0:
		return
	for body: Node2D in contact_area.get_overlapping_bodies():
		if _try_contact_attack(body as PhasePlayer):
			return


# Resolves one contact strike or lets the precision counter destroy the drone.
func _try_contact_attack(player: PhasePlayer) -> bool:
	if player == null or player.departed or player.get_viewport() != get_viewport() or state != State.ATTACK_DASH:
		return false
	_contact_cooldown = 0.9
	if player.try_counter_incoming_attack():
		receive_attack({"damage": max_health, "break_power": 4, "kind": &"counter", "direction": -signf(player.global_position.x - global_position.x)})
	else:
		player.take_damage(1)
		var retreat_direction := -signf(player.global_position.x - global_position.x)
		if is_zero_approx(retreat_direction):
			retreat_direction = 1.0
		state = State.HIT
		_hit_time_left = 0.26
		velocity.x = retreat_direction * hunt_speed * 3.2
	return true


# Routes a newly entered body through the same overlap-safe contact attack.
func _on_contact_body_entered(body: Node2D) -> void:
	if not combat_enabled or state != State.ATTACK_DASH or _contact_cooldown > 0.0:
		return
	_try_contact_attack(body as PhasePlayer)


# Disables combat, plays the authored explosion, and emits one optional delayed result.
func _defeat() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_play_collapse()
	if not destroyed_link_id.is_empty():
		EntanglementBus.emit_event(
			destroyed_link_id,
			EntanglementBus.DESTROYED,
			{"value": true, "enemy": &"phase_drone"},
			side,
			destroyed_delay_override
		)
	defeated.emit(self)


# Plays the shared local or remote drone collapse without sending timeline state.
func _play_collapse() -> void:
	collision.set_deferred("disabled", true)
	contact_area.set_deferred("monitoring", false)
	contact_warning.visible = false
	death_particles.restart()
	death_particles.emitting = true
	engine_audio.stop()
	death_audio.play()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_group, ^"scale", Vector2(1.5, 0.2), 0.28)
	tween.parallel().tween_property(visual_group, ^"modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(core_light, ^"energy", 0.0, 0.28)
	tween.tween_callback(visual_group.hide)
