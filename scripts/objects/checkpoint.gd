extends Area3D

signal checkpoint_activated(checkpoint: Node3D)

var is_activated: bool = false

@onready var activation_light: OmniLight3D = $ActivationLight

func _ready() -> void:
	activation_light.light_energy = 0.0

	# Connect the Area3D signal in code.
	# This guarantees the checkpoint works even if the editor connection is missing.
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_activated:
		return

	if body is CharacterBody3D:
		is_activated = true
		activation_light.light_energy = 2.0

		GameManager.set_checkpoint(self)
		checkpoint_activated.emit(self)

		print("CHECKPOINT: Activated ", name)
