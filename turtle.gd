extends RigidBody2D

@export var player_id = 0

@export var peer_id = 0

@export var dir = 0

func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	# print(dir)
	if dir > 0:
		apply_torque(-10000)
		# print("%s: -1000" % [multiplayer.get_unique_id()])
	elif dir < 0:
		apply_torque(+10000)
		# print("%s: +1000" % [multiplayer.get_unique_id()])
		
func set_attrs(new_name, new_player_id, new_peer_id):
	self.name = new_name
	self.player_id = new_player_id
	self.peer_id = new_peer_id
	# $label.text = str(new_player_id)
