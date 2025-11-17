extends Label

func _on_game_state_changed(new_state) -> void:
	# print("received _on_game_state_changed ", new_state)
	text = Game.State.find_key(new_state)
