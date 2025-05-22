extends Node2D
class_name DetectionArrow

## A visual indicator that appears when the player is being detected by an enemy
## Points in the direction of the detecting entity

signal detection_ended

# Arrow visual properties
@export var max_distance: float = 150.0
@export var min_opacity: float = 0.2
@export var max_opacity: float = 1.0
@export var pulse_speed: float = 2.0
@export var detection_color: Color = Color.RED
@export var warning_color: Color = Color.YELLOW
# Arrow will appear for any detection above zero now

# Color interpolation for intensity
@export var low_intensity_color: Color = Color(0.5, 0.5, 0.0, 1.0) # Dim yellow
@export var high_intensity_color: Color = Color(1.0, 1.0, 0.0, 1.0) # Bright yellow

# Detection state tracking
var is_detected: bool = false
var detecting_entity: Node2D = null
var detection_level: float = 0.0  # 0.0 to 1.0 where 1.0 is fully detected
var should_disappear: bool = false # Flag to track if arrow should disappear due to low alertness

@onready var arrow_line: Line2D = $ArrowLine
@onready var arrow_head: Polygon2D = $ArrowHead

func _ready() -> void:
	# Initialize the arrow as invisible
	visible = false
	# Set initial colors
	arrow_line.default_color = warning_color
	arrow_head.color = warning_color
	# Make sure the arrow is above other elements
	z_index = 10

func _process(delta: float) -> void:
	# Only hide arrow when detection level is exactly zero
	if detection_level <= 0.0:
		if visible:
			visible = false
			detection_ended.emit()
		return
	
	# Otherwise show and update the arrow
	if not visible:
		visible = true
	
	if is_detected and is_instance_valid(detecting_entity):
		# Update arrow direction to point at detecting entity
		var direction: Vector2 = (detecting_entity.global_position - global_position).normalized()
		rotation = direction.angle()
		
		# Update arrow appearance based on detection level
		_update_arrow_appearance(delta)
	elif visible:
		# Fade out if no longer detected
		detection_level = max(0.0, detection_level - delta * 2.0) # Faster fade out
		_update_arrow_appearance(delta)

## Start showing the detection arrow pointing toward the specified entity
func start_detection(entity: Node2D, initial_level: float = 0.05) -> void:
	detecting_entity = entity
	is_detected = true
	detection_level = initial_level
	visible = true
	
	# Set initial appearance
	_update_arrow_appearance(0.0)

## Update the detection level (how strongly the player is being detected)
func update_detection_level(new_level: float) -> void:
	detection_level = clamp(new_level, 0.0, 1.0)
	
	# Show when any detection is happening (above 0)
	# Hide only when detection is exactly 0
	if detection_level <= 0.0:
		if visible:
			visible = false
			detection_ended.emit()
		return
	elif not visible:
		visible = true
	
	# Change color based on detection level
	if detection_level >= 0.7:
		# Red alert color when highly detected
		arrow_line.default_color = detection_color
		arrow_head.color = detection_color
	else:
			# Interpolate between low and high intensity yellow based on detection level
		# This creates a progressively more intense yellow as detection increases
		var t = clamp(detection_level / 0.7, 0.0, 1.0) 
		var interpolated_color = low_intensity_color.lerp(high_intensity_color, t)
		arrow_line.default_color = interpolated_color
		arrow_head.color = interpolated_color

## Stop showing the detection arrow
func stop_detection() -> void:
	is_detected = false
	# Let the process function handle the fade out

## Update arrow's visual appearance based on detection level
func _update_arrow_appearance(_delta: float) -> void:
	# Pulsing effect increases with detection level
	var pulse_frequency = pulse_speed * (1.0 + detection_level * 2.0) # More intense pulsing at higher detection
	var pulse_factor: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * pulse_frequency)
	
	# Calculate opacity based on detection level and pulse
	# Higher detection levels = less transparency variation (more solid)
	var min_pulse_opacity = lerp(min_opacity, max_opacity * 0.7, detection_level)
	var opacity: float = lerp(min_pulse_opacity, max_opacity, detection_level * pulse_factor)
	modulate.a = opacity
	
	# Scale arrow line based on detection level
	arrow_line.width = 2.0 + detection_level * 3.0
	
	# Scale arrow head based on detection level
	var scale_factor: float = 0.8 + detection_level * 0.6
	arrow_head.scale = Vector2(scale_factor, scale_factor)
