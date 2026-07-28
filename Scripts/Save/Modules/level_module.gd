class_name LevelModule
extends ISaveModule
## Slot save for one stable Echo Chase checkpoint.

static var instance: LevelModule

var checkpoint_scene_path := ""
var checkpoint_id := ""
var persistent_state: Dictionary = {}


# Registers the active slot-progress module for menu and gameplay callers.
func _init() -> void:
	instance = self


# Returns the stable slot-save key.
func get_module_key() -> String:
	return "level"


# Keeps Echo Chase progress isolated to the selected save slot.
func is_global() -> bool:
	return false


# Serializes only stable room state, never live temporal bodies or recordings.
func collect_data() -> Dictionary:
	return {
		"checkpoint_scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"persistent_state": persistent_state.duplicate(true),
	}


# Loads the current Echo schema and intentionally ignores retired Phase Lag fields.
func apply_data(data: Dictionary) -> void:
	checkpoint_scene_path = str(data.get("checkpoint_scene_path", ""))
	checkpoint_id = str(data.get("checkpoint_id", ""))
	var stored_state: Variant = data.get("persistent_state", {})
	persistent_state = stored_state.duplicate(true) if stored_state is Dictionary else {}


# Provides an empty timeline for a new save slot.
func get_default_data() -> Dictionary:
	return {
		"checkpoint_scene_path": "",
		"checkpoint_id": "",
		"persistent_state": {},
	}


# Clears the checkpoint when the player begins a fresh timeline.
func on_new_game() -> void:
	clear_checkpoint()


# Stores one clean authored checkpoint after temporal state has been reset.
func set_checkpoint(scene_path: String, new_checkpoint_id: String, state: Dictionary = {}) -> void:
	if scene_path.is_empty() or new_checkpoint_id.is_empty():
		push_error("LevelModule.set_checkpoint requires a scene path and checkpoint id")
		return
	checkpoint_scene_path = scene_path
	checkpoint_id = new_checkpoint_id
	persistent_state = state.duplicate(true)


# Reports whether this slot can resume at an authored Echo Chase checkpoint.
func has_continue_point() -> bool:
	return not checkpoint_scene_path.is_empty() and not checkpoint_id.is_empty()


# Returns the scene path owning the latest clean checkpoint.
func get_continue_scene_path() -> String:
	return checkpoint_scene_path


# Returns an isolated snapshot for an authored level host.
func get_checkpoint() -> Dictionary:
	if not has_continue_point():
		return {}
	return {
		"scene_path": checkpoint_scene_path,
		"checkpoint_id": checkpoint_id,
		"persistent_state": persistent_state.duplicate(true),
	}


# Removes stable progress without attempting to migrate retired prototype saves.
func clear_checkpoint() -> void:
	checkpoint_scene_path = ""
	checkpoint_id = ""
	persistent_state.clear()
