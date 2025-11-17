extends Node

class_name Player

@export var units = []

func standing_still():
	set_dir(0)

func going_left():
	# print("going_left")
	set_dir(+1)


func going_right():
	# print("going_right")
	set_dir(-1)

func set_dir(new_dir):
	# print(units[0].dir, " -> ", new_dir)
	units[0].dir = new_dir
	
	if new_dir != 0:
		units[0].sleeping = false
