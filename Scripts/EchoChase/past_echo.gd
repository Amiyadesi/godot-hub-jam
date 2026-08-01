class_name PastEcho
extends Area2D
## 永久延迟体：回放玩家历史并追捕当前体。

signal caught_player

const MATERIALIZE_PREVIEW_SECONDS := 0.35

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var visual: AnimatedSprite2D = %Visual
@onready var outline_visual: AnimatedSprite2D = %OutlineVisual
@onready var history_trail: AnimatedSprite2D = %HistoryTrail
@onready var history_trail_far: AnimatedSprite2D = %HistoryTrailFar
@onready var pixel_burst: GPUParticles2D = %PixelBurst
@onready var vfx_animation_player: AnimationPlayer = %VfxAnimationPlayer
@onready var departure_vfx: TemporalDepartureVfx = %DepartureVfx
@onready var appear_audio: AudioStreamPlayer2D = $AppearAudio

var _active := false
var _phase_shifting := false
var _materializing := false
var _first_materialization_pending := true
var _last_velocity := Vector2.ZERO


# 只连接 authored 玩家与未来体接触检测。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	departure_vfx.finished.connect(_on_departure_finished)
	if SettingsModule.instance != null:
		SettingsModule.instance.settings_changed.connect(_on_setting_changed)
	reset_echo()


# 历史抵达前先预显轮廓，抵达后再启用过去体玩法影响。
func play_at(track: TemporalTrack, playback_time: float) -> void:
	if _phase_shifting:
		return
	if _first_materialization_pending and not track.is_empty():
		var first_time := track.get_start_time()
		if playback_time >= first_time - MATERIALIZE_PREVIEW_SECONDS and playback_time < first_time:
			var first_frame: TemporalFrame = track.sample_at(first_time)
			if first_frame != null:
				_begin_materialization(first_frame)
			return
	var frame: TemporalFrame = track.sample_at(playback_time)
	if frame == null:
		if not _materializing:
			_set_active(false)
		return
	global_position = frame.position
	_apply_frame_visual(frame)
	if _first_materialization_pending:
		if not _materializing:
			_begin_materialization(frame)
		_first_materialization_pending = false
		_materializing = false
	_set_active(true)


# 延迟切档预警期间禁用世界影响。
func begin_phase_shift() -> void:
	_phase_shifting = true
	_materializing = false
	_active = false
	collision_shape.set_deferred("disabled", true)
	if visible:
		departure_vfx.play_from_sprites(visual, outline_visual, _last_velocity)


# 将切档轮廓放到目标历史位置，并从既有预警进度继续播放。
func preview_phase_target(track: TemporalTrack, playback_time: float, elapsed_seconds: float) -> void:
	var frame: TemporalFrame = track.sample_at(playback_time)
	if frame == null:
		return
	global_position = frame.position
	_apply_frame_visual(frame)
	visible = true
	visual.visible = true
	outline_visual.visible = true
	history_trail.visible = true
	history_trail_far.visible = true
	_active = false
	_materializing = true
	var animation_name := &"phase_target_reduced" if _uses_low_flash_mode() else &"phase_target"
	vfx_animation_player.play(animation_name)
	vfx_animation_player.seek(clampf(elapsed_seconds, 0.0, vfx_animation_player.current_animation_length), true)


# 相位预警结束后恢复正常历史回放。
func end_phase_shift() -> void:
	_phase_shifting = false
	_materializing = false


# 干净时间线重置时清除可见、碰撞和预警状态。
func reset_echo() -> void:
	_phase_shifting = false
	_materializing = false
	_first_materialization_pending = true
	_active = false
	visible = false
	visual.flip_h = false
	outline_visual.flip_h = false
	history_trail.flip_h = false
	history_trail_far.flip_h = false
	visual.play(&"idle")
	outline_visual.play(&"idle")
	history_trail.play(&"idle")
	history_trail_far.play(&"idle")
	pixel_burst.emitting = false
	departure_vfx.reset_vfx()
	_last_velocity = Vector2.ZERO
	vfx_animation_player.play(&"RESET")
	collision_shape.set_deferred("disabled", true)


# Removes the past echo with its authored departure snapshot for a present room.
func dissipate() -> void:
	if visible:
		departure_vfx.play_from_sprites(visual, outline_visual, _last_velocity)
	_phase_shifting = false
	_materializing = false
	_first_materialization_pending = true
	_active = false
	vfx_animation_player.stop()
	visual.visible = false
	outline_visual.visible = false
	history_trail.visible = false
	history_trail_far.visible = false
	pixel_burst.emitting = false
	collision_shape.set_deferred("disabled", true)


# 隔离尾效结束后隐藏不再参与时间线的过去体外壳。
func _on_departure_finished() -> void:
	if not _active and not _materializing and not _phase_shifting:
		visible = false


# 返回过去体是否已具备伤害和机关能力。
func is_active() -> bool:
	return _active


# 返回过去体是否正在显示无碰撞的实体化轮廓。
func is_materializing() -> bool:
	return _materializing


# 不改历史路径，只切换该区域的玩法存在状态。
func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	collision_shape.set_deferred("disabled", not value)
	if value:
		visible = true
		visual.visible = true
		outline_visual.visible = true
		history_trail.visible = true
		history_trail_far.visible = true
		vfx_animation_player.play(&"solid")
		appear_audio.play()
	elif not _materializing and not _phase_shifting:
		visible = false


# 回放路径帧携带的动画与朝向，不重新模拟输入。
func _apply_frame_visual(frame: TemporalFrame) -> void:
	_last_velocity = frame.velocity
	if visual.animation != frame.animation_name:
		visual.play(frame.animation_name)
	if outline_visual.animation != frame.animation_name:
		outline_visual.play(frame.animation_name)
	if history_trail.animation != frame.animation_name:
		history_trail.play(frame.animation_name)
	if history_trail_far.animation != frame.animation_name:
		history_trail_far.play(frame.animation_name)
	visual.flip_h = frame.facing < 0.0
	outline_visual.flip_h = visual.flip_h
	history_trail.flip_h = visual.flip_h
	history_trail_far.flip_h = visual.flip_h
	var trail_direction := frame.velocity.normalized() if not frame.velocity.is_zero_approx() else Vector2(frame.facing, 0.0)
	history_trail.position = -trail_direction * 5.0 + Vector2(0.0, 1.0)
	history_trail_far.position = -trail_direction * 10.0 + Vector2(0.0, 2.0)


# 只抓取不在相位期的当前玩家。
func _on_body_entered(body: Node2D) -> void:
	var echo_player := body as EchoPlayer
	if not _active or echo_player == null or echo_player.is_temporally_phased():
		return
	caught_player.emit()


# 永久过去体接触未来可能性时令其消散。
func _on_area_entered(area: Area2D) -> void:
	var future_echo := area as FutureEcho
	if not _active or future_echo == null or future_echo.is_temporally_phased():
		return
	future_echo.dissipate()


# 开始首次出现轮廓，保持碰撞关闭直到真实延迟抵达。
func _begin_materialization(frame: TemporalFrame) -> void:
	if _materializing:
		return
	global_position = frame.position
	_apply_frame_visual(frame)
	_active = false
	_materializing = true
	visible = true
	visual.visible = true
	outline_visual.visible = true
	history_trail.visible = true
	history_trail_far.visible = true
	collision_shape.set_deferred("disabled", true)
	vfx_animation_player.play(&"materialize_reduced" if _uses_low_flash_mode() else &"materialize")


# 实体化或切档途中切换低闪时保留当前预警进度。
func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "low_flash_mode":
		return
	if _uses_low_flash_mode():
		pixel_burst.emitting = false
	match vfx_animation_player.current_animation:
		&"materialize", &"materialize_reduced":
			_switch_vfx_animation(&"materialize_reduced" if _uses_low_flash_mode() else &"materialize")
		&"phase_target", &"phase_target_reduced":
			_switch_vfx_animation(&"phase_target_reduced" if _uses_low_flash_mode() else &"phase_target")


# 在成对 authored 动画之间保留归一化进度。
func _switch_vfx_animation(animation_name: StringName) -> void:
	var progress_ratio := 0.0
	if vfx_animation_player.current_animation_length > 0.0:
		progress_ratio = vfx_animation_player.current_animation_position / vfx_animation_player.current_animation_length
	vfx_animation_player.play(animation_name)
	vfx_animation_player.seek(progress_ratio * vfx_animation_player.current_animation_length, true)


# 读取低闪烁模式，缺少设置模块时使用标准特效。
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
