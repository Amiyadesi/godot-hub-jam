extends Node

const TEMPORAL_FRAME_SCRIPT := preload("res://Scripts/EchoChase/temporal_frame.gd")
const TEMPORAL_TRACK_SCRIPT := preload("res://Scripts/EchoChase/temporal_track.gd")
const PLAYER_SCENE := preload("res://Scenes/EchoChase/Prefabs/echo_player.tscn")

const PHYSICS_STEP := 1.0 / 60.0
const TILE_SIZE := 16.0

var _failures: Array[String] = []


# 在项目树中检查不会随着关卡、美术或手感调参变化的轨迹语义。
func _ready() -> void:
	_test_track_interpolates_continuous_motion()
	_test_track_keeps_recall_until_its_exact_time()
	_test_player_tuning_matches_authored_envelope()
	_finish()


# 验证普通相邻样本按时间连续插值。
func _test_track_interpolates_continuous_motion() -> void:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(100.0, 20.0)))
	var sample: TemporalFrame = track.sample_at(0.5)
	_expect(sample != null, "TemporalTrack returns a midpoint sample")
	if sample != null:
		_expect(sample.position.is_equal_approx(Vector2(50.0, 10.0)), "TemporalTrack interpolates continuous position")


# 验证回传只在精确时刻跳变，绝不提前插值到目的地。
func _test_track_keeps_recall_until_its_exact_time() -> void:
	var track: TemporalTrack = TEMPORAL_TRACK_SCRIPT.new()
	track.append(TEMPORAL_FRAME_SCRIPT.new(0.0, Vector2.ZERO))
	track.append(TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(100.0, 0.0)))
	var recall := TEMPORAL_FRAME_SCRIPT.new(1.0, Vector2(12.0, 0.0))
	recall.flags = TemporalFrame.Flag.RECALL
	track.append(recall)
	var before_recall: TemporalFrame = track.sample_at(0.99)
	var at_recall: TemporalFrame = track.sample_at(1.0)
	_expect(before_recall != null and before_recall.position.x > 90.0, "TemporalTrack keeps the pre-recall path until recall time")
	_expect(at_recall != null and at_recall.is_recall(), "TemporalTrack returns the recall frame at its exact time")
	if at_recall != null:
		_expect(is_equal_approx(at_recall.position.x, 12.0), "TemporalTrack applies the recall destination at recall time")


# 验证玩家 prefab 只继承脚本调参，并保持关卡采用的移动包线。
func _test_player_tuning_matches_authored_envelope() -> void:
	var player := PLAYER_SCENE.instantiate() as EchoPlayer
	_expect(is_equal_approx(player.run_speed, 144.0), "EchoPlayer runs at 9 tiles per second")
	_expect(is_equal_approx(player.run_acceleration, 2304.0), "EchoPlayer reaches run speed in one tile")
	_expect(is_equal_approx(player.jump_speed, 320.0), "EchoPlayer uses the authored jump speed")
	_expect(is_equal_approx(player.jump_release_multiplier, 0.65), "EchoPlayer keeps the authored short-hop cut")
	_expect(is_equal_approx(player.gravity, 1200.0), "EchoPlayer uses the authored gravity")
	_expect(is_equal_approx(player.wall_slide_speed, 48.0), "EchoPlayer wall-slides at 3 tiles per second")
	_expect(is_equal_approx(player.wall_jump_speed_x, 176.0), "EchoPlayer uses the authored wall-jump push")
	_expect(is_equal_approx(player.wall_push_seconds, 0.10), "EchoPlayer keeps the authored wall push window")
	_expect(is_equal_approx(player.wall_narrow_gap_probe_distance, 16.0), "EchoPlayer blocks one-tile wall gaps")
	_expect(is_equal_approx(player.dash_aim_seconds, 0.04), "EchoPlayer keeps the short dash aim window")
	_expect(is_equal_approx(player.dash_speed, 336.0), "EchoPlayer uses the authored dash speed")
	_expect(is_equal_approx(player.dash_seconds, 0.10), "EchoPlayer keeps the authored dash duration")
	_expect(is_equal_approx(player.dash_input_recovery_seconds, 0.06), "EchoPlayer keeps the authored dash recovery")
	_expect(is_equal_approx(player.dash_jump_momentum, 0.65), "EchoPlayer keeps the authored dash-jump momentum")
	_expect(is_equal_approx(player.dash_speed_cap_multiplier, 1.60), "EchoPlayer keeps the authored dash-jump cap")
	var full_jump_height := _simulate_jump_height(player.jump_speed, player.gravity)
	var short_jump_height := _simulate_short_jump_height(
		player.jump_speed,
		player.gravity,
		player.jump_release_multiplier
	)
	var dash_distance := _simulate_dash_distance(
		player.dash_speed,
		player.dash_seconds,
		player.dash_input_recovery_seconds,
		player.run_acceleration
	)
	_expect(is_equal_approx(full_jump_height / TILE_SIZE, 2.5), "EchoPlayer full jump reaches 2.5 tiles")
	_expect(short_jump_height / TILE_SIZE >= 1.15 and short_jump_height / TILE_SIZE <= 1.25, "EchoPlayer short jump stays near 1.2 tiles")
	_expect(dash_distance / TILE_SIZE >= 3.0 and dash_distance / TILE_SIZE <= 3.3, "EchoPlayer dash stays near 3.25 tiles")
	player.free()


# 模拟脚本采用的先加重力、后移动的固定物理步。
func _simulate_jump_height(jump_speed: float, gravity: float) -> float:
	var velocity_y := -jump_speed
	var position_y := 0.0
	while velocity_y < 0.0:
		velocity_y += gravity * PHYSICS_STEP
		position_y += velocity_y * PHYSICS_STEP
	return -position_y


# 模拟起跳后一帧松键的最短稳定跳跃。
func _simulate_short_jump_height(jump_speed: float, gravity: float, release_multiplier: float) -> float:
	var velocity_y := -jump_speed
	var position_y := 0.0
	velocity_y += gravity * PHYSICS_STEP
	position_y += velocity_y * PHYSICS_STEP
	velocity_y *= release_multiplier
	while velocity_y < 0.0:
		velocity_y += gravity * PHYSICS_STEP
		position_y += velocity_y * PHYSICS_STEP
	return -position_y


# 模拟冲刺定速段与现有整向量恢复段的水平位移。
func _simulate_dash_distance(speed: float, seconds: float, recovery_seconds: float, acceleration: float) -> float:
	var distance := 0.0
	for _frame in ceili(seconds / PHYSICS_STEP):
		distance += speed * PHYSICS_STEP
	var velocity_x := speed
	for _frame in ceili(recovery_seconds / PHYSICS_STEP):
		velocity_x = move_toward(velocity_x, 0.0, acceleration * PHYSICS_STEP)
		distance += velocity_x * PHYSICS_STEP
	return distance


# 收集失败并以稳定的进程状态交给命令行。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 输出结果后退出，避免原型阶段引入额外测试框架。
func _finish() -> void:
	if _failures.is_empty():
		print("Echo Chase temporal path checks passed")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("PATH CHECK FAILED: %s" % failure)
	get_tree().quit(1)
