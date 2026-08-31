extends Node
## Boot: entry point. Routes to the main menu.

func _ready() -> void:
	SceneRouter.goto("res://scenes/main_menu.tscn")