extends RefCounted

const SIDE := 8
const SHAPES := [
	[[0,0]], [[0,0],[1,0]], [[0,0],[0,1]],
	[[0,0],[1,0],[2,0]], [[0,0],[0,1],[0,2]],
	[[0,0],[1,0],[0,1],[1,1]],
	[[0,0],[1,0],[2,0],[3,0]], [[0,0],[0,1],[0,2],[0,3]],
	[[0,0],[0,1],[1,1]], [[0,0],[1,0],[1,1]],
	[[0,0],[1,0],[2,0],[1,1]], [[1,0],[0,1],[1,1],[2,1]],
	[[0,0],[0,1],[0,2],[1,2],[2,2]],
	[[0,0],[1,0],[1,1],[2,1]], [[1,0],[2,0],[0,1],[1,1]],
	[[0,0],[1,0],[2,0],[0,1],[1,1],[2,1]],
	[[0,0],[1,0],[2,0],[3,0],[4,0]]
]

var grid: Array = []
var pieces: Array = []
var score := 0
var combo := 0
var best := 0
var last_state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	reset()

func reset() -> void:
	grid.clear()
	for y in SIDE:
		var row: Array = []
		row.resize(SIDE)
		row.fill(0)
		grid.append(row)
	score = 0
	combo = 0
	last_state = {}
	deal()

func shape(id: int) -> Array:
	return SHAPES[id]

func fits(id: int, at: Vector2i) -> bool:
	if id < 0 or id >= SHAPES.size():
		return false
	for offset in shape(id):
		var x: int = at.x + int(offset[0])
		var y: int = at.y + int(offset[1])
		if x < 0 or y < 0 or x >= SIDE or y >= SIDE or grid[y][x] != 0:
			return false
	return true

func can_place(id: int) -> bool:
	for y in SIDE:
		for x in SIDE:
			if fits(id, Vector2i(x,y)):
				return true
	return false

func deal() -> void:
	pieces.clear()
	for i in 3:
		pieces.append(rng.randi_range(0, SHAPES.size() - 1))

func is_over() -> bool:
	for id in pieces:
		if id >= 0 and can_place(id):
			return false
	return true

func snapshot() -> Dictionary:
	return {"grid":grid.duplicate(true), "pieces":pieces.duplicate(), "score":score, "combo":combo}

func restore(data: Dictionary) -> bool:
	var rows = data.get("grid")
	var tray = data.get("pieces")
	if not rows is Array or rows.size() != SIDE or not tray is Array or tray.size() != 3:
		return false
	for row in rows:
		if not row is Array or row.size() != SIDE:
			return false
		for value in row:
			if not (value is int or value is float) or int(value) < 0 or int(value) > 6:
				return false
	for value in tray:
		if not (value is int or value is float) or int(value) < -1 or int(value) >= SHAPES.size():
			return false
	var any_piece := false
	for value in tray:
		any_piece = any_piece or int(value) >= 0
	if not any_piece or not (data.get("score",0) is int or data.get("score",0) is float):
		return false
	grid = rows.duplicate(true)
	pieces = tray.duplicate()
	score = maxi(0,int(data.get("score",0)))
	combo = maxi(0,int(data.get("combo",0)))
	last_state = {}
	return true

func place(slot: int, at: Vector2i) -> Dictionary:
	if slot < 0 or slot >= pieces.size() or not fits(int(pieces[slot]), at):
		return {}
	last_state = snapshot()
	var id: int = pieces[slot]
	var color_id: int = id % 6 + 1
	for offset in shape(id):
		grid[at.y + int(offset[1])][at.x + int(offset[0])] = color_id
	pieces[slot] = -1
	var rows: Array = []
	var columns: Array = []
	for i in SIDE:
		var full_row := true
		var full_column := true
		for j in SIDE:
			full_row = full_row and grid[i][j] != 0
			full_column = full_column and grid[j][i] != 0
		if full_row:
			rows.append(i)
		if full_column:
			columns.append(i)
	var cleared: Array = []
	for y in SIDE:
		for x in SIDE:
			if rows.has(y) or columns.has(x):
				cleared.append(Vector2i(x,y))
	for cell in cleared:
		grid[cell.y][cell.x] = 0
	var lines: int = rows.size() + columns.size()
	combo = combo + 1 if lines > 0 else 0
	var earned: int = shape(id).size() + lines * lines * 20 + maxi(0,combo - 1) * 15
	score += earned
	best = maxi(best,score)
	if pieces.all(func(value): return value == -1):
		deal()
	return {"earned":earned, "lines":lines, "cleared":cleared, "over":is_over()}

func undo() -> bool:
	if last_state.is_empty():
		return false
	var previous := last_state.duplicate(true)
	return restore(previous)
