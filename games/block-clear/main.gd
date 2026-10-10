extends Control

const Board = preload("res://board.gd")
const Ads = preload("res://ad_config.gd")
var reward_rect := Rect2()
var banner_rect := Rect2()
var reward_ready := false
var reward_pending := false
var reward_used := false
var ad_sdk: Node
const COLORS := [Color("55d9bb"),Color("71aaff"),Color("ffbd6b"),Color("bc98ff"),Color("ff839d"),Color("6dd6ec")]
const INK := Color("edf4ff")
const MUTED := Color("8fabc8")
var game = Board.new()
var board_rect := Rect2()
var slots: Array[Rect2] = []
var undo_rect := Rect2()
var restart_rect := Rect2()
var play_rect := Rect2()
var cell := 78.0
var selected := -1
var dragging := false
var pointer := Vector2.ZERO
var press_origin := Vector2.ZERO
var preview := Vector2i(-100,-100)
var over := false
var confirm_restart := false
var message := "拖动方块，填满整行或整列即可消除"
var flash_cells: Array = []
var flash_time := 0.0
var message_time := 0.0
var active_touch := -1
var font: Font
var particles: Array = []
var score_popups: Array = []
var burst_time := 0.0
var burst_text := ""
var sound_rect := Rect2()
var sound_enabled := true
var sfx: AudioStreamPlayer
var voice: AudioStreamPlayer
var sound_bank: Dictionary = {}
var voice_bank: Dictionary = {}
const VOICE_COUNTS := {"great":6,"amazing":5,"combo":6,"again":3}
var voice_pools: Dictionary = {}
var last_voice: Dictionary = {}
var voice_cooldown := 0.0

func _ready() -> void:
	ad_sdk = get_node_or_null("/root/MiniGameSDK")
	if Ads.REWARDED_ENABLED and not Ads.REWARDED_UNIT_ID.is_empty() and ad_sdk != null:
		ad_sdk.ad_created.connect(_ad_created)
		ad_sdk.rewarded_ad_result.connect(_reward_result)
		ad_sdk.create_rewarded_ad(Ads.REWARDED_UNIT_ID)
	font = preload("res://assets/fonts/Chinese.ttf")
	sfx = AudioStreamPlayer.new()
	voice = AudioStreamPlayer.new()
	add_child(sfx)
	add_child(voice)
	for key in ["place", "clear", "combo", "invalid"]:
		sound_bank[key] = load("res://assets/audio/" + key + ".wav")
	for key in VOICE_COUNTS:
		for i in VOICE_COUNTS[key]:
			voice_bank[key + "_" + str(i)] = load("res://assets/audio/voice_" + key + "_" + str(i) + ".mp3")
	voice.volume_db = -3.0
	sfx.volume_db = -6.0
	_load_game()
	resized.connect(_layout)
	_layout()
	queue_redraw()

func _layout() -> void:
	var side := minf(size.x - 64, size.y * 0.50)
	if Ads.BANNER_RESERVED:
		side = minf(side,size.y-740-Ads.BANNER_HEIGHT)
	cell = side / 8.0
	board_rect = Rect2((size.x - side) / 2.0, 240, side, side)
	var tray_y := board_rect.end.y + 55
	slots.clear()
	for i in 3:
		slots.append(Rect2(32 + i * (size.x - 64) / 3.0, tray_y, (size.x - 64) / 3.0 - 10, 170))
	undo_rect = Rect2(32, size.y - 115, (size.x - 76) / 2.0, 70)
	restart_rect = Rect2(undo_rect.end.x + 12,size.y - 115,undo_rect.size.x,70)
	banner_rect = Rect2(0,size.y-Ads.BANNER_HEIGHT,size.x,Ads.BANNER_HEIGHT)
	if Ads.BANNER_RESERVED:
		undo_rect.position.y -= Ads.BANNER_HEIGHT
		restart_rect.position.y -= Ads.BANNER_HEIGHT
	play_rect = Rect2(size.x / 2 - 190, size.y / 2 + 75, 380, 76)
	reward_rect = Rect2(size.x/2-190,size.y/2-10,380,65)
	sound_rect = Rect2(size.x - 174, 38, 142, 50)
	queue_redraw()

func _panel(rect: Rect2, color: Color, radius: float = 16.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style,rect)

func _text(value: String, at: Vector2, px: int, color: Color = INK) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _center(value: String, rect: Rect2, px: int, color: Color = INK) -> void:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	_text(value,Vector2(rect.get_center().x - width/2, rect.get_center().y + px*0.34),px,color)

func _tile(rect: Rect2, color: Color) -> void:
	_panel(rect,color,8)
	draw_line(rect.position + Vector2(9,5),Vector2(rect.end.x-9,rect.position.y+5),color.lightened(0.22),3,true)

func _extent(id: int) -> Vector2:
	var result := Vector2.ONE
	for offset in game.shape(id):
		result.x = maxf(result.x,float(offset[0])+1)
		result.y = maxf(result.y,float(offset[1])+1)
	return result

func _shape(id: int, at: Vector2, tile_size: float, alpha: float = 1.0) -> void:
	var color: Color = COLORS[id % COLORS.size()]
	color.a = alpha
	for offset in game.shape(id):
		_tile(Rect2(at + Vector2(offset[0],offset[1])*tile_size + Vector2(3,3),Vector2.ONE*(tile_size-6)),color)

func _draw() -> void:
	if font == null:
		return
	_text("方块消除",Vector2(32,80),42)
	_text("留一点空间，多一份可能",Vector2(34,120),22,MUTED)
	_panel(sound_rect,Color("1a3045"))
	_center("声音：开" if sound_enabled else "声音：关",sound_rect,21,MUTED)
	_panel(Rect2(32,150,size.x-64,66),Color("152438"))
	_text("当前得分",Vector2(52,175),15,MUTED)
	_text(str(game.score),Vector2(52,202),28)
	_text("最高分  " + str(game.best),Vector2(size.x-235,191),23,COLORS[0])
	_panel(board_rect.grow(12),Color("18283c"),22)
	for y in 8:
		for x in 8:
			var rect := Rect2(board_rect.position+Vector2(x,y)*cell+Vector2(3,3),Vector2.ONE*(cell-6))
			var value: int = int(game.grid[y][x])
			if value == 0:
				_panel(rect,Color("223449"),8)
			else:
				_tile(rect,COLORS[value-1])
	if selected >= 0 and preview.x > -50:
		var id: int = game.pieces[selected]
		var valid: bool = game.fits(id,preview)
		for offset in game.shape(id):
			var pos := preview+Vector2i(offset[0],offset[1])
			if pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8:
				var color := Color(0.4,1,0.8,0.42) if valid else Color(1,0.3,0.4,0.4)
				_panel(Rect2(board_rect.position+Vector2(pos)*cell+Vector2(3,3),Vector2.ONE*(cell-6)),color,8)
	for pos in flash_cells:
		_panel(Rect2(board_rect.position+Vector2(pos)*cell+Vector2(3,3),Vector2.ONE*(cell-6)),Color(1,1,1,flash_time/0.35),8)
		var sweep := 1.0 - flash_time / 0.35
		var center: Vector2 = board_rect.position + (Vector2(pos) + Vector2.ONE * 0.5) * cell
		draw_line(center-Vector2(cell*0.5,0),center+Vector2(cell*0.5,0),Color(0.65,1,0.95,(1-sweep)*0.8),maxf(1,cell*(1-sweep)*0.3),true)
	for particle in particles:
		var tint: Color = particle.color
		tint.a = particle.life / particle.duration
		draw_circle(particle.position,particle.radius*tint.a,tint)
	for popup in score_popups:
		var tint := COLORS[2]
		tint.a = popup.life / 0.9
		_center(popup.text,Rect2(popup.position-Vector2(100,25),Vector2(200,50)),34,tint)
	if burst_time > 0:
		var pulse := 1.0 + sin((1.0-burst_time)*PI)*0.05
		var banner := Rect2(90,board_rect.get_center().y-42,size.x-180,84)
		_panel(banner,Color(0.05,0.14,0.2,minf(0.95,burst_time*3)),22)
		_center(burst_text,banner,int(34*pulse),COLORS[0])
	for i in 3:
		_panel(slots[i],Color("263e53") if selected == i else Color("142337"))
		var id: int = int(game.pieces[i])
		if id >= 0:
			var tile_size := minf(33,(slots[i].size.x-28)/_extent(id).x)
			_shape(id,slots[i].get_center()-_extent(id)*tile_size/2,tile_size,0.35 if dragging and selected == i else 1.0)
		else:
			_center("已放置",slots[i],17,MUTED)
	_center(message,Rect2(20,slots[0].end.y+12,size.x-40,42),21,COLORS[0] if message_time > 0 else MUTED)
	if game.combo > 0:
		_center("连消  " + str(game.combo),Rect2(0,board_rect.position.y-26,size.x,22),15,COLORS[2])
	_panel(undo_rect,Color("1a3045"))
	_panel(restart_rect,Color("1a3045"))
	_center("撤销一步",undo_rect,23,MUTED if game.last_state.is_empty() else INK)
	_center("重新开始",restart_rect,23)
	if dragging and selected >= 0 and not board_rect.has_point(pointer-Vector2(0,80)):
		var id: int = game.pieces[selected]
		_shape(id,pointer-Vector2(0,80)-_extent(id)*cell/2,cell,0.85)
	if over or confirm_restart:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.04,0.07,0.88))
		var panel := Rect2(40,size.y/2-170,size.x-80,350)
		_panel(panel,Color("1b2e43"),28)
		_center("暂时没有空位啦" if over else "开始新的一局？",Rect2(40,panel.position.y+25,size.x-80,60),33)
		_center("本局得分  " + str(game.score) if over else "当前棋盘将被清空",Rect2(40,panel.position.y+100,size.x-80,50),24,MUTED)
		_panel(play_rect,COLORS[0])
		_center("再来一局" if over else "确认重新开始",play_rect,25,Color("102d2a"))
		if over and reward_ready and not reward_used and not game.last_state.is_empty():
			_panel(reward_rect,Color("304b69"))
			_center("视频加载中" if reward_pending else "看视频，撤销一步",reward_rect,23)
		if confirm_restart:
			_center("点击外侧取消",Rect2(0,panel.end.y+12,size.x,35),20,MUTED)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_down(event.position)
		elif not event.pressed and event.index == active_touch:
			if not event.canceled:
				_up(event.position)
			else:
				dragging = false
				preview = Vector2i(-100,-100)
			active_touch = -1
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		if event.pressed:
			_down(event.position)
		else:
			_up(event.position)
	elif event is InputEventMouseMotion and active_touch == -1:
		_move(event.position)

func _down(at: Vector2) -> void:
	pointer = at
	press_origin = at
	if over or confirm_restart:
		return
	for i in 3:
		if slots[i].has_point(at) and game.pieces[i] >= 0:
			selected = i
			preview = Vector2i(-100,-100)
			queue_redraw()
			return
	_update_preview(at)

func _move(at: Vector2) -> void:
	pointer = at
	if selected >= 0 and at.distance_to(press_origin) > 15 and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or active_touch >= 0):
		dragging = true
	_update_preview(at-Vector2(0,80) if dragging else at)
	queue_redraw()

func _update_preview(at: Vector2) -> void:
	preview = Vector2i(-100,-100)
	if selected < 0 or not board_rect.has_point(at):
		return
	var extent := _extent(int(game.pieces[selected]))
	preview = Vector2i(((at-board_rect.position)/cell).floor())-Vector2i((extent/2).floor())

func _up(at: Vector2) -> void:
	if sound_rect.has_point(at) and sound_rect.has_point(press_origin):
		sound_enabled = not sound_enabled
		if not sound_enabled:
			sfx.stop()
			voice.stop()
		_save_game()
		queue_redraw()
		return
	if over or confirm_restart:
		if reward_pending:
			return
		if over and reward_ready and not reward_used and not game.last_state.is_empty() and reward_rect.has_point(at) and reward_rect.has_point(press_origin):
			reward_pending = true
			ad_sdk.show_rewarded_ad()
			queue_redraw()
			return
		if play_rect.has_point(at) and play_rect.has_point(press_origin):
			game.reset()
			reward_used = false
			over = false
			confirm_restart = false
			selected = -1
			message = "拖动方块，填满整行或整列即可消除"
			particles.clear()
			score_popups.clear()
			flash_cells.clear()
			burst_time = 0
			_save_game()
		elif confirm_restart:
			confirm_restart = false
		queue_redraw()
		return
	if undo_rect.has_point(at) and undo_rect.has_point(press_origin):
		if game.undo():
			selected = -1
			over = false
			message = "已撤销上一步"
			particles.clear()
			score_popups.clear()
			flash_cells.clear()
			burst_time = 0
			_save_game()
	elif restart_rect.has_point(at) and restart_rect.has_point(press_origin):
		confirm_restart = true
	elif selected >= 0:
		_update_preview(at-Vector2(0,80) if dragging else at)
		if preview.x > -50:
			var result: Dictionary = game.place(selected,preview)
			if not result.is_empty():
				selected = -1
				over = result.over
				flash_cells = result.cleared
				flash_time = 0.35
				message = ("消除 %d 行列！  +%d 分" % [result.lines,result.earned]) if result.lines > 0 else "+%d 分，继续寻找好位置" % result.earned
				_feedback(result)
				message_time = 2.0
				_save_game()
			else:
				message = "这里放不下，换个位置试试"
				_play_sound("invalid")
				message_time = 1.5
	dragging = false
	preview = Vector2i(-100,-100)
	queue_redraw()

func _ad_created(kind: String, success: bool, _error: String) -> void:
	if kind == "rewarded":
		reward_ready = success
		queue_redraw()

func _reward_result(ended: bool, error: String) -> void:
	if not reward_pending:
		return
	reward_pending = false
	if ended and error.is_empty() and over and not reward_used and game.undo():
		reward_used = true
		over = false
		selected = -1
		message = "已撤销上一步"
		_save_game()
	queue_redraw()

func _process(delta: float) -> void:
	voice_cooldown = maxf(0,voice_cooldown-delta)
	if not particles.is_empty() or not score_popups.is_empty() or burst_time > 0:
		for particle in particles:
			particle.life -= delta
			particle.position += particle.velocity * delta
			particle.velocity.y += 250 * delta
		particles = particles.filter(func(p): return p.life > 0)
		for popup in score_popups:
			popup.life -= delta
			popup.position.y -= 65 * delta
		score_popups = score_popups.filter(func(p): return p.life > 0)
		burst_time = maxf(0,burst_time-delta)
		queue_redraw()
	if flash_time > 0:
		flash_time = maxf(0,flash_time-delta)
		if flash_time == 0:
			flash_cells.clear()
		queue_redraw()
	if message_time > 0:
		message_time = maxf(0,message_time-delta)
		if message_time == 0:
			message = "拖动放置，或先选方块再点棋盘"
			queue_redraw()

func _save_game() -> void:
	var data: Dictionary = game.snapshot()
	data["best"] = game.best
	data["sound"] = sound_enabled
	var file := FileAccess.open("user://block-clear.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_game() -> void:
	if not FileAccess.file_exists("user://block-clear.json"):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://block-clear.json"))
	if data is Dictionary and game.restore(data):
		game.best = maxi(game.score,int(data.get("best",0)))
		sound_enabled = bool(data.get("sound",true))
		over = game.is_over()

func _play_sound(key: String, spoken: String = "") -> void:
	if not sound_enabled:
		return
	sfx.stream = sound_bank[key]
	sfx.play()
	if not spoken.is_empty() and (spoken == "again" or (voice_cooldown == 0 and not voice.playing)):
		voice.stream = voice_bank[_next_voice(spoken)]
		voice.play()
		voice_cooldown = 2.8

func _next_voice(category: String) -> String:
	if not voice_pools.has(category) or voice_pools[category].is_empty():
		var pool: Array = []
		for i in VOICE_COUNTS[category]:
			pool.append(category + "_" + str(i))
		pool.shuffle()
		if pool.back() == last_voice.get(category, ""):
			var previous = pool.pop_back()
			pool.push_front(previous)
		voice_pools[category] = pool
	var chosen: String = voice_pools[category].pop_back()
	last_voice[category] = chosen
	return chosen

func _feedback(result: Dictionary) -> void:
	score_popups.append({"text":"+%d" % result.earned,"position":pointer-Vector2(0,65),"life":0.9})
	if result.lines > 0:
		burst_time = 0.95
		burst_text = "连消 %d 次！" % game.combo if game.combo > 1 else ("太棒了！多线消除" if result.lines > 1 else "漂亮！")
		_play_sound("combo" if game.combo > 1 else "clear", "combo" if game.combo > 1 else ("amazing" if result.lines > 1 else "great"))
		for pos in result.cleared:
			for i in 5:
				var duration := randf_range(0.4,0.8)
				particles.append({"position":board_rect.position+(Vector2(pos)+Vector2.ONE*0.5)*cell,"velocity":Vector2(randf_range(-170,170),randf_range(-240,40)),"color":COLORS[(pos.x+pos.y)%6],"radius":randf_range(3,7),"life":duration,"duration":duration})
	else:
		_play_sound("place")
	if result.over:
		_play_sound("invalid","again")
