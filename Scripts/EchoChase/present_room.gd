class_name PresentRoom
extends Area2D
## Authored central room that permanently suppresses temporal echoes after its first dialogue.

@onready var dialogue_npc: DialogueNpc = %DialogueNpc
@onready var shockwave_animation_player: AnimationPlayer = %ShockwaveAnimationPlayer
@onready var shockwave_audio: AudioStreamPlayer2D = %ShockwaveAudio

var _player_inside := false


# Connects room entry and the one-time NPC conversion event.
func _ready() -> void:
	if LevelModule.instance == null:
		push_error("PresentRoom requires LevelModule")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	dialogue_npc.dialogue_finished.connect(_on_dialogue_finished)
	if LevelModule.instance != null and LevelModule.instance.is_present_hub_unlocked():
		dialogue_npc.dialogue_title = "return"


# Clears temporal entities whenever the current player enters the authored room.
func _on_body_entered(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = true
	EchoTimeline.enter_present_room()


# Starts a clean timeline from whichever authored exit the player uses.
func _on_body_exited(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = false
	if EchoTimeline.is_present_room_active():
		EchoTimeline.leave_present_room()


# Converts the room once after the first completed central NPC conversation.
func _on_dialogue_finished() -> void:
	if not _player_inside or LevelModule.instance == null or LevelModule.instance.is_present_hub_unlocked():
		return
	LevelModule.instance.unlock_present_hub()
	if not SaveSystem.save_slot(1):
		push_error("PresentRoom failed to save slot 1 after unlocking")
	dialogue_npc.dialogue_title = "return"
	_play_shockwave()
	EchoTimeline.enter_present_room()


# Plays the authored blue conversion pulse with the accessibility variant.
func _play_shockwave() -> void:
	var low_flash := (
		SettingsModule.instance != null
		and bool(SettingsModule.instance.get_value("low_flash_mode", false))
	)
	shockwave_animation_player.play(&"pulse_reduced" if low_flash else &"pulse")
	shockwave_audio.play()
