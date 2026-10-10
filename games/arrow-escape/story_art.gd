extends RefCounted

# Ten illustrated chapter sheets, each containing four chronological comic panels.
# Keep only the current sheet resident; Godot slices the atlas without duplicate files.
static var current_chapter: int = -1
static var sheet: Texture2D

static func paint(c: Control, rect: Rect2, chapter: int, panel: int) -> void:
	if current_chapter != chapter or sheet == null:
		sheet = load("res://art/comics/chapter_%02d.png" % (chapter + 1))
		current_chapter = chapter
	if sheet == null:
		return
	var half := sheet.get_size() * 0.5
	var region := Rect2(Vector2(panel % 2, panel >> 1) * half, half)
	# Fit the actual image aspect ratio; no stretching of faces or clipping of action.
	var scale := minf(rect.size.x / half.x, rect.size.y / half.y)
	var fitted := half * scale
	var destination := Rect2(rect.get_center() - fitted * 0.5, fitted)
	c.draw_texture_rect_region(sheet, destination, region)
