class_name LuHengToolController
extends Node
## Routes Lu Heng's authored J/K actions into nearby physical pipelines and maintenance tools.

signal held_magnetic_changed(object: Node2D)

const NAVIGATION_INITIAL_DELAY: float = 0.24
const NAVIGATION_REPEAT_INTERVAL: float = 0.10

@export_range(80.0, 320.0, 1.0, "suffix:px") var pipeline_entry_range: float = 220.0
@export_range(80.0, 280.0, 1.0, "suffix:px") var magnetic_interaction_range: float = 190.0
@export_range(80.0, 280.0, 1.0, "suffix:px") var device_interaction_range: float = 180.0

var held_magnetic_object: Node2D
var _active_pipeline: PhaseCausalPipeline
var _player: PhasePlayer
var _navigation_direction: Vector2i = Vector2i.ZERO
var _navigation_hold_time: float = 0.0
var _navigation_repeat_time: float = 0.0


# Resolves the authored player parent used for range and role checks.
func _ready() -> void:
	_player = get_parent() as PhasePlayer
	if _player == null:
		push_error("LuHengToolController must be an authored child of PhasePlayer")


# Keeps one world hint and its matching outline on the current highest-priority J target.
func _process(_delta: float) -> void:
	_refresh_interaction_feedback()


# Performs J through active focus, magnetic priority, or authored focus entry.
func request_primary() -> bool:
	if held_magnetic_object != null:
		return _drop_magnetic_object()
	if is_focus_active():
		return _active_pipeline.primary_action_on_focused_target()
	var pipeline := _find_nearest_pipeline()
	if pipeline != null and pipeline.begin_player_focus(_player.global_position):
		_active_pipeline = pipeline
		_player.velocity.x = 0.0
		_reset_navigation_repeat()
		return true
	if _try_pick_up_magnetic_object():
		return true
	return _try_activate_authored_interactable()


# Performs K only inside maintenance focus or on a directly held magnetic object.
func request_secondary() -> bool:
	if is_focus_active():
		return _active_pipeline.secondary_action_on_focused_target()
	if held_magnetic_object != null and held_magnetic_object.has_method("rotate_held_clockwise"):
		return bool(held_magnetic_object.call("rotate_held_clockwise"))
	return false


# Uses L to leave maintenance focus and otherwise leaves dash available.
func request_dodge() -> bool:
	if is_focus_active():
		_active_pipeline.end_player_focus()
		_reset_navigation_repeat()
		return true
	return false


# Advances one immediate navigation step and deterministic held-input repeats.
func update_focus_navigation(direction: Vector2i, delta: float) -> void:
	if not is_focus_active():
		_reset_navigation_repeat()
		return
	if direction == Vector2i.ZERO:
		_reset_navigation_repeat()
		return
	if direction != _navigation_direction:
		_navigation_direction = direction
		_navigation_hold_time = 0.0
		_navigation_repeat_time = 0.0
		_active_pipeline.move_player_focus(direction)
		return
	var frame_delta := maxf(delta, 0.0)
	var previous_hold_time := _navigation_hold_time
	_navigation_hold_time += frame_delta
	if _navigation_hold_time < NAVIGATION_INITIAL_DELAY:
		return
	if previous_hold_time < NAVIGATION_INITIAL_DELAY:
		_active_pipeline.move_player_focus(direction)
		_navigation_repeat_time = _navigation_hold_time - NAVIGATION_INITIAL_DELAY
	else:
		_navigation_repeat_time += frame_delta
	while _navigation_repeat_time >= NAVIGATION_REPEAT_INTERVAL:
		_navigation_repeat_time -= NAVIGATION_REPEAT_INTERVAL
		_active_pipeline.move_player_focus(direction)


# Reports whether Lu Heng currently owns an authored pipeline focus.
func is_focus_active() -> bool:
	return (
		_active_pipeline != null
		and is_instance_valid(_active_pipeline)
		and _active_pipeline.has_player_focus()
	)


# Clears transient physical-tool feedback and releases any room-owned magnetic object.
func prepare_for_role_switch() -> bool:
	_clear_interaction_feedback()
	if _active_pipeline != null and is_instance_valid(_active_pipeline):
		_active_pipeline.clear_player_proximity()
	_active_pipeline = null
	_reset_navigation_repeat()
	if held_magnetic_object != null:
		if is_instance_valid(held_magnetic_object) and held_magnetic_object.has_method("end_magnetic_hold"):
			held_magnetic_object.call("end_magnetic_hold")
		held_magnetic_object = null
		held_magnetic_changed.emit(null)
	return true


# Reports whether normal platform movement is available outside maintenance focus.
func can_move() -> bool:
	return not is_focus_active()


# Finds the closest authored physical pipeline in the same SubViewport.
func _find_nearest_pipeline() -> PhaseCausalPipeline:
	if _player == null:
		return null
	if (
		_active_pipeline != null
		and is_instance_valid(_active_pipeline)
		and _active_pipeline.is_interaction_enabled()
		and (_active_pipeline.has_player_focus() or _active_pipeline.has_held_part())
	):
		return _active_pipeline
	var nearest: PhaseCausalPipeline = null
	var nearest_distance := INF
	for candidate: Node in get_tree().get_nodes_in_group("causal_pipelines"):
		var pipeline := candidate as PhaseCausalPipeline
		if pipeline == null or not pipeline.is_interaction_enabled() or pipeline.get_viewport() != _player.get_viewport():
			continue
		var distance := pipeline.get_focus_entry_distance(_player.global_position)
		var effective_range := minf(pipeline_entry_range, pipeline.interaction_radius)
		if distance <= effective_range and distance <= nearest_distance:
			nearest = pipeline
			nearest_distance = distance
	return nearest


# Selects exactly one prompt using the same held, pipeline, magnetic, and device priority as J.
func _refresh_interaction_feedback() -> void:
	if _player == null:
		return
	var may_interact := _player.role == PhasePlayer.Role.LU_HENG and _player.controlled and not _player.departed
	var selected_pipeline: PhaseCausalPipeline = null
	var selected_magnetic: MagneticObject = null
	var selected_interactable: Node2D = null
	if may_interact:
		if held_magnetic_object != null and is_instance_valid(held_magnetic_object):
			selected_magnetic = held_magnetic_object as MagneticObject
		else:
			selected_pipeline = _find_nearest_pipeline()
			if selected_pipeline == null:
				selected_magnetic = _find_nearest_magnetic_object()
			if selected_magnetic == null:
				selected_interactable = _find_nearest_authored_interactable()
	for candidate: Node in get_tree().get_nodes_in_group("causal_pipelines"):
		var pipeline := candidate as PhaseCausalPipeline
		if pipeline == null or pipeline.get_viewport() != _player.get_viewport():
			continue
		if pipeline == selected_pipeline:
			pipeline.update_player_proximity(_player.global_position, minf(pipeline_entry_range, pipeline.interaction_radius))
		else:
			pipeline.clear_player_proximity()
	for candidate: Node in get_tree().get_nodes_in_group("magnetic_objects"):
		var object := candidate as MagneticObject
		if object == null or object.get_viewport() != _player.get_viewport():
			continue
		object.set_interaction_prompt_active(object == selected_magnetic)
	for candidate: Node in get_tree().get_nodes_in_group("lu_heng_interactables"):
		var interactable := candidate as Node2D
		if interactable == null or interactable.get_viewport() != _player.get_viewport():
			continue
		interactable.call("set_interaction_prompt_active", interactable == selected_interactable)


# Clears all authored prompts immediately during role switches, exits, and rebuilds.
func _clear_interaction_feedback() -> void:
	if _player == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("causal_pipelines"):
		var pipeline := candidate as PhaseCausalPipeline
		if pipeline != null and pipeline.get_viewport() == _player.get_viewport():
			pipeline.clear_player_proximity()
	for candidate: Node in get_tree().get_nodes_in_group("magnetic_objects"):
		var object := candidate as MagneticObject
		if object != null and object.get_viewport() == _player.get_viewport():
			object.set_interaction_prompt_active(false)
	for candidate: Node in get_tree().get_nodes_in_group("lu_heng_interactables"):
		var interactable := candidate as Node2D
		if interactable != null and interactable.get_viewport() == _player.get_viewport():
			interactable.call("set_interaction_prompt_active", false)


# Finds the closest available magnetic object in Lu Heng's current SubViewport.
func _find_nearest_magnetic_object() -> MagneticObject:
	if _player == null:
		return null
	var nearest: MagneticObject = null
	var nearest_distance := magnetic_interaction_range
	for candidate: Node in get_tree().get_nodes_in_group("magnetic_objects"):
		var object := candidate as MagneticObject
		if object == null or object.get_viewport() != _player.get_viewport() or not object.can_begin_magnetic_hold():
			continue
		var distance := _player.global_position.distance_to(object.global_position)
		if distance <= nearest_distance:
			nearest = object
			nearest_distance = distance
	return nearest


# Finds the closest currently usable world-mounted Lu Heng device.
func _find_nearest_authored_interactable() -> Node2D:
	if _player == null:
		return null
	var nearest: Node2D = null
	var nearest_distance := device_interaction_range
	for candidate: Node in get_tree().get_nodes_in_group("lu_heng_interactables"):
		var interactable := candidate as Node2D
		if interactable == null or interactable.get_viewport() != _player.get_viewport():
			continue
		if not bool(interactable.call("can_activate")):
			continue
		var distance := _player.global_position.distance_to(interactable.global_position)
		if distance <= nearest_distance:
			nearest = interactable
			nearest_distance = distance
	return nearest


# Finds and grabs the nearest authored magnetic object without becoming a physics gun.
func _try_pick_up_magnetic_object() -> bool:
	var nearest := _find_nearest_magnetic_object()
	if nearest == null or not nearest.begin_magnetic_hold(_player):
		return false
	held_magnetic_object = nearest
	held_magnetic_changed.emit(held_magnetic_object)
	return true


# Releases the held object through its constrained authored drop behavior.
func _drop_magnetic_object() -> bool:
	if held_magnetic_object == null:
		return false
	if held_magnetic_object.has_method("end_magnetic_hold"):
		held_magnetic_object.call("end_magnetic_hold")
	held_magnetic_object = null
	held_magnetic_changed.emit(null)
	return true


# Activates the closest authored Lu Heng device after pipelines and magnetic tools decline J.
func _try_activate_authored_interactable() -> bool:
	var nearest := _find_nearest_authored_interactable()
	return nearest != null and bool(nearest.call("activate"))


# Clears held-direction repeat state on focus exit, ownership change, or release.
func _reset_navigation_repeat() -> void:
	_navigation_direction = Vector2i.ZERO
	_navigation_hold_time = 0.0
	_navigation_repeat_time = 0.0
