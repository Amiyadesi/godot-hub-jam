class_name TemporalFrame
extends RefCounted
## 过去体与未来体路径回放使用的一帧确定性玩家状态。

enum Flag {
	NONE = 0,
	DASH = 1,
	JUMP = 2,
	RECALL = 4,
}

var time_seconds := 0.0
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1.0
var animation_name: StringName = &"idle"
var flags := Flag.NONE


# 从可观察玩家状态构造一帧独立样本。
func _init(
	new_time_seconds := 0.0,
	new_position := Vector2.ZERO,
	new_velocity := Vector2.ZERO,
	new_facing := 1.0,
	new_animation_name: StringName = &"idle",
	new_flags := Flag.NONE
) -> void:
	time_seconds = new_time_seconds
	position = new_position
	velocity = new_velocity
	facing = new_facing
	animation_name = new_animation_name
	flags = new_flags


# 为不同生命周期的轨迹创建完整独立副本。
func copy() -> TemporalFrame:
	return TemporalFrame.new(time_seconds, position, velocity, facing, animation_name, flags)


# 判断这一帧是否表示不连续的回传跳变。
func is_recall() -> bool:
	return (flags & Flag.RECALL) != 0


# 插值普通移动，同时保留离散动作标签。
func interpolate_to(next_frame: TemporalFrame, weight: float) -> TemporalFrame:
	var clamped_weight := clampf(weight, 0.0, 1.0)
	if next_frame.is_recall():
		return next_frame.copy()
	return TemporalFrame.new(
		lerpf(time_seconds, next_frame.time_seconds, clamped_weight),
		position.lerp(next_frame.position, clamped_weight),
		velocity.lerp(next_frame.velocity, clamped_weight),
		lerpf(facing, next_frame.facing, clamped_weight),
		animation_name if clamped_weight < 0.5 else next_frame.animation_name,
		flags if clamped_weight < 0.5 else next_frame.flags
	)
