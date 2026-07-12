extends "res://addons/enhance_save_system/core/save_system.gd"

# Select this project's owned module list before core registration begins.
func _init() -> void:
	auto_register = true
	module_config_path = "res://Config/save_modules.cfg"
