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

var state : State

###

func _ready() -> void:
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
			pass
			





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
		match state:
			State.STARTING:
				set_state(State.PROCESSING)

func _start_simulation():
	for child in %simulation.get_node("map").get_children():
		child.free()
		
	for child in %simulation.get_node("units").get_children():
		child.free()
	
	var scenario = map.instantiate()
		
	for do in scenario.get_node("dynamic_objects").get_children():
		do.connect("sleeping_state_changed", self._check_sleeping.bind(do))
	
	%simulation.get_node("map").add_child(scenario)

	add_a_turtle(scenario.get_node('spawn0').position, "turtle1")
	add_a_turtle(scenario.get_node('spawn1').position, "turtle2")
	

func add_a_turtle(position, name):
	var new_turtle = player.instantiate()
	new_turtle.connect("sleeping_state_changed", self._check_sleeping.bind(new_turtle))
	%simulation.get_node("units").add_child(new_turtle)

	new_turtle.position = position
	new_turtle.name = name
	
	return new_turtle
