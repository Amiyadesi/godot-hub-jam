class_name PresentRoom
extends Area2D
## Authored central room that converts only after its first completed dialogue.

@onready var dialogue_npc: DialogueNpc = %DialogueNpc
@onready var room_departure_vfx: TemporalDepartureVfx = %RoomDepartureVfx
@onready var ambient_glow: Polygon2D = $AmbientGlow
@onready var ambient_particles: GPUParticles2D = $AmbientParticles

var _player_inside := false


# Connects room entry and the one-time NPC conversion event.
func _ready() -> void:
	if LevelModule.instance == null:
		push_error("PresentRoom requires LevelModule")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	dialogue_npc.dialogue_started_here.connect(_on_dialogue_started)
	dialogue_npc.dialogue_finished.connect(_on_dialogue_finished)
	if LevelModule.instance != null and LevelModule.instance.is_present_hub_unlocked():
		dialogue_npc.dialogue_title = "return"
	_apply_present_ambient()


# Shows the central-room field only after its permanent conversion is complete.
func _apply_present_ambient() -> void:
	var active := LevelModule.instance != null and LevelModule.instance.is_present_hub_unlocked()
	ambient_glow.visible = active
	ambient_particles.emitting = active
	if active:
		ambient_particles.restart()


# Lets the first Past enter; unlocked returns clear the room immediately.
func _on_body_entered(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = true
	if LevelModule.instance != null and LevelModule.instance.is_present_hub_unlocked():
		EchoTimeline.enter_present_room()


# Starts a clean timeline from whichever authored exit the player uses.
func _on_body_exited(body: Node2D) -> void:
	if body != EchoTimeline.player:
		return
	_player_inside = false
	if EchoTimeline.is_present_room_active():
		EchoTimeline.leave_present_room()


# Stops only the run limit while the NPC conversation owns the screen.
func _on_dialogue_started() -> void:
	EchoTimeline.pause_run_countdown()


# Starts the same first conversation when the current-room checkpoint is touched.
func request_checkpoint_dialogue() -> bool:
	if LevelModule.instance == null or LevelModule.instance.is_present_hub_unlocked():
		return false
	return dialogue_npc.start_dialogue()


# Converts the room once after the first completed central NPC conversation.
func _on_dialogue_finished() -> void:
	if LevelModule.instance == null or LevelModule.instance.is_present_hub_unlocked():
		return
	LevelModule.instance.unlock_present_hub()
	if not SaveSystem.save_slot(1):
		push_error("PresentRoom failed to save slot 1 after unlocking")
	dialogue_npc.dialogue_title = "return"
	_apply_present_ambient()
	if EchoTimeline.enter_present_room():
		room_departure_vfx.play_room_departure()
