class_name FacilityGuard
extends CharacterBody2D
## Powered security machine with autonomous attacks and a pushable pressure-weight corpse.

signal armor_changed(powered: bool)
signal armor_blocked
signal attack_warned(player: PhasePlayer, duration: float)
signal charge_started(direction: float)
signal staggered
signal defeated(guard: FacilityGuard)
signal remote_collapse_changed(collapsed: bool)

enum State {
	PATROL,
	CHARGE_WINDUP,
	CHARGE,
	ATTACK,
	STAGGER,
	SHUTDOWN,
	CORPSE,
}

@export_range(1, 20, 1) var max_health: int = 6
@export_range(40.0, 320.0, 1.0, "suffix:px/s") var patrol_speed: float = 92.0
@export_range(120.0, 720.0, 1.0, "suffix:px/s") var charge_speed: float = 420.0
@export_range(120.0, 900.0, 1.0, "suffix:px") var detection_range: float = 640.0
@export_range(48.0, 360.0, 1.0, "suffix:px") var melee_range: float = 240.0
@export_range(96.0, 480.0, 1.0, "suffix:px") var charge_min_range: float = 210.0
@export_range(180.0, 900.0, 1.0, "suffix:px") var charge_max_range: float = 560.0
@export_range(80.0, 520.0, 1.0, "suffix:px/s") var heavy_push_speed: float = 260.0
@export_range(80.0, 520.0, 1.0, "suffix:px/s") var corpse_push_speed: float = 320.0
@export_range(0.5, 4.0, 0.1) var corpse_weight: float = 1.5
@export var starts_armor_powered: bool = true
@export var auto_hunt_player: bool = true
@export var destroyed_link_id: StringName = &""
@export var destroyed_delay_override: float = -1.0
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.XING_YAO

var health: int = 6
var armor_powered: bool = true
var state: State = State.PATROL
var facing: float = -1.0
var _state_time: float = 0.0
var _attack_cooldown: float = 0.0
var _charge_cooldown: float = 0.0
var _attack_landed: bool = false
var _target_player: PhasePlayer
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var _room_unloading: bool = false

@onready var visual_group: CanvasGroup = $VisualGroup
@onready var biped_sprite: AnimatedSprite2D = $VisualGroup/BipedSprite
@onready var armor_field: Polygon2D = $VisualGroup/ArmorField
@onready var eye: Polygon2D = $VisualGroup/Eye
@onready var charge_warning: Line2D = $VisualGroup/ChargeWarning
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sight_ray: RayCast2D = $SightRay
@onready var charge_hit_area: Area2D = $ChargeHitArea
@onready var charge_audio: AudioStreamPlayer2D = $ChargeAudio
@onready var impact_audio: AudioStreamPlayer2D = $ImpactAudio


# Initializes stable armor, local targeting, combat state, and authored contact callbacks.
func _ready() -> void:
	health = max_health
	armor_powered = starts_armor_powered
	_target_player = _find_target_player()
	charge_hit_area.body_entered.connect(_on_charge_hit_body_entered)
	charge_hit_area.monitoring = false
	charge_warning.visible = false
	_update_armor_visual()
	_update_animation()


# Advances the autonomous FSM, gravity, retained corpse motion, and charge collisions.
func _physics_process(delta: float) -> void:
	if not _physics_space_ready():
		return
	advance_state(delta)
	biped_sprite.flip_h = facing > 0.0
	if not is_on_floor():
		velocity.y += _gravity * delta
	move_and_slide()
	_update_animation()
	if state == State.CHARGE:
		_resolve_charge_overlap()
		if state == State.CHARGE:
			_resolve_charge_slide_collisions()


# Rejects physics work after the authored room has left the PhysicsServer space.
func _physics_space_ready() -> bool:
	if _room_unloading or not is_inside_tree():
		return false
	var world := get_world_2d()
	if world == null or not world.space.is_valid():
		return false
	return PhysicsServer2D.body_get_space(get_rid()).is_valid()


# Makes a pending room removal inert before the body can leave its physics space.
func prepare_for_room_unload() -> void:
	_room_unloading = true
	velocity = Vector2.ZERO
	charge_hit_area.set_deferred("monitoring", false)
	set_physics_process(false)


# Marks this body inert during direct scene-tree removal as a final lifecycle guard.
func _exit_tree() -> void:
	_room_unloading = true


# Advances targeting, attack windows, cooldowns, and deterministic state timers.
func advance_state(delta: float) -> void:
	if delta <= 0.0:
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_charge_cooldown = maxf(_charge_cooldown - delta, 0.0)
	match state:
		State.PATROL:
			_advance_patrol(delta)
		State.CHARGE_WINDUP, State.ATTACK, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		State.CHARGE:
			velocity.x = facing * charge_speed
			_update_charge_hitbox()
		State.SHUTDOWN, State.CORPSE:
			velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
	if state == State.ATTACK and not _attack_landed and _state_time <= 0.18:
		_attack_landed = true
		_resolve_melee_strike()
	if _state_time <= 0.0:
		return
	_state_time = maxf(_state_time - delta, 0.0)
	if state == State.ATTACK and not _attack_landed and _state_time <= 0.18:
		_attack_landed = true
		_resolve_melee_strike()
	if _state_time > 0.0:
		return
	match state:
		State.CHARGE_WINDUP:
			_start_charge_motion()
		State.CHARGE:
			_end_charge(false)
		State.ATTACK:
			state = State.PATROL
			_attack_cooldown = 0.72
		State.STAGGER:
			state = State.PATROL
		State.SHUTDOWN:
			_enter_corpse()


# Starts one readable charge used by both autonomous behavior and authored tests.
func begin_charge(direction: float) -> bool:
	if state in [State.CORPSE, State.SHUTDOWN] or is_zero_approx(direction):
		return false
	facing = signf(direction)
	state = State.CHARGE_WINDUP
	_state_time = 0.46
	velocity.x = 0.0
	charge_audio.play()
	charge_warning.visible = true
	charge_warning.scale = Vector2(facing * 1.2, 1.2)
	charge_warning.modulate.a = 0.92
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(charge_warning, ^"scale", Vector2(facing * 0.88, 0.88), _state_time)
	tween.parallel().tween_property(charge_warning, ^"modulate:a", 0.25, _state_time)
	if _target_player != null:
		attack_warned.emit(_target_player, _state_time)
	charge_started.emit(facing)
	return true


# Routes one horizontal charge impact into an authored cracked-wall contract.
func notify_charge_collision(target: Node) -> bool:
	if state != State.CHARGE or target == null or not target.has_method("break_from_guard_charge"):
		return false
	var broke := bool(target.call("break_from_guard_charge", self))
	if broke:
		_enter_stagger(0.42)
	return broke


# Updates external armor power after the entangled child receives a delayed event.
func set_armor_powered(value: bool) -> void:
	if state in [State.CORPSE, State.SHUTDOWN]:
		return
	if armor_powered == value:
		_update_armor_visual()
		return
	armor_powered = value
	_update_armor_visual()
	armor_changed.emit(armor_powered)


# Applies sword damage, heavy push, armor blocking, and retained-corpse movement.
func receive_attack(payload: Dictionary) -> void:
	var damage := maxi(int(payload.get("damage", 1)), 0)
	var break_power := maxi(int(payload.get("break_power", 0)), 0)
	var direction := signf(float(payload.get("direction", 1.0)))
	if is_zero_approx(direction):
		direction = 1.0
	if state == State.CORPSE:
		if break_power >= 2:
			_apply_push(direction, corpse_push_speed)
		return
	if state == State.SHUTDOWN:
		return
	if armor_powered:
		armor_blocked.emit()
		impact_audio.play()
		_flash_color(Color(0.35, 0.92, 1.0, 1.0))
		return
	if damage > 0:
		health = maxi(health - damage, 0)
		impact_audio.play()
	if health == 0:
		_begin_shutdown()
		if break_power >= 2:
			_apply_push(direction, corpse_push_speed)
		return
	if break_power >= 2:
		_apply_push(direction, heavy_push_speed)
		_enter_stagger(0.32)
	if damage > 0:
		_flash_color(Color(1.0, 0.38, 0.24, 1.0))


# Reports whether the machine has completed shutdown and become a corpse weight.
func is_defeated() -> bool:
	return state == State.CORPSE


# Collapses a passive counterpart in place while retaining its pressure weight.
func apply_remote_destruction(_event: EntanglementEvent) -> void:
	if state == State.CORPSE:
		return
	health = 0
	armor_powered = false
	state = State.CORPSE
	velocity = Vector2.ZERO
	charge_hit_area.set_deferred("monitoring", false)
	charge_warning.visible = false
	impact_audio.play()
	_update_armor_visual()
	_update_animation()
	visual_group.modulate = Color(0.58, 0.62, 0.62, 1.0)
	remote_collapse_changed.emit(true)


# Returns weight only after the guard body has become a stable retained corpse.
func get_pressure_weight() -> float:
	return corpse_weight if state == State.CORPSE else 0.0


# Chooses melee, charge, or chase movement from the nearest matching local role.
func _advance_patrol(delta: float) -> void:
	if not auto_hunt_player:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	if not _target_is_valid():
		_target_player = _find_target_player()
	if _target_player == null or _target_player.departed:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	if not _has_line_of_sight_to_target():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	var offset := _target_player.global_position - global_position
	var distance_x := absf(offset.x)
	if distance_x > detection_range:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	if not is_zero_approx(offset.x):
		facing = signf(offset.x)
	if distance_x <= melee_range and _attack_cooldown <= 0.0:
		_begin_melee_attack()
		return
	if distance_x >= charge_min_range and distance_x <= charge_max_range and _charge_cooldown <= 0.0 and is_on_floor():
		begin_charge(facing)
		return
	velocity.x = facing * patrol_speed


# Opens one ordinary melee warning whose precision-counter timing is optional.
func _begin_melee_attack() -> void:
	state = State.ATTACK
	_state_time = 0.34
	_attack_landed = false
	velocity.x = 0.0
	eye.color = Color(1.0, 0.44, 0.18, 1.0)
	charge_warning.visible = true
	charge_warning.scale = Vector2(facing * 0.82, 0.82)
	charge_warning.modulate.a = 0.9
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(charge_warning, ^"scale", Vector2(facing * 1.12, 1.12), _state_time)
	tween.parallel().tween_property(charge_warning, ^"modulate:a", 0.0, _state_time)
	tween.tween_callback(charge_warning.hide)
	if _target_player != null:
		attack_warned.emit(_target_player, _state_time)


# Resolves one melee active frame against the currently tracked local player.
func _resolve_melee_strike() -> void:
	if _target_player == null or not is_instance_valid(_target_player):
		return
	if global_position.distance_to(_target_player.global_position) > melee_range + 105.0:
		return
	if _target_player.try_counter_incoming_attack():
		receive_attack({"damage": 4, "break_power": 4, "kind": &"counter", "direction": -facing})
	else:
		impact_audio.play()
		_target_player.take_damage(1)
		_attack_cooldown = 0.72
		velocity.x = -facing * 220.0
		_enter_stagger(0.28)


# Enables the authored forward hit area when the windup completes.
func _start_charge_motion() -> void:
	state = State.CHARGE
	_state_time = 0.72
	charge_warning.visible = false
	charge_hit_area.monitoring = true
	_update_charge_hitbox()


# Positions the authored charge contact area on the current facing side.
func _update_charge_hitbox() -> void:
	charge_hit_area.position.x = 145.0 * facing
	charge_hit_area.scale.x = facing


# Ends charge contact and optionally enters readable impact stagger.
func _end_charge(with_stagger: bool) -> void:
	charge_hit_area.set_deferred("monitoring", false)
	_charge_cooldown = 1.8
	if with_stagger:
		_enter_stagger(0.38)
	else:
		state = State.PATROL
		velocity.x = 0.0


# Applies charge damage or the optional precision counter when the player is reached.
func _on_charge_hit_body_entered(body: Node2D) -> void:
	var player := body as PhasePlayer
	if player == null or state != State.CHARGE:
		return
	if player.try_counter_incoming_attack():
		receive_attack({"damage": 4, "break_power": 4, "kind": &"counter", "direction": -facing})
	else:
		impact_audio.play()
		player.take_damage(1, true)
		player.velocity.x = facing * 360.0
	_end_charge(true)


# Samples a player already inside the charge area when its windup ends.
func _resolve_charge_overlap() -> void:
	for body: Node2D in charge_hit_area.get_overlapping_bodies():
		if body is PhasePlayer:
			_on_charge_hit_body_entered(body)
			return


# Converts horizontal CharacterBody collisions into player hits, wall breaks, or stagger.
func _resolve_charge_slide_collisions() -> void:
	for index in get_slide_collision_count():
		var slide := get_slide_collision(index)
		if absf(slide.get_normal().x) < 0.65:
			continue
		var collider := slide.get_collider() as Node
		if collider is PhasePlayer:
			_on_charge_hit_body_entered(collider)
			return
		if notify_charge_collision(collider):
			return
		_end_charge(true)
		return


# Finds the matching authored role inside this guard's own SubViewport.
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


# Rejects melee and charge acquisition while authored walls or closed doors block sight.
func _has_line_of_sight_to_target() -> bool:
	if _target_player == null:
		return false
	var origin := global_position + Vector2(0.0, -64.0)
	var space_state := get_world_2d().direct_space_state
	# Check both the torso and lower body. A single high ray can pass over a
	# bulkhead, making the guard acquire a player who is visibly behind cover.
	for target_position: Vector2 in [
		_target_player.global_position + Vector2(0.0, -54.0),
		_target_player.global_position + Vector2(0.0, -10.0),
	]:
		var query := PhysicsRayQueryParameters2D.create(origin, target_position, 4, [get_rid()])
		if not space_state.intersect_ray(query).is_empty():
			return false
	return true


# Keeps a cached guard target valid after departure, reset, or viewport changes.
func _target_is_valid() -> bool:
	return (
		_target_player != null
		and is_instance_valid(_target_player)
		and _target_player.get_viewport() == get_viewport()
		and not _target_player.departed
	)


# Applies one directional sword impulse to a living guard or retained corpse.
func _apply_push(direction: float, speed: float) -> void:
	velocity.x = direction * speed
	facing = -direction


# Enters one bounded stagger state and disables active charge contact.
func _enter_stagger(duration: float) -> void:
	charge_hit_area.set_deferred("monitoring", false)
	state = State.STAGGER
	_state_time = maxf(duration, 0.01)
	staggered.emit()


# Begins a short shutdown while preserving the body as usable level geometry.
func _begin_shutdown() -> void:
	armor_powered = false
	_update_armor_visual()
	state = State.SHUTDOWN
	_state_time = 0.0
	_enter_corpse()


# Converts the machine into a retained pressure-plate body and emits one optional result.
func _enter_corpse() -> void:
	if state == State.CORPSE:
		return
	state = State.CORPSE
	velocity = Vector2.ZERO
	charge_hit_area.set_deferred("monitoring", false)
	charge_warning.visible = false
	eye.color = Color(0.18, 0.24, 0.24, 0.8)
	visual_group.modulate = Color(0.58, 0.62, 0.62, 1.0)
	_update_animation()
	if not destroyed_link_id.is_empty():
		EntanglementBus.emit_event(
			destroyed_link_id,
			EntanglementBus.DESTROYED,
			{"value": true, "enemy": &"facility_guard"},
			side,
			destroyed_delay_override
		)
	defeated.emit(self)


# Keeps the seven-frame authored sheet synchronized with the guard FSM.
func _update_animation() -> void:
	var next_animation: StringName = &"idle"
	match state:
		State.PATROL:
			next_animation = &"walk" if absf(velocity.x) > 1.0 else &"idle"
		State.CHARGE_WINDUP:
			next_animation = &"charge_windup"
		State.CHARGE:
			next_animation = &"charge"
		State.ATTACK:
			next_animation = &"attack"
		State.STAGGER:
			next_animation = &"stagger"
		State.SHUTDOWN:
			next_animation = &"shutdown"
		State.CORPSE:
			next_animation = &"corpse"
	biped_sprite.rotation = -PI * 0.5 if state == State.CORPSE else 0.0
	if biped_sprite.animation != next_animation:
		biped_sprite.play(next_animation)


# Updates the authored shield silhouette without changing underlying health.
func _update_armor_visual() -> void:
	if not is_node_ready():
		return
	armor_field.visible = armor_powered and state not in [State.CORPSE, State.SHUTDOWN]
	eye.color = Color(0.4, 1.0, 0.86, 1.0) if armor_powered else Color(1.0, 0.48, 0.2, 1.0)


# Plays restrained impact feedback while leaving combat state ownership explicit.
func _flash_color(color: Color) -> void:
	if not is_node_ready():
		return
	visual_group.modulate = color
	var tween := create_tween()
	tween.tween_property(visual_group, ^"modulate", Color.WHITE, 0.16)
