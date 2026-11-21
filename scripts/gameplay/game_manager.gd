extends Node

var current_checkpoint: Node3D = null
var elapsed_time: float = 0.0
var is_timer_running: bool = true
var has_finished: bool = false

func _process(delta: float) -> void:
	if is_timer_running and not has_finished:
		elapsed_time += delta

func set_checkpoint(checkpoint: Node3D) -> void:
	current_checkpoint = checkpoint
	print("GAME MANAGER: Checkpoint saved")

func respawn_player(player: CharacterBody3D) -> void:
	if current_checkpoint != null:
		player.global_position = current_checkpoint.global_position + Vector3(0, 2, 0)
	else:
		player.global_position = Vector3(0, 2, 0)

	player.velocity = Vector3.ZERO

func restart_run() -> void:
	elapsed_time = 0.0
	is_timer_running = true
	has_finished = false
	current_checkpoint = null

func finish_run() -> void:
	if has_finished:
		return

	has_finished = true
	is_timer_running = false

	print("FINISH: Time: ", elapsed_time)
