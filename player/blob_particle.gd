class_name BlobParticle2D
extends RigidBody2D

## Contact samples are reused by PlayerBlob's crush detector.
var environment_contact_normals := PackedVector2Array()
var environment_contact_impulses := PackedFloat32Array()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	environment_contact_normals.clear()
	environment_contact_impulses.clear()
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
