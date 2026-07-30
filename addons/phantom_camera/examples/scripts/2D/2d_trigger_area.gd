extends Area2D

@export var area_pcam: PhantomCamera2D


func _ready() -> void:
	area_entered.connect(_entered_area)
	area_exited.connect(_exited_area)


func _entered_area(area_2d: Area2D) -> void:
	if area_2d.get_parent() is CharacterBody2D:
		area_pcam.set_priority(20)


func _exited_area(area_2d: Area2D) -> void:
	if area_2d.get_parent() is CharacterBody2D:
		area_pcam.set_priority(0)
