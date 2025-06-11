extends CharacterBody3D

# Movement parameters
@export var acceleration: float = 12.0
@export var max_speed: float = 8.0
@export var friction: float = 0.15  # Ice friction (lower = more slippery)
@export var turn_speed: float = 3.0

# Physics
var input_vector: Vector2
var momentum_velocity: Vector3

func _ready():
	# Initialize momentum
	momentum_velocity = Vector3.ZERO

func _physics_process(delta):
	handle_input()
	apply_movement(delta)
	apply_friction(delta)
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
