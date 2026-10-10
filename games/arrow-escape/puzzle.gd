class_name ArrowPuzzle
extends RefCounted

var width: int
var height: int
var paths: Array = []
var removed: Dictionary = {}

func setup(data: Dictionary) -> void:
	width = int(data.width)
	height = int(data.height)
	paths.clear()
	removed.clear()
	for raw in data.paths:
		var path: Array[Vector2i] = []
		for point in raw:
			path.append(Vector2i(int(point[0]), int(point[1])))
		paths.append(path)

func direction(index: int) -> Vector2i:
	var path: Array = paths[index]
	return path[-1] - path[-2]

func blocker(index: int) -> int:
	if removed.has(index):
		return -1
	var occupied: Dictionary = {}
	for other in paths.size():
		if other == index or removed.has(other):
			continue
		for point in paths[other]:
			occupied[point] = other
	var point: Vector2i = paths[index][-1] + direction(index)
	while point.x >= 0 and point.x < width and point.y >= 0 and point.y < height:
		if occupied.has(point):
			return int(occupied[point])
		point += direction(index)
	return -1

func legal_moves() -> Array[int]:
	var result: Array[int] = []
	for index in paths.size():
		if not removed.has(index) and blocker(index) == -1:
			result.append(index)
	return result

func remove_arrow(index: int) -> bool:
	if index < 0 or index >= paths.size() or removed.has(index) or blocker(index) != -1:
		return false
	removed[index] = true
	return true

func solution() -> Array[int]:
	var previous := removed.duplicate()
	var result: Array[int] = []
	while removed.size() < paths.size():
		var moves := legal_moves()
		if moves.is_empty():
			result.clear()
			break
		result.append(moves[0])
		removed[moves[0]] = true
	removed = previous
	return result
