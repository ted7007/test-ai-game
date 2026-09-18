extends Node2D

const WORLD_WIDTH := 9600.0
const FLOOR_Y := 650.0
const HALF_VIEW_WIDTH := 640.0
const OBSTACLE_COLOR := Color("f3a6c8")
const OBSTACLE_OUTLINE_COLOR := Color("ffe3f0")
const DEATH_WALL_COLOR := Color("d85f8e")
const INITIAL_PLAYER_POSITION := Vector2(170.0, 300.0)
const SPLIT_CHILD_SCALE := 0.65
const SPLIT_SPAWN_OFFSET := 14.0
const SPLIT_SEPARATION_IMPULSE := 35.0
const PLAYER_SCENE := preload("res://player/player_blob.tscn")

@export var show_collider_guides := false
@export_category("Camera pacing")
@export_range(0.0, 300.0, 5.0, "suffix:px/s") var camera_base_scroll_speed := 55.0
@export_range(0.0, 500.0, 10.0, "suffix:px") var camera_catchup_start_distance := 220.0
@export_range(0.0, 3.0, 0.05) var camera_catchup_gain := 0.65
@export_range(55.0, 500.0, 5.0, "suffix:px/s") var camera_max_scroll_speed := 220.0
@export_category("Playground")
@export_range(0.0, 160.0, 5.0, "suffix:px") var left_wall_inset := 20.0
@export_range(720.0, 1200.0, 10.0, "suffix:px") var fall_death_y := 820.0
@onready var camera: Camera2D = $Camera2D

var _players: Array[PlayerBlob] = []
var _terrain_guides: Array[PackedVector2Array] = []
var _terrain_colors: Array[Color] = []
var _pause_button: Button
var _game_over_label: Label
var _camera_x := HALF_VIEW_WIDTH
var _game_over := false
var _has_split := false
var _touch_lift := false

func _ready() -> void:
	_register_player($PlayerBlob)
	_build_course()
	_build_mobile_controls()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _game_over:
		return
	var eliminated: Array[PlayerBlob] = []
	var last_elimination_reason := "No players remaining"
	for current_player in _players:
		if current_player.needs_safety_reset():
			if not _has_split and _players.size() == 1:
				current_player.reset_to_start()
				_reset_camera()
			else:
				current_player.recover_shape_in_place()
	_update_camera(delta)
	for current_player in _players:
		if current_player in eliminated:
			continue
		if current_player.get_center_position().y > fall_death_y:
			eliminated.append(current_player)
			last_elimination_reason = "Fell below the level"
		elif current_player.get_core_left_position() <= _left_wall_x():
			eliminated.append(current_player)
			last_elimination_reason = "Caught by the left wall"
	for current_player in eliminated:
		_remove_player(current_player)
	if _players.is_empty():
		_game_over_now(last_elimination_reason)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_lift = event.pressed
		for current_player in _players:
			current_player.set_touch_lift(_touch_lift)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_F1:
			show_collider_guides = not show_collider_guides
			queue_redraw()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://debug_launcher.tscn")

func _build_mobile_controls() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var controls := HBoxContainer.new()
	controls.process_mode = Node.PROCESS_MODE_ALWAYS
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.position = Vector2(-337, 18)
	controls.size = Vector2(319, 54)
	controls.add_theme_constant_override("separation", 12)
	layer.add_child(controls)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(115, 54)
	restart.pressed.connect(_restart)
	controls.add_child(restart)
	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.custom_minimum_size = Vector2(65, 54)
	_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_button.pressed.connect(_toggle_pause)
	controls.add_child(_pause_button)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(115, 54)
	menu.pressed.connect(_return_to_menu)
	controls.add_child(menu)
	_game_over_label = Label.new()
	_game_over_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_label.position = Vector2(-300, -90)
	_game_over_label.size = Vector2(600, 180)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 32)
	_game_over_label.add_theme_color_override("font_color", Color("ffd166"))
	_game_over_label.visible = false
	layer.add_child(_game_over_label)

func _restart() -> void:
	_game_over = false
	_has_split = false
	_touch_lift = false
	_game_over_label.visible = false
	_pause_button.disabled = false
	_set_paused(false)
	_reset_camera()
	_clear_players()
	_spawn_player(INITIAL_PLAYER_POSITION, 1.0, true, Vector2.ZERO, Vector2.ZERO)

func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)

func _set_paused(paused: bool) -> void:
	_touch_lift = false
	for current_player in _players:
		current_player.set_touch_lift(false)
	get_tree().paused = paused
	_pause_button.text = "Play" if paused else "Pause"

func _game_over_now(reason: String) -> void:
	_game_over = true
	_touch_lift = false
	for current_player in _players:
		current_player.set_touch_lift(false)
	_game_over_label.text = "GAME OVER\n%s\nTap Restart" % reason
	_game_over_label.visible = true
	_pause_button.disabled = true
	get_tree().paused = true

func _reset_camera() -> void:
	_camera_x = HALF_VIEW_WIDTH
	camera.global_position = Vector2(_camera_x, 360.0)

func _update_camera(delta: float) -> void:
	var focus_x := _get_player_group_center_x()
	var lead_distance := maxf(0.0, focus_x - _camera_x - camera_catchup_start_distance)
	var scroll_speed := minf(camera_base_scroll_speed + lead_distance * camera_catchup_gain, maxf(camera_base_scroll_speed, camera_max_scroll_speed))
	_camera_x = minf(_camera_x + scroll_speed * delta, WORLD_WIDTH - HALF_VIEW_WIDTH)
	camera.global_position = Vector2(_camera_x, 360.0)

func _get_player_group_center_x() -> float:
	if _players.is_empty():
		return _camera_x
	var total_x := 0.0
	for current_player in _players:
		total_x += current_player.get_center_position().x
	return total_x / float(_players.size())

func _left_wall_x() -> float:
	return _camera_x - HALF_VIEW_WIDTH + left_wall_inset

func _register_player(new_player: PlayerBlob) -> void:
	_players.append(new_player)
	new_player.set_touch_lift(_touch_lift)
	new_player.split_requested.connect(_on_player_split_requested)

func _spawn_player(spawn_position: Vector2, size_scale: float, allow_split: bool, inherited_velocity: Vector2, separation_impulse: Vector2) -> PlayerBlob:
	var new_player := PLAYER_SCENE.instantiate() as PlayerBlob
	new_player.configure_variant(size_scale, allow_split)
	new_player.position = spawn_position
	add_child(new_player)
	_register_player(new_player)
	new_player.initialize_motion(inherited_velocity, separation_impulse)
	return new_player

func _on_player_split_requested(source: PlayerBlob, separation_axis: Vector2) -> void:
	call_deferred("_replace_player_with_children", source, separation_axis, 2, SPLIT_CHILD_SCALE, false, SPLIT_SEPARATION_IMPULSE)

func _replace_player_with_children(source: PlayerBlob, separation_axis: Vector2, child_count: int, child_scale: float, children_can_split: bool, separation_impulse: float) -> void:
	if not is_instance_valid(source) or source not in _players or child_count < 1:
		return
	var spawn_position := source.get_center_position()
	var inherited_velocity := source.get_velocity()
	var axis := separation_axis.normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.UP
	_remove_player(source)
	var max_centered_index := maxf(float(child_count - 1) * 0.5, 0.5)
	for child_index in child_count:
		var centered_index := float(child_index) - float(child_count - 1) * 0.5
		var direction_factor := centered_index / max_centered_index if child_count > 1 else 0.0
		var child_position := spawn_position + axis * SPLIT_SPAWN_OFFSET * direction_factor
		var child_impulse := axis * separation_impulse * direction_factor
		_spawn_player(child_position, child_scale, children_can_split, inherited_velocity, child_impulse)
	_has_split = true

func _remove_player(current_player: PlayerBlob) -> void:
	if current_player not in _players:
		return
	_players.erase(current_player)
	if current_player.get_parent() == self:
		remove_child(current_player)
	current_player.queue_free()

func _clear_players() -> void:
	for current_player in _players.duplicate():
		_remove_player(current_player)

func _return_to_menu() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file("res://debug_launcher.tscn")

func _build_course() -> void:
	_add_label(Vector2(120, 125), "УЧАСТОК 1 · базовые контакты")
	_add_rect("Floor1", Rect2(0, FLOOR_Y, 2300, 70), OBSTACLE_COLOR, "Ровный пол")
	_add_polygon("Slope", PackedVector2Array([Vector2(380, FLOOR_Y), Vector2(650, FLOOR_Y), Vector2(650, 480)]), OBSTACLE_COLOR, "Наклон")
	_add_rect("Wall", Rect2(790, 270, 44, 380), OBSTACLE_COLOR, "Вертикальная стена")
	_add_circle("RoundObstacle", Vector2(1080, 510), 88.0, OBSTACLE_COLOR, "Закруглённый obstacle")
	_add_rect("PassageTop", Rect2(1360, 85, 48, 245), OBSTACLE_COLOR, "Узкий проход")
	_add_rect("PassageBottom", Rect2(1360, 410, 48, 240), OBSTACLE_COLOR, "")
	_add_polygon("Edge", PackedVector2Array([Vector2(1680, FLOOR_Y), Vector2(1720, FLOOR_Y), Vector2(1720, 500)]), OBSTACLE_COLOR, "Край препятствия")
	_add_label(Vector2(1910, 620), "Зона волочения")

	_add_label(Vector2(2520, 125), "УЧАСТОК 2 · холмы и платформы")
	_add_rect("Floor2", Rect2(2500, FLOOR_Y, 2100, 70), OBSTACLE_COLOR, "Восстановление после падения")
	_add_circle("GroundBump", Vector2(2760, 590), 60.0, OBSTACLE_COLOR, "Круглый выступ")
	_add_polygon("WideHill", PackedVector2Array([Vector2(3020, FLOOR_Y), Vector2(3320, 490), Vector2(3620, FLOOR_Y)]), OBSTACLE_COLOR, "Широкий холм")
	_add_rect("HighPlatform", Rect2(3750, 510, 330, 40), OBSTACLE_COLOR, "Платформа")
	_add_rect("LowCeiling", Rect2(4200, 120, 70, 300), OBSTACLE_COLOR, "Низкий потолок")
	_add_polygon("ExitRamp", PackedVector2Array([Vector2(4380, FLOOR_Y), Vector2(4580, FLOOR_Y), Vector2(4580, 540)]), OBSTACLE_COLOR, "Выходной край")

	_add_label(Vector2(4770, 125), "УЧАСТОК 3 · последовательные контакты")
	_add_rect("Floor3", Rect2(4750, FLOOR_Y, 2150, 70), OBSTACLE_COLOR, "")
	_add_polygon("TallRamp", PackedVector2Array([Vector2(4920, FLOOR_Y), Vector2(5270, FLOOR_Y), Vector2(5270, 440)]), OBSTACLE_COLOR, "Крутой подъём")
	_add_circle("LargeRound", Vector2(5570, 500), 110.0, OBSTACLE_COLOR, "Крупный круг")
	_add_rect("CorridorTop", Rect2(5940, 80, 70, 245), OBSTACLE_COLOR, "Коридор")
	_add_rect("CorridorBottom", Rect2(5940, 435, 70, 215), OBSTACLE_COLOR, "")
	_add_polygon("UpperEdge", PackedVector2Array([Vector2(6280, 210), Vector2(6560, 210), Vector2(6560, 390)]), OBSTACLE_COLOR, "Split-клин")
	_add_polygon("LowerEdge", PackedVector2Array([Vector2(6280, 570), Vector2(6560, 390), Vector2(6560, 570)]), OBSTACLE_COLOR, "")
	_add_rect("ContactPost", Rect2(6740, 390, 44, 260), OBSTACLE_COLOR, "Столб")

	_add_label(Vector2(7120, 125), "УЧАСТОК 4 · качение и восстановление")
	_add_rect("Floor4", Rect2(7100, FLOOR_Y, 2500, 70), OBSTACLE_COLOR, "Длинный пол")
	_add_circle("RollingBump1", Vector2(7360, 595), 55.0, OBSTACLE_COLOR, "Серия выступов")
	_add_circle("RollingBump2", Vector2(7580, 575), 75.0, OBSTACLE_COLOR, "")
	_add_circle("RollingBump3", Vector2(7830, 600), 50.0, OBSTACLE_COLOR, "")
	_add_polygon("RecoveryHill", PackedVector2Array([Vector2(8050, FLOOR_Y), Vector2(8320, 500), Vector2(8590, FLOOR_Y)]), OBSTACLE_COLOR, "Холм восстановления")
	_add_rect("FinalPassageTop", Rect2(8760, 90, 60, 250), OBSTACLE_COLOR, "Финальный проход")
	_add_rect("FinalPassageBottom", Rect2(8760, 415, 60, 235), OBSTACLE_COLOR, "")
	_add_circle("FinalRound", Vector2(9120, 520), 95.0, OBSTACLE_COLOR, "Финальный контакт")
	_add_rect("EndWall", Rect2(9480, 190, 28, 460), OBSTACLE_COLOR, "Конец полигона")

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
		draw_polyline(guide + PackedVector2Array([guide[0]]), OBSTACLE_OUTLINE_COLOR, 2.0)
	draw_rect(Rect2(_left_wall_x() - 14.0, 0.0, 14.0, 720.0), DEATH_WALL_COLOR)
	if show_collider_guides:
		draw_string(ThemeDB.fallback_font, Vector2(26, 42), "F1: collider guides ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe29a"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(26, 42), "R: reset   F1: collider guides", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("eaf6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(26, 70), "Hold screen / Space: lift   Release: fall", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("cce6f3"))
