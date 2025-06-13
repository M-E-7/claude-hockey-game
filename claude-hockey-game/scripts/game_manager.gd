extends Node

# Score tracking
var team_scores = {}
var game_time: float = 0.0
var is_game_active: bool = true

# UI elements
var score_label: Label
var time_label: Label

# Signals
signal game_ended(winning_team: String, final_scores: Dictionary)

func _ready():
	# Initialize scores
	team_scores["Team A"] = 0
	team_scores["Team B"] = 0
	
	# Create UI
	create_score_ui()
	
	# Connect to all goalposts in the scene
	connect_to_goalposts()

func _process(delta):
	if is_game_active:
		game_time += delta
		update_time_display()

func create_score_ui():
	# Create CanvasLayer for UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)
	
	# Create score container
	var score_container = VBoxContainer.new()
	score_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_container.position = Vector2(20, 20)
	canvas_layer.add_child(score_container)
	
	# Create score label
	score_label = Label.new()
	score_label.text = "Team A: 0 - Team B: 0"
	score_label.add_theme_font_size_override("font_size", 24)
	score_container.add_child(score_label)
	
	# Create time label
	time_label = Label.new()
	time_label.text = "Time: 0:00"
	time_label.add_theme_font_size_override("font_size", 18)
	score_container.add_child(time_label)

func connect_to_goalposts():
	# Find all goalpost nodes and connect their signals
	var goalposts = get_tree().get_nodes_in_group("goalposts")
	
	for goalpost in goalposts:
		if goalpost.has_signal("goal_scored"):
			goalpost.goal_scored.connect(_on_goal_scored)

func _on_goal_scored(team_name: String, points: int):
	# Update score
	if team_name in team_scores:
		team_scores[team_name] += points
		print("Score updated: ", team_name, " now has ", team_scores[team_name], " points")
		
		# Update UI
		update_score_display()
		
		# Check for win condition (optional)
		check_win_condition()
	else:
		print("Unknown team scored: ", team_name)

func update_score_display():
	if score_label:
		score_label.text = "Team A: %d - Team B: %d" % [team_scores.get("Team A", 0), team_scores.get("Team B", 0)]

func update_time_display():
	if time_label:
		var minutes = int(game_time) / 60
		var seconds = int(game_time) % 60
		time_label.text = "Time: %d:%02d" % [minutes, seconds]

func check_win_condition():
	# Optional: End game when a team reaches a certain score
	var win_score = 5  # First to 5 goals wins
	
	for team in team_scores:
		if team_scores[team] >= win_score:
			end_game(team)
			break

func end_game(winning_team: String):
	is_game_active = false
	print("Game Over! ", winning_team, " wins!")
	
	# Emit game end signal
	game_ended.emit(winning_team, team_scores)
	
	# Show game over message
	show_game_over_message(winning_team)

func show_game_over_message(winning_team: String):
	# Create game over popup
	var popup = AcceptDialog.new()
	popup.title = "Game Over!"
	popup.dialog_text = "%s wins!\nFinal Score: Team A: %d - Team B: %d" % [winning_team, team_scores["Team A"], team_scores["Team B"]]
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()

func reset_game():
	# Reset scores and time
	for team in team_scores:
		team_scores[team] = 0
	
	game_time = 0.0
	is_game_active = true
	
	# Update displays
	update_score_display()
	update_time_display()
	
	print("Game reset!")