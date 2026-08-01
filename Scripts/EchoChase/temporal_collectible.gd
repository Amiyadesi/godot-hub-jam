class_name TemporalCollectible
extends Area2D
## Slot-persistent authored collectible with one stable world ID.

signal collected(item_id: StringName)

@export var item_id: StringName

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var collect_audio: AudioStreamPlayer2D = %CollectAudio

var _collected := false


# Restores collected state and connects the player trigger.
func _ready() -> void:
	if item_id.is_empty():
		push_error("TemporalCollectible requires a non-empty item_id")
		return
	if LevelModule.instance == null:
		push_error("TemporalCollectible requires LevelModule")
		return
	body_entered.connect(_on_body_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	if LevelModule.instance.is_item_collected(String(item_id)):
		queue_free()
		return
	animation_player.play(&"idle")


# Stores the item once, then plays authored pickup feedback.
func _on_body_entered(body: Node2D) -> void:
	if _collected or body != EchoTimeline.player:
		return
	if not LevelModule.instance.collect_item(String(item_id)):
		return
	_collected = true
	collision_shape.set_deferred("disabled", true)
	collected.emit(item_id)
	if not SaveSystem.save_slot(1):
		push_error("TemporalCollectible failed to save slot 1")
	collect_audio.play()
	animation_player.play(&"collect")


# Removes the authored instance after its pickup animation completes.
func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"collect":
		queue_free()
