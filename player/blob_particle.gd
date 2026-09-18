class_name BlobParticle2D
extends RigidBody2D

## Contact samples are reused by PlayerBlob's crush detector.
var environment_contact_normals := PackedVector2Array()
var environment_contact_impulses := PackedFloat32Array()
var environment_contact_positions := PackedVector2Array()
var environment_contact_is_round := PackedByteArray()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	environment_contact_normals.clear()
	environment_contact_impulses.clear()
	environment_contact_positions.clear()
	environment_contact_is_round.clear()
	for contact_index in state.get_contact_count():
		var collider := state.get_contact_collider_object(contact_index)
		if not collider is CollisionObject2D:
			continue
		if (collider.collision_layer & 1) == 0:
			continue
		var normal := state.get_contact_local_normal(contact_index).normalized()
		if normal.length_squared() <= 0.01:
			continue
		environment_contact_normals.append(normal)
		environment_contact_impulses.append(state.get_contact_impulse(contact_index).length())
		environment_contact_positions.append(state.get_contact_collider_position(contact_index))
		var shape_index := state.get_contact_collider_shape(contact_index)
		var shape_owner: Object = collider.shape_owner_get_owner(collider.shape_find_owner(shape_index))
		var is_round := shape_owner is CollisionShape2D and (shape_owner as CollisionShape2D).shape is CircleShape2D
		environment_contact_is_round.append(1 if is_round else 0)
