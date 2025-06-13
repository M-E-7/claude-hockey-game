extends CharacterBody3D

# Movement parameters
@export var acceleration: float = 12.0
@export var max_speed: float = 15.0
@export var friction: float = 0.15  # Ice friction (lower = more slippery)
@export var turn_speed: float = 8.0  # How fast the player rotates
@export var rotation_threshold: float = 0.5  # Minimum speed needed to rotate

# Puck handling parameters
@export var shoot_force: float = 25.0
@export var max_shoot_force: float = 50.0
@export var charge_rate: float = 30.0  # How fast the shot charges per second
@export var pickup_range: float = 1.5

# Physics
var input_vector: Vector2
var momentum_velocity: Vector3

# Puck handling
var has_puck: bool = false
var held_puck: RigidBody3D = null

# Shot charging
var is_charging_shot: bool = false
var current_charge: float = 0.0
var power_bar_3d: MeshInstance3D = null
var power_bar_background: MeshInstance3D = null

# Pickup cooldown
var pickup_cooldown_time: float = 1.0  # Seconds before can pickup again
var pickup_cooldown_timer: float = 0.0

func _ready():
	# Initialize momentum
	momentum_velocity = Vector3.ZERO
	
	# Create 3D power bar
	create_3d_power_bar()

func _physics_process(delta):
	handle_input()
	handle_puck_actions()
	apply_movement(delta)
	apply_rotation(delta)
	apply_friction(delta)
	update_pickup_cooldown(delta)
	update_power_bar_rotation()
	move_and_slide()

func handle_input():
	# Get input from WASD or arrow keys
	input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# Normalize diagonal movement
	input_vector = input_vector.normalized()

func handle_puck_actions():
	# Handle shot charging
	if has_puck and held_puck:
		if Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			# Start or continue charging
			if not is_charging_shot:
				start_charging_shot()
			charge_shot()
		else:
			# Release shot if we were charging
			if is_charging_shot:
				shoot_charged_puck()
			else:
				# Quick shot if just tapped
				pass

func apply_movement(delta):
	if input_vector != Vector2.ZERO:
		# Convert 2D input to 3D movement (XZ plane for hockey)
		var desired_velocity = Vector3(input_vector.x, 0, input_vector.y) * max_speed
		
		# Gradually accelerate towards desired velocity (hockey-like acceleration)
		momentum_velocity = momentum_velocity.move_toward(desired_velocity, acceleration * delta)
	
	# Apply the momentum to character velocity
	velocity.x = momentum_velocity.x
	velocity.z = momentum_velocity.z
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

func apply_friction(delta):
	# Apply ice friction - gradually slow down when not inputting
	var friction_force = friction * delta
	
	# Only apply friction when not actively accelerating in that direction
	if input_vector.x == 0:
		momentum_velocity.x = move_toward(momentum_velocity.x, 0.0, friction_force * abs(momentum_velocity.x) + 0.5)
	
	if input_vector.y == 0:
		momentum_velocity.z = move_toward(momentum_velocity.z, 0.0, friction_force * abs(momentum_velocity.z) + 0.5)
	
	# Prevent tiny movements (dead zone)
	if momentum_velocity.length() < 0.1:
		momentum_velocity = Vector3.ZERO

func apply_rotation(delta):
	# Only rotate if moving fast enough
	if momentum_velocity.length() > rotation_threshold:
		# Calculate the direction we're moving in
		var movement_direction = Vector3(momentum_velocity.x, 0, momentum_velocity.z).normalized()
		
		# Calculate the target rotation (looking in movement direction)
		var target_transform = transform.looking_at(global_position + movement_direction, Vector3.UP)
		
		# Smoothly rotate toward the target
		transform = transform.interpolate_with(target_transform, turn_speed * delta)

# Puck handling methods
func can_pickup_puck() -> bool:
	# Check if we don't have puck AND cooldown has expired
	return not has_puck and pickup_cooldown_timer <= 0.0

func pickup_puck(puck: RigidBody3D):
	if has_puck:
		return
	
	has_puck = true
	held_puck = puck
	print("Player picked up puck!")

func release_puck():
	has_puck = false
	held_puck = null
	# Stop any charging when puck is released
	stop_charging_shot()
	print("Player released puck!")

func shoot_puck():
	if not has_puck or not held_puck:
		return
	
	# Calculate shoot direction based on player's facing direction
	var shoot_direction = Vector3.ZERO
	
	# Use the player's facing direction (transform.basis.z is forward in Godot, but negative)
	shoot_direction = -transform.basis.z
	
	# If no clear facing direction, use movement direction
	if momentum_velocity.length() > 0.5:
		shoot_direction = Vector3(momentum_velocity.x, 0, momentum_velocity.z).normalized()
	
	# Ensure direction is valid
	if shoot_direction == Vector3.ZERO:
		shoot_direction = Vector3(0, 0, -1)  # Default forward
	
	# Release and shoot the puck
	held_puck.release_puck(shoot_direction, shoot_force)
	
	print("Player shot the puck!")

# Shot charging system
func create_3d_power_bar():
	# Create background bar
	power_bar_background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(2.0, 0.2, 0.1)  # Width, Height, Depth
	power_bar_background.mesh = bg_mesh
	
	# Background material (dark)
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)
	bg_material.flags_unshaded = true
	bg_material.no_depth_test = true
	bg_material.flags_transparent = false
	power_bar_background.material_override = bg_material
	
	# Position below player
	power_bar_background.position = Vector3(0, -0.8, 0)
	add_child(power_bar_background)
	
	# Create foreground bar (the actual power indicator)
	power_bar_3d = MeshInstance3D.new()
	var fg_mesh = BoxMesh.new()
	fg_mesh.size = Vector3(0.1, 0.25, 0.12)  # Start very thin, slightly taller than background
	power_bar_3d.mesh = fg_mesh
	
	# Foreground material (starts red)
	var fg_material = StandardMaterial3D.new()
	fg_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Red
	fg_material.flags_unshaded = true
	fg_material.no_depth_test = true
	fg_material.flags_transparent = false
	power_bar_3d.material_override = fg_material
	
	# Position aligned with background, slightly forward and higher
	power_bar_3d.position = Vector3(-0.95, -0.8, 0.01)  # Start at left edge
	add_child(power_bar_3d)
	
	# Start both as invisible
	power_bar_background.visible = false
	power_bar_3d.visible = false
	
	print("Created 3D power bar")

func start_charging_shot():
	is_charging_shot = true
	current_charge = 0.0
	print("Starting charge shot - making bars visible")
	
	if power_bar_3d and power_bar_background:
		power_bar_3d.visible = true
		power_bar_background.visible = true
		print("Bars should now be visible")
		
		# Reset bar to minimum size and red color
		var fg_mesh = power_bar_3d.mesh as BoxMesh
		if fg_mesh:
			fg_mesh.size = Vector3(0.1, 0.25, 0.12)
			power_bar_3d.position.x = -0.95
			print("Reset bar size and position")
		
		var material = power_bar_3d.material_override as StandardMaterial3D
		if material:
			material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
			print("Set bar color to red")
	else:
		print("ERROR: Power bars not found!")
	
	print("Started charging shot!")

func charge_shot():
	if not is_charging_shot:
		return
	
	# Increase charge based on time
	current_charge += charge_rate * get_physics_process_delta_time()
	current_charge = min(current_charge, max_shoot_force)
	
	# Update 3D power bar
	if power_bar_3d:
		var charge_ratio = current_charge / max_shoot_force
		
		# Update bar width (scale from 0.1 to 2.0)
		var bar_width = 0.1 + (charge_ratio * 1.9)
		var fg_mesh = power_bar_3d.mesh as BoxMesh
		if fg_mesh:
			fg_mesh.size.x = bar_width
		
		# Update bar position (keep left edge aligned)
		power_bar_3d.position.x = -0.95 + (bar_width - 0.1) / 2.0
		
		# Update color (red to yellow to green)
		var color = Color.RED
		if charge_ratio <= 0.5:
			# Red to Yellow (0.0 to 0.5)
			color = Color.RED.lerp(Color.YELLOW, charge_ratio * 2.0)
		else:
			# Yellow to Green (0.5 to 1.0)
			color = Color.YELLOW.lerp(Color.GREEN, (charge_ratio - 0.5) * 2.0)
		
		var material = power_bar_3d.material_override as StandardMaterial3D
		if material:
			material.albedo_color = color
		
		# Debug output every so often
		if int(current_charge * 10) % 5 == 0:
			print("Charge: ", current_charge, " Ratio: ", charge_ratio, " Width: ", bar_width)

func shoot_charged_puck():
	if not has_puck or not held_puck or not is_charging_shot:
		return
	
	# Calculate shoot direction
	var shoot_direction = -transform.basis.z
	if momentum_velocity.length() > 0.5:
		shoot_direction = Vector3(momentum_velocity.x, 0, momentum_velocity.z).normalized()
	if shoot_direction == Vector3.ZERO:
		shoot_direction = Vector3(0, 0, -1)
	
	# Use charged power
	var final_force = max(current_charge, shoot_force * 0.3)  # Minimum 30% of base force
	held_puck.release_puck(shoot_direction, final_force)
	
	# Start pickup cooldown
	pickup_cooldown_timer = pickup_cooldown_time
	
	# Reset charging
	stop_charging_shot()
	
	print("Shot puck with charged force: ", final_force)

func update_pickup_cooldown(delta):
	if pickup_cooldown_timer > 0.0:
		pickup_cooldown_timer -= delta

func stop_charging_shot():
	is_charging_shot = false
	current_charge = 0.0
	if power_bar_3d and power_bar_background:
		power_bar_3d.visible = false
		power_bar_background.visible = false

func update_power_bar_rotation():
	if power_bar_background and power_bar_3d:
		var camera = get_viewport().get_camera_3d()
		print(camera)
		if camera:
			var look_direction = (camera.global_position - global_position).normalized()
			power_bar_background.look_at(global_position + look_direction, Vector3.UP)
			power_bar_3d.look_at(global_position + look_direction, Vector3.UP)
