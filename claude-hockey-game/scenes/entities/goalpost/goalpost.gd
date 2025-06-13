extends Node3D

# Goal configuration
@export var team_name: String = "Team A"
@export var goal_value: int = 1

# Goal area detection
var goal_area: Area3D
var has_scored: bool = false
var score_cooldown: float = 2.0  # Prevent multiple scores in quick succession
var cooldown_timer: float = 0.0

# Signals for scoring
signal goal_scored(team_name: String, points: int)

func _ready():
	# Get the goal area
	goal_area = $GoalArea
	
	# Connect the area signals
	goal_area.body_entered.connect(_on_goal_area_entered)
	goal_area.body_exited.connect(_on_goal_area_exited)
	
	print("Goalpost for ", team_name, " initialized")

func _process(delta):
	# Handle score cooldown
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			has_scored = false

func _on_goal_area_entered(body):
	# Check if it's the puck entering the goal
	if body.name == "Puck" and not has_scored and cooldown_timer <= 0.0:
		score_goal()

func _on_goal_area_exited(body):
	# Optional: Handle puck leaving goal area
	pass

func score_goal():
	if has_scored:
		return
	
	has_scored = true
	cooldown_timer = score_cooldown
	
	print("GOAL! ", team_name, " scored ", goal_value, " point(s)!")
	
	# Emit signal for game manager to handle
	goal_scored.emit(team_name, goal_value)
	
	# Visual feedback - make the goal flash
	flash_goal()

func flash_goal():
	# Create a tween for visual feedback
	var tween = create_tween()
	
	# Get all mesh instances for flashing effect
	var meshes = []
	meshes.append($LeftPost/MeshInstance3D)
	meshes.append($RightPost/MeshInstance3D)
	meshes.append($Crossbar/MeshInstance3D)
	meshes.append($Net)
	
	# Flash effect
	for i in range(3):  # Flash 3 times
		# Make bright
		tween.parallel().tween_method(_set_goal_brightness, 1.0, 2.0, 0.2)
		tween.parallel().tween_delay(0.2)
		# Return to normal
		tween.parallel().tween_method(_set_goal_brightness, 2.0, 1.0, 0.2)
		tween.parallel().tween_delay(0.4)

func _set_goal_brightness(brightness: float):
	# Change material brightness for flash effect
	var meshes = [$LeftPost/MeshInstance3D, $RightPost/MeshInstance3D, $Crossbar/MeshInstance3D, $Net]
	
	for mesh_instance in meshes:
		var material = mesh_instance.get_surface_override_material(0)
		if not material:
			material = mesh_instance.mesh.surface_get_material(0)
			if material:
				material = material.duplicate()
				mesh_instance.set_surface_override_material(0, material)
		
		if material and material is StandardMaterial3D:
			var base_color = Color(1, 0, 0, 1)  # Red color
			material.albedo_color = base_color * brightness