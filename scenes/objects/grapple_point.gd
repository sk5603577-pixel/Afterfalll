extends Area3D

func _ready() -> void:
	add_to_group("grapple_points")
	collision_layer = 2
	collision_mask = 0
	monitorable = true
