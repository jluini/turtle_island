extends RigidBody2D

@export var dir = 0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# print(dir)
	if dir > 0:
		
		apply_torque(-10000)
	elif dir < 0:
		
		apply_torque(+10000)
		
