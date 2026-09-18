class_name PlayerBlob
extends Node2D

signal split_requested(source, separation_axis: Vector2)

## Production spring-blob player. Gameplay tuning remains exposed in Inspector.
@export_category("Blob shape")
@export_range(4, 12, 1) var outer_body_count := 6
@export_range(8.0, 40.0, 1.0, "suffix:px") var outer_radius := 16.0
@export_range(4.0, 30.0, 1.0, "suffix:px") var center_radius := 12.0
@export_range(25.0, 110.0, 1.0, "suffix:px") var rest_radius := 44.0
@export_range(0.1, 8.0, 0.1) var body_mass := 1.0

@export_category("Springs")
@export_range(5.0, 2000.0, 5.0) var radial_stiffness := 260.0
@export_range(5.0, 2000.0, 5.0) var ring_stiffness := 210.0
@export_range(5.0, 2000.0, 5.0) var brace_stiffness := 320.0
@export_range(0.0, 100.0, 0.5) var spring_damping := 14.0
@export_range(1.0, 300.0, 1.0, "suffix:px") var spring_max_length := 110.0
@export_range(50.0, 400.0, 5.0, "suffix:px") var safety_reset_radius := 150.0
@export_range(0.05, 1.0, 0.05) var minimum_thickness_ratio := 0.15
@export_range(0.0, 500.0, 5.0) var shape_recovery_stiffness := 90.0
@export_range(0.0, 5000.0, 50.0) var max_shape_recovery_force := 1400.0

@export_category("Snag recovery")
@export_range(1.0, 3.0, 0.05) var snag_stretch_ratio := 1.35
@export_range(1.0, 2.0, 0.05) var snag_recover_ratio := 1.15
@export_range(0.05, 1.0, 0.05, "suffix:s") var snag_release_delay := 0.20
@export_range(0.0, 5000.0, 50.0) var snag_catchup_force := 2200.0
@export_range(-1.0, 1.0, 0.05) var small_blob_snag_x_ratio := 0.25
@export_range(0.25, 1.0, 0.05) var small_blob_snag_delay_scale := 0.65

@export_category("Movement")
@export_range(0.0, 4000.0, 10.0) var forward_force := 360.0
@export_range(0.0, 5000.0, 10.0) var lift_force := 1750.0
@export_range(0.0, 3000.0, 10.0) var gravity := 980.0
@export_range(20.0, 1200.0, 10.0, "suffix:px/s") var max_speed := 260.0
@export_range(0.0, 20.0, 0.1) var linear_damping := 1.2
@export_range(0.0, 20.0, 0.1) var angular_damping := 4.0

@export_category("Surface response")
@export_range(0.0, 2.0, 0.05) var friction := 0.35
@export_range(0.0, 1.0, 0.01) var bounce := 0.05

@export_category("Experimental split")
@export var can_split := true
@export_range(-1.0, 0.0, 0.05) var crush_normal_dot_min := -0.90
@export_range(-1.0, 0.0, 0.05) var crush_normal_dot_max := -0.35
@export_range(-1.0, -0.90, 0.01) var crush_tip_normal_dot_min := -0.99
@export_range(0.2, 1.0, 0.01) var crush_compression_ratio := 0.82
@export_range(0.25, 2.0, 0.05) var crush_tip_contact_span_ratio := 1.15
@export_range(0.0, 20.0, 0.25) var crush_min_contact_impulse := 2.0
@export_range(0.0, 1.0, 0.05) var crush_min_pressure_alignment := 0.35
@export_range(0.05, 1.0, 0.05, "suffix:s") var crush_grace_period := 0.25
@export_range(0.0, 1.0, 0.05, "suffix:s") var split_feedback_duration := 0.15

var center_body: BlobParticle2D
var outer_bodies: Array[BlobParticle2D] = []
var _outline := PackedVector2Array()
var _touch_lift := false
var _snag_timers := PackedFloat32Array()
var _snag_releasing := PackedByteArray()
var _contact_normals := PackedVector2Array()
var _contact_impulses := PackedFloat32Array()
var _contact_positions := PackedVector2Array()
var _contact_is_round := PackedByteArray()
var _size_scale := 1.0
var _crush_timer := 0.0
var _split_requested := false
var _split_feedback_remaining := 0.0

func _ready() -> void:
	_build_bodies()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var lift := _touch_lift or Input.is_action_pressed("fly")
	_update_snag_recovery(delta)
	_apply_shape_recovery()
	for body in outer_bodies:
		_apply_control(body, lift)
	_apply_control(center_body, lift)
	_update_crush_detection(delta, lift)
	_split_feedback_remaining = maxf(0.0, _split_feedback_remaining - delta)
	queue_redraw()

func configure_variant(size_scale: float, allow_split: bool) -> void:
	if is_inside_tree():
		push_error("PlayerBlob.configure_variant must be called before adding the blob to the scene tree")
		return
	_size_scale = maxf(0.1, size_scale)
	can_split = allow_split

func initialize_motion(inherited_velocity: Vector2, separation_impulse: Vector2) -> void:
	for body in _all_bodies():
		body.linear_velocity = inherited_velocity
		body.apply_central_impulse(separation_impulse)
	_split_feedback_remaining = split_feedback_duration
	queue_redraw()

func set_touch_lift(pressed: bool) -> void:
	_touch_lift = pressed

func reset_to_start() -> void:
	_touch_lift = false
	_reset_body(center_body, Vector2.ZERO)
	for i in outer_bodies.size():
		var angle := TAU * float(i) / float(outer_bodies.size())
		_reset_body(outer_bodies[i], Vector2.RIGHT.rotated(angle) * _effective_rest_radius())
		outer_bodies[i].collision_mask = 3
		_snag_timers[i] = 0.0
		_snag_releasing[i] = 0
	_crush_timer = 0.0
	_split_requested = false
	queue_redraw()

func get_center_position() -> Vector2:
	return center_body.global_position

func get_core_left_position() -> float:
	return center_body.global_position.x - _effective_center_radius()

func get_velocity() -> Vector2:
	return center_body.linear_velocity

func needs_safety_reset() -> bool:
	for body in outer_bodies:
		if body.global_position.distance_to(center_body.global_position) > safety_reset_radius * maxf(1.0, _size_scale):
			return true
	return false

func recover_shape_in_place() -> void:
	var center_local_position := center_body.position
	var inherited_velocity := center_body.linear_velocity
	_reset_body(center_body, center_local_position, inherited_velocity)
	for i in outer_bodies.size():
		var angle := TAU * float(i) / float(outer_bodies.size())
		_reset_body(outer_bodies[i], center_local_position + Vector2.RIGHT.rotated(angle) * _effective_rest_radius(), inherited_velocity)
		outer_bodies[i].collision_mask = 3
		_snag_timers[i] = 0.0
		_snag_releasing[i] = 0
	queue_redraw()

func _apply_control(body: RigidBody2D, lift: bool) -> void:
	body.apply_central_force(Vector2.RIGHT * forward_force)
	if lift:
		body.apply_central_force(Vector2.UP * lift_force)
	if body.linear_velocity.length() > max_speed:
		body.linear_velocity = body.linear_velocity.limit_length(max_speed)

func _build_bodies() -> void:
	center_body = _make_body("Center", Vector2.ZERO, _effective_center_radius())
	add_child(center_body)
	for i in outer_body_count:
		var angle := TAU * float(i) / float(outer_body_count)
		var body := _make_body("Outer%d" % i, Vector2.RIGHT.rotated(angle) * _effective_rest_radius(), _effective_outer_radius())
		add_child(body)
		outer_bodies.append(body)
		_make_spring(center_body, body, radial_stiffness, _effective_rest_radius())
	for i in outer_body_count:
		var next := (i + 1) % outer_body_count
		var ring_rest := outer_bodies[i].global_position.distance_to(outer_bodies[next].global_position)
		_make_spring(outer_bodies[i], outer_bodies[next], ring_stiffness, ring_rest)
	if outer_body_count % 2 == 0:
		var opposite_offset := outer_body_count / 2
		for i in opposite_offset:
			_make_spring(outer_bodies[i], outer_bodies[i + opposite_offset], brace_stiffness, _effective_rest_radius() * 2.0)
	_add_internal_collision_exceptions()
	_snag_timers.resize(outer_bodies.size())
	_snag_releasing.resize(outer_bodies.size())

func _make_body(body_name: String, body_position: Vector2, collision_radius: float) -> BlobParticle2D:
	var body := BlobParticle2D.new()
	body.name = body_name
	body.position = body_position
	body.mass = body_mass
	body.gravity_scale = gravity / 980.0
	body.linear_damp = linear_damping
	body.angular_damp = angular_damping
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.lock_rotation = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.collision_layer = 2
	body.collision_mask = 3
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	collider.shape = shape
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = bounce
	body.physics_material_override = material
	body.add_child(collider)
	return body

func _make_spring(body_a: RigidBody2D, body_b: RigidBody2D, stiffness: float, rest_length: float) -> void:
	var spring := DampedSpringJoint2D.new()
	spring.position = body_a.position
	spring.rotation = body_a.position.direction_to(body_b.position).angle()
	spring.node_a = NodePath("../" + body_a.name)
	spring.node_b = NodePath("../" + body_b.name)
	spring.length = rest_length
	spring.rest_length = rest_length
	spring.max_length = spring_max_length * _size_scale
	spring.stiffness = stiffness
	spring.damping = spring_damping
	spring.exclude_nodes_from_collision = true
	add_child(spring)

func _reset_body(body: RigidBody2D, local_position: Vector2, inherited_velocity := Vector2.ZERO) -> void:
	body.freeze = true
	body.position = local_position
	body.rotation = 0.0
	body.linear_velocity = inherited_velocity
	body.angular_velocity = 0.0
	body.sleeping = false
	body.set_deferred("freeze", false)

func _apply_shape_recovery() -> void:
	var alignment := Vector2.ZERO
	for i in outer_bodies.size():
		var radial := outer_bodies[i].global_position - center_body.global_position
		if radial.length_squared() > 0.01:
			var base_angle := TAU * float(i) / float(outer_bodies.size())
			alignment += radial.normalized().rotated(-base_angle)
	var orientation := alignment.angle() if alignment.length_squared() > 0.01 else 0.0
	var effective_rest_radius := _effective_rest_radius()
	var minimum_radius := effective_rest_radius * minimum_thickness_ratio
	var total_force := Vector2.ZERO
	for i in outer_bodies.size():
		var target_direction := Vector2.RIGHT.rotated(orientation + TAU * float(i) / float(outer_bodies.size()))
		var target_position := center_body.global_position + target_direction * effective_rest_radius
		var recovery := (target_position - outer_bodies[i].global_position) * shape_recovery_stiffness
		var radial := outer_bodies[i].global_position - center_body.global_position
		if radial.length() < minimum_radius:
			recovery += target_direction * (minimum_radius - radial.length()) * shape_recovery_stiffness
		recovery = recovery.limit_length(max_shape_recovery_force)
		outer_bodies[i].apply_central_force(recovery)
		total_force += recovery
	center_body.apply_central_force(-total_force)

func _update_snag_recovery(delta: float) -> void:
	var center_position := center_body.global_position
	var effective_rest_radius := _effective_rest_radius()
	for i in outer_bodies.size():
		var body := outer_bodies[i]
		var offset := body.global_position - center_position
		var distance := offset.length()
		if _snag_releasing[i] != 0:
			body.collision_mask = 0
			if distance > 0.01:
				body.apply_central_force(-offset.normalized() * snag_catchup_force)
			if distance <= effective_rest_radius * snag_recover_ratio:
				body.collision_mask = 3
				_snag_timers[i] = 0.0
				_snag_releasing[i] = 0
			continue
		var trailing_limit := -effective_rest_radius * 0.75
		var release_delay := snag_release_delay
		if _size_scale < 1.0:
			trailing_limit = effective_rest_radius * small_blob_snag_x_ratio
			release_delay *= small_blob_snag_delay_scale
		var trailing := offset.x < trailing_limit
		var stretched := distance > effective_rest_radius * snag_stretch_ratio
		if trailing and stretched:
			_snag_timers[i] += delta
			if _snag_timers[i] >= release_delay:
				_snag_releasing[i] = 1
				body.collision_mask = 0
		else:
			_snag_timers[i] = maxf(0.0, _snag_timers[i] - delta * 2.0)

func _update_crush_detection(delta: float, lift: bool) -> void:
	if not can_split or _split_requested:
		return
	_collect_environment_contacts()
	var separation_axis := _find_crush_axis(lift)
	if separation_axis == Vector2.ZERO:
		_crush_timer = maxf(0.0, _crush_timer - delta * 2.0)
		return
	_crush_timer += delta
	if _crush_timer < crush_grace_period:
		return
	_split_requested = true
	can_split = false
	split_requested.emit(self, separation_axis)

func _collect_environment_contacts() -> void:
	_contact_normals.clear()
	_contact_impulses.clear()
	_contact_positions.clear()
	_contact_is_round.clear()
	for body in _all_bodies():
		for contact_index in body.environment_contact_normals.size():
			_contact_normals.append(body.environment_contact_normals[contact_index])
			_contact_impulses.append(body.environment_contact_impulses[contact_index])
			_contact_positions.append(body.environment_contact_positions[contact_index])
			_contact_is_round.append(body.environment_contact_is_round[contact_index])

func _find_crush_axis(lift: bool) -> Vector2:
	if _contact_normals.size() < 2:
		return Vector2.ZERO
	for first_index in _contact_normals.size() - 1:
		if _contact_impulses[first_index] < crush_min_contact_impulse:
			continue
		var first_normal := _contact_normals[first_index]
		for second_index in range(first_index + 1, _contact_normals.size()):
			if _contact_is_round[first_index] != 0 or _contact_is_round[second_index] != 0:
				continue
			if _contact_impulses[second_index] < crush_min_contact_impulse:
				continue
			var second_normal := _contact_normals[second_index]
			var normal_dot := first_normal.dot(second_normal)
			var close_to_sharp_tip := _contact_positions[first_index].distance_to(_contact_positions[second_index]) <= _effective_rest_radius() * crush_tip_contact_span_ratio
			var thin_tip_pair := close_to_sharp_tip and normal_dot >= crush_tip_normal_dot_min
			if normal_dot > crush_normal_dot_max or (normal_dot < crush_normal_dot_min and not thin_tip_pair):
				continue
			var wedge_outward := first_normal + second_normal
			if wedge_outward.length_squared() <= 0.01:
				continue
			var wedge_entry := -wedge_outward.normalized()
			if _pressure_alignment(wedge_entry, lift) < crush_min_pressure_alignment:
				continue
			var axis := (first_normal - second_normal).normalized()
			if axis.length_squared() <= 0.01:
				continue
			var compressed_between_surfaces := _compression_ratio_on_axis(axis) <= crush_compression_ratio
			if compressed_between_surfaces or close_to_sharp_tip:
				return axis
	return Vector2.ZERO

func _pressure_alignment(wedge_entry: Vector2, lift: bool) -> float:
	var alignment := wedge_entry.dot(Vector2.RIGHT) if forward_force > 0.0 else -1.0
	var vertical_force := gravity * body_mass - (lift_force if lift else 0.0)
	if absf(vertical_force) > 0.01:
		alignment = maxf(alignment, wedge_entry.dot(Vector2.DOWN * signf(vertical_force)))
	return alignment

func _compression_ratio_on_axis(axis: Vector2) -> float:
	var current_min := INF
	var current_max := -INF
	var rest_min := INF
	var rest_max := -INF
	for i in outer_bodies.size():
		var current_projection := outer_bodies[i].global_position.dot(axis)
		current_min = minf(current_min, current_projection)
		current_max = maxf(current_max, current_projection)
		var rest_offset := Vector2.RIGHT.rotated(TAU * float(i) / float(outer_bodies.size())) * _effective_rest_radius()
		var rest_projection := rest_offset.dot(axis)
		rest_min = minf(rest_min, rest_projection)
		rest_max = maxf(rest_max, rest_projection)
	var rest_span := rest_max - rest_min
	if rest_span <= 0.01:
		return 1.0
	return (current_max - current_min) / rest_span

func _add_internal_collision_exceptions() -> void:
	var bodies := _all_bodies()
	for first_index in bodies.size() - 1:
		for second_index in range(first_index + 1, bodies.size()):
			bodies[first_index].add_collision_exception_with(bodies[second_index])

func _all_bodies() -> Array[BlobParticle2D]:
	var bodies: Array[BlobParticle2D] = [center_body]
	bodies.append_array(outer_bodies)
	return bodies

func _effective_outer_radius() -> float:
	return outer_radius * _size_scale

func _effective_center_radius() -> float:
	return center_radius * _size_scale

func _effective_rest_radius() -> float:
	return rest_radius * _size_scale

func _draw() -> void:
	if outer_bodies.is_empty():
		return
	_outline.resize(outer_bodies.size())
	for i in outer_bodies.size():
		_outline[i] = to_local(outer_bodies[i].global_position)
	var fill_color := Color("fff1a8") if _split_feedback_remaining > 0.0 else Color("ffd166")
	var outline_width := 5.0 if _split_feedback_remaining > 0.0 else 3.0
	draw_colored_polygon(_outline, fill_color)
	draw_polyline(_outline + PackedVector2Array([_outline[0]]), Color("4a2a17"), outline_width, true)
	for point in _outline:
		draw_circle(point, _effective_outer_radius() * 0.28, Color("8c4b28"))
	draw_circle(to_local(center_body.global_position), 7.0 * _size_scale, Color("24324a"))
