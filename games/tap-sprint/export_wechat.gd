extends SceneTree

const Exporter = preload("res://addons/godot_mini_game/exporter.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("Usage: --script res://export_wechat.gd -- OUTPUT_DIRECTORY [APPID]")
		quit(2)
		return
	var appid := str(args[1]) if args.size() > 1 else "touristappid"
	var exporter := Exporter.new()
	var result: Error = await exporter.export_mini_game(
		"wechat", appid, "portrait", "MiniGame", args[0])
	if result != OK:
		push_error("WeChat export failed: %s" % error_string(result))
	quit(0 if result == OK else 1)
