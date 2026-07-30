extends Label

const LINES: Array[String] = [
	"audio bus linked",
	"input map ready",
	"save layer stable",
	"signal route checked",
	"settings shell online",
]

var _rng := RandomNumberGenerator.new()
var _serial: int


func _ready() -> void:
	_rng.randomize()
	_start_loop()


# Starts one authored diagnostic text loop after the label enters the tree.
func _start_loop() -> void:
	_serial += 1
	call_deferred("_run_loop", _serial)


# Types and erases one diagnostic line until the label leaves the scene.
func _run_loop(serial: int) -> void:
	while is_inside_tree() and serial == _serial:
		var line := LINES[_rng.randi_range(0, LINES.size() - 1)]
		text = "> "
		await _wait(_rng.randf_range(0.18, 0.46))
		for i in range(line.length()):
			if not is_inside_tree() or serial != _serial:
				return
			text = "> " + line.substr(0, i + 1) + "_"
			await _wait(_rng.randf_range(0.024, 0.064))
		await _wait(_rng.randf_range(1.0, 2.1))
		for i in range(line.length(), -1, -1):
			if not is_inside_tree() or serial != _serial:
				return
			text = "> " + line.substr(0, i) + "_"
			await _wait(_rng.randf_range(0.012, 0.036))
		await _wait(_rng.randf_range(0.44, 1.0))


# Waits through the tree timer without changing authored UI state.
func _wait(seconds: float) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(seconds, true, false, true).timeout
