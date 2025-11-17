extends Label


func _on_game_turn_changed(new_turn: Variant) -> void:
	text = str(new_turn)
