class_name TrueEndingRoute
extends Node2D
## Reveals the authored backward branch after all four stable memory IDs are collected.

signal memory_reassembly_requested
signal true_ending_requested

const MEMORY_IDS := [
	"memory_t_minus_5",
	"memory_t_minus_3",
	"memory_t_minus_1",
	"memory_after",
]

@onready var route_bodies: Array[StaticBody2D] = [
	$PlatformA,
	$PlatformB,
	$PlatformC,
	$KnowledgeGate,
]
@onready var future_recorder: FutureRecorder = %KnowledgeRecorder
@onready var knowledge_lock: KnowledgeLock = %KnowledgeLock
@onready var reassembly_trigger: Area2D = %ReassemblyTrigger
@onready var true_ending_trigger: Area2D = %TrueEndingTrigger

var _revealed := false
var _reassembly_requested := false
var _knowledge_armed := false
var _true_ending_requested := false


# Restores route visibility and connects the two authored story thresholds.
func _ready() -> void:
	if (
		LevelModule.instance == null
		or future_recorder == null
		or knowledge_lock == null
		or reassembly_trigger == null
		or true_ending_trigger == null
	):
		push_error("TrueEndingRoute requires LevelModule and all authored route nodes")
		return
	LevelModule.instance.collectible_collected.connect(_on_collectible_collected)
	reassembly_trigger.body_entered.connect(_on_reassembly_body_entered)
	true_ending_trigger.body_entered.connect(_on_true_ending_body_entered)
	_set_revealed(_has_all_memories())
	if knowledge_lock.is_unlocked():
		_knowledge_armed = true


# Makes the knowledge-lock recorder usable after the complete memory is shown.
func arm_knowledge_lock() -> void:
	if not _revealed or _knowledge_armed or knowledge_lock.is_unlocked():
		return
	_knowledge_armed = true
	future_recorder.show()
	future_recorder.monitoring = true
	EchoTimeline.register_recorder(future_recorder)


# Reports whether the hidden physical branch is currently present.
func is_revealed() -> bool:
	return _revealed


# Reveals the branch on the exact pickup that completes the four-memory set.
func _on_collectible_collected(_item_id: String) -> void:
	if not _revealed and _has_all_memories():
		_set_revealed(true)


# Requests the fixed chronological reconstruction once per scene visit.
func _on_reassembly_body_entered(body: Node2D) -> void:
	if _reassembly_requested or body != EchoTimeline.player:
		return
	_reassembly_requested = true
	reassembly_trigger.set_deferred("monitoring", false)
	memory_reassembly_requested.emit()


# Opens the true-ending cinematic only beyond the completed knowledge lock.
func _on_true_ending_body_entered(body: Node2D) -> void:
	if _true_ending_requested or body != EchoTimeline.player or not knowledge_lock.is_unlocked():
		return
	_true_ending_requested = true
	true_ending_requested.emit()


# Applies authored visibility, collision, and recorder registration as one state.
func _set_revealed(value: bool) -> void:
	_revealed = value
	visible = value
	for body in route_bodies:
		body.collision_layer = 1 if value else 0
	reassembly_trigger.monitoring = value
	true_ending_trigger.monitoring = value
	future_recorder.hide()
	future_recorder.monitoring = false
	EchoTimeline.unregister_recorder(future_recorder)


# Checks the four stable IDs without depending on pickup order.
func _has_all_memories() -> bool:
	for item_id in MEMORY_IDS:
		if not LevelModule.instance.is_item_collected(item_id):
			return false
	return true
