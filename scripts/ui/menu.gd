extends Control
## Main menu: minimal but styled entry screen (Vision 5.9 UI pass comes later).

@onready var host_button: Button = $VBox/PlayButton
@onready var join_button: Button = $VBox/JoinButton
@onready var quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	quit_button.pressed.connect(_on_quit)
	host_button.grab_focus()

func _on_host() -> void:
	SceneRouter.goto("res://scenes/match.tscn")

func _on_join() -> void:
	# Networking arrives in a later iteration; join currently starts local play.
	SceneRouter.goto("res://scenes/match.tscn")

func _on_quit() -> void:
	get_tree().quit()