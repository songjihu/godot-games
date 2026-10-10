extends SceneTree
const Board = preload("res://board.gd")

func _init() -> void:
	_run.call_deferred()

func _tap(at: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	var game = Board.new()
	game.pieces = [0,0,0]
	assert(not game.fits(0,Vector2i(-1,0)))
	assert(not game.fits(1,Vector2i(7,0)))
	for i in 8:
		if i != 3:
			game.grid[2][i] = 1
		if i != 2:
			game.grid[i][3] = 2
	var result: Dictionary = game.place(0,Vector2i(3,2))
	assert(result.lines == 2 and result.cleared.size() == 15)
	assert(game.score == 81 and game.combo == 1)
	assert(game.undo() and game.score == 0 and game.grid[2][3] == 0)
	assert(not game.undo())
	var saved: Dictionary = game.snapshot()
	assert(game.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(not game.restore({"grid":[],"pieces":[]}))
	for y in 8:
		for x in 8:
			game.grid[y][x] = 1
	assert(game.is_over())
	assert(game.place(0,Vector2i(0,0)).is_empty())
	# Deterministic seeded play checks all intermediate moves and restores.
	for seed_value in 20:
		game.rng.seed = seed_value
		game.reset()
		for turn in 100:
			if game.is_over():
				break
			var placed := false
			for slot in 3:
				for y in 8:
					for x in 8:
						if not placed and game.fits(int(game.pieces[slot]),Vector2i(x,y)):
							assert(not game.place(slot,Vector2i(x,y)).is_empty())
							placed = true
			assert(placed)
			assert(game.restore(JSON.parse_string(JSON.stringify(game.snapshot()))))
	print("PASS: simultaneous row/column clear, score, collision, undo, save, game over, 20 seeded games")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.game.reset()
	scene.over = false
	scene.game.pieces = [0,0,0]
	_tap(scene.slots[0].get_center())
	assert(scene.selected == 0)
	_tap(scene.board_rect.position + Vector2.ONE * scene.cell / 2)
	assert(scene.game.grid[0][0] != 0 and scene.game.score == 1)
	assert(scene.game.pieces[0] == -1)
	_tap(scene.undo_rect.get_center())
	assert(scene.game.score == 0 and scene.game.grid[0][0] == 0)
	# Drag the second slot onto a different cell, offset above finger.
	var start := scene.slots[1].get_center() as Vector2
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = start
	down.pressed = true
	root.push_input(down, true)
	var landing: Vector2 = scene.board_rect.position + Vector2(2.5,2.5)*scene.cell + Vector2(0,80)
	var move := InputEventScreenDrag.new()
	move.index = 0
	move.position = landing
	root.push_input(move, true)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = landing
	root.push_input(up, true)
	assert(scene.game.grid[2][2] != 0 and scene.game.score == 1)
	for viewport_size in [Vector2i(720,1280),Vector2i(720,1560),Vector2i(900,1280)]:
		root.size = viewport_size
		await process_frame
		assert(scene.board_rect.end.y < scene.slots[0].position.y)
		assert(scene.slots[0].end.y + 50 < scene.undo_rect.position.y)
		assert(scene.undo_rect.end.y < scene.size.y)
	print("PASS: actual viewport touch selection, placement, single scoring, undo, drag, responsive layout")
	scene.game.reset()
	scene.over = false
	scene.game.pieces = [0,0,0]
	for x in 7:
		scene.game.grid[0][x] = 1
	_tap(scene.slots[0].get_center())
	_tap(scene.board_rect.position + Vector2(7.5,0.5)*scene.cell)
	assert(scene.game.combo == 1 and scene.particles.size() == 40)
	assert(scene.burst_time > 0 and not scene.score_popups.is_empty())
	assert(scene.voice_bank.great_0 is AudioStreamMP3)
	scene.voice_pools.clear()
	scene.last_voice.clear()
	for category in scene.VOICE_COUNTS:
		var heard: Array = []
		var previous := ""
		for i in scene.VOICE_COUNTS[category]*3:
			var chosen: String = scene._next_voice(category)
			assert(chosen != previous)
			assert(scene.voice_bank[chosen] is AudioStreamMP3)
			if i % scene.VOICE_COUNTS[category] == 0:
				heard.clear()
			assert(not heard.has(chosen))
			heard.append(chosen)
			previous = chosen
	assert(scene.sound_bank.clear is AudioStreamWAV)
	var was_enabled: bool = scene.sound_enabled
	_tap(scene.sound_rect.get_center())
	assert(scene.sound_enabled != was_enabled)
	scene._process(1.0)
	assert(scene.particles.is_empty() and scene.score_popups.is_empty())
	print("PASS: clear particles, score popup, Chinese voice assets, mute toggle, effect cleanup")
	scene.queue_free()
	# Reward is only granted once, after a successful completed video callback.
	scene.game.reset()
	scene.game.pieces = [0,0,0]
	scene.game.place(0,Vector2i(0,0))
	scene.over = true
	scene.reward_pending = true
	scene._reward_result(false,"")
	assert(scene.over and scene.game.score == 1 and not scene.reward_used)
	scene.reward_pending = true
	scene._reward_result(true,"load failed")
	assert(scene.over and scene.game.score == 1)
	scene.reward_pending = true
	scene._reward_result(true,"")
	assert(not scene.over and scene.game.score == 0 and scene.reward_used)
	scene._reward_result(true,"")
	assert(scene.game.score == 0)
	print("PASS: reward cancelled/error gives nothing; complete grants one undo; duplicate ignored")
	await process_frame
	quit(0)

