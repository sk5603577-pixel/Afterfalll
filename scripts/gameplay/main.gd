extends Node3D

func _on_checkpoint_1_checkpoint_activated(checkpoint: Node3D) -> void:
	GameManager.set_checkpoint(checkpoint)
