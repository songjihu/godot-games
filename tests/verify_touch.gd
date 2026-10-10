extends SceneTree

func _init() -> void:
    _run.call_deferred()

func _tap(at: Vector2) -> void:
    var down := InputEventScreenTouch.new()
    down.index = 0
    down.position = at
    down.pressed = true
    root.push_input(down)
    var up := InputEventScreenTouch.new()
    up.index = 0
    up.position = at
    up.pressed = false
    root.push_input(up)

func _run() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    await process_frame
    assert(not Input.is_emulating_mouse_from_touch())
    for viewport_size in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(900, 1280)]:
        root.size = viewport_size
        await process_frame
        scene._layout()
        assert(is_equal_approx(scene.start.position.y, scene.size.y - 180))
        assert(is_equal_approx(scene.start.size.x, scene.size.x - 120))
        assert(scene.get_rect().encloses(scene.start.get_rect()))
    _tap(scene.start.get_global_rect().get_center())
    assert(scene.playing, "Touch must start the game through viewport input dispatch")
    assert(scene.score == 0)
    for i in range(5):
        _tap(scene.target.get_global_rect().get_center())
        assert(scene.score == i + 1, "One touch must score exactly once")
    _tap(Vector2(2, 2))
    assert(scene.score == 5, "A miss must not score")
    scene._process(31.0)
    assert(not scene.playing)
    _tap(scene.start.get_global_rect().get_center())
    assert(scene.playing and scene.score == 0)
    print("PASS: viewport-dispatched touch start, exactly-once scoring, miss, timeout, restart, responsive layouts")
    scene.queue_free()
    quit(0)
