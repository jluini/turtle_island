extends Control

class_name Game

#signal network_state_changed(new_state)
signal state_changed(new_state)
signal turn_changed(new_turn)

#enum NetworkState {
	#NOTHING,
	#SERVER,
	#
	#CONNECTING,
	#CONNECTED
#}

enum State {
	NOTHING,
	INITIAL,

	HOSTING,
	# STARTING,
	SETTLING,
	WAITING,
	PLAYING,
	PLAYING_REMOTELLY,
	CELEBRATING,
	
	CONNECTING,
	CONNECTED
}

@export var map : PackedScene
@export var player : PackedScene

###

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

###

var local_player = preload("res://local_player.gd")

###

var state : State = State.NOTHING

var turn = 0
var peers = []
var players = []
var current_player = null

###

func _ready() -> void:
	%timer.connect("timeout", _on_timer_timeout)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	set_state(State.INITIAL)
	set_turn(0)

func set_state(new_state : State):
	emit_signal("state_changed", new_state)
	self.state = new_state

#func set_network_state(new_state):
	#emit_signal("network_state_changed", new_state)
	#self.network_state = new_state
	
func set_turn(new_turn : int):
	emit_signal("turn_changed", new_turn)
	self.turn = new_turn

func _input(event: InputEvent):
	match state:
		State.INITIAL:
			if event.is_action_pressed("ui_accept"):
				pass # _start_simulation(false, [1, 1])
	
			elif event.is_action_pressed("ui_page_down"):
				_start_server()
			elif event.is_action_pressed("ui_page_up"):
				_start_client()

		State.PLAYING:
			pass # TODO
			#if event.is_action_pressed("ui_left"):
				#current_player.going_left()
			#elif event.is_action_pressed("ui_right"):
				#current_player.going_right()
			#elif event.is_action_released("ui_left"):
				#current_player.standing_still()
			#elif event.is_action_released("ui_right"):
				#current_player.standing_still()
			

###

func _start_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)
	
	print("create_server -> ", error)
	if error:
		return error
		
	multiplayer.multiplayer_peer = peer
	set_state(State.HOSTING)

# func _start_simulation(is_multiplayer: bool, peers: Array):
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
	
	for i in range(peers.size()):
		var peer_id = peers[i]
		var new_player = local_player.new()
		var spawn_point_name = ["spawn0", "spawn1"][i]
		var turtle_name = ["turtle1", "turtle2"][i]
		
		var new_turtle = add_a_turtle(scenario.get_node(spawn_point_name).position, turtle_name, peer_id)
		
		new_player.peer_id = peer_id
		new_player.units.append(new_turtle)
	
		players.append(new_player)
	
###
# Signal handlers

func _on_timer_timeout():
	match state:
		State.WAITING:
			_continue_game()
		State.PLAYING:
			if multiplayer.is_server():
				print("Termino un turno server")
				if anything_is_moving():
					set_state(State.SETTLING)
				else:
					set_state(State.WAITING)
					%timer.start()
			else:
				print("Termino un turno cliente")
				pass # TODO
			
			## TODO
			#current_player.standing_still()
			#set_state(State.SETTLING)
	#
			#%timer.start()
		#State.SETTLING:
			#_continue_game()
		

func _check_sleeping(source):
	if state != State.SETTLING:
		return
	
	var is_moving = anything_is_moving()
	
	if is_moving:
		return
	
	if multiplayer.is_server():
		# print("%s: should continue game here" % [multiplayer.get_unique_id()])
		#pass
		#_continue_game()
		set_state(State.WAITING)
		%timer.start()
	else:
		pass # TODO
	
	#if not is_moving:
		#match state:
			#State.STARTING:
				#_start_game()

	
func anything_is_moving():
	for do in %simulation.get_node("map/map/dynamic_objects").get_children():
		if !do.sleeping:
			return true
	
	for do in %simulation.get_node("units").get_children():
		if !do.sleeping:
			return true

	return false
	
func _continue_game():
	set_turn((turn % 2) + 1)
	var current_peer = peers[turn - 1]
	current_player = players[turn - 1]
	
	if _game_goes_on():
		if current_peer == 1:
			print("le toca al server")
			set_state(State.PLAYING)
			%timer.start()
		else:
			print("le toca al cliente")
	else:
		pass # TODO

func _game_goes_on():
	return true # TODO

func add_a_turtle(position, name, peer_id):
	var new_turtle : RigidBody2D = player.instantiate()
	new_turtle.connect("sleeping_state_changed", self._check_sleeping.bind(new_turtle))
	%simulation.get_node("units").add_child(new_turtle)

	new_turtle.position = position
	new_turtle.name = name
	
	if !multiplayer.is_server():
		new_turtle.freeze = true
	
	return new_turtle

###

func _start_client():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(DEFAULT_SERVER_IP, PORT)
	
	print("create_client -> ", error)

	if error:
		return error
	
	multiplayer.multiplayer_peer = peer
	set_state(State.CONNECTING)
#

@rpc("authority", "call_local", "reliable", 0)
func start_online_game(peers):
	print("STARTING ONLINE %s %s %s" % [multiplayer.is_server(), multiplayer.get_unique_id(), peers])
	
	self.peers = peers
	_start_simulation()
	
	if multiplayer.is_server():
		# set_state(State.STARTING)
		turn = 2
		set_state(State.SETTLING)
	else:
		set_state(State.PLAYING_REMOTELLY)

func _on_peer_connected(id):
	print("%s: peer_connected %s" % [multiplayer.get_unique_id(), id])
	
	if multiplayer.is_server():
		start_online_game.rpc([1, id])
	else:
		set_state(State.CONNECTED)
	
	#if multiplayer.is_server():
		#_start_simulation(true, [1, id])

	
func _on_peer_disconnected(id):
	print("%s: peer_disconnected %s" % [multiplayer.get_unique_id(), id])
func _on_connected_to_server():
	print("%s: connected_to_server" % [multiplayer.get_unique_id()])
func _on_connection_failed():
	print("%s: connection_failed" % [multiplayer.get_unique_id()])
func _on_server_disconnected():
	print("%s: server_disconnected" % [multiplayer.get_unique_id()])
	
