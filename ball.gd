extends RigidBody2D

func _ready():
	print("estoy ready")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	pass
	# state.set_linear_velocity(Vector2.ZERO)
	
	#if Input.is_action_pressed("ui_left"):
		#state.apply_torque(-10000)
	#elif Input.is_action_pressed("ui_right"):
		#state.apply_torque(10000)
