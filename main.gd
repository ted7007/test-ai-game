extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const WORLD_WIDTH := 9800.0
const FLOOR_Y := 635.0
const CEILING_HEIGHT := 85.0
const HALF_VIEW_WIDTH := 640.0
const FINISH_X := 9500.0
const LEFT_WALL_INSET := 20.0
const FALL_DEATH_Y := 820.0
const INITIAL_PLAYER_POSITION := Vector2(260.0, 360.0)
const SPLIT_CHILD_SCALE := 0.65
const SPLIT_CHILD_CLEARANCE := 52.0
const SPLIT_SEPARATION_IMPULSE := 35.0
const PLAYER_SCENE := preload("res://player/player_blob.tscn")
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")

@export_category("Camera pacing")
@export_range(0.0, 300.0, 5.0, "suffix:px/s") var camera_base_scroll_speed := 90.0
@export_range(0.0, 500.0, 10.0, "suffix:px") var camera_catchup_start_distance := 110.0
@export_range(0.0, 3.0, 0.05) var camera_catchup_gain := 0.90
@export_range(55.0, 500.0, 5.0, "suffix:px/s") var camera_max_scroll_speed := 300.0

@onready var camera: Camera2D = $Camera2D

var _players: Array[PlayerBlob] = []
var _terrain_guides: Array[PackedVector2Array] = []
var _terrain_colors: Array[Color] = []
var _terrain_circle_centers: Array[Vector2] = []
var _terrain_circle_radii: Array[float] = []
var _terrain_circle_colors: Array[Color] = []
var _camera_x := HALF_VIEW_WIDTH
var _elapsed := 0.0
var _game_over := false
var _won := false
var _has_split := false
var _touch_lift := false
var _pause_menu: GamePauseMenu
var _total_participants := 0
var _finished_participants := 0
var _lost_participants := 0

func _ready() -> void:
	_reset_attempt_result()
	_register_player($PlayerBlob)
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
	var finished: Array[PlayerBlob] = []
	var eliminated: Array[PlayerBlob] = []
	var last_elimination_reason := "No players remaining"
	for current_player in _players:
		if current_player.needs_safety_reset():
			if not _has_split and _players.size() == 1:
				current_player.reset_to_start()
				_reset_camera()
			else:
				current_player.recover_shape_in_place()
				DebugLog.event("Small blob recovered from an unstable stretch")
	for current_player in _players:
		if current_player.get_center_position().x >= FINISH_X:
			finished.append(current_player)
		elif current_player.get_center_position().y > FALL_DEATH_Y:
			eliminated.append(current_player)
			last_elimination_reason = "Fell below the level"
	for current_player in finished:
		_finish_player(current_player)
	for current_player in eliminated:
		_lose_player(current_player, last_elimination_reason)
	if _players.is_empty():
		_complete_attempt(last_elimination_reason)
	else:
		_update_camera(delta)
		var left_behind: Array[PlayerBlob] = []
		for current_player in _players:
			if current_player.get_core_left_position() <= _left_wall_x():
				left_behind.append(current_player)
		for current_player in left_behind:
			_lose_player(current_player, "Caught by the left wall")
		if _players.is_empty():
			_complete_attempt("Caught by the left wall")
	_publish_debug_data(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if DebugOverlay.is_badge_hit(event.position):
			return
		_touch_lift = event.pressed
		for current_player in _players:
			current_player.set_touch_lift(_touch_lift)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()

func _restart() -> void:
	_game_over = false
	_won = false
	_elapsed = 0.0
	_has_split = false
	_touch_lift = false
	_reset_attempt_result()
	get_tree().paused = false
	_clear_players()
	_spawn_player(INITIAL_PLAYER_POSITION, 1.0, true, Vector2.ZERO, Vector2.ZERO)
	_reset_camera()
	DebugLog.event("Production level restarted")

func _end_attempt(reason: String) -> void:
	_game_over = true
	_touch_lift = false
	for current_player in _players:
		current_player.set_touch_lift(false)
	_pause_menu.show_menu(false, "GAME OVER\n%s" % reason)
	DebugLog.event("Production attempt ended", "%s (%d / %d finished)" % [reason, _finished_participants, _total_participants])

func _win_level() -> void:
	_won = true
	_touch_lift = false
	for current_player in _players:
		current_player.set_touch_lift(false)
	_pause_menu.show_menu(false, "FINISH!")
	DebugLog.event("Production level finished", "%d / %d finished" % [_finished_participants, _total_participants])

func _complete_attempt(last_elimination_reason: String) -> void:
	if _finished_participants > 0:
		_win_level()
	else:
		_end_attempt(last_elimination_reason)

func _finish_player(current_player: PlayerBlob) -> void:
	if current_player not in _players:
		return
	_finished_participants += 1
	_remove_player(current_player)
	DebugLog.event("Player reached Finish", "%d active remaining" % _players.size())

func _lose_player(current_player: PlayerBlob, reason: String) -> void:
	if current_player not in _players:
		return
	_lost_participants += 1
	_remove_player(current_player)
	DebugLog.event("Player lost", reason)

func _reset_attempt_result() -> void:
	_total_participants = 0
	_finished_participants = 0
	_lost_participants = 0

func _reset_camera() -> void:
	_camera_x = HALF_VIEW_WIDTH
	camera.global_position = Vector2(_camera_x, 360.0)

func _update_camera(delta: float) -> void:
	var focus_x := _get_leading_player_x()
	var lead_distance := maxf(0.0, focus_x - _camera_x - camera_catchup_start_distance)
	var scroll_speed := minf(camera_base_scroll_speed + lead_distance * camera_catchup_gain, maxf(camera_base_scroll_speed, camera_max_scroll_speed))
	_camera_x = minf(_camera_x + scroll_speed * delta, WORLD_WIDTH - HALF_VIEW_WIDTH)
	camera.global_position = Vector2(_camera_x, 360.0)

func _get_leading_player_x() -> float:
	if _players.is_empty():
		return _camera_x
	var leading_x := -INF
	for current_player in _players:
		leading_x = maxf(leading_x, current_player.get_center_position().x)
	return leading_x

func _left_wall_x() -> float:
	return _camera_x - HALF_VIEW_WIDTH + LEFT_WALL_INSET

func _register_player(new_player: PlayerBlob, count_toward_result := true) -> void:
	_players.append(new_player)
	if count_toward_result:
		_total_participants += 1
	new_player.set_touch_lift(_touch_lift)
	new_player.split_requested.connect(_on_player_split_requested)

func _spawn_player(spawn_position: Vector2, size_scale: float, allow_split: bool, inherited_velocity: Vector2, separation_impulse: Vector2, count_toward_result := true) -> PlayerBlob:
	var new_player := PLAYER_SCENE.instantiate() as PlayerBlob
	new_player.configure_variant(size_scale, allow_split)
	new_player.position = spawn_position
	add_child(new_player)
	_register_player(new_player, count_toward_result)
	new_player.initialize_motion(inherited_velocity, separation_impulse)
	return new_player

func _on_player_split_requested(source: PlayerBlob, separation_axis: Vector2, split_origin: Vector2) -> void:
	call_deferred("_replace_player_with_children", source, separation_axis, split_origin, 2, SPLIT_CHILD_SCALE, false, SPLIT_SEPARATION_IMPULSE)

func _replace_player_with_children(source: PlayerBlob, separation_axis: Vector2, split_origin: Vector2, child_count: int, child_scale: float, children_can_split: bool, separation_impulse: float) -> void:
	if not is_instance_valid(source) or source not in _players or child_count < 1:
		return
	var inherited_velocity := source.get_velocity()
	var axis := separation_axis.normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.UP
	_remove_player(source)
	var max_centered_index := maxf(float(child_count - 1) * 0.5, 0.5)
	for child_index in child_count:
		var centered_index := float(child_index) - float(child_count - 1) * 0.5
		var direction_factor := centered_index / max_centered_index if child_count > 1 else 0.0
		var child_position := split_origin + axis * SPLIT_CHILD_CLEARANCE * direction_factor
		var child_impulse := axis * separation_impulse * direction_factor
		_spawn_player(child_position, child_scale, children_can_split, inherited_velocity, child_impulse, false)
	# Split replaces one result participant with its children, rather than
	# counting the disappearing source as an additional failed participant.
	_total_participants += child_count - 1
	_has_split = true
	DebugLog.event("Player split", "%d children at %.2f scale" % [child_count, child_scale])

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

func _build_level() -> void:
	var terrain_color := Color("f3a6c8")
	_add_rect("Ceiling", Rect2(0, 0, WORLD_WIDTH, CEILING_HEIGHT), Color("f3a6c8"))
	# The floor is interrupted once late in the level by a forgiving recovery gap.
	_add_rect("FloorBeforeGap", Rect2(0, FLOOR_Y, 7600, 85), terrain_color)
	_add_rect("FloorAfterGap", Rect2(8350, FLOOR_Y, WORLD_WIDTH - 8350, 85), terrain_color)

	# Safe introduction: open flight, a shallow floor contact, then one required
	# rounded squeeze which cannot trigger Split.
	_add_round_obstacle("IntroFloorBump", Vector2(650, 690), 115.0, terrain_color)
	_add_round_obstacle("RequiredSqueezeTop", Vector2(1300, 150), 155.0, terrain_color)
	_add_round_obstacle("RequiredSqueezeBottom", Vector2(1300, 580), 165.0, terrain_color)

	# The spike array is visible immediately. Six long converging tips provide
	# sustained crush pressure, while 38 px lanes block the full-size blob and
	# require the Split children to deform while passing through.
	_add_spiked_row("SplitRow1", 2250.0, 2450.0, 300.0, 25.0, 4000.0, terrain_color)
	_add_spiked_row("SplitRow2", 2250.0, 2450.0, 363.0, 25.0, 4000.0, terrain_color)
	_add_spiked_row("SplitRow3", 2250.0, 2450.0, 426.0, 25.0, 4000.0, terrain_color)
	_add_spiked_row("SplitRow4", 2250.0, 2450.0, 489.0, 25.0, 4000.0, terrain_color)
	_add_spiked_row("SplitRow5", 2250.0, 2450.0, 552.0, 25.0, 4000.0, terrain_color)
	_add_spiked_row("SplitRow6", 2250.0, 2450.0, 615.0, 20.0, 4000.0, terrain_color)
	_add_round_obstacle("SplitRow1Cap", Vector2(4000, 312.5), 12.5, terrain_color)
	_add_round_obstacle("SplitRow2Cap", Vector2(4000, 375.5), 12.5, terrain_color)
	_add_round_obstacle("SplitRow3Cap", Vector2(4000, 438.5), 12.5, terrain_color)
	_add_round_obstacle("SplitRow4Cap", Vector2(4000, 501.5), 12.5, terrain_color)
	_add_round_obstacle("SplitRow5Cap", Vector2(4000, 564.5), 12.5, terrain_color)
	_add_round_obstacle("SplitRow6Cap", Vector2(4000, 625.0), 10.0, terrain_color)

	# Three tight rounded gates make the shared section physically dense while
	# remaining recoverable. Their gaps require visible full-size deformation.
	_add_round_gap("SharedGateCenter", 4650.0, 360.0, 105.0, 165.0, terrain_color)
	_add_round_obstacle("SharedCeilingDrift", Vector2(5100, 55), 150.0, terrain_color)
	_add_round_gap("SharedGateHigh", 5500.0, 285.0, 100.0, 170.0, terrain_color)
	_add_round_obstacle("SharedFloorRoll", Vector2(5950, 680), 130.0, terrain_color)
	_add_round_gap("SharedGateLow", 6400.0, 430.0, 100.0, 170.0, terrain_color)
	_add_round_obstacle("SharedCeilingExit", Vector2(7050, 100), 170.0, terrain_color)

	# Rounded lips make the late floor gap readable. Holding lift provides ample
	# recovery time; the final stretch after it is intentionally calm.
	_add_round_obstacle("RecoveryGapEntry", Vector2(7580, 675), 80.0, terrain_color)
	_add_round_obstacle("RecoveryGapExit", Vector2(8370, 675), 80.0, terrain_color)

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

func _add_polygon(body_name: String, points: PackedVector2Array, color: Color) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)
	_terrain_guides.append(points)
	_terrain_colors.append(color)

func _add_spiked_row(body_name: String, tip_x: float, base_x: float, top_y: float, height: float, end_x: float, color: Color) -> void:
	var middle_y := top_y + height * 0.5
	_add_polygon("%sSpike" % body_name, PackedVector2Array([
		Vector2(tip_x, middle_y),
		Vector2(base_x, top_y),
		Vector2(base_x, top_y + height),
	]), color)
	_add_rect("%sBeam" % body_name, Rect2(base_x, top_y, end_x - base_x, height), color)

func _add_round_gap(body_name: String, center_x: float, gap_center_y: float, gap_height: float, radius: float, color: Color) -> void:
	var half_gap := gap_height * 0.5
	_add_round_obstacle("%sTop" % body_name, Vector2(center_x, gap_center_y - half_gap - radius), radius, color)
	_add_round_obstacle("%sBottom" % body_name, Vector2(center_x, gap_center_y + half_gap + radius), radius, color)

func _add_round_obstacle(body_name: String, center: Vector2, radius: float, color: Color) -> void:
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
	_terrain_circle_centers.append(center)
	_terrain_circle_radii.append(radius)
	_terrain_circle_colors.append(color)

func _build_ui() -> void:
	_pause_menu = PAUSE_MENU_SCENE.instantiate() as GamePauseMenu
	_pause_menu.restart_requested.connect(_restart)
	_pause_menu.menu_requested.connect(_return_to_menu)
	_pause_menu.pause_changed.connect(_on_pause_changed)
	add_child(_pause_menu)

func _on_pause_changed(_paused: bool) -> void:
	_touch_lift = false
	for current_player in _players:
		current_player.set_touch_lift(false)

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://debug_launcher.tscn")

func _publish_debug_data(delta: float) -> void:
	var state := "game_over" if _game_over else ("finished" if _won else "playing")
	var leading_player: PlayerBlob = null
	for current_player in _players:
		if leading_player == null or current_player.get_center_position().x > leading_player.get_center_position().x:
			leading_player = current_player
	var leading_position := leading_player.get_center_position() if leading_player != null else Vector2.ZERO
	var leading_velocity := leading_player.get_velocity() if leading_player != null else Vector2.ZERO
	DebugOverlay.set_game_data({
		"scene": get_tree().current_scene.name,
		"state": state,
		"elapsed": _elapsed,
		"position": leading_position,
		"velocity": leading_velocity,
		"vertical_velocity": leading_velocity.y,
		"alive": not _players.is_empty(),
		"players": _players.size(),
		"participants_total": _total_participants,
		"participants_finished": _finished_participants,
		"participants_lost": _lost_participants,
		"result": "%d / %d" % [_finished_participants, _total_participants],
		"touch": "pressed" if (_touch_lift or Input.is_action_pressed("fly")) else "released",
		"input": "spring blob",
		"frame_time": delta * 1000.0,
	})

func _draw() -> void:
	draw_rect(Rect2(0, 0, WORLD_WIDTH, VIEW.y), Color("10233b"))
	for i in range(int(ceil(WORLD_WIDTH / 310.0)) + 1):
		draw_circle(Vector2(float(i * 310), 250 + (i % 3) * 90), 150.0, Color("173653"))
	for i in _terrain_guides.size():
		var guide := _terrain_guides[i]
		draw_colored_polygon(guide, _terrain_colors[i])
		draw_polyline(guide + PackedVector2Array([guide[0]]), Color("ffe3f0"), 2.0)
	for i in _terrain_circle_centers.size():
		draw_circle(_terrain_circle_centers[i], _terrain_circle_radii[i], _terrain_circle_colors[i])
		draw_arc(_terrain_circle_centers[i], _terrain_circle_radii[i], 0.0, TAU, 48, Color("ffe3f0"), 2.0, true)
	draw_rect(Rect2(_left_wall_x() - 14.0, 0.0, 14.0, VIEW.y), Color("d85f8e"))
	draw_rect(Rect2(FINISH_X, CEILING_HEIGHT, 20, FLOOR_Y - CEILING_HEIGHT), Color("61e786"))
	draw_string(ThemeDB.fallback_font, Vector2(38, 48), "HOLD: LIFT  •  RELEASE: FALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("eaf6ff"))
