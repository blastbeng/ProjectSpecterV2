extends Node
## Boot: entry point short hold, then splash (Vision 5.9 chain: splash ->
## menu -> match).

func _ready() -> void:
	SceneRouter.goto("res://scenes/splash.tscn")