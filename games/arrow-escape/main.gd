extends Control

const StoryArt = preload("res://story_art.gd")
const RELICS = ["雨中来信", "画中龙鳞", "断链墨痕", "半片铜铃", "渡口指引", "渡口断桨", "归流龙鳞", "水中红绡", "不灭灯芯", "逆城船票"]
var completed: Dictionary = {}
var collection_open: bool = false
var collection_page: int = 0
const Puzzle = preload("res://puzzle.gd")
const INK = Color("244b4a")
const MUTED = Color("8b8f7d")
const TEAL = Color("357f78")
const CORAL = Color("b96a51")
const PAPER = Color("f7f2e7")
var campaign: Array = []
var story: Array = []
var story_mode: String = ""
var story_page: int = 0
var puzzle = Puzzle.new()
var level: int = 0
var unlocked: int = 0
var lives: int = 3
var history: Array[int] = []
var hint_arrow: int = -1
var blocked_arrow: int = -1
var feedback_time: float = 0.0
var message: String = "轻点箭头，让思绪顺流而出。"
var animating: int = -1
var travel: float = 0.0
var phase: String = "playing"
var message_rect: Rect2
var collection_rect: Rect2
var board: Rect2
var cell: float = 60.0
var grid_origin: Vector2
var buttons: Dictionary = {}
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var ads: Node
var free_hints_used: int = 0
var continues_used: int = 0
var ad_feedback: String = ""
var font: Font

func _ready() -> void:
	ads = preload("res://game_ads.gd").new()
	add_child(ads)
	ads.finished.connect(_ad_finished)
	for key in ["tap", "escape", "blocked", "win", "lose"]:
		sounds[key] = load("res://audio/" + key + ".wav")
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6
		add_child(player)
		voices.append(player)
	font = preload("res://fonts/ChineseSerif.ttf")
	story = JSON.parse_string(FileAccess.get_file_as_string("res://levels/story.json"))
	campaign = JSON.parse_string(FileAccess.get_file_as_string("res://levels/campaign.json"))
	var saved := ConfigFile.new()
	if saved.load("user://arrow_escape.cfg") == OK:
		for cleared in saved.get_value("collection", "completed", []):
			if int(cleared) >= 0 and int(cleared) < campaign.size():
				completed[int(cleared)] = true
		unlocked = clampi(int(saved.get_value("progress", "unlocked", 0)), 0, campaign.size() - 1)
		if not saved.has_section_key("collection", "completed"):
			for cleared in range(unlocked):
				completed[cleared] = true
		level = clampi(int(saved.get_value("progress", "level", 0)), 0, unlocked)
		if int(saved.get_value("story", "version", 0)) < 2:
			level = 0
	resized.connect(_layout)
	load_level(level)

func load_level(index: int, show_story: bool = true) -> void:
	level = clampi(index, 0, campaign.size() - 1)
	puzzle.setup(campaign[level])
	lives = 3
	free_hints_used = 0
	continues_used = 0
	ad_feedback = ""
	history.clear()
	hint_arrow = -1
	blocked_arrow = -1
	feedback_time = 0.0
	animating = -1
	travel = 0.0
	phase = "playing"
	story_mode = "before" if show_story and level == 0 else ""
	story_page = 0
	message = "本关已通关，重玩不重复计入进度。" if completed.has(level) else "轻点箭头，让思绪顺流而出。"
	_layout()
	_save()

func _layout() -> void:
	if campaign.is_empty():
		return
	var w := size.x
	var bottom := size.y - 104.0
	buttons = {
		"restart": Rect2(32, bottom, (w - 88) / 3, 66),
		"undo": Rect2(44 + (w - 88) / 3, bottom, (w - 88) / 3, 66),
		"hint": Rect2(56 + 2 * (w - 88) / 3, bottom, (w - 88) / 3, 66),
		"previous": Rect2(w - 164, 153, 58, 54),
		"forward": Rect2(w - 96, 153, 58, 54),
		"continue": Rect2(w * 0.5 - 210, size.y * 0.5 + 84, 420, 76),
	}
	collection_rect = Rect2(32,222,w-64,42)
	message_rect = Rect2(32,bottom-82,w-64,54)
	board = Rect2(28,370,w-56,message_rect.position.y-392)
	cell = minf((board.size.x - 70) / puzzle.width, (board.size.y - 70) / puzzle.height)
	grid_origin = board.get_center() - Vector2(puzzle.width - 1, puzzle.height - 1) * cell * 0.5
	queue_redraw()

func _save() -> void:
	var saved := ConfigFile.new()
	saved.set_value("progress", "unlocked", unlocked)
	saved.set_value("progress", "level", level)
	saved.set_value("story", "version", 2)
	saved.set_value("collection", "completed", completed.keys())
	var result := saved.save("user://arrow_escape.cfg")
	if result != OK:
		push_warning("Progress could not be saved: " + error_string(result))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		press_at(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		press_at(event.position)
		get_viewport().set_input_as_handled()

func _sound(key: String) -> void:
	if voices.is_empty():
		return
	var player := voices[0]
	for voice in voices:
		if not voice.playing:
			player = voice
			break
	player.stream = sounds[key]
	player.play()

func press_at(point: Vector2) -> void:
	if ads.pending != "":
		return
	if phase == "lost" and _revive_button().has_point(point) and _can_continue_ad():
		ads.request("continue",level + 1)
		return
	if collection_open:
		if Rect2(38,175,64,52).has_point(point):
			collection_page = maxi(0,collection_page-1)
			queue_redraw()
		elif Rect2(size.x-102,175,64,52).has_point(point):
			collection_page = mini((RELICS.size()-1)/5,collection_page+1)
			queue_redraw()
		if _collection_close().has_point(point):
			collection_open = false
			queue_redraw()
		return
	if _collection_button().has_point(point):
		collection_open = true
		collection_page = level / 10
		_sound("tap")
		queue_redraw()
		return
	if story_mode != "":
		if _story_next().has_point(point):
			_sound("tap")
			if story_mode == "before":
				story_mode = ""
			else:
				load_level(level + 1 if level < campaign.size() - 1 else 0)
			queue_redraw()
		elif _story_skip().has_point(point):
			if story_mode == "before":
				story_mode = ""
			else:
				load_level(level + 1 if level < campaign.size() - 1 else 0)
			queue_redraw()
		return
	if phase != "playing":
		if buttons.continue.has_point(point):
			_sound("tap")
			if phase == "won" and level < campaign.size() - 1:
				load_level(level + 1)
			else:
				load_level(0 if phase == "won" else level, phase == "won")
		return
	if animating != -1:
		return
	for key in ["restart", "undo", "hint", "previous", "forward"]:
		if buttons[key].has_point(point):
			_sound("tap")
			match key:
				"restart": load_level(level, false)
				"undo": undo()
				"hint":
					if _needs_hint_ad():
						ads.request("hint",level + 1)
					else:
						free_hints_used += 1
						show_hint()
				"previous": load_level(maxi(0, level - 1))
				"forward":
					if level < unlocked: load_level(level + 1)
			return
	var index := hit_test(point)
	if index >= 0:
		try_arrow(index)

func hit_test(point: Vector2) -> int:
	var nearest := -1
	var distance := minf(24.0, cell * 0.32)
	for index in puzzle.paths.size():
		if puzzle.removed.has(index):
			continue
		var path: Array = puzzle.paths[index]
		for k in range(1, path.size()):
			var a := grid_origin + Vector2(path[k - 1]) * cell
			var b := grid_origin + Vector2(path[k]) * cell
			var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
			var candidate := point.distance_to(closest)
			if candidate < distance:
				distance = candidate
				nearest = index
	return nearest

func try_arrow(index: int) -> void:
	if phase != "playing" or animating != -1 or puzzle.removed.has(index):
		return
	if puzzle.blocker(index) != -1:
		lives -= 1
		_sound("blocked")
		blocked_arrow = index
		feedback_time = 0.85
		message = "前路有阻，先为它腾出一条路。"
		if lives == 0:
			phase = "lost"
			_sound("lose")
	else:
		_sound("escape")
		animating = index
		travel = 0.0
		hint_arrow = -1
		message = "一笔舒展，留下一方从容。"
	queue_redraw()

func finish_move() -> void:
	if animating < 0:
		return
	var index := animating
	animating = -1
	if puzzle.remove_arrow(index):
		history.append(index)
	if puzzle.removed.size() == puzzle.paths.size():
		phase = "won"
		completed[level] = true
		story_mode = "after" if story[level].show_comic else ""
		story_page = 0
		_sound("win")
		unlocked = maxi(unlocked, mini(level + 1, campaign.size() - 1))
		_save()
	queue_redraw()

func show_hint() -> void:
	var legal: Array[int] = puzzle.legal_moves()
	if not legal.is_empty():
		hint_arrow = legal[0]
		message = "循着微光，这一笔可以先行。"
	queue_redraw()

func undo() -> void:
	if history.is_empty():
		message = "落笔之前，不妨再看一眼。"
	else:
		puzzle.removed.erase(history.pop_back())
		hint_arrow = -1
		message = "退回一笔，换个角度。"
	queue_redraw()

func _process(delta: float) -> void:
	if feedback_time > 0:
		feedback_time = maxf(0, feedback_time - delta)
		queue_redraw()
	if animating >= 0:
		travel += delta * 24.0
		var head: Vector2i = puzzle.paths[animating][-1]
		var direction: Vector2i = puzzle.direction(animating)
		var to_edge: int = puzzle.width - head.x if direction.x > 0 else head.x + 1
		if direction.y != 0:
			to_edge = puzzle.height - head.y if direction.y > 0 else head.y + 1
		if travel > to_edge + puzzle.paths[animating].size() + 1:
			finish_move()
		queue_redraw()
	elif hint_arrow >= 0:
		queue_redraw()

func _text(value: String, at: Vector2, font_size: int, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(value: String, rect: Rect2, font_size: int, color: Color = INK) -> void:
	var text_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_text(value, Vector2(rect.get_center().x - text_size.x / 2, rect.get_center().y + font_size * 0.34), font_size, color)

func _panel(rect: Rect2, color: Color, radius: int = 24) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _sample(index: int, offset: float) -> Vector2:
	var path: Array = puzzle.paths[index]
	var last := path.size() - 1
	if offset >= last:
		return Vector2(path[last]) + Vector2(puzzle.direction(index)) * (offset - last)
	var segment := clampi(int(floor(offset)), 0, last - 1)
	return Vector2(path[segment]).lerp(Vector2(path[segment + 1]), offset - segment)

func _draw_arrow(index: int) -> void:
	var offset := travel if index == animating else 0.0
	var length: int = puzzle.paths[index].size() - 1
	var points := PackedVector2Array()
	points.append(grid_origin + _sample(index, offset) * cell)
	for k in range(int(floor(offset)) + 1, int(ceil(offset + length))):
		points.append(grid_origin + _sample(index, float(k)) * cell)
	points.append(grid_origin + _sample(index, offset + length) * cell)
	var color: Color = [INK, TEAL, CORAL, Color("a1884b"), Color("78718e")][index % 5]
	points = _rounded_path(points)
	var thickness := clampf(cell * 0.30, 10, 19)
	if index == blocked_arrow and feedback_time > 0:
		color = Color("d45a48")
		for k in points.size():
			points[k].x += sin(feedback_time * 65) * 4
	var clip := board.grow(-12)
	var polygon := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	var sections := Geometry2D.intersect_polyline_with_polygon(points, polygon)
	for section in sections:
		if section.size() < 2:
			continue
		if index == hint_arrow:
			var glow := Color("b8d69d")
			glow.a = 0.6 + sin(Time.get_ticks_msec() * 0.005) * 0.2
			draw_polyline(section, glow, thickness + 17, true)
		var shadow := PackedVector2Array()
		for point in section:
			shadow.append(point + Vector2(0, 3))
		draw_polyline(shadow, Color(0.15, 0.22, 0.19, 0.12), thickness + 3, true)
		draw_polyline(section, color, thickness, true)
		draw_polyline(section, color.lightened(0.28), thickness * 0.28, true)
		for point in section:
			draw_circle(point, thickness / 2, color, true, -1, true)
		# Belly ridge and paired scales follow the curved body.
		var spacing := 0.0
		for k in range(1, section.size()):
			var delta := section[k] - section[k - 1]
			var distance := delta.length()
			if distance < 0.1:
				continue
			var tangent := delta / distance
			var normal := Vector2(-tangent.y, tangent.x)
			var cursor := spacing
			while cursor < distance:
				var center := section[k - 1] + tangent * cursor
				draw_line(center - normal * thickness * 0.28 - tangent * 2, center + tangent * 2, color.lightened(0.5), 1.2, true)
				draw_line(center + normal * thickness * 0.28 - tangent * 2, center + tangent * 2, color.lightened(0.5), 1.2, true)
				cursor += thickness * 0.8
			spacing = cursor - distance
	var head := points[-1]
	if clip.grow(-20).has_point(head):
		_draw_dragon_head(head, Vector2(puzzle.direction(index)), color, thickness)

func _dragon_point(head: Vector2, direction: Vector2, local: Vector2, unit: float) -> Vector2:
	return head + (direction * local.x + Vector2(-direction.y, direction.x) * local.y) * unit

func _draw_dragon_head(head: Vector2, direction: Vector2, color: Color, unit: float) -> void:
	# Broad jade head, gold antlers, cheek mane, whiskers and a clear forward snout.
	var gold := Color("c5a361")
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array()
		for local in [Vector2(-0.2, side * 0.6), Vector2(-0.7, side * 1.2), Vector2(-1.3, side * 1.35)]:
			horn.append(_dragon_point(head, direction, local, unit))
		draw_polyline(horn, gold, unit * 0.2, true)
		draw_line(horn[1], _dragon_point(head, direction, Vector2(-0.65, side * 1.55), unit), gold, unit * 0.16, true)
		var mane := PackedVector2Array()
		for local in [Vector2(-0.15, side * 0.4), Vector2(-0.8, side * 1.0), Vector2(-1.15, side * 0.25)]:
			mane.append(_dragon_point(head, direction, local, unit))
		draw_colored_polygon(mane, color.lightened(0.25))
	var shape := PackedVector2Array()
	for local in [Vector2(-0.7,-0.5),Vector2(-0.15,-0.78),Vector2(0.55,-0.55),Vector2(1.0,-0.3),Vector2(1.05,0.3),Vector2(0.55,0.55),Vector2(-0.15,0.78),Vector2(-0.7,0.5)]:
		shape.append(_dragon_point(head, direction, local, unit))
	draw_colored_polygon(shape, color)
	draw_polyline(PackedVector2Array([shape[0],shape[1],shape[2],shape[3]]), color.lightened(0.4), 2, true)
	for side in [-1.0, 1.0]:
		var eye := _dragon_point(head,direction,Vector2(0.15,side * 0.42),unit)
		draw_circle(eye,unit * 0.18,Color("fff4cb"),true,-1,true)
		draw_circle(eye + direction * unit * 0.05,unit * 0.085,INK,true,-1,true)
		draw_circle(eye + Vector2(-1,-1),unit * 0.035,Color.WHITE,true,-1,true)
		var whisker := PackedVector2Array()
		for local in [Vector2(0.7,side * 0.25),Vector2(0.5,side * 0.85),Vector2(-0.1,side * 1.0)]:
			whisker.append(_dragon_point(head,direction,local,unit))
		draw_polyline(whisker,gold,1.5,true)
		draw_circle(_dragon_point(head,direction,Vector2(0.83,side * 0.16),unit),unit * 0.07,color.darkened(0.3),true,-1,true)

func _rounded_path(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var result := PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var before := points[i - 1]
		var corner := points[i]
		var after := points[i + 1]
		var radius := minf(cell * 0.20, minf(corner.distance_to(before), corner.distance_to(after)) * 0.38)
		var a := corner.move_toward(before, radius)
		var b := corner.move_toward(after, radius)
		result.append(a)
		for step in range(1, 7):
			var t := float(step) / 6.0
			result.append(a * (1.0-t) * (1.0-t) + corner * 2.0 * (1.0-t) * t + b * t * t)
	result.append(points[-1])
	return result

func _landscape() -> void:
	# Fixed paper flecks and sweeping contour lines, independent of frame timing.
	for i in range(180):
		var x := fmod(float(i * 137 + 31), size.x)
		var y := fmod(float(i * 233 + 47), size.y)
		draw_circle(Vector2(x, y), 0.8, Color(0.45, 0.35, 0.2, 0.07), true, -1, true)
	for layer in 6:
		var curve := PackedVector2Array()
		for i in range(51):
			var x := size.x * float(i) / 50.0
			var y := 230.0 + layer * 12.0 + sin(x * 0.007 + layer * 0.19) * 27.0
			curve.append(Vector2(x, y))
		draw_polyline(curve, Color(0.35, 0.52, 0.46, 0.065), 1.3, true)
	draw_circle(Vector2(size.x - 114, 194), 34, Color(0.72, 0.4, 0.28, 0.08), true, -1, true)
	draw_arc(Vector2(size.x - 114, 194), 39, -0.3, 4.8, 48, Color(0.72, 0.4, 0.28, 0.2), 1.0, true)

func _draw() -> void:
	if campaign.is_empty() or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_landscape()
	_text("箭头出逃", Vector2(32, 128), 54)
	_center("<", buttons.previous, 30, MUTED if level == 0 else INK)
	_center(">", buttons.forward, 30, MUTED if level >= unlocked else INK)
	_panel(Rect2(32, 161, 142, 42), INK, 21)
	_center("第 %02d 关" % (level + 1), Rect2(32, 161, 142, 42), 20, Color.WHITE)
	_text(campaign[level].name, Vector2(190, 191), 24, MUTED)
	_text("理清来路，寻得归途", Vector2(32, 302), 25)
	_text("已舒展 %d / %d 笔" % [puzzle.removed.size(), puzzle.paths.size()], Vector2(34, 338), 22, MUTED)
	for i in 3:
		draw_circle(Vector2(size.x - 108 + i * 27, 326), 8, CORAL if i < lives else Color("d8dfd5"), true, -1, true)
	_panel(Rect2(board.position + Vector2(0, 7), board.size), Color(0.20, 0.29, 0.24, 0.08), 32)
	_panel(board.grow(2), Color("dfdecc"), 32)
	_panel(board, Color("fffdf6"), 30)
	for y in puzzle.height:
		for x in puzzle.width:
			draw_circle(grid_origin + Vector2(x, y) * cell, 2, Color("e9e4d6"), true, -1, true)
	for index in puzzle.paths.size():
		if not puzzle.removed.has(index):
			_draw_arrow(index)
	_panel(message_rect,Color("edeadd"),16)
	_center(message,message_rect,21,MUTED)
	for key in ["restart", "undo", "hint"]:
		_panel(buttons[key], TEAL if key == "hint" else Color("e8e6d7"), 20)
		_center({"restart": "重来", "undo": "退一步", "hint": "广告寻路" if _needs_hint_ad() else "寻路"}[key], buttons[key], 24, Color.WHITE if key == "hint" else INK)
	if phase != "playing":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.19, 0.17, 0.55))
		var modal := Rect2(size.x * 0.5 - 265, size.y * 0.5 - 180, 530, 390)
		_panel(modal, Color("fffdf6"), 32)
		var won := phase == "won"
		_center("豁然开朗" if won else "再想一想", Rect2(modal.position + Vector2(0, 35), Vector2(530, 70)), 34)
		_story_lines(story[level].after_1 if won else (ad_feedback if ad_feedback != "" else "三次机会已用完，重新落笔吧。"),Rect2(modal.position + Vector2(35,125),Vector2(460,75)),22,MUTED)
		if not won and _can_continue_ad():
			_panel(_revive_button(),Color("dfd5b7"),18)
			_center("看广告 · 保留盘面再试一次",_revive_button(),20,INK)
		_panel(buttons.continue, TEAL, 22)
		_center(("从头再来" if level == campaign.size()-1 else "下一重清境") if won else "重新挑战", buttons.continue, 27, Color.WHITE)
	if story_mode != "":
		_draw_story()
	_draw_collection_strip()
	if collection_open:
		_draw_collection()

func _story_next() -> Rect2:
	return Rect2(52, size.y - 150, size.x - 104, 74)

func _story_skip() -> Rect2:
	return Rect2(size.x - 156, size.y - 214, 110, 46)

func _story_lines(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var line := ""
	var y := rect.position.y
	for ch in text:
		if font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
			_text(line, Vector2(rect.position.x, y), font_size, color)
			y += font_size * 1.65
			line = ""
		line += ch
	_text(line, Vector2(rect.position.x, y), font_size, color)

func _draw_story() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PAPER)
	_landscape()
	var chapter: Dictionary = story[level]
	var prefix := story_mode
	_text("画中有灵 · 第 %02d 回" % (level + 1),Vector2(52,164),22,MUTED)
	_center("跳过",_story_skip(),22,MUTED)
	_text(chapter[prefix + "_title"],Vector2(52,232),42,INK)
	var art := Rect2(40,274,size.x - 80,size.y * 0.37)
	_panel(art,Color("e7e9dd"),30)
	StoryArt.paint(self,art.grow(-8),int(story[level].comic_sheet),0 if story_mode == "before" else int(story[level].comic_frame))
	if story_mode == "after" and level % 2 == 1:
		_center("信物入册 · " + RELICS[level >> 1],Rect2(45,art.end.y-50,size.x-90,42),23,CORAL)
	var y := art.end.y + 62
	_story_lines(chapter[prefix + "_1"],Rect2(56,y,size.x - 112,210),27,INK)
	_center("第一章 · 雨画来信" if level < 10 else "第二章 · 无声渡口",Rect2(0,size.y - 205,size.x,32),18,MUTED)
	_panel(_story_next(),TEAL,23)
	var label := "解开这一重盘结" if story_mode == "before" else ("继续追寻" if level < campaign.size()-1 else "重访已开放章节")
	_center(label,_story_next(),26,Color.WHITE)

func _relic_owned(index: int) -> bool:
	return completed.has(index * 2) and completed.has(index * 2 + 1)

func _collection_button() -> Rect2:
	return Rect2(32, size.y - 280, size.x - 64, 46) if story_mode != "" else collection_rect

func _collection_close() -> Rect2:
	return Rect2(60,size.y - 145,size.x - 120,70)

func _collection_caption() -> String:
	var count := 0
	for i in RELICS.size():
		if _relic_owned(i):
			count += 1
	for i in RELICS.size():
		if not _relic_owned(i):
			var left := int(not completed.has(i*2)) + int(not completed.has(i*2+1))
			return "通关%d/%d · 信物%d/%d · 再%d关得%s" % [completed.size(),campaign.size(),count,RELICS.size(),left,RELICS[i]]
	return "通关%d/%d · 信物%d/%d · 下一章待寻访" % [completed.size(),campaign.size(),count,RELICS.size()]

func _collection_ratio() -> float:
	# Every newly completed level contributes half a relic, even before it is awarded.
	return clampf(float(completed.size()) / maxf(1.0,float(campaign.size())),0.0,1.0)

func _draw_collection_strip() -> void:
	var rect := _collection_button()
	var ratio := _collection_ratio()
	_panel(rect,Color("e4e6d7"),12)
	var center := rect.position + Vector2(24,rect.size.y * 0.5)
	var radius := 15.0
	draw_circle(center,radius,Color("c7cbbb"),true,-1,true)
	var disk := PackedVector2Array()
	for i in 49:
		var angle := TAU * float(i) / 48.0
		disk.append(center + Vector2(cos(angle),sin(angle)) * radius)
	if ratio > 0:
		var waterline := center.y + radius - 2.0 * radius * ratio
		var fill := PackedVector2Array([Vector2(center.x-radius,waterline),Vector2(center.x+radius,waterline),center+Vector2(radius,radius),center+Vector2(-radius,radius)])
		for section in Geometry2D.intersect_polygons(disk,fill):
			draw_colored_polygon(section,TEAL)
		draw_arc(center,radius+2,-PI*0.5,-PI*0.5+TAU*ratio,48,Color("b49a59"),2.2,true)
	# Brass bell inside a jade seal, progressively illuminated by the collection.
	draw_arc(center+Vector2(0,2),6,PI,TAU,18,Color("f4e6b9"),2,true)
	draw_line(center+Vector2(-7,2),center+Vector2(7,2),Color("f4e6b9"),2,true)
	draw_circle(center+Vector2(0,6),2,Color("f4e6b9"),true,-1,true)
	var caption := _collection_caption()
	var caption_size := 16
	while caption_size > 12 and font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x > rect.size.x-112:
		caption_size -= 1
	_text(caption,rect.position+Vector2(49,19),caption_size,INK)
	var track := Rect2(rect.position+Vector2(49,rect.size.y-13),Vector2(rect.size.x-110,7))
	_panel(track,Color("cbd0bf"),3)
	if ratio > 0:
		_panel(Rect2(track.position,Vector2(track.size.x*ratio,track.size.y)),TEAL,3)
	for i in range(1,RELICS.size()):
		var x := track.position.x + track.size.x * float(i) / RELICS.size()
		draw_line(Vector2(x,track.position.y),Vector2(x,track.end.y),Color("e4e6d7"),2,true)
	_center("%d%%" % roundi(ratio*100),Rect2(rect.end.x-57,rect.position.y,52,rect.size.y),21,TEAL)

func _draw_collection() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PAPER)
	_landscape()
	_text("画中信物",Vector2(55,150),40,INK)
	_center("<",Rect2(38,175,64,52),30,MUTED)
	_center(">",Rect2(size.x-102,175,64,52),30,MUTED)
	_center("第 %d 章 / %d 章" % [collection_page+1,(RELICS.size()+4)/5],Rect2(120,175,size.x-240,52),23,INK)
	_text("走过的路，都有回响。",Vector2(56,255),24,MUTED)
	var gap := minf(145,(size.y - 440) / 5)
	for row in 5:
		var i := collection_page * 5 + row
		if i >= RELICS.size():
			break
		var owned := _relic_owned(i)
		var rect := Rect2(48,285+row*gap,size.x-96,gap-14)
		_panel(rect,Color("e4e8db") if owned else Color("ebe7dc"),20)
		var pos := rect.position + Vector2(48,rect.size.y/2)
		draw_circle(pos,25,TEAL if owned else MUTED,true,-1,true)
		_center(str(i+1),Rect2(pos-Vector2(25,25),Vector2(50,50)),24,Color.WHITE)
		_text(RELICS[i],rect.position+Vector2(94,40),27,INK if owned else MUTED)
		_text("已收藏 · 这段记忆属于你" if owned else "完成第%d、%d关收集" % [i*2+1,i*2+2],rect.position+Vector2(94,76),19,MUTED)
	_panel(_collection_close(),TEAL,22)
	_center("继续追寻",_collection_close(),26,Color.WHITE)

func _needs_hint_ad() -> bool:
	return ads.available("hint",level + 1) and free_hints_used >= int(ads.settings.get("free_hints_per_level",1))

func _can_continue_ad() -> bool:
	return ads.available("continue",level + 1) and continues_used < int(ads.settings.get("max_continues_per_attempt",1))

func _revive_button() -> Rect2:
	return Rect2(size.x * 0.5 - 210,size.y * 0.5 + 18,420,52)

func _ad_finished(placement: String, granted: bool, error: String) -> void:
	if not granted:
		message = "广告暂不可用，可免费重新挑战。" if error != "" else "未完整观看，进度保留。"
		ad_feedback = message
		queue_redraw()
		return
	if placement == "hint" and phase == "playing":
		show_hint()
	elif placement == "continue" and phase == "lost" and continues_used < 1:
		continues_used += 1
		lives = 1
		phase = "playing"
		message = "再试一次，先为青龙找到出路。"
	queue_redraw()
