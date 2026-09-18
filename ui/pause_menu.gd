class_name GamePauseMenu
extends CanvasLayer

signal restart_requested
signal menu_requested
signal pause_changed(paused: bool)

var _overlay: ColorRect
var _pause_button: Button
var _continue_button: Button
var _title_label: Label
var _menu_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func show_menu(allow_continue := true, title := "PAUSED") -> void:
	_title_label.text = title
	_continue_button.visible = allow_continue
	_overlay.visible = true
	_pause_button.visible = false
	if not _menu_open:
		_menu_open = true
		get_tree().paused = true
		pause_changed.emit(true)

func close_menu() -> void:
	var was_open := _menu_open
	_menu_open = false
	_overlay.visible = false
	_pause_button.visible = true
	get_tree().paused = false
	if was_open:
		pause_changed.emit(false)

func is_menu_open() -> bool:
	return _menu_open

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if _menu_open:
		if _continue_button.visible:
			close_menu()
	else:
		show_menu()
	get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-158, 18)
	_pause_button.size = Vector2(140, 54)
	_pause_button.add_theme_font_size_override("font_size", 20)
	_pause_button.pressed.connect(show_menu)
	root.add_child(_pause_button)

	_overlay = ColorRect.new()
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.04, 0.08, 0.78)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	root.add_child(_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -170)
	panel.size = Vector2(360, 340)
	_overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	_title_label = Label.new()
	_title_label.custom_minimum_size = Vector2(320, 95)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color("ffd166"))
	content.add_child(_title_label)

	_continue_button = _make_menu_button("Continue")
	_continue_button.pressed.connect(close_menu)
	content.add_child(_continue_button)

	var restart_button := _make_menu_button("Restart")
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)

	var menu_button := _make_menu_button("Menu")
	menu_button.pressed.connect(_on_menu_pressed)
	content.add_child(menu_button)

func _make_menu_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(320, 58)
	button.add_theme_font_size_override("font_size", 20)
	return button

func _on_restart_pressed() -> void:
	close_menu()
	restart_requested.emit()

func _on_menu_pressed() -> void:
	close_menu()
	menu_requested.emit()
