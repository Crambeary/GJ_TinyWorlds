class_name StatusBar
extends Control

## Manages a layered status bar display for suspicion and alert levels.

# Enum to define the visual state of the bar, controlled by Sentry
# This can also be defined in a global script if SentryState is used elsewhere.
# For now, keeping it local to where it's directly used for styling.
enum BarState { IDLE, SUSPICIOUS, ALERT, DETECTED }

@onready var suspicion_bar: ProgressBar = $SuspicionBar
@onready var alert_bar: ProgressBar = $AlertBar

const MAX_PERCENT: float = 100.0

func _ready() -> void:
	# super() # Control does not have a _ready(), so super() is not needed here.
	if not is_instance_valid(suspicion_bar):
		push_error("StatusBar: SuspicionBar node not found!")
		return
	if not is_instance_valid(alert_bar):
		push_error("StatusBar: AlertBar node not found!")
		return

	suspicion_bar.max_value = MAX_PERCENT
	suspicion_bar.value = 0
	_set_bar_fill_color(suspicion_bar, Color.WHITE)

	alert_bar.max_value = MAX_PERCENT
	alert_bar.value = 0
	alert_bar.visible = false
	_set_bar_fill_color(alert_bar, Color.YELLOW)


# --- Public API for Sentry to use --- #

## Sets the overall state of the status bar, updating visuals accordingly.
func set_meter_state(state: BarState, current_suspicion_value: float, current_alert_value: float) -> void:
	if not (is_instance_valid(suspicion_bar) and is_instance_valid(alert_bar)):
		push_warning("StatusBar: Bars not ready for set_meter_state.")
		return

	suspicion_bar.value = clampf(current_suspicion_value, 0.0, MAX_PERCENT)
	alert_bar.value = clampf(current_alert_value, 0.0, MAX_PERCENT)

	match state:
		BarState.IDLE:
			suspicion_bar.value = 0
			_set_bar_fill_color(suspicion_bar, Color.WHITE)
			alert_bar.visible = false
			alert_bar.value = 0
		BarState.SUSPICIOUS:
			_set_bar_fill_color(suspicion_bar, Color.WHITE)
			alert_bar.visible = false
			alert_bar.value = 0 # Ensure alert bar is reset if dropping from alert
		BarState.ALERT:
			suspicion_bar.value = MAX_PERCENT # Suspicion is full
			_set_bar_fill_color(suspicion_bar, Color.WHITE)
			alert_bar.visible = true
			_set_bar_fill_color(alert_bar, Color.YELLOW)
		BarState.DETECTED:
			suspicion_bar.value = MAX_PERCENT
			alert_bar.value = MAX_PERCENT
			alert_bar.visible = true
			# "Whole bar is red" - set both fills to red
			_set_bar_fill_color(suspicion_bar, Color.RED)
			_set_bar_fill_color(alert_bar, Color.RED)

## Directly sets the suspicion value (0-100).
## Note: Prefer using set_meter_state for coordinated updates.
func set_suspicion_value(value: float) -> void:
	if not is_instance_valid(suspicion_bar):
		push_warning("StatusBar: SuspicionBar not ready for set_suspicion_value.")
		return
	suspicion_bar.value = clampf(value, 0.0, MAX_PERCENT)

## Directly sets the alert value (0-100).
## Note: Prefer using set_meter_state for coordinated updates.
func set_alert_value(value: float) -> void:
	if not is_instance_valid(alert_bar):
		push_warning("StatusBar: AlertBar not ready for set_alert_value.")
		return
	alert_bar.value = clampf(value, 0.0, MAX_PERCENT)

## Sets the fill color of a specific progress bar.
func _set_bar_fill_color(bar: ProgressBar, new_color: Color) -> void:
	if not is_instance_valid(bar):
		push_warning("StatusBar: Invalid bar provided to _set_bar_fill_color.")
		return

	var style_box_fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style_box_fill:
		style_box_fill.bg_color = new_color
	else:
		# This fallback is generally not recommended for production if themes are used.
		# Ensure StyleBoxFlat is set up in the .tscn file.
		var new_style_box = StyleBoxFlat.new()
		new_style_box.bg_color = new_color
		bar.add_theme_stylebox_override("fill", new_style_box)
		push_warning("StatusBar (%s): 'fill' StyleBoxFlat was not found. Created a new one. Review theme setup in .tscn." % bar.name)


# --- Deprecated/Replaced Functions from original script --- #
# These are kept for reference or if direct single-bar manipulation is ever needed,
# but set_meter_state is the primary interface now.

# Sets the maximum value of the (now default) suspicion_bar.
func set_max_value(max_val: float) -> void:
	push_warning("StatusBar: set_max_value is deprecated. Max is fixed at 100. Use set_meter_state.")
	if is_instance_valid(suspicion_bar):
		suspicion_bar.max_value = max_val # Or keep fixed at MAX_PERCENT
		
# Sets the current value of the (now default) suspicion_bar.
func set_value(current_val: float) -> void:
	push_warning("StatusBar: set_value is deprecated. Use set_meter_state or set_suspicion_value.")
	if is_instance_valid(suspicion_bar):
		suspicion_bar.value = current_val

# Updates both the current and maximum values of the (now default) suspicion_bar.
func update_status(current_val: float, max_val: float) -> void:
	push_warning("StatusBar: update_status is deprecated. Use set_meter_state.")
	if is_instance_valid(suspicion_bar):
		suspicion_bar.max_value = max_val
		suspicion_bar.value = current_val

# Optional: Function to set the size of the status bar control itself
func set_bar_size(new_size: Vector2) -> void:
	size = new_size

# Optional: Function to set tint or color if needed via code (now use _set_bar_fill_color or set_meter_state)
func set_fill_color(new_color: Color) -> void:
	push_warning("StatusBar: set_fill_color is deprecated. Use set_meter_state.")
	_set_bar_fill_color(suspicion_bar, new_color) # Defaults to suspicion bar
