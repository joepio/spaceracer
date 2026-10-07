extends "res://src/desert_terrain.gd"
## The seafloor: the desert's height field without strata steps, so the same
## ranges weather into rounded reefs, seamounts and trenches around the course.

func _init(track:RefCounted)->void:
	super(track,false)
	shader_path="res://src/ocean_ground.gdshader"
