extends CanvasLayer

var _panel: PanelContainer
var _details: Label
var _events: Label
var _badge: Button
var _visible := false
var _tap_count := 0
var _last_tap_msec := 0
var _game_data := {
	"scene": "-", "state": "-", "elapsed": 0.0,
	"position": Vector2.ZERO, "velocity": Vector2.ZERO,
	"vertical_velocity": 0.0, "alive": false,
	"touch": "-", "input": "-", "frame_time": 0.0,
}

func _ready() -> void:
	if not BuildInfo.is_development():
		return
	layer = 100
	_build_ui()
	DebugLog.event("Debug session started")

func _build_ui() -> void:
	_badge = Button.new()
	_badge.text = BuildInfo.compact_label()
	_badge.tooltip_text = "Tap five times quickly to open debug info"
	_badge.flat = true
	_badge.focus_mode = Control.FOCUS_NONE
	_badge.position = Vector2(1080, 8)
	_badge.size = Vector2(190, 30)
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.modulate = Color(0.82, 0.88, 0.96, 0.70)
	_badge.pressed.connect(_on_badge_pressed)
	add_child(_badge)

	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 48)
	_panel.size = Vector2(490, 570)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG OVERLAY"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 16)
	box.add_child(_details)
	var events_title := Label.new()
	events_title.text = "EVENTS"
	events_title.add_theme_font_size_override("font_size", 17)
	box.add_child(events_title)
	_events = Label.new()
	_events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_events.add_theme_font_size_override("font_size", 14)
	box.add_child(_events)
	var copy_button := Button.new()
	copy_button.text = "COPY DEBUG INFO"
	copy_button.pressed.connect(_copy_report)
	box.add_child(copy_button)

func _unhandled_input(input_event: InputEvent) -> void:
	if not BuildInfo.is_development():
		return
	if input_event is InputEventKey and input_event.pressed and not input_event.echo and input_event.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _visible:
		return
	_game_data.frame_time = delta * 1000.0
	_refresh()

func _on_badge_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_msec > 1500:
		_tap_count = 0
	_tap_count += 1
	_last_tap_msec = now
	if _tap_count >= 5:
		_tap_count = 0
		toggle()

func toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		DebugLog.event("Debug overlay opened")
		_refresh()

func set_game_data(data: Dictionary) -> void:
	if not BuildInfo.is_development():
		return
	_game_data.merge(data, true)

func is_badge_hit(position: Vector2) -> bool:
	return BuildInfo.is_development() and is_instance_valid(_badge) and _badge.get_global_rect().has_point(position)

func _refresh() -> void:
	var state := "paused" if get_tree().paused else str(_game_data.state)
	var position: Vector2 = _game_data.position
	var velocity: Vector2 = _game_data.velocity
	_details.text = "BUILD\n%s\nCommit: %s\nBuilt: %s\n\nPERFORMANCE\nFPS: %d   Frame: %.1f ms\n\nGAME\nScene: %s\nState: %s\nElapsed: %.2f s\n\nPLAYER\nPosition: %.0f, %.0f\nVelocity: %.0f, %.0f\nVertical: %.0f\nAlive: %s\n\nINPUT\nTouch: %s\nLast input: %s" % [BuildInfo.version(), BuildInfo.commit(), BuildInfo.built_at(), Engine.get_frames_per_second(), _game_data.frame_time, _game_data.scene, state, _game_data.elapsed, position.x, position.y, velocity.x, velocity.y, _game_data.vertical_velocity, "yes" if _game_data.alive else "no", _game_data.touch, _game_data.input]
	_events.text = "\n".join(DebugLog.recent_events())

func _copy_report() -> void:
	var position: Vector2 = _game_data.position
	var velocity: Vector2 = _game_data.velocity
	var report := "Game: %s\nBuild: %s\nCommit: %s\nBuilt: %s\nScene: %s\nState: %s\nFPS: %d\nPlayerPos: %.0f, %.0f\nPlayerVelocity: %.0f, %.0f\nLastEvents:" % [BuildInfo.version(), BuildInfo.build_type(), BuildInfo.commit(), BuildInfo.built_at(), _game_data.scene, _game_data.state, Engine.get_frames_per_second(), position.x, position.y, velocity.x, velocity.y]
	for entry in DebugLog.recent_events():
		report += "\n- %s" % entry
	DisplayServer.clipboard_set(report)
	DebugLog.event("Debug info copied")
