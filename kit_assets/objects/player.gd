extends CharacterBody3D

# ---------------- MOVEMENT ----------------
@export var walk_speed: float = 7.0
@export var sprint_speed: float = 15.0
@export var ground_acceleration: float = 55.0
@export var air_acceleration: float = 30.0
@export var ground_friction: float = 40.0
@export var air_friction: float = 5.0

@export var jump_velocity: float = 10.0
@export var double_jump_velocity: float = 9.0
@export var gravity: float = 26.0

# ---------------- AIR DASH ----------------
@export var air_dash_speed: float = 26.0
@export var air_dash_duration: float = 0.18
@export var air_dash_cooldown: float = 1.0

# ---------------- GRAPPLE ----------------
@export var grapple_pull_strength: float = 50.0
@export var grapple_max_distance: float = 60.0
@export var grapple_min_distance: float = 3.0

# ---------------- CAMERA ----------------
@export var mouse_sensitivity: float = 0.0022
@export var base_fov: float = 85.0
@export var sprint_fov: float = 94.0
@export var camera_shake_enabled: bool = true

# ---------------- INTERNAL STATE ----------------
var can_double_jump: bool = true

var is_air_dashing: bool = false
var air_dash_timer: float = 0.0
var air_dash_cooldown_timer: float = 0.0
var air_dash_direction: Vector3 = Vector3.ZERO

var is_grappling: bool = false
var current_grapple_point: Node3D = null

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var grapple_ray_cast: RayCast3D = $GrappleRayCast
@onready var grapple_line: MeshInstance3D = $GrappleLine

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Create the rope mesh in code, so no manual mesh setup is needed.
	grapple_line.mesh = ImmediateMesh.new()

	var rope_material := StandardMaterial3D.new()
	rope_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_material.albedo_color = Color("#4FF3FF")
	grapple_line.material_override = rope_material
	grapple_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_rig.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_rig.rotation.x = clamp(
			camera_rig.rotation.x,
			deg_to_rad(-80.0),
			deg_to_rad(80.0)
		)

	# Toggle camera shake
	if event.is_action_pressed("toggle_camera_shake"):
		camera_shake_enabled = not camera_shake_enabled

	# Pause / release mouse
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Return to the latest checkpoint
	if event.is_action_pressed("restart"):
		GameManager.respawn_player(self)

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_air_dash(delta)
	handle_horizontal_movement(delta)
	handle_jump()
	handle_grapple_input()
	apply_grapple_force(delta)
	move_and_slide()
	update_grapple_line()
	update_camera_fov()

# ---------------- MOVEMENT ----------------

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func get_input_direction() -> Vector3:
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	return (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

func handle_horizontal_movement(delta: float) -> void:
	# While grappling, do not let normal movement cancel grapple momentum.
	if is_grappling:
		return

	var direction := get_input_direction()
	var target_speed := walk_speed

	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed

	if is_air_dashing:
		velocity.x = air_dash_direction.x * air_dash_speed
		velocity.z = air_dash_direction.z * air_dash_speed
		return

	if is_on_floor():
		if direction != Vector3.ZERO:
			velocity.x = move_toward(
				velocity.x,
				direction.x * target_speed,
				ground_acceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				direction.z * target_speed,
				ground_acceleration * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				ground_friction * delta
			)
			velocity.z = move_toward(
				velocity.z,
				0.0,
				ground_friction * delta
			)
	else:
		if direction != Vector3.ZERO:
			velocity.x = move_toward(
				velocity.x,
				direction.x * target_speed,
				air_acceleration * delta
			)
			velocity.z = move_toward(
				velocity.z,
				direction.z * target_speed,
				air_acceleration * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				air_friction * delta
			)
			velocity.z = move_toward(
				velocity.z,
				0.0,
				air_friction * delta
			)

func handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			can_double_jump = true
		elif can_double_jump:
			velocity.y = double_jump_velocity
			can_double_jump = false

	if is_on_floor():
		can_double_jump = true

func handle_air_dash(delta: float) -> void:
	air_dash_cooldown_timer = maxf(air_dash_cooldown_timer - delta, 0.0)

	if is_air_dashing:
		air_dash_timer -= delta

		if air_dash_timer <= 0.0:
			is_air_dashing = false

		return

	if Input.is_action_just_pressed("air_dash") and air_dash_cooldown_timer <= 0.0:
		var direction := get_input_direction()

		if direction == Vector3.ZERO:
			direction = -transform.basis.z

		air_dash_direction = direction.normalized()
		is_air_dashing = true
		air_dash_timer = air_dash_duration
		air_dash_cooldown_timer = air_dash_cooldown

# ---------------- GRAPPLE ----------------

func handle_grapple_input() -> void:
	# Right click attaches. Right click again releases.
	if Input.is_action_just_pressed("grapple"):
		if is_grappling:
			release_grapple()
		else:
			try_start_grapple()

func try_start_grapple() -> void:
	var grapple_points := get_tree().get_nodes_in_group("grapple_points")

	print("GRAPPLE: Found ", grapple_points.size(), " grapple point(s).")

	if grapple_points.is_empty():
		print("GRAPPLE ERROR: No nodes are in the group 'grapple_points'.")
		return

	var camera_forward: Vector3 = -camera.global_basis.z
	var best_point: Node3D = null
	var best_score: float = -999999.0

	for point in grapple_points:
		if point is not Node3D:
			continue

		var offset: Vector3 = point.global_position - camera.global_position
		var distance: float = offset.length()

		if distance > grapple_max_distance:
			continue

		var direction_to_point: Vector3 = offset.normalized()
		var aim_alignment: float = camera_forward.dot(direction_to_point)

		# The point must be generally in front of the player.
		if aim_alignment < 0.25:
			continue

		var score: float = aim_alignment - distance * 0.01

		if score > best_score:
			best_score = score
			best_point = point

	if best_point == null:
		print("GRAPPLE: No valid point in range or in front of you.")
		return

	current_grapple_point = best_point
	is_grappling = true
	is_air_dashing = false

	print("GRAPPLE: Attached to ", best_point.name)

func apply_grapple_force(delta: float) -> void:
	if not is_grappling:
		return

	if not is_instance_valid(current_grapple_point):
		release_grapple()
		return

	var offset: Vector3 = (
		current_grapple_point.global_position
		- camera.global_position
	)

	if offset.length() < grapple_min_distance:
		release_grapple()
		return

	velocity += offset.normalized() * grapple_pull_strength * delta

func release_grapple() -> void:
	if not is_grappling:
		return

	is_grappling = false
	current_grapple_point = null

	print("GRAPPLE: Released")

func update_grapple_line() -> void:
	var rope_mesh := grapple_line.mesh as ImmediateMesh

	if rope_mesh == null:
		return

	rope_mesh.clear_surfaces()

	if not is_grappling:
		return

	if not is_instance_valid(current_grapple_point):
		return

	# Draw the rope slightly below and to the right of the camera.
	var start_world: Vector3 = (
		camera.global_position
		+ camera.global_basis.x * 0.25
		- camera.global_basis.y * 0.2
		- camera.global_basis.z * 0.4
	)

	var end_world: Vector3 = current_grapple_point.global_position

	rope_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	rope_mesh.surface_add_vertex(grapple_line.to_local(start_world))
	rope_mesh.surface_add_vertex(grapple_line.to_local(end_world))
	rope_mesh.surface_end()

# ---------------- CAMERA ----------------

func update_camera_fov() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_fov := base_fov

	if horizontal_speed > 11.0:
		target_fov = sprint_fov

	camera.fov = lerpf(camera.fov, target_fov, 0.08)
func _process(delta: float) -> void:
	if global_position.y < -30.0:
		GameManager.respawn_player(self)
