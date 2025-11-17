extends Control

enum State {
	NO_GAME,

	STARTING,
	PROCESSING,
	PLAYING,
	WAITING,
	CELEBRATING
}

@export var map : PackedScene
@export var player : PackedScene

###

var local_player = preload("res://local_player.gd")

###

var state : State
var turn = 0
var players = []
var current_player = null

###

func _ready() -> void:
	%timer.connect("timeout", _on_timer_timeout)
	set_state(State.NO_GAME)

func set_state(new_state):
	print(State.find_key(state), " -> ", State.find_key(new_state))
	
	self.state = new_state
	
func _input(event: InputEvent):
	match state:
		State.NO_GAME:
			if event.is_action_pressed("ui_accept"):
				set_state(State.STARTING)
				_start_simulation()
		State.PLAYING:
			if event.is_action_pressed("ui_left"):
				current_player.going_left()
			elif event.is_action_pressed("ui_right"):
				current_player.going_right()
			elif event.is_action_released("ui_left"):
				current_player.standing_still()
			elif event.is_action_released("ui_right"):
				current_player.standing_still()
			


# Signal handlers

func _on_timer_timeout():
	match state:
		State.PLAYING:
			current_player.standing_still()
			set_state(State.WAITING)
	
			%timer.start()
		State.WAITING:
			turn = (turn % 2) + 1
			current_player = players[turn - 1]
			_continue_game()
		

func _check_sleeping(source):
	var is_moving = false
	for do in %simulation.get_node("map/map/dynamic_objects").get_children():
		if !do.sleeping:
			is_moving = true
			break
	
	for do in %simulation.get_node("units").get_children():
		if !do.sleeping:
			is_moving = true
			break

	if not is_moving:
		print("DONE ", source.name)
		match state:
			State.STARTING:
				_start_game()
	else:
		print("---- ", source.name)

func _start_game():
	turn = 1
	current_player = players[turn - 1]
	_continue_game()

func _continue_game():
	if _game_goes_on():
		set_state(State.PLAYING)
		%timer.start()
	else:
		pass # TODO

func _game_goes_on():
	return true # TODO
	

func _start_simulation():
	for child in %simulation.get_node("map").get_children():
		child.free()
		
	for child in %simulation.get_node("units").get_children():
		child.free()
	
	var scenario = map.instantiate()
		
	for do in scenario.get_node("dynamic_objects").get_children():
		do.connect("sleeping_state_changed", self._check_sleeping.bind(do))
	
	%simulation.get_node("map").add_child(scenario)

	# TODO: delete old players
	
	var player1 = local_player.new()
	player1.units.append(add_a_turtle(scenario.get_node('spawn0').position, "turtle1"))
	
	var player2 = local_player.new()
	player2.units.append(add_a_turtle(scenario.get_node('spawn1').position, "turtle2"))
	
	players.append(player1)
	players.append(player2)

func add_a_turtle(position, name):
	var new_turtle = player.instantiate()
	new_turtle.connect("sleeping_state_changed", self._check_sleeping.bind(new_turtle))
	%simulation.get_node("units").add_child(new_turtle)

	new_turtle.position = position
	new_turtle.name = name
	
	return new_turtle
