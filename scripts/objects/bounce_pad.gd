extends Area3D

@export var bounce_strength: float = 22.0
@export var preserve_horizontal_momentum: float = 1.15

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.velocity.y = bounce_strength
		body.velocity.x *= preserve_horizontal_momentum
		body.velocity.z *= preserve_horizontal_momentum

		print("BOUNCE: Launched player")
