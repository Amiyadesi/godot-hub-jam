class_name MemoryFloorGate
extends StaticBody2D
## Lights the four authored memory markers and clears the final floor at four shards.

@export var memory_item_ids: Array[StringName] = [
	&"memory_after",
	&"memory_t_minus_1",
	&"memory_t_minus_3",
	&"memory_t_minus_5",
]
@export var indicator_fills: Array[CanvasItem] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var unlock_particles: GPUParticles2D = $UnlockParticles

var _active_indicator_count := 0
var _unlocked := false


# Restores the collected count and listens for later shard pickups.
func _ready() -> void:
	if LevelModule.instance == null:
		push_error("MemoryFloorGate requires LevelModule")
		return
	if memory_item_ids.size() != 4 or indicator_fills.size() != 4:
		push_error("MemoryFloorGate requires four memory IDs and four authored indicator fills")
		return
	for indicator in indicator_fills:
		assert(indicator != null, "MemoryFloorGate indicator_fills cannot contain null")
	LevelModule.instance.collectible_collected.connect(_on_collectible_collected)
	animation_player.animation_finished.connect(_on_animation_finished)
	_refresh_state(false)


# Reports how many left-to-right markers are currently lit.
func get_active_indicator_count() -> int:
	return _active_indicator_count


# Reports whether the final floor collision has been cleared.
func is_unlocked() -> bool:
	return _unlocked


# Refreshes only when one of the four authored memory shards is collected.
func _on_collectible_collected(item_id: String) -> void:
	if memory_item_ids.has(StringName(item_id)):
		_refresh_state(true)


# Applies the slot state to indicators, collision, and authored animation.
func _refresh_state(play_feedback: bool) -> void:
	_active_indicator_count = 0
	for item_id in memory_item_ids:
		if LevelModule.instance.is_item_collected(String(item_id)):
			_active_indicator_count += 1
	for index in indicator_fills.size():
		indicator_fills[index].visible = index < _active_indicator_count
	_set_unlocked(_active_indicator_count == memory_item_ids.size(), play_feedback)


# Switches the floor between its solid and unlocked authored states.
func _set_unlocked(value: bool, play_feedback: bool) -> void:
	if _unlocked == value and animation_player.current_animation != "":
		return
	_unlocked = value
	collision_shape.set_deferred("disabled", value)
	if not value:
		animation_player.play(&"locked")
		return
	if not play_feedback:
		animation_player.play(&"unlocked")
		return
	unlock_particles.amount_ratio = 0.25 if _uses_low_flash_mode() else 1.0
	unlock_particles.restart()
	unlock_particles.emitting = true
	animation_player.play(&"unlock")


# Enters the persistent flicker after the one-shot unlock flash.
func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"unlock" and _unlocked:
		animation_player.play(&"unlocked")


# Reads the existing accessibility setting before the one-shot particle burst.
func _uses_low_flash_mode() -> bool:
	return (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
