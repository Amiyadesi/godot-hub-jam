class_name EchoMobileControls
extends Control
## Authored touch controls: same gameplay actions, mobile-only presentation.

@export var pause_screen: CanvasItem
@export var setting_screen: CanvasItem
@export var dialogue_npc: DialogueNpc

var _dialogue_active := false
var _last_tree_paused := false


# Validates authored overlay owners and hides this layer on desktop builds.
func _ready() -> void:
	if pause_screen == null or setting_screen == null or dialogue_npc == null:
		push_error("EchoMobileControls requires pause_screen, setting_screen, and dialogue_npc")
		return
	pause_screen.visibility_changed.connect(_refresh_visibility)
	setting_screen.visibility_changed.connect(_refresh_visibility)
	dialogue_npc.dialogue_started_here.connect(_on_dialogue_started)
	dialogue_npc.dialogue_finished.connect(_on_dialogue_finished)
	_last_tree_paused = get_tree().paused
	_refresh_visibility()


# Hides the touch layer as soon as a cinematic or menu pauses the world.
func _process(_delta: float) -> void:
	var tree_paused := get_tree().paused
	if tree_paused == _last_tree_paused:
		return
	_last_tree_paused = tree_paused
	_refresh_visibility()


# Hides mobile controls while authored menus or dialogue own the screen.
func _refresh_visibility() -> void:
	visible = (
		OS.has_feature("mobile")
		and not get_tree().paused
		and not pause_screen.visible
		and not setting_screen.visible
		and not _dialogue_active
	)


# Removes touch buttons before the dialogue balloon opens.
func _on_dialogue_started() -> void:
	_dialogue_active = true
	_refresh_visibility()


# Restores touch buttons after dialogue returns control to gameplay.
func _on_dialogue_finished() -> void:
	_dialogue_active = false
	_refresh_visibility()
