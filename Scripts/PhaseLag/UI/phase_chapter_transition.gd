class_name PhaseChapterTransition
extends Control
## Plays the authored chapter close and entry reveal around the shared phase seam.

@onready var title_label: Label = %TitleLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer


# Holds the authored first frame of the reveal before the new scene begins its flow.
func prepare_open(title: String) -> void:
	title_label.text = title
	show()
	animation_player.play(&"open")
	animation_player.advance(0.0)
	animation_player.pause()


# Leaves ordinary scene entries unobstructed before the first rendered frame.
func hide_immediately() -> void:
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	hide()


# Covers both timelines toward the seam and holds the next chapter title in place.
func play_close(title: String) -> void:
	title_label.text = title
	show()
	animation_player.play(&"close")
	animation_player.advance(0.0)
	await animation_player.animation_finished


# Reveals the new chapter outward from the seam without a full-screen flash.
func play_open(title: String) -> void:
	title_label.text = title
	show()
	animation_player.play(&"open")
	animation_player.advance(0.0)
	await animation_player.animation_finished
	hide()
