extends Node
## Boot: entry point short hold, then splash (Vision 5.9 chain: splash ->
## menu -> match).

func _ready() -> void:
	# --quick-match: evidence/CI shortcut, routes straight into the match
	# scene (skipping splash/menu) so screenshot tooling can frame gameplay.
	if "--quick-match" in OS.get_cmdline_user_args():
		SceneRouter.goto("res://scenes/match.tscn")
		return
	SceneRouter.goto("res://scenes/splash.tscn")