extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const FLOOR_Y := 635.0
const CEILING_Y := 85.0
const PLAYER_X_OFFSET := 300.0
const SPEED := 245.0
const LIFT := 820.0
const GRAVITY := 1150.0
const MAX_FALL := 620.0
const PLAYER_RADIUS := 27.0
const FINISH_X := 3650.0

var player_pos := Vector2(260.0, 360.0)
var velocity_y := 0.0
var touching := false
var dead := false
var won := false
var obstacles: Array[Rect2] = [
	Rect2(820, 85, 120, 300),
	Rect2(1230, 390, 120, 245),
	Rect2(1640, 85, 120, 330),
	Rect2(2050, 410, 120, 225),
	Rect2(2460, 85, 120, 285),
	Rect2(2870, 365, 120, 270),
	Rect2(3260, 85, 120, 315),
]

func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touching = event.pressed
	if event is InputEventScreenDrag:
		touching = true
	if event.is_action_pressed("ui_accept") and (dead or won):
		restart()

func _physics_process(delta: float) -> void:
	if dead or won:
		queue_redraw()
		return
	var lifting: bool = touching or Input.is_action_pressed("fly")
	velocity_y += (-LIFT if lifting else GRAVITY) * delta
	velocity_y = clamp(velocity_y, -470.0, MAX_FALL)
	player_pos += Vector2(SPEED * delta, velocity_y * delta)
	var player_box: Rect2 = Rect2(player_pos - Vector2.ONE * PLAYER_RADIUS, Vector2.ONE * PLAYER_RADIUS * 2.0)
	if player_pos.y - PLAYER_RADIUS <= CEILING_Y or player_pos.y + PLAYER_RADIUS >= FLOOR_Y:
		die()
	for obstacle in obstacles:
		if player_box.intersects(obstacle):
			die()
	if player_pos.x >= FINISH_X:
		won = true
	queue_redraw()

func die() -> void:
	dead = true
	touching = false

func restart() -> void:
	player_pos = Vector2(260.0, 360.0)
	velocity_y = 0.0
	dead = false
	won = false
	touching = false
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var scale_factor: float = minf(size.x / VIEW.x, size.y / VIEW.y)
	var origin: Vector2 = (size - VIEW * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("10233b"))
	var camera_x: float = maxf(0.0, player_pos.x - PLAYER_X_OFFSET)
	# Soft background bands add depth without external assets.
	for i in range(7):
		var bx: float = fmod(float(i * 310) - camera_x * 0.18, 2170.0) - 200.0
		draw_circle(Vector2(bx, 310 + (i % 3) * 70), 150.0, Color("173653"))
	draw_rect(Rect2(0, 0, VIEW.x, CEILING_Y), Color("07131f"))
	draw_rect(Rect2(0, FLOOR_Y, VIEW.x, VIEW.y - FLOOR_Y), Color("07131f"))
	for obstacle in obstacles:
		var shown: Rect2 = Rect2(obstacle.position - Vector2(camera_x, 0), obstacle.size)
		draw_rect(shown, Color("ed4b4b"))
		for y in range(int(shown.position.y) + 20, int(shown.end.y), 42):
			draw_circle(Vector2(shown.position.x + shown.size.x / 2.0, y), 8.0, Color("781f32"))
	var finish_x: float = FINISH_X - camera_x
	draw_rect(Rect2(finish_x, CEILING_Y, 22, FLOOR_Y - CEILING_Y), Color("61e786"))
	draw_circle(Vector2(player_pos.x - camera_x, player_pos.y), PLAYER_RADIUS + 6, Color("081019"))
	draw_circle(Vector2(player_pos.x - camera_x, player_pos.y), PLAYER_RADIUS, Color("ffd166"))
	draw_circle(Vector2(player_pos.x - camera_x + 9, player_pos.y - 7), 5, Color("101820"))
	draw_string(ThemeDB.fallback_font, Vector2(36, 52), "УДЕРЖИВАЙ: ВВЕРХ   •   ОТПУСТИ: ВНИЗ", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("eaf6ff"))
	if dead or won:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.02, 0.04, 0.07, 0.76))
		var title: String = "ФИНИШ!" if won else "СТОЛКНОВЕНИЕ"
		draw_string(ThemeDB.fallback_font, Vector2(0, 285), title, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 58, Color("ffffff"))
		draw_rect(Rect2(440, 340, 400, 120), Color("ffd166"), true)
		draw_string(ThemeDB.fallback_font, Vector2(440, 418), "ЗАНОВО", HORIZONTAL_ALIGNMENT_CENTER, 400, 46, Color("142030"))

func _unhandled_input(event: InputEvent) -> void:
	if not (dead or won):
		return
	var press: bool = false
	var pointer_position := Vector2.ZERO
	if event is InputEventScreenTouch:
		press = event.pressed
		pointer_position = event.position
	elif event is InputEventMouseButton:
		press = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		pointer_position = event.position
	if press:
		var size: Vector2 = get_viewport_rect().size
		var scale_factor: float = minf(size.x / VIEW.x, size.y / VIEW.y)
		var origin: Vector2 = (size - VIEW * scale_factor) * 0.5
		var local: Vector2 = (pointer_position - origin) / scale_factor
		if Rect2(440, 340, 400, 120).has_point(local):
			restart()
