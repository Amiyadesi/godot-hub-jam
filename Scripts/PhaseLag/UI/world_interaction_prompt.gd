class_name WorldInteractionPrompt
extends Node2D
## Displays one compact authored action hint beside a world interaction target.

@export var default_text: String = "J 操作"

@onready var prompt_label: Label = $Panel/PromptLabel


# Applies the authored default text and starts hidden until a controller selects this target.
func _ready() -> void:
	prompt_label.text = default_text
	hide()


# Shows one action string without creating or restyling runtime UI nodes.
func show_prompt(text: String = "") -> void:
	prompt_label.text = default_text if text.is_empty() else text
	show()


# Hides this target's hint when another interaction has higher priority.
func hide_prompt() -> void:
	hide()
