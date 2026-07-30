extends Node

const TEMPORAL_FRAME_SCRIPT := preload("res://Scripts/EchoChase/temporal_frame.gd")
const TEMPORAL_TRACK_SCRIPT := preload("res://Scripts/EchoChase/temporal_track.gd")

var _failures: Array[String] = []


# 在项目树中检查不会随着关卡、美术或手感调参变化的轨迹语义。
func _ready() -> void:
	_test_track_interpolates_continuous_motion()
	_test_track_keeps_recall_until_its_exact_time()
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
