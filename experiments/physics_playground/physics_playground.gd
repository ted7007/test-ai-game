extends Node2D

const WORLD_WIDTH := 2400.0
const FLOOR_Y := 650.0

@export var show_collider_guides := false
@onready var blob: PrototypeABlob = $PrototypeABlob
@onready var camera: Camera2D = $Camera2D

var _terrain_guides: Array[PackedVector2Array] = []
var _terrain_colors: Array[Color] = []

func _ready() -> void:
	_build_course()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	camera.global_position = Vector2(clampf(blob.get_center_position().x, 640.0, WORLD_WIDTH - 640.0), 360.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			blob.reset_to_start()
		elif event.keycode == KEY_F1:
			show_collider_guides = not show_collider_guides
			queue_redraw()

func _build_course() -> void:
	_add_rect("Floor", Rect2(1200, FLOOR_Y + 30, WORLD_WIDTH, 60), Color("19364b"), "Ровный пол")
	_add_polygon("Slope", PackedVector2Array([Vector2(380, FLOOR_Y), Vector2(650, FLOOR_Y), Vector2(650, 480), Vector2(380, FLOOR_Y)]), Color("315a6f"), "Наклон")
	_add_rect("Wall", Rect2(790, 270, 44, 380), Color("8f4051"), "Вертикальная стена")
	_add_circle("RoundObstacle", Vector2(1080, 510), 88.0, Color("477b76"), "Закруглённый obstacle")
	_add_rect("PassageTop", Rect2(1360, 85, 48, 245), Color("6a4b86"), "Узкий проход")
	_add_rect("PassageBottom", Rect2(1360, 410, 48, 240), Color("6a4b86"), "")
	_add_polygon("Edge", PackedVector2Array([Vector2(1680, FLOOR_Y), Vector2(1720, FLOOR_Y), Vector2(1720, 500)]), Color("a46a37"), "Край препятствия")
	_add_rect("DragMarker", Rect2(1900, FLOOR_Y - 8, 310, 8), Color("2a5770"), "Падение и волочение")

func _add_rect(body_name: String, rect: Rect2, color: Color, label: String) -> void:
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
	_add_label(rect.position + Vector2(0, -12), label)

func _add_circle(body_name: String, center: Vector2, radius: float, color: Color, label: String) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.position = center
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var guide := PackedVector2Array()
	for i in 24:
		guide.append(center + Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * radius)
	_terrain_guides.append(guide)
	_terrain_colors.append(color)
	_add_label(center + Vector2(-radius, -radius - 12), label)

func _add_polygon(body_name: String, points: PackedVector2Array, color: Color, label: String) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)
	_terrain_guides.append(points)
	_terrain_colors.append(color)
	_add_label(points[0] + Vector2(0, -12), label)

func _add_label(position: Vector2, value: String) -> void:
	if value.is_empty():
		return
	var label := Label.new()
	label.position = position
	label.text = value
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color("cce6f3")
	add_child(label)

func _draw() -> void:
	draw_rect(Rect2(0, 0, WORLD_WIDTH, 720), Color("10233b"))
	for i in _terrain_guides.size():
		var guide := _terrain_guides[i]
		draw_colored_polygon(guide, _terrain_colors[i])
		draw_polyline(guide + PackedVector2Array([guide[0]]), Color("90b7c6"), 2.0)
	if show_collider_guides:
		draw_string(ThemeDB.fallback_font, Vector2(26, 42), "F1: collider guides ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe29a"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(26, 42), "R: reset   F1: collider guides", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("eaf6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(26, 70), "Hold Space / LMB: lift   Release: fall", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("cce6f3"))
