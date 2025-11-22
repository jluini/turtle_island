extends Control

class_name Game

signal state_changed(new_state)
signal turn_changed(new_turn)

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

@rpc("authority", "call_local", "reliable", 0)
func set_turn(new_turn : int):
	emit_signal("turn_changed", new_turn)
	self.turn = new_turn

func _input(event: InputEvent):
	match state:
		State.INITIAL:
			if event.is_action_pressed("ui_accept"):
				start_online_game([1, 1])

			elif event.is_action_pressed("ui_page_down"):
				_start_server()
			elif event.is_action_pressed("ui_page_up"):
				_start_client()

		State.PLAYING:
			if event.is_action_pressed("ui_left"):
				players[turn - 1].going_left()
			elif event.is_action_pressed("ui_right"):
				players[turn - 1].going_right()
			elif event.is_action_released("ui_left"):
				players[turn - 1].standing_still()
			elif event.is_action_released("ui_right"):
				players[turn - 1].standing_still()

###

func _start_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)

	print("create_server -> ", error)
	if error:
		return error

	multiplayer.multiplayer_peer = peer
	set_state(State.HOSTING)

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
		var player_id = i + 1
		var peer_id = peers[i]
		var new_player = local_player.new()
		var spawn_point_name = ["spawn0", "spawn1"][i]
		var turtle_name = ["turtle1", "turtle2"][i]

		var new_turtle = add_a_turtle(scenario.get_node(spawn_point_name).position, turtle_name, player_id, peer_id)

		new_player.player_id = player_id
		new_player.peer_id = peer_id
		new_player.units.append(new_turtle)

		players.append(new_player)

###
# Signal handlers

@rpc("any_peer", "call_local", "reliable", 0)
func wait_and_continue():
	set_state(State.WAITING)
	%timer.start()

func _on_timer_timeout():
	match state:
		State.WAITING:
			_continue_game()
		State.PLAYING:
			players[turn - 1].standing_still()
			if anything_is_moving():
				set_state(State.SETTLING)
			else:
				turn_is_over()

func turn_is_over():
	freeze_all(1)
	if not multiplayer.is_server():
		set_state(State.PLAYING_REMOTELLY)
	wait_and_continue.rpc_id(1)

func _check_sleeping(_source):
	if state != State.SETTLING:
		return

	var is_moving = anything_is_moving()

	if is_moving:
		return

	turn_is_over()

@rpc("any_peer", "call_remote", "reliable", 0)
func back_to_server(from):
	print("%s: back_to_server called by %s" % [multiplayer.get_unique_id(), from])
	_continue_game()

func anything_is_moving():
	for do in %simulation.get_node("map/map/dynamic_objects").get_children():
		if !do.sleeping:
			print("%s: is moving %s" % [multiplayer.get_unique_id(), do.name])
			return true

	for do in %simulation.get_node("units").get_children():
		if !do.sleeping:
			print("%s: is moving %s" % [multiplayer.get_unique_id(), do.name])
			return true

	return false

func freeze_this(do, new_authority):
	do.freeze = true
	# do.sleeping = val
	do.set_multiplayer_authority(new_authority)
	do.get_node("label").text = str(new_authority)
	
	
func freeze_all(new_authority):
	for do in %simulation.get_node("map/map/dynamic_objects").get_children():
		call_deferred("freeze_this", do, new_authority)
		# do.call_deferred("set_multiplayer_authority", new_authority)
		# do.set_multiplayer_authority(new_authority)

	for do in %simulation.get_node("units").get_children():
		call_deferred("freeze_this", do, new_authority)
		
func unfreeze_all():
	for do in %simulation.get_node("map/map/dynamic_objects").get_children():
		call_deferred("unfreeze_this", do)
		#call_deferred("freeze_this", do, false)
		#call_deferred("authorize", do, multiplayer.get_unique_id())
		#do.call_deferred("set_multiplayer_authority", multiplayer.get_unique_id())
		# do.set_multiplayer_authority(multiplayer.get_unique_id())
		# do.get_node("label").text = "X"

	for do in %simulation.get_node("units").get_children():
		call_deferred("unfreeze_this", do)
		
func unfreeze_this(do):
		# do.global_position = do.position
		do.freeze = false
		do.set_multiplayer_authority(multiplayer.get_unique_id())
		do.get_node("label").text = "X"

# only in server
func _continue_game():
	if multiplayer.get_unique_id() != 1:
		print("_continue_game should be called in server only")
		return
		
	if !_game_goes_on():
		# TODO
		pass
	else:
		set_turn.rpc((turn % 2) + 1)
		te_toca.rpc_id(peers[turn - 1])
		
		if peers[turn - 1] != 1:
			set_state(State.PLAYING_REMOTELLY)
			freeze_all(peers[turn - 1])
		
func _game_goes_on():
	return true # TODO

func add_a_turtle(new_position, new_name, player_id, peer_id):
	var new_turtle : RigidBody2D = player.instantiate()
	new_turtle.connect("sleeping_state_changed", self._check_sleeping.bind(new_turtle))
	%simulation.get_node("units").add_child(new_turtle)

	new_turtle.position = new_position
	new_turtle.set_attrs(new_name, player_id, peer_id)

	if !multiplayer.is_server():
		freeze_this(new_turtle, true)

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
func start_online_game(the_peers):
	print("STARTING ONLINE %s %s %s" % [multiplayer.is_server(), multiplayer.get_unique_id(), peers])

	self.peers = the_peers
	_start_simulation()

	if multiplayer.is_server():
		turn = 2
		set_state(State.SETTLING)
	else:
		set_state(State.PLAYING_REMOTELLY)

@rpc("authority", "call_local", "reliable", 0)
func te_toca():
	set_state(State.PLAYING)
	%timer.start()
	unfreeze_all()

func _on_peer_connected(id):
	print("%s: peer_connected %s" % [multiplayer.get_unique_id(), id])

	if multiplayer.is_server():
		start_online_game.rpc([1, id])
	else:
		set_state(State.CONNECTED)

func _on_peer_disconnected(id):
	print("%s: peer_disconnected %s" % [multiplayer.get_unique_id(), id])
func _on_connected_to_server():
	print("%s: connected_to_server" % [multiplayer.get_unique_id()])
func _on_connection_failed():
	print("%s: connection_failed" % [multiplayer.get_unique_id()])
func _on_server_disconnected():
	print("server_disconnected")
