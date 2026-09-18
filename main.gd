extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const WORLD_WIDTH := 3800.0
const FLOOR_Y := 635.0
const CEILING_HEIGHT := 85.0
const HALF_VIEW_WIDTH := 640.0
const FINISH_X := 3650.0
const CAMERA_SCROLL_SPEED := 55.0
const LEFT_WALL_INSET := 20.0
const FALL_DEATH_Y := 820.0

@onready var player: PlayerBlob = $PlayerBlob
@onready var camera: Camera2D = $Camera2D

var _terrain_guides: Array[PackedVector2Array] = []
var _terrain_colors: Array[Color] = []
var _camera_x := HALF_VIEW_WIDTH
var _elapsed := 0.0
var _game_over := false
var _won := false
var _restart_button: Button
var _status_label: Label

func _ready() -> void:
	_build_level()
	_build_ui()
	_reset_camera()
	DebugLog.event("Production spring blob spawned")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _game_over or _won:
		_publish_debug_data(delta)
		return
	_elapsed += delta
	if player.needs_safety_reset():
		player.reset_to_start()
		_reset_camera()
	_camera_x = minf(_camera_x + CAMERA_SCROLL_SPEED * delta, WORLD_WIDTH - HALF_VIEW_WIDTH)
	camera.global_position = Vector2(_camera_x, 360.0)
	if player.get_center_position().y > FALL_DEATH_Y:
		_end_attempt("Fell below the level")
	elif player.get_core_left_position() <= _left_wall_x():
		_end_attempt("Caught by the left wall")
	elif player.get_center_position().x >= FINISH_X:
		_win_level()
	_publish_debug_data(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if DebugOverlay.is_badge_hit(event.position):
			return
		player.set_touch_lift(event.pressed)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()

func _restart() -> void:
	_game_over = false
	_won = false
	_elapsed = 0.0
	get_tree().paused = false
	player.reset_to_start()
	_reset_camera()
	_status_label.visible = false
	_restart_button.visible = false
	DebugLog.event("Production level restarted")

func _end_attempt(reason: String) -> void:
	_game_over = true
	player.set_touch_lift(false)
	_status_label.text = "GAME OVER\n%s" % reason
	_status_label.visible = true
	_restart_button.visible = true
	get_tree().paused = true
	DebugLog.event("Production attempt ended", reason)

func _win_level() -> void:
	_won = true
	player.set_touch_lift(false)
	_status_label.text = "FINISH!"
	_status_label.visible = true
	_restart_button.visible = true
	get_tree().paused = true
	DebugLog.event("Production level finished")

func _reset_camera() -> void:
	_camera_x = HALF_VIEW_WIDTH
	camera.global_position = Vector2(_camera_x, 360.0)

func _left_wall_x() -> float:
	return _camera_x - HALF_VIEW_WIDTH + LEFT_WALL_INSET

func _build_level() -> void:
	_add_rect("Ceiling", Rect2(0, 0, WORLD_WIDTH, CEILING_HEIGHT), Color("f3a6c8"))
	_add_rect("Floor", Rect2(0, FLOOR_Y, WORLD_WIDTH, 85), Color("f3a6c8"))
	_add_rect("Obstacle1", Rect2(820, 85, 120, 300), Color("f3a6c8"))
	_add_rect("Obstacle2", Rect2(1230, 390, 120, 245), Color("f3a6c8"))
	_add_rect("Obstacle3", Rect2(1640, 85, 120, 330), Color("f3a6c8"))
	_add_rect("Obstacle4", Rect2(2050, 410, 120, 225), Color("f3a6c8"))
	_add_rect("Obstacle5", Rect2(2460, 85, 120, 285), Color("f3a6c8"))
	_add_rect("Obstacle6", Rect2(2870, 365, 120, 270), Color("f3a6c8"))
	_add_rect("Obstacle7", Rect2(3260, 85, 120, 315), Color("f3a6c8"))

func _add_rect(body_name: String, rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)
	_terrain_guides.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	_terrain_colors.append(color)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_restart_button = Button.new()
	_restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_button.text = "Restart"
	_restart_button.position = Vector2(1080, 18)
	_restart_button.size = Vector2(170, 58)
	_restart_button.add_theme_font_size_override("font_size", 22)
	_restart_button.visible = false
	_restart_button.pressed.connect(_restart)
	layer.add_child(_restart_button)
	_status_label = Label.new()
	_status_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.position = Vector2(-300, -70)
	_status_label.size = Vector2(600, 140)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 42)
	_status_label.add_theme_color_override("font_color", Color("ffd166"))
	_status_label.visible = false
	layer.add_child(_status_label)

func _publish_debug_data(delta: float) -> void:
	var state := "game_over" if _game_over else ("finished" if _won else "playing")
	DebugOverlay.set_game_data({
		"scene": get_tree().current_scene.name,
		"state": state,
		"elapsed": _elapsed,
		"position": player.get_center_position(),
		"velocity": player.get_velocity(),
		"vertical_velocity": player.get_velocity().y,
		"alive": not _game_over,
		"touch": "pressed" if Input.is_action_pressed("fly") else "released",
		"input": "spring blob",
		"frame_time": delta * 1000.0,
	})

func _draw() -> void:
	draw_rect(Rect2(0, 0, WORLD_WIDTH, VIEW.y), Color("10233b"))
	for i in range(14):
		draw_circle(Vector2(float(i * 310), 250 + (i % 3) * 90), 150.0, Color("173653"))
	for i in _terrain_guides.size():
		var guide := _terrain_guides[i]
		draw_colored_polygon(guide, _terrain_colors[i])
		draw_polyline(guide + PackedVector2Array([guide[0]]), Color("ffe3f0"), 2.0)
	draw_rect(Rect2(_left_wall_x() - 14.0, 0.0, 14.0, VIEW.y), Color("d85f8e"))
	draw_rect(Rect2(FINISH_X, CEILING_HEIGHT, 20, FLOOR_Y - CEILING_HEIGHT), Color("61e786"))
	draw_string(ThemeDB.fallback_font, Vector2(38, 48), "HOLD: LIFT  •  RELEASE: FALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("eaf6ff"))
