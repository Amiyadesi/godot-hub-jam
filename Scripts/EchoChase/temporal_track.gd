class_name TemporalTrack
extends RefCounted
## Ordered path samples with explicit recall discontinuities.

var _frames: Array[TemporalFrame] = []


# Appends one monotonic sample and owns a copy independent from its sender.
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


# Removes all recorded history during a clean timeline reset.
func clear() -> void:
	_frames.clear()


# Reports whether the path has any sample available for playback.
func is_empty() -> bool:
	return _frames.is_empty()


# Returns the earliest sampled time, or zero for an empty track.
func get_start_time() -> float:
	return _frames.front().time_seconds if not _frames.is_empty() else 0.0


# Returns the latest sampled time, or zero for an empty track.
func get_end_time() -> float:
	return _frames.back().time_seconds if not _frames.is_empty() else 0.0


# Returns the recorded duration without inventing samples outside its bounds.
func get_duration() -> float:
	return maxf(get_end_time() - get_start_time(), 0.0)


# Samples one exact past or future point, never interpolating across a recall.
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


# Returns a separate path segment normalized to its first sample time.
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
