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
	state = State.NO_GAME
	
	# print(State)
	# print(State.keys())
	

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("Accept")
		if state == State.NO_GAME:
			state = State.STARTING
			_start_simulation(%simulation)
				
	elif event.is_action_pressed("ui_select"):
		print("Select")



func _start_simulation(container: Node):
	for child in container.get_children():
		child.free()
	
	var scenario = map.instantiate()
	container.add_child(scenario)
	
	var turtle1 = player.instantiate()
	var turtle2 = player.instantiate()
	
	container.add_child(turtle1)
	container.add_child(turtle2)
	
	turtle1.position = scenario.get_node('spawn0').position
	turtle2.position = scenario.get_node('spawn1').position
	
