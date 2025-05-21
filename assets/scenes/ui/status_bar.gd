class_name StatusBar
extends Control

## Manages a simple status bar display, typically using a ProgressBar.

@onready var display_bar: ProgressBar = $DisplayBar

# Sets the maximum value of the progress bar.
func set_max_value(max_val: float) -> void:
	if not is_instance_valid(display_bar):
		push_warning("DisplayBar node not ready or invalid.")
		return
	display_bar.max_value = max_val

# Sets the current value of the progress bar.
func set_value(current_val: float) -> void:
	if not is_instance_valid(display_bar):
		push_warning("DisplayBar node not ready or invalid.")
		return
	display_bar.value = current_val

# Updates both the current and maximum values of the progress bar.
func update_status(current_val: float, max_val: float) -> void:
	if not is_instance_valid(display_bar):
		push_warning("DisplayBar node not ready or invalid.")
		return
	display_bar.max_value = max_val
	display_bar.value = current_val

# Optional: Function to set the size of the status bar control itself
func set_bar_size(new_size: Vector2) -> void:
	size = new_size
	# If DisplayBar is set to fill parent, it will adjust.
	# Otherwise, you might need to resize DisplayBar too:
	# if is_instance_valid(display_bar):
	#    display_bar.size = new_size

# Optional: Function to set tint or color if needed via code
func set_fill_color(new_color: Color) -> void:
	if not is_instance_valid(display_bar):
		push_warning("DisplayBar node not ready or invalid for set_fill_color.")
		return
	# This requires the ProgressBar to have a theme override for 'fill' style that is a StyleBoxFlat
	var style_box_fill: StyleBoxFlat = display_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style_box_fill:
		style_box_fill.bg_color = new_color
	else:
		# Fallback: create a new StyleBoxFlat if one doesn't exist.
		# It's better to set this up in the status_bar.tscn scene for consistent styling.
		var new_style_box = StyleBoxFlat.new()
		new_style_box.bg_color = new_color
		display_bar.add_theme_stylebox_override("fill", new_style_box)
		push_warning("StatusBar: 'fill' StyleBoxFlat was not found for ProgressBar. Created a new one. Please set up theme overrides in status_bar.tscn.")
