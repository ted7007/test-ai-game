extends Control

const PRODUCTION_SCENE := "res://main.tscn"
const PLAYGROUND_SCENE := "res://experiments/physics_playground/physics_playground.tscn"

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("09131f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-300, -180)
	menu.size = Vector2(600, 360)
	menu.add_theme_constant_override("separation", 22)
	add_child(menu)
	menu.add_child(_label("DEBUG SCENE SELECTOR", 36, Color("eaf6ff")))
	menu.add_child(_label("Choose a scene for this development build", 19, Color("b9d4e2")))
	menu.add_child(_button("Production level", _on_production_pressed))
	menu.add_child(_button("Physics playground — Prototype A", _on_playground_pressed))
	menu.add_child(_label("The playground and production level use the same PlayerBlob component.", 15, Color("ffd166")))

func _label(value: String, font_size: int, text_color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 88)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	return button

func _on_production_pressed() -> void:
	get_tree().change_scene_to_file(PRODUCTION_SCENE)

func _on_playground_pressed() -> void:
	get_tree().change_scene_to_file(PLAYGROUND_SCENE)
