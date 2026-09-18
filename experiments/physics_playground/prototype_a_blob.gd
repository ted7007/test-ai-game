class_name PrototypeABlob
extends Node2D

## Prototype A: a small RigidBody2D spring blob. All values are exposed so the
## experiment can be tuned in the Inspector without editing this script.
@export_category("Blob shape")
@export_range(4, 12, 1) var outer_body_count := 6
@export_range(8.0, 40.0, 1.0, "suffix:px") var outer_radius := 16.0
@export_range(25.0, 110.0, 1.0, "suffix:px") var rest_radius := 44.0
@export_range(0.1, 8.0, 0.1) var body_mass := 1.0

@export_category("Springs")
@export_range(5.0, 2000.0, 5.0) var radial_stiffness := 260.0
@export_range(5.0, 2000.0, 5.0) var ring_stiffness := 210.0
@export_range(0.0, 100.0, 0.5) var spring_damping := 14.0
@export_range(1.0, 300.0, 1.0, "suffix:px") var spring_max_length := 110.0

@export_category("Movement")
@export_range(0.0, 4000.0, 10.0) var forward_force := 780.0
@export_range(0.0, 5000.0, 10.0) var lift_force := 1750.0
@export_range(0.0, 3000.0, 10.0) var gravity := 980.0
@export_range(20.0, 1200.0, 10.0, "suffix:px/s") var max_speed := 430.0
@export_range(0.0, 20.0, 0.1) var linear_damping := 1.2
@export_range(0.0, 20.0, 0.1) var angular_damping := 4.0

@export_category("Surface response")
@export_range(0.0, 2.0, 0.05) var friction := 0.75
@export_range(0.0, 1.0, 0.01) var bounce := 0.05

var center_body: RigidBody2D
var outer_bodies: Array[RigidBody2D] = []
var start_position := Vector2.ZERO
var _outline := PackedVector2Array()

func _ready() -> void:
	start_position = global_position
	_build_bodies()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var lift := Input.is_action_pressed("fly")
	for body in outer_bodies:
		_apply_control(body, lift)
	_apply_control(center_body, lift)
	queue_redraw()

func reset_to_start() -> void:
	global_position = start_position
	center_body.global_position = start_position
	center_body.linear_velocity = Vector2.ZERO
	center_body.angular_velocity = 0.0
	for i in outer_bodies.size():
		var angle := TAU * float(i) / float(outer_bodies.size())
		var body := outer_bodies[i]
		body.global_position = start_position + Vector2.RIGHT.rotated(angle) * rest_radius
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
	queue_redraw()

func get_center_position() -> Vector2:
	return center_body.global_position

func _apply_control(body: RigidBody2D, lift: bool) -> void:
	body.apply_central_force(Vector2.RIGHT * forward_force)
	if lift:
		body.apply_central_force(Vector2.UP * lift_force)
	if body.linear_velocity.length() > max_speed:
		body.linear_velocity = body.linear_velocity.limit_length(max_speed)

func _build_bodies() -> void:
	center_body = _make_body("Center", start_position, false)
	add_child(center_body)
	for i in outer_body_count:
		var angle := TAU * float(i) / float(outer_body_count)
		var body := _make_body("Outer%d" % i, start_position + Vector2.RIGHT.rotated(angle) * rest_radius, true)
		add_child(body)
		outer_bodies.append(body)
		_make_spring(center_body, body, radial_stiffness, rest_radius)
	for i in outer_body_count:
		var next := (i + 1) % outer_body_count
		var ring_rest := outer_bodies[i].global_position.distance_to(outer_bodies[next].global_position)
		_make_spring(outer_bodies[i], outer_bodies[next], ring_stiffness, ring_rest)

func _make_body(body_name: String, body_position: Vector2, collides_with_world: bool) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.name = body_name
	body.global_position = body_position
	body.mass = body_mass
	body.gravity_scale = gravity / 980.0
	body.linear_damp = linear_damping
	body.angular_damp = angular_damping
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body.lock_rotation = true
	body.collision_layer = 2 if collides_with_world else 0
	body.collision_mask = 1 if collides_with_world else 0
	if collides_with_world:
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = outer_radius
		collider.shape = shape
		var material := PhysicsMaterial.new()
		material.friction = friction
		material.bounce = bounce
		body.physics_material_override = material
		body.add_child(collider)
	return body

func _make_spring(body_a: RigidBody2D, body_b: RigidBody2D, stiffness: float, rest_length: float) -> void:
	var spring := DampedSpringJoint2D.new()
	spring.node_a = NodePath("../" + body_a.name)
	spring.node_b = NodePath("../" + body_b.name)
	spring.length = rest_length
	spring.rest_length = rest_length
	spring.max_length = spring_max_length
	spring.stiffness = stiffness
	spring.damping = spring_damping
	spring.exclude_nodes_from_collision = true
	add_child(spring)

func _draw() -> void:
	if outer_bodies.is_empty():
		return
	_outline.resize(outer_bodies.size())
	for i in outer_bodies.size():
		_outline[i] = to_local(outer_bodies[i].global_position)
	draw_colored_polygon(_outline, Color("ffd166"))
	draw_polyline(_outline + PackedVector2Array([_outline[0]]), Color("4a2a17"), 3.0, true)
	for point in _outline:
		draw_circle(point, outer_radius * 0.28, Color("8c4b28"))
	draw_circle(to_local(center_body.global_position), 7.0, Color("24324a"))
