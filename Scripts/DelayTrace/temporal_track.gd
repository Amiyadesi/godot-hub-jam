class_name TemporalTrack
extends RefCounted
## 带显式回传断点的有序路径样本。

var _frames: Array[TemporalFrame] = []


# 追加单调时间样本，并持有与发送者无关的副本。
func append(frame: TemporalFrame) -> void:
	if not _frames.is_empty() and frame.time_seconds < _frames.back().time_seconds:
		push_error("TemporalTrack.append requires monotonically increasing time")
		return
	if not _frames.is_empty() and is_equal_approx(frame.time_seconds, _frames.back().time_seconds):
		if frame.is_recall() and not _frames.back().is_recall():
			_frames.append(frame.copy())
			return
		_frames[_frames.size() - 1] = frame.copy()
		return
	_frames.append(frame.copy())


# 干净时间线重置时删除全部历史。
func clear() -> void:
	_frames.clear()


# 删除锚点之后的废弃可能性，保留锚点及更早历史。
func trim_after(end_time: float) -> void:
	while not _frames.is_empty() and _frames.back().time_seconds > end_time:
		_frames.pop_back()


# 判断路径是否存在可回放样本。
func is_empty() -> bool:
	return _frames.is_empty()


# 返回最早样本时间；空轨迹返回零。
func get_start_time() -> float:
	return _frames.front().time_seconds if not _frames.is_empty() else 0.0


# 返回最晚样本时间；空轨迹返回零。
func get_end_time() -> float:
	return _frames.back().time_seconds if not _frames.is_empty() else 0.0


# 返回真实录制时长，不补造边界外样本。
func get_duration() -> float:
	return maxf(get_end_time() - get_start_time(), 0.0)


# 复制末帧到指定时间，使极短录像保持确定性的最短播放时长。
func hold_last_frame_until(end_time: float) -> void:
	if _frames.is_empty():
		push_error("TemporalTrack.hold_last_frame_until requires at least one frame")
		return
	if end_time <= get_end_time():
		return
	var held_frame: TemporalFrame = _frames.back().copy()
	held_frame.time_seconds = end_time
	append(held_frame)


# 采样过去或未来的精确位置，绝不跨回传断点插值。
func sample_at(sample_time: float):
	if _frames.is_empty():
		return null
	if sample_time < get_start_time() or sample_time > get_end_time():
		return null
	if _frames.size() == 1:
		return _frames[0].copy()
	for index in range(_frames.size() - 1, -1, -1):
		var exact_frame := _frames[index]
		if is_equal_approx(sample_time, exact_frame.time_seconds):
			return exact_frame.copy()
	for index in range(1, _frames.size()):
		var left := _frames[index - 1]
		var right := _frames[index]
		if sample_time > right.time_seconds:
			continue
		if right.is_recall():
			return left.copy()
		var span := right.time_seconds - left.time_seconds
		if is_zero_approx(span):
			return right.copy()
		return left.interpolate_to(right, (sample_time - left.time_seconds) / span)
	return _frames.back().copy()


# 返回以首帧时间归零的独立路径片段。
func copy_segment(from_time: float, to_time: float) -> TemporalTrack:
	var segment := TemporalTrack.new()
	if from_time > to_time or _frames.is_empty():
		return segment
	var start_sample = sample_at(from_time)
	if start_sample != null:
		start_sample.time_seconds = 0.0
		segment.append(start_sample)
	for frame in _frames:
		if frame.time_seconds <= from_time or frame.time_seconds >= to_time:
			continue
		var rebased := frame.copy()
		rebased.time_seconds -= from_time
		segment.append(rebased)
	var end_sample = sample_at(to_time)
	if end_sample != null:
		end_sample.time_seconds = to_time - from_time
		segment.append(end_sample)
	return segment
