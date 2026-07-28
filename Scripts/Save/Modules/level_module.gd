class_name LevelModule
extends ISaveModule
## Slot save for the current Phase Lag timeline.
##
## The game persists only chapter progress, play mode, and one clean authored checkpoint.
## In-flight events, health, enemies, Boss rounds, and compatibility fields are excluded.

static var instance: LevelModule

const PHASE_LAG_CHAPTER_IDS: Array[String] = [
	"chapter_01",
	"chapter_02",
	"chapter_03",
	"chapter_04",
	"chapter_05",
]
const PHASE_LAG_TUTORIAL_CHAPTER_ID := "chapter_01"
const PLAY_MODE_SOLO: StringName = &"solo"
const PLAY_MODE_LOCAL_COOP: StringName = &"local_coop"

var current_chapter_id: String = ""
var completed_chapters: Array[String] = []
var checkpoint: Dictionary = {}
var play_mode: StringName = PLAY_MODE_SOLO


# Registers the active slot-progress module for menu and gameplay callers.
func _init() -> void:
	instance = self


# Returns the slot-save key for Phase Lag progression.
func get_module_key() -> String:
	return "level"


# Keeps timeline progress isolated to one save slot.
func is_global() -> bool:
	return false


# Serializes only the current Phase Lag slot schema.
func collect_data() -> Dictionary:
	return {
		"current_chapter_id": current_chapter_id,
		"completed_chapters": completed_chapters.duplicate(),
		"checkpoint": checkpoint.duplicate(true),
		"play_mode": String(play_mode),
	}


# Applies the current schema and narrows legacy Ch4/Ch5 room checkpoints to stable entry points.
func apply_data(data: Dictionary) -> void:
	current_chapter_id = str(data.get("current_chapter_id", ""))
	completed_chapters.clear()
	var stored_chapters: Variant = data.get("completed_chapters", [])
	if stored_chapters is Array:
		for chapter_value: Variant in stored_chapters:
			var chapter_id := str(chapter_value)
			if _is_phase_lag_chapter(chapter_id) and not completed_chapters.has(chapter_id):
				completed_chapters.append(chapter_id)
	var stored_checkpoint: Variant = data.get("checkpoint", {})
	checkpoint = (stored_checkpoint as Dictionary).duplicate(true) if stored_checkpoint is Dictionary else {}
	var stored_play_mode := StringName(str(data.get("play_mode", PLAY_MODE_SOLO)))
	play_mode = stored_play_mode if _is_valid_play_mode(stored_play_mode) else PLAY_MODE_SOLO
	if not _is_phase_lag_chapter(current_chapter_id):
		current_chapter_id = ""
		checkpoint.clear()
	elif not checkpoint.is_empty() and str(checkpoint.get("chapter_id", "")) != current_chapter_id:
		checkpoint.clear()
	_migrate_legacy_phase_checkpoint()


# Provides an empty timeline for a fresh slot.
func get_default_data() -> Dictionary:
	return {
		"current_chapter_id": "",
		"completed_chapters": [],
		"checkpoint": {},
		"play_mode": String(PLAY_MODE_SOLO),
	}


# Clears the slot timeline and restores the default single-player mode.
func on_new_game() -> void:
	current_chapter_id = ""
	completed_chapters.clear()
	checkpoint.clear()
	play_mode = PLAY_MODE_SOLO


# Stores one stable authored input mode for this save slot.
func set_play_mode(value: StringName) -> void:
	if not _is_valid_play_mode(value):
		push_error("LevelModule.set_play_mode: unsupported mode '%s'" % String(value))
		return
	play_mode = value


# Enters one authored chapter and drops a checkpoint owned by a different chapter.
func enter_chapter(chapter_id: String) -> void:
	if not _is_phase_lag_chapter(chapter_id):
		push_error("LevelModule.enter_chapter: unknown chapter '%s'" % chapter_id)
		return
	if current_chapter_id != chapter_id:
		checkpoint.clear()
	current_chapter_id = chapter_id


# Marks one chapter complete and makes the next authored chapter the resume target.
func complete_chapter(chapter_id: String, next_chapter_id: String = "") -> void:
	if not _is_phase_lag_chapter(chapter_id):
		push_error("LevelModule.complete_chapter: unknown chapter '%s'" % chapter_id)
		return
	if not completed_chapters.has(chapter_id):
		completed_chapters.append(chapter_id)
	checkpoint.clear()
	if next_chapter_id.is_empty():
		current_chapter_id = chapter_id
	elif _is_phase_lag_chapter(next_chapter_id):
		current_chapter_id = next_chapter_id
	else:
		push_error("LevelModule.complete_chapter: unknown next chapter '%s'" % next_chapter_id)
		current_chapter_id = chapter_id


# Reports whether one authored chapter has reached settlement.
func is_chapter_completed(chapter_id: String) -> bool:
	return completed_chapters.has(chapter_id)


# Stores the latest clean room state and replaces the previous checkpoint.
func set_phase_checkpoint(
		chapter_id: String,
		room_id: String,
		checkpoint_id: String,
		persistent_state: Dictionary = {}
	) -> void:
	if not _is_phase_lag_chapter(chapter_id):
		push_error("LevelModule.set_phase_checkpoint: unknown chapter '%s'" % chapter_id)
		return
	current_chapter_id = chapter_id
	checkpoint = {
		"chapter_id": chapter_id,
		"room_id": room_id,
		"checkpoint_id": checkpoint_id,
		"persistent_state": persistent_state.duplicate(true),
	}


# Returns the active chapter's isolated checkpoint snapshot.
func get_phase_checkpoint(chapter_id: String) -> Dictionary:
	if current_chapter_id != chapter_id or str(checkpoint.get("chapter_id", "")) != chapter_id:
		return {}
	return checkpoint.duplicate(true)


# Reports whether Continue can enter a post-tutorial timeline.
func has_phase_lag_resume_point() -> bool:
	return not get_phase_lag_resume_point().is_empty()


# Returns the current chapter plus its optional clean authored checkpoint.
func get_phase_lag_resume_point() -> Dictionary:
	if not is_chapter_completed(PHASE_LAG_TUTORIAL_CHAPTER_ID):
		return {}
	if current_chapter_id == PHASE_LAG_TUTORIAL_CHAPTER_ID or not _is_phase_lag_chapter(current_chapter_id):
		return {}
	var result := {
		"chapter_id": current_chapter_id,
		"checkpoint_id": "start",
	}
	var active_checkpoint := get_phase_checkpoint(current_chapter_id)
	if not active_checkpoint.is_empty():
		result["room_id"] = str(active_checkpoint.get("room_id", ""))
		result["checkpoint_id"] = str(active_checkpoint.get("checkpoint_id", "start"))
	return result


# Maps retired room checkpoints to the stable Boss or Finale entry points.
func _migrate_legacy_phase_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	var chapter_id := str(checkpoint.get("chapter_id", ""))
	var room_id := str(checkpoint.get("room_id", ""))
	if chapter_id == "chapter_04" and room_id != "phase_hunter":
		checkpoint["room_id"] = "phase_hunter"
		checkpoint["checkpoint_id"] = "boss"
		checkpoint["persistent_state"] = {}
		return
	if chapter_id == "chapter_05":
		current_chapter_id = "chapter_05"
		checkpoint = {
			"chapter_id": "chapter_05",
			"room_id": "finale",
			"checkpoint_id": "finale_start",
			"persistent_state": {},
		}


# Restricts persisted progress to the five authored Phase Lag chapters.
func _is_phase_lag_chapter(chapter_id: String) -> bool:
	return PHASE_LAG_CHAPTER_IDS.has(chapter_id)


# Restricts persisted input modes to the two menu-authored choices.
func _is_valid_play_mode(value: StringName) -> bool:
	return value == PLAY_MODE_SOLO or value == PLAY_MODE_LOCAL_COOP
