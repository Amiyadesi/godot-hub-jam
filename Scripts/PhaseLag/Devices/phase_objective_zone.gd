class_name PhaseObjectiveZone
extends Area2D
## Authored traversal checkpoint that emits one causal room objective on entry.

signal objective_reached(event: EntanglementEvent)

@export var link_id: StringName = &""
@export_enum("陆衡", "星遥") var side: int = EntangledEntity.Side.XING_YAO
@export_enum("任意:-1", "陆衡:0", "星遥:1") var required_role: int = -1
@export var delay_override: float = -1.0

var _reached: bool = false

@onready var frame: Line2D = $Frame
@onready var core: Polygon2D = $Core


# Wires the authored traversal volume and rejects an unusable completion link.
func _ready() -> void:
	if link_id.is_empty():
		push_error("PhaseObjectiveZone requires a non-empty link_id")
		return
	body_entered.connect(_on_body_entered)


# Emits one stable objective only for the authored protagonist role.
func _on_body_entered(body: Node2D) -> void:
	if _reached:
		return
	var player := body as PhasePlayer
	if player == null or (required_role >= 0 and player.role != required_role):
		return
	var event := EntanglementBus.emit_event(
		link_id,
		EntanglementBus.POWER_CHANGED,
		{"value": true, "source": &"objective_zone"},
		side,
		delay_override
	)
	if event == null:
		return
	_reached = true
	frame.default_color = Color(0.42, 1.0, 0.78, 0.9)
	core.color = Color(0.42, 1.0, 0.78, 0.34)
	objective_reached.emit(event)
