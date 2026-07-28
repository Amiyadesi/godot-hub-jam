class_name PhaseDashAfterimage
extends Node2D
## Reuses two authored sprites to leave a restrained snapshot behind a dash.

@export_range(0.1, 0.3, 0.01, "suffix:s") var fade_duration: float = 0.18
@export_range(8.0, 72.0, 1.0, "suffix:px") var near_offset: float = 24.0
@export_range(16.0, 96.0, 1.0, "suffix:px") var far_offset: float = 48.0
@export_range(0.0, 0.5, 0.01) var near_alpha: float = 0.24
@export_range(0.0, 0.5, 0.01) var far_alpha: float = 0.12

@onready var near_sprite: Sprite2D = $NearSprite
@onready var far_sprite: Sprite2D = $FarSprite

var _fade_tween: Tween


# Starts hidden until a player supplies one concrete animation frame.
func _ready() -> void:
	clear()


# Copies the current player frame into the two authored trailing sprites.
func play_from(source: AnimatedSprite2D, movement_direction: float) -> void:
	if source.sprite_frames == null:
		push_error("PhaseDashAfterimage requires an AnimatedSprite2D with SpriteFrames")
		return
	var frame_texture := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if frame_texture == null:
		push_error("PhaseDashAfterimage could not resolve the current animation frame")
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var direction := movement_direction if not is_zero_approx(movement_direction) else 1.0
	var alpha_scale := 0.5 if _read_low_flash_mode() else 1.0
	_copy_frame(near_sprite, source, frame_texture, -direction * near_offset, near_alpha * alpha_scale)
	_copy_frame(far_sprite, source, frame_texture, -direction * far_offset, far_alpha * alpha_scale)
	_fade_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.parallel().tween_property(near_sprite, ^"modulate:a", 0.0, fade_duration)
	_fade_tween.parallel().tween_property(far_sprite, ^"modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(_hide_sprites)


# Stops any active fade and hides both reusable authored sprites.
func clear() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_hide_sprites()


# Hides both authored sprites after a completed or cancelled fade.
func _hide_sprites() -> void:
	near_sprite.visible = false
	far_sprite.visible = false
	near_sprite.modulate.a = 0.0
	far_sprite.modulate.a = 0.0


# Mirrors one AnimatedSprite2D frame without changing the source animation.
func _copy_frame(
		target: Sprite2D,
		source: AnimatedSprite2D,
		frame_texture: Texture2D,
		offset_x: float,
		alpha: float
	) -> void:
	target.texture = frame_texture
	target.position = source.position + Vector2(offset_x, 0.0)
	target.rotation = source.rotation
	target.scale = source.scale
	target.centered = source.centered
	target.offset = source.offset
	target.flip_h = source.flip_h
	target.flip_v = source.flip_v
	target.modulate = Color(1.0, 1.0, 1.0, alpha)
	target.visible = true


# Reads the persisted accessibility preference at the instant the dash begins.
func _read_low_flash_mode() -> bool:
	return bool(SettingsModule.instance.get_value("low_flash_mode", false)) if SettingsModule.instance != null else false
