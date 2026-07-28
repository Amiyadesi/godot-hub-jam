@tool
class_name ThankScreen
extends SceneManagerBackdrop

signal return_requested

@onready var return_button: ShaderButton = %ReturnButton
@onready var credits_text: RichTextLabel = %CreditsText

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var game_audio: Node = get_tree().root.get_node_or_null("GameAudio")
	if game_audio != null and game_audio.has_method("setup_menu_shader_button"):
		game_audio.call("setup_menu_shader_button", return_button)
	if game_audio != null and game_audio.has_method("setup_plain_button"):
		game_audio.call("setup_plain_button", return_button, "cancel")
	return_button.pressed.connect(return_requested.emit)
	credits_text.meta_clicked.connect(_on_credit_link_clicked)


# Routes Escape through the same origin-aware return signal as the button.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	return_requested.emit()


# Opens authored public credit links in the system browser.
func _on_credit_link_clicked(meta: Variant) -> void:
	var url := str(meta)
	var error := OS.shell_open(url)
	if error != OK:
		push_warning("Unable to open credit link '%s': %s" % [url, error_string(error)])
