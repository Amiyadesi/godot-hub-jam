class_name PhasePlayer
extends CharacterBody2D
## Shared responsive platform body composed with role-specific authored action controllers.

signal primary_requested(player: PhasePlayer)
signal secondary_requested(player: PhasePlayer)
signal failed(player: PhasePlayer, reason: StringName)
signal health_changed(player: PhasePlayer, health: int, max_health: int)
signal defended(player: PhasePlayer)
signal dodge_started(player: PhasePlayer)
signal attack_feedback(player: PhasePlayer)

enum Role {
	LU_HENG,
	XING_YAO,
}

@export_enum("陆衡", "星遥") var role: int = Role.LU_HENG
@export_range(1, 2, 1) var control_slot: int = 1
@export var move_speed: float = 260.0
@export var jump_velocity: float = -510.0
@export var dash_speed: float = 590.0
@export var max_health: int = 2
@export var lu_heng_visual: PhaseCharacterVisualConfig
@export var xing_yao_visual: PhaseCharacterVisualConfig

var controlled: bool = false
var auto_defend: bool = true
var departed: bool = false
var health: int = 2
var facing: float = 1.0
var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dodge_cooldown: float = 0.0
var _dash_timer: float = 0.0
var _air_dash_available: bool = true
var _failed_once: bool = false
var _defense_tween: Tween
var _action_animation_time: float = 0.0
var _footstep_timer: float = 0.0
var _footstep_index: int = 0

@onready var pixel_sprite: AnimatedSprite2D = $PixelSprite
@onready var dash_afterimage: PhaseDashAfterimage = $DashAfterimage
@onready var magnetic_beam: Line2D = $MagneticBeam
@onready var lu_heng_tools: LuHengToolController = $LuHengToolController
@onready var xing_yao_combat: XingYaoCombatController = $XingYaoCombatController
@onready var footsteps: Array[AudioStreamPlayer2D] = [$FootstepA, $FootstepB]
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var dash_audio: AudioStreamPlayer2D = $DashAudio
@onready var hurt_audio: AudioStreamPlayer2D = $HurtAudio
@onready var defend_audio: AudioStreamPlayer2D = $DefendAudio


# Initializes role health, replaceable visuals, and authored feedback nodes.
func _ready() -> void:
	_configure_role_health(true)
	dash_afterimage.clear()
	magnetic_beam.visible = false
	xing_yao_combat.attack_active.connect(_on_xing_attack_active)
	_update_role_visual()


# Runs movement, role state, dash timing, and fall failure checks.
func _physics_process(delta: float) -> void:
	if departed:
		velocity = Vector2.ZERO
		return
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_action_animation_time = maxf(_action_animation_time - delta, 0.0)
	if role == Role.LU_HENG and controlled:
		lu_heng_tools.update_focus_navigation(_read_focus_navigation_direction(), delta)
	if role == Role.XING_YAO:
		xing_yao_combat.advance(delta)
	if is_on_floor():
		_coyote_timer = 0.12
		_air_dash_available = true
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if _dash_timer > 0.0:
		_dash_timer = maxf(_dash_timer - delta, 0.0)
		velocity.x = facing * dash_speed
		if role == Role.XING_YAO and not is_on_floor():
			velocity.y = 0.0
	else:
		if not is_on_floor():
			velocity.y += _gravity * delta
		if controlled and _role_can_move():
			_read_movement(delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and controlled and _role_can_move():
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	move_and_slide()
	_update_motion_animation()
	_update_footstep_audio(delta)
	if position.y > 790.0 and not _failed_once:
		_failed_once = true
		prepare_for_role_switch()
		failed.emit(self, &"fell")


# Captures reliable discrete actions and delegates them to the active role controller.
func _unhandled_input(event: InputEvent) -> void:
	if not controlled or departed:
		return
	if role == Role.LU_HENG and lu_heng_tools.is_focus_active() and _is_focus_navigation_event(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(_action("jump")):
		_jump_buffer_timer = 0.12
		get_viewport().set_input_as_handled()
	elif event.is_action_released(_action("jump")) and velocity.y < 0.0:
		velocity.y *= 0.5
	if event.is_action_pressed(_action("primary")):
		var focus_was_active := role == Role.LU_HENG and lu_heng_tools.is_focus_active()
		var accepted := lu_heng_tools.request_primary() if role == Role.LU_HENG else xing_yao_combat.request_primary(is_on_floor())
		if accepted:
			primary_requested.emit(self)
			if role == Role.LU_HENG and (focus_was_active or not lu_heng_tools.is_focus_active()):
				play_role_animation(&"grab", 0.18)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(_action("secondary")):
		var accepted := lu_heng_tools.request_secondary() if role == Role.LU_HENG else xing_yao_combat.request_secondary_pressed(is_on_floor())
		if accepted:
			secondary_requested.emit(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(_action("secondary")) and role == Role.XING_YAO:
		xing_yao_combat.request_secondary_released()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(_action("dodge")):
		var consumed := lu_heng_tools.request_dodge() if role == Role.LU_HENG else not xing_yao_combat.request_dodge()
		if not consumed:
			_start_dodge()
		get_viewport().set_input_as_handled()


# Switches player ownership and releases role-specific focus when control leaves.
func set_controlled(value: bool) -> void:
	if departed and value:
		return
	if controlled and not value:
		prepare_for_role_switch()
	controlled = value
	modulate = Color.WHITE if controlled else Color(0.78, 0.82, 0.86, 0.9)


# Changes the physical input slot while preserving the role identity.
func set_control_slot(slot: int) -> void:
	control_slot = clampi(slot, 1, 2)


# Applies role identity, health capacity, and its replaceable animation resource.
func configure_role(new_role: int) -> void:
	role = new_role
	_configure_role_health(true)
	if is_node_ready():
		_update_role_visual()


# Restores position and optionally refills health at a checkpoint or room transition.
func reset_player(spawn_position: Vector2, refill_health: bool = true) -> void:
	prepare_for_role_switch()
	departed = false
	position = spawn_position
	velocity = Vector2.ZERO
	if refill_health:
		health = max_health
	_failed_once = false
	_action_animation_time = 0.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_dodge_cooldown = 0.0
	_dash_timer = 0.0
	_footstep_timer = 0.0
	_footstep_index = 0
	_air_dash_available = true
	if _defense_tween != null and _defense_tween.is_valid():
		_defense_tween.kill()
	dash_afterimage.clear()
	magnetic_beam.visible = false
	pixel_sprite.modulate = Color.WHITE
	modulate = Color.WHITE if controlled else Color(0.78, 0.82, 0.86, 0.9)
	pixel_sprite.play(&"idle")
	health_changed.emit(self, health, max_health)


# Sets inherited room health while clamping it to the role's fixed capacity.
func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(self, health, max_health)


# Applies damage while keeping an unowned role safe from both ordinary and break hits.
func take_damage(amount: int, guard_break: bool = false) -> bool:
	if amount <= 0 or departed:
		return false
	if auto_defend and not controlled:
		if not guard_break:
			_play_auto_defend_feedback()
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(self, health, max_health)
	_flash_damage()
	if health == 0 and not _failed_once:
		_failed_once = true
		prepare_for_role_switch()
		failed.emit(self, &"defeated")
	return true


# Clears both role action controllers before ownership, room, or death transitions.
func prepare_for_role_switch() -> bool:
	var tools_released := lu_heng_tools.prepare_for_role_switch()
	xing_yao_combat.reset_action_state()
	_action_animation_time = 0.0
	_dash_timer = 0.0
	_jump_buffer_timer = 0.0
	dash_afterimage.clear()
	magnetic_beam.visible = false
	if _defense_tween != null and _defense_tween.is_valid():
		_defense_tween.kill()
	pixel_sprite.modulate = Color.WHITE
	if is_node_ready():
		pixel_sprite.play(&"idle")
	return tools_released


# Freezes and protects a character that already crossed its room exit.
func set_departed(value: bool) -> void:
	departed = value
	if departed:
		prepare_for_role_switch()
		controlled = false
		velocity = Vector2.ZERO


# Returns the authored Lu Heng tool child for room wiring and tests.
func get_tool_controller() -> LuHengToolController:
	return lu_heng_tools


# Returns the authored Xing Yao combat child for enemies and tests.
func get_combat_controller() -> XingYaoCombatController:
	return xing_yao_combat


# Lets enemies request the precision counter without treating Lu Heng as Xing Yao.
func try_counter_incoming_attack() -> bool:
	if role != Role.XING_YAO or not controlled:
		return false
	return xing_yao_combat.notify_incoming_attack()


# Plays one required replaceable animation for a bounded action duration.
func play_role_animation(animation_name: StringName, duration: float) -> void:
	if pixel_sprite.sprite_frames == null or not pixel_sprite.sprite_frames.has_animation(animation_name):
		push_error("PhasePlayer role %d is missing required animation '%s'" % [role, animation_name])
		return
	_action_animation_time = maxf(duration, 0.0)
	pixel_sprite.play(animation_name)


# Returns the role-specific action name for the current physical ownership slot.
func _action(kind: String) -> StringName:
	return StringName("p%d_%s" % [control_slot, kind])


# Reports whether the active role state currently permits normal locomotion.
func _role_can_move() -> bool:
	return lu_heng_tools.can_move() if role == Role.LU_HENG else xing_yao_combat.can_move()


# Reads cardinal focus navigation from the current keyboard or controller slot.
func _read_focus_navigation_direction() -> Vector2i:
	if role != Role.LU_HENG or not lu_heng_tools.is_focus_active():
		return Vector2i.ZERO
	var horizontal := Input.get_axis(_action("left"), _action("right"))
	var vertical := Input.get_axis(_action("jump"), _action("down"))
	if absf(horizontal) < 0.35 and absf(vertical) < 0.35:
		return Vector2i.ZERO
	if absf(horizontal) >= absf(vertical):
		return Vector2i(1 if horizontal > 0.0 else -1, 0)
	return Vector2i(0, 1 if vertical > 0.0 else -1)


# Identifies movement actions that must not leak into locomotion during focus.
func _is_focus_navigation_event(event: InputEvent) -> bool:
	return (
		event.is_action(_action("left"))
		or event.is_action(_action("right"))
		or event.is_action(_action("jump"))
		or event.is_action(_action("down"))
	)


# Reads horizontal movement with acceleration and stable facing direction.
func _read_movement(delta: float) -> void:
	var input_x: float = Input.get_axis(_action("left"), _action("right"))
	if not is_zero_approx(input_x):
		velocity.x = move_toward(velocity.x, input_x * move_speed, 1500.0 * delta)
		facing = signf(input_x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1900.0 * delta)


# Starts Lu Heng's grounded dash or Xing Yao's grounded/airborne cancel dash.
func _start_dodge() -> bool:
	if _dodge_cooldown > 0.0:
		return false
	if role == Role.LU_HENG and not is_on_floor():
		return false
	if role == Role.XING_YAO and not is_on_floor():
		if not _air_dash_available:
			return false
		_air_dash_available = false
	_dodge_cooldown = 0.52
	_dash_timer = 0.16
	velocity.x = facing * dash_speed
	play_role_animation(&"dash", 0.22)
	dash_audio.play()
	dash_afterimage.play_from(pixel_sprite, facing)
	dodge_started.emit(self)
	return true


# Plays blade audio on the real active frame while the sprite sheet supplies its own slash arc.
func _on_xing_attack_active(_kind: StringName, _damage: int, _break_power: int) -> void:
	attack_audio.pitch_scale = 1.0 + float(maxi(xing_yao_combat.combo_step - 1, 0)) * 0.08
	attack_audio.play()
	attack_feedback.emit(self)


# Makes an unowned role's protection visible instead of silently swallowing the hit.
func _play_auto_defend_feedback() -> void:
	play_role_animation(&"defend", 0.3)
	defend_audio.play()
	if _defense_tween != null and _defense_tween.is_valid():
		_defense_tween.kill()
	pixel_sprite.modulate = Color(0.48, 1.0, 0.86, 1.0)
	_defense_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_defense_tween.tween_property(pixel_sprite, ^"modulate", Color.WHITE, 0.2)
	defended.emit(self)


# Gives the player a brief red impact flash after taking damage.
func _flash_damage() -> void:
	play_role_animation(&"hurt", 0.24)
	hurt_audio.play()
	pixel_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(pixel_sprite, ^"modulate", Color.WHITE, 0.2)


# Applies the authored replaceable sprite configuration for the current role.
func _update_role_visual() -> void:
	var visual := lu_heng_visual if role == Role.LU_HENG else xing_yao_visual
	if visual == null or visual.sprite_frames == null:
		push_error("PhasePlayer requires a visual configuration for role %d" % role)
		return
	pixel_sprite.sprite_frames = visual.sprite_frames
	pixel_sprite.position = visual.sprite_offset
	pixel_sprite.scale = visual.sprite_scale
	pixel_sprite.play(&"idle")


# Keeps locomotion readable whenever no role action owns the sprite.
func _update_motion_animation() -> void:
	pixel_sprite.flip_h = facing < 0.0
	if _action_animation_time > 0.0:
		return
	if not is_on_floor():
		pixel_sprite.play(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(velocity.x) > 12.0:
		pixel_sprite.play(&"run")
	else:
		pixel_sprite.play(&"idle")


# Plays alternating authored steps only during grounded locomotion.
func _update_footstep_audio(delta: float) -> void:
	if not controlled or not is_on_floor() or absf(velocity.x) < 80.0 or _dash_timer > 0.0:
		_footstep_timer = 0.0
		return
	_footstep_timer = maxf(_footstep_timer - delta, 0.0)
	if _footstep_timer > 0.0:
		return
	var footstep := footsteps[_footstep_index]
	footstep.pitch_scale = 0.96 if _footstep_index == 0 else 1.04
	footstep.play()
	_footstep_index = (_footstep_index + 1) % footsteps.size()
	_footstep_timer = 0.32


# Applies the fixed two-heart and three-heart capacities for the two roles.
func _configure_role_health(refill: bool) -> void:
	max_health = 2 if role == Role.LU_HENG else 3
	if refill:
		health = max_health
	else:
		health = mini(health, max_health)
