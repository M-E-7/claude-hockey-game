extends RigidBody3D

# Puck physics parameters
@export var ice_friction: float = 0.98  # Multiplier for velocity each frame (0.98 = 2% friction)
@export var min_velocity_threshold: float = 0.1  # Stop moving below this speed
@export var pickup_range: float = 1.5  # Distance for pickup

var is_held: bool = false
var holder: CharacterBody3D = null
var pickup_area: Area3D

func _ready():
	print("Puck ready!")
	# Set up the pickup area
	pickup_area = $PickupArea
	pickup_area.body_entered.connect(_on_pickup_area_entered)
	pickup_area.body_exited.connect(_on_pickup_area_exited)
	
	# Configure RigidBody properties for hockey puck physics
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.5
	
	# Don't freeze rotation - let's see if this helps
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

func _physics_process(delta):
	if not is_held:
		apply_ice_friction()
		check_for_pickup()
	else:
		follow_holder()

func apply_ice_friction():
	# Apply ice-like friction - gradually slow down
	var current_velocity = linear_velocity
	
	# Apply friction to horizontal movement
	current_velocity.x *= ice_friction
	current_velocity.z *= ice_friction
	
	# Stop very small movements
	if abs(current_velocity.x) < min_velocity_threshold:
		current_velocity.x = 0
	if abs(current_velocity.z) < min_velocity_threshold:
		current_velocity.z = 0
	
	linear_velocity = current_velocity

func check_for_pickup():
	# Get all bodies in pickup range
	var bodies = pickup_area.get_overlapping_bodies()
	
	if bodies.size() > 0:
		print("Bodies detected: ", bodies.size())
		
	for body in bodies:
		print("Checking body: ", body.name)
		if body.has_method("can_pickup_puck"):
			print("Body has can_pickup_puck method")
			if body.can_pickup_puck():
				print("Body can pickup puck - attempting pickup")
				pickup_by_player(body)
				break
			else:
				print("Body cannot pickup puck")
		else:
			print("Body does not have can_pickup_puck method")

func pickup_by_player(player: CharacterBody3D):
	if is_held:
		print("Puck already held!")
		return
	
	print("Picking up puck with player: ", player.name)
	is_held = true
	holder = player
	
	# Disable physics while held
	freeze = true
	
	# Tell the player they now have the puck
	player.pickup_puck(self)

func release_puck(shoot_direction: Vector3 = Vector3.ZERO, shoot_force: float = 0.0):
	if not is_held:
		return
	
	print("Releasing puck")
	is_held = false
	freeze = false
	
	# Tell the holder they no longer have the puck
	if holder and holder.has_method("release_puck"):
		holder.release_puck()
	
	holder = null
	
	# Apply shooting force if provided
	if shoot_direction != Vector3.ZERO and shoot_force > 0.0:
		# Ensure the puck stays on the ice (Y = 0 for direction)
		shoot_direction.y = 0
		shoot_direction = shoot_direction.normalized()
		
		# Apply the force
		linear_velocity = shoot_direction * shoot_force
		print("Shot puck with force: ", shoot_force, " in direction: ", shoot_direction)

func follow_holder():
	if holder == null:
		release_puck()
		return
	
	# Position the puck in front of the player
	var hold_offset = Vector3(0, 0.5, -1.5)  # In front and slightly up
	var target_position = holder.global_position + hold_offset
	
	global_position = target_position

func _on_pickup_area_entered(body):
	print("Pickup area entered by: ", body.name)

func _on_pickup_area_exited(body):
	print("Pickup area exited by: ", body.name)