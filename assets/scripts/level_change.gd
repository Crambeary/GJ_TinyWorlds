class_name LevelChangeArea
extends Area2D

## Script to change to a specified level when a player enters this Area2D.

@export_file("*.tscn") var next_level_path: String = ""

func _ready() -> void:
	# Ensure the Area2D is monitoring for bodies.
	# This is often set in the editor, but good to double-check or enforce.
	monitoring = true 
	
	# Connect the body_entered signal to our function.
	# Make sure the signal is connected, either here or in the editor.
	# It's generally safer to connect in code if this script is meant to be plug-and-play.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the entering body is the player (assumes player is in group "player")
	print("Entered Zone")
	if body.is_in_group("player"):
		if next_level_path.is_empty():
			print_debug("LevelChangeArea: next_level_path is not set on ", get_path())
			return
		
		print_debug("Player entered ", name, ". Changing to level: ", next_level_path)
		var error_code = get_tree().change_scene_to_file(next_level_path)
		if error_code != OK:
			print_debug("LevelChangeArea: Error changing scene to '" + next_level_path + "'. Error code: ", error_code)
