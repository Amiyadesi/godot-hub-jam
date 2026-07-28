class_name PhaseCharacterVisualConfig
extends Resource
## Replaceable sprite-frame contract for one Phase Lag protagonist.

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"run",
	&"jump",
	&"fall",
	&"dash",
	&"primary",
	&"secondary",
	&"dodge",
	&"hurt",
	&"defend",
]

const LU_HENG_ANIMATIONS: Array[StringName] = [
	&"idle", &"run", &"jump", &"fall", &"dash", &"aim", &"grab", &"rotate", &"hurt", &"collapse", &"revive",
]

const XING_YAO_ANIMATIONS: Array[StringName] = [
	&"idle", &"run", &"jump", &"fall", &"dash", &"slash_1", &"slash_2", &"slash_3", &"charge", &"heavy",
	&"counter", &"air_slash", &"dive", &"hurt", &"collapse", &"revive",
]

@export var sprite_frames: SpriteFrames
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: Vector2 = Vector2.ONE


# Reports whether this replaceable visual resource satisfies one role's final animation contract.
func supports_role(role: int) -> bool:
	if sprite_frames == null:
		return false
	var required := LU_HENG_ANIMATIONS if role == 0 else XING_YAO_ANIMATIONS
	for animation_name: StringName in required:
		if not sprite_frames.has_animation(animation_name):
			return false
	return true
