class_name PhaseChargeAccumulator
extends Node2D
## Authored three-cell accumulator that mirrors a counted delayed event source.

@export var relay_path: NodePath
@export_range(1, 16, 1) var required_count: int = 3

@onready var relay: CircuitSourceRelay = get_node(relay_path) as CircuitSourceRelay
@onready var cells: Array[Sprite2D] = [$CellA, $CellB, $CellC]
@onready var indicators: Array[Polygon2D] = [$IndicatorA, $IndicatorB, $IndicatorC]


# Connects the authored indicator to the existing counted source relay.
func _ready() -> void:
	if relay == null:
		push_error("PhaseChargeAccumulator requires a CircuitSourceRelay path")
		return
	relay.event_count_changed.connect(_on_event_count_changed)
	_on_event_count_changed(0, required_count)


# Lights exactly the number of cells represented by arrived delayed events.
func _on_event_count_changed(count: int, _required: int) -> void:
	var active_count := clampi(count, 0, cells.size())
	for index in cells.size():
		var active := index < active_count
		cells[index].modulate = Color(0.82, 1.0, 0.92, 1.0) if active else Color(0.3, 0.38, 0.4, 0.72)
		indicators[index].color = Color(0.32, 1.0, 0.74, 0.95) if active else Color(0.2, 0.25, 0.27, 0.82)
