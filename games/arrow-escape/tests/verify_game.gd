extends SceneTree

func _init() -> void:
	_run.call_deferred()

func tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = false
	root.push_input(event, true)

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	assert(game.campaign.size() == 20)
	assert(game.story.size() == 20)
	for sheet in 2:
		var texture: Texture2D = load("res://art/comics/chapter_%02d.png" % (sheet+1))
		assert(texture != null and texture.get_width() >= 1000)
	var season: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/season_100.json"))
	assert(season.planned_levels == 100 and season.chapters.size() == 10)
	assert(season.chapters[9].levels[1] == 100)

	game.load_level(0)
	assert(game.story_mode == "before")
	tap(game._story_next().get_center())
	assert(game.story_mode == "" and game.phase == "playing")
	game.completed.clear()
	game.completed[0] = true
	assert(not game._relic_owned(0), "One level cannot award a two-level relic")
	game.completed[1] = true
	assert(game._relic_owned(0))
	game.completed.clear()
	for cleared in 6:
		game.completed[cleared] = true
	assert(is_equal_approx(game._collection_ratio(),0.30))
	assert(game._relic_owned(2) and not game._relic_owned(3))
	game.completed[6] = true
	assert(is_equal_approx(game._collection_ratio(),0.35), "Level seven must advance fill despite no whole relic")
	assert(not game._relic_owned(3))
	game.completed[6] = true
	assert(is_equal_approx(game._collection_ratio(),0.35), "Replay must not inflate progress")
	game.completed[7] = true
	assert(is_equal_approx(game._collection_ratio(),0.40) and game._relic_owned(3))
	game._save()
	var partial = load("res://main.tscn").instantiate()
	root.add_child(partial)
	partial.set_process(false)
	assert(partial.completed.size() == 8 and is_equal_approx(partial._collection_ratio(),0.40))
	partial.queue_free()
	await process_frame
	game.completed.clear()
	for chapter in game.campaign.size():
		game.load_level(chapter)
		game.story_mode = "after"
		game.queue_redraw()
		await process_frame
	game.story_mode = ""
	var total := 0
	var blocked_levels := 0
	for level in game.campaign.size():
		game.load_level(level, false)
		var occupied: Dictionary = {}
		for path in game.puzzle.paths:
			assert(path.size() >= 2)
			for i in path.size():
				var point: Vector2i = path[i]
				assert(not occupied.has(point), "Paths must not overlap")
				assert(point.x >= 0 and point.x < game.puzzle.width and point.y >= 0 and point.y < game.puzzle.height)
				occupied[point] = true
				if i > 0:
					assert((point - path[i - 1]).length_squared() == 1)
		var solution: Array[int] = game.puzzle.solution()
		assert(solution.size() == game.puzzle.paths.size(), "Every level must be solvable")
		assert(game.puzzle.removed.is_empty(), "Solver must preserve live state")
		for index in game.puzzle.paths.size():
			if game.puzzle.blocker(index) != -1:
				game.try_arrow(index)
				assert(game.lives == 2 and game.puzzle.removed.is_empty())
				blocked_levels += 1
				break
		game.load_level(level, false)
		game.show_hint()
		assert(game.hint_arrow in game.puzzle.legal_moves())
		# Exercise actual viewport touch dispatch, not just game helper methods.
		var first: int = solution[0]
		var path: Array = game.puzzle.paths[first]
		var at: Vector2 = game.grid_origin + (Vector2(path[0]) + Vector2(path[1])) * game.cell / 2
		assert(game.hit_test(at) == first)
		tap(at)
		assert(game.animating == first)
		tap(at)
		game.finish_move()
		assert(game.puzzle.removed.size() == 1, "One touch must remove exactly one arrow")
		game.undo()
		assert(game.puzzle.removed.is_empty())
		for index in solution:
			assert(game.puzzle.blocker(index) == -1)
			game.try_arrow(index)
			game.finish_move()
			total += 1
		assert(game.phase == "won")
		if game.story[level].show_comic:
			assert(game.story_mode == "after")
			tap(game._story_next().get_center())
		else:
			assert(game.story_mode == "")
			tap(game.buttons.continue.get_center())
		if game.story_mode != "":
			tap(game._story_skip().get_center())
		assert(game.story_mode == "")
		assert(game.unlocked >= mini(level + 1, game.campaign.size()-1))
	assert(game.completed.size() == 20)
	for i in game.RELICS.size():
		assert(game._relic_owned(i))
	game.load_level(0, false)
	tap(game._collection_button().get_center())
	assert(game.collection_open)
	await process_frame
	tap(game.buttons.hint.get_center())
	assert(game.collection_open and game.hint_arrow == -1)
	tap(Vector2(game.size.x-70,200))
	assert(game.collection_page == 1)
	await process_frame
	tap(game._collection_close().get_center())
	assert(not game.collection_open)
	var restored = load("res://main.tscn").instantiate()
	root.add_child(restored)
	restored.set_process(false)
	assert(restored.completed.size() == 20, "Collection must survive reopening")
	for i in restored.RELICS.size():
		assert(restored._relic_owned(i))
	restored.queue_free()
	await process_frame
	assert(blocked_levels >= 7, "Later levels need meaningful dependencies")
	game.load_level(5, false)
	var bad := -1
	for index in game.puzzle.paths.size():
		if game.puzzle.blocker(index) != -1:
			bad = index
			break
	assert(bad >= 0)
	for i in 3:
		game.try_arrow(bad)
	assert(game.phase == "lost")
	tap(game.buttons.continue.get_center())
	assert(game.phase == "playing" and game.lives == 3)
	for dimensions in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(900, 1280)]:
		root.size = dimensions
		await process_frame
		game._layout()
		assert(game.board.end.y + 20 <= game.message_rect.position.y)
		assert(game.message_rect.end.y + 20 <= game.buttons.hint.position.y)
		assert(game.collection_rect.end.y + 10 < 277)
		assert(not game.collection_rect.intersects(Rect2(32,277,500,30)))
		assert(game.board.position.y >= 365)
		assert(game.buttons.hint.end.x <= game.size.x)
		assert(game.buttons.hint.end.y < game.size.y)
	assert(not game.ads.available("hint",11), "Ads stay disabled without real configuration")
	game.phase = "lost"
	game.lives = 0
	game.continues_used = 0
	var old_removed: int = game.puzzle.removed.size()
	game._ad_finished("continue",false,"")
	assert(game.lives == 0 and game.phase == "lost")
	game._ad_finished("continue",true,"")
	assert(game.lives == 1 and game.continues_used == 1)
	assert(game.puzzle.removed.size() == old_removed)
	game.phase = "lost"
	game._ad_finished("continue",true,"")
	assert(game.phase == "lost", "Duplicate result cannot grant another revive")
	var saved := ConfigFile.new()
	assert(saved.load("user://arrow_escape.cfg") == OK)
	assert(int(saved.get_value("progress", "unlocked")) == 19)
	print("PASS: 20 solvable original levels, %d removals, touch, hints, undo, failure/retry, progress, responsive layout, single-panel milestones, collection milestones and persistence" % total)
	game.queue_free()
	await process_frame
	quit(0)

