extends Control

var score: int = 0
var best: int = 0
var remaining: float = 30.0
var playing: bool = false
var hud: Label
var hint: Label
var target: Button
var start: Button

func _ready() -> void:
	var saved := ConfigFile.new()
	if saved.load("user://scores.cfg") == OK:
		best = int(saved.get_value("score", "best", 0))
	var title := _label("TAP SPRINT", Vector2(60, 130), 64)
	title.add_theme_color_override("font_color", Color("6ee7b7"))
	_label("30 seconds. Tap the moving target.", Vector2(60, 225), 27)
	hud = _label("", Vector2(60, 310), 32)
	hint = _label("Ready when you are.", Vector2(60, 1010), 28)
	target = Button.new()
	target.text = "+1"
	target.size = Vector2(140, 140)
	target.add_theme_font_size_override("font_size", 42)
	target.pressed.connect(_hit)
	add_child(target)
	target.hide()
	start = Button.new()
	start.text = "START GAME"
	start.position = Vector2(60, 1100)
	start.size = Vector2(600, 90)
	start.add_theme_font_size_override("font_size", 30)
	start.pressed.connect(_start)
	add_child(start)
	resized.connect(_layout)
	_layout()
	_refresh()

func _layout() -> void:
	if not is_instance_valid(start):
		return
	start.position = Vector2(60, size.y - 180)
	start.size = Vector2(maxf(140, size.x - 120), 90)
	hint.position = Vector2(60, size.y - 270)
	if playing:
		_move_target()

func _input(event: InputEvent) -> void:
	# Mini-game touch input is handled directly; desktop mouse still uses Button.pressed.
	# Mouse emulation is disabled so one touch cannot score twice.
	if event is InputEventScreenTouch and event.pressed:
		var point: Vector2 = event.position
		if start.visible and start.get_global_rect().has_point(point):
			get_viewport().set_input_as_handled()
			_start()
		elif playing and target.visible and target.get_global_rect().has_point(point):
			get_viewport().set_input_as_handled()
			_hit()

func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _start() -> void:
	score = 0
	remaining = 30.0
	playing = true
	start.hide()
	target.show()
	hint.text = "Tap +1. No ads in this demo."
	_move_target()
	_refresh()

func _hit() -> void:
	if not playing:
		return
	score += 1
	_move_target()
	_refresh()

func _move_target() -> void:
	target.position = Vector2(randf_range(60, maxf(60, size.x - 200)), randf_range(440, maxf(440, hint.position.y - 200)))

func _process(delta: float) -> void:
	if not playing:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		playing = false
		best = maxi(best, score)
		var saved := ConfigFile.new()
		saved.set_value("score", "best", best)
		var result := saved.save("user://scores.cfg")
		if result != OK:
			push_warning("Could not save best score: %s" % error_string(result))
		target.hide()
		start.text = "PLAY AGAIN"
		start.show()
		hint.text = "Time! Your score: %d" % score
	_refresh()

func _refresh() -> void:
	hud.text = "Score %d     Time %02d     Best %d" % [score, ceili(remaining), best]
