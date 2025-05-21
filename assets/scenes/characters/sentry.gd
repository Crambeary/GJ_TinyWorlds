extends Node2D

var player: Node2D
@onready var vision_manager: VisionManager = $VisionManager
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var question_mark: Node2D = $Emotes/QuestionMark
@onready var exclamation: Node2D = $Emotes/Exclamation
@onready var emote_node: Node2D = $Emotes
@onready var animated_sprite_2d_ref_for_status_bar: AnimatedSprite2D = $AnimatedSprite2D # Explicit reference for clarity

# Preload the status bar scene. Ensure this path is correct.
const STATUS_BAR_SCENE: PackedScene = preload("res://assets/scenes/ui/status_bar.tscn")

# CONFIGURATION for status bar positioning
const STATUS_BAR_Y_OFFSET_FROM_SPRITE_TOP: float = -10.0 # Negative to go upwards from origin
const PADDING_BELOW_EMOTE: float = 2.0 # Small space between emote and status bar

var status_bar_instance: StatusBar

@export var path_group_name: String = "Sentry1"
@onready var waypoints: Array = get_tree().get_first_node_in_group(path_group_name).get_children()
var current_index: int = 0
var dir: Vector2
enum IdleTasks {PATROL, WAIT, INSPECT, RETURN}
enum AlertnessState {IDLE, SUSPICIOUS, ALERTED}
@export var idle_task = IdleTasks.PATROL
@export var alertness_state = AlertnessState.IDLE
# Alertness ranges from 0.0 (completely calm) to 1.0 (fully alerted)
@export_range(0.0, 1.0, 0.01) var alertness_value: float = 0.0:
	set(value):
		var new_value = clampf(value, 0.0, 1.0)
		if alertness_value == new_value:
			return
		alertness_value = new_value
		# Update debug print for alertness
		# print_alertness_bar()
		# Potentially change state based on new alertness
		# check_alertness_thresholds()
		if is_instance_valid(status_bar_instance):
			status_bar_instance.update_status(alertness_value, 1.0) # Max is 1.0 for alertness

# Thresholds as percentages (0.0-1.0)
const SUSPICIOUS_THRESHOLD: float = 0.3 # Example: 30% alertness to become suspicious
@export_range(0.0, 1.0, 0.05) var suspicion_threshold: float = 0.3
@export_range(0.0, 1.0, 0.05) var alertness_threshold: float = 0.7

# Rate of change per second
@export var initial_alertness_increase_rate: float = 0.2  # Slow initial increase
@export var alertness_increase_rate: float = 0.5          # Faster increase once suspicious/alerted

# Cooldown for returning to IDLE (e.g., from ALERTED or brief sightings)
@export var idle_cooldown_delay: float = 2.0              # Seconds before idle cooldown starts
@export var idle_cooldown_rate: float = 0.1               # Rate of idle cooldown after delay

# Cooldown specific to SUSPICIOUS state
@export var suspicious_cooldown_delay: float = 5.0        # Seconds before suspicious cooldown starts
@export var suspicious_cooldown_rate: float = 0.05        # Rate of suspicious cooldown after delay (slower)

# Internal state
var cooldown_timer: float = 0.0
var is_in_cooldown: bool = false
var was_player_seen: bool = false

@export var speed: float = 10.0

func get_enum_name(enum_dict: Dictionary, value: int) -> String:
	for name in enum_dict.keys():
		if enum_dict[name] == value:
			return name
	return "Unknown"

func get_current_waypoint():
	return waypoints[current_index] as Marker2D
	
func handle_waypoint_action(wp):
	match wp.action:
		"wait":
			idle_task = IdleTasks.WAIT
			await get_tree().create_timer(wp.wait_time, false).timeout
			idle_task = IdleTasks.PATROL
		_:
			pass
	
func set_vision_direction(direction: Vector2) -> void:
	direction = direction * -1 # Invert Vector2 Values
	vision_manager.rotation = direction.angle()
	
func update_alertness():
	if alertness_value < suspicion_threshold \
	and alertness_state != AlertnessState.IDLE:
		update_alert_state(AlertnessState.IDLE)
		idle_task = IdleTasks.PATROL
		question_mark.visible = false
		exclamation.visible = false
	elif alertness_value >= suspicion_threshold \
	and alertness_value < alertness_threshold \
	and alertness_state != AlertnessState.SUSPICIOUS:
		update_alert_state(AlertnessState.SUSPICIOUS)
		idle_task = IdleTasks.WAIT
		question_mark.visible = true
		exclamation.visible = false
	elif alertness_value >= alertness_threshold \
	and alertness_state != AlertnessState.ALERTED:
		update_alert_state(AlertnessState.ALERTED)
		question_mark.visible = false
		exclamation.visible = true


func update_alert_state(new_state: AlertnessState) -> void:
	if !new_state:
		pass
	if !AlertnessState.find_key(new_state):
		print("Invalid Alertness State: ", new_state)
		pass
	var enum_name = get_enum_name(AlertnessState, new_state)
	alertness_state = new_state
	
func _ready() -> void:
	print("Sentry _ready: Attempting to initialize status bar.") # Debug print
	if STATUS_BAR_SCENE == null:
		push_error("Sentry _ready: STATUS_BAR_SCENE is null! Preload failed.")
		return # Stop further execution if preload failed
	else:
		print("Sentry _ready: STATUS_BAR_SCENE loaded successfully.")
	
	player = get_tree().get_first_node_in_group("player")

	# Instantiate and add the status bar
	if STATUS_BAR_SCENE:
		status_bar_instance = STATUS_BAR_SCENE.instantiate() as StatusBar # Cast to StatusBar
		if status_bar_instance == null:
			push_error("Sentry _ready: Failed to instantiate STATUS_BAR_SCENE! status_bar_instance is null.")
			# return # Stop if instantiation failed - let's allow it to continue for now to see other errors if any
		else:
			print("Sentry _ready: status_bar_instance created successfully: ", status_bar_instance)
		
		add_child(status_bar_instance)
		# Initial update for alertness
		status_bar_instance.update_status(alertness_value, 1.0)
	else:
		# This case should ideally be caught by the null check above
		push_error("Sentry _ready: STATUS_BAR_SCENE was unexpectedly null after initial check.")

func _physics_process(delta: float) -> void:
	var target = get_current_waypoint().global_position
	dir = (target - global_position).normalized()
	if idle_task == IdleTasks.WAIT:
		if dir.x <= -0.5:
			animated_sprite_2d.flip_h = true
			animated_sprite_2d.play("idle_side")
		elif dir.x >= 0.5:
			animated_sprite_2d.flip_h = false
			animated_sprite_2d.play("idle_side")
		if dir.y >= 0.5:
			animated_sprite_2d.play("idle_down")
		elif dir.y <= -0.5:
			animated_sprite_2d.play("idle_up")
			
	if idle_task == IdleTasks.PATROL:
		if dir.x <= -0.5:
			animated_sprite_2d.flip_h = true
			animated_sprite_2d.play("walk_side")
		elif dir.x >= 0.5:
			animated_sprite_2d.flip_h = false
			animated_sprite_2d.play("walk_side")
		if dir.y >= 0.5:
			animated_sprite_2d.play("walk_down")
		elif dir.y <= -0.5:
			animated_sprite_2d.play("walk_up")
		
		set_vision_direction(dir)
		position += dir * speed * delta
	
		if global_position.distance_to(target) < 1:
			var wp = get_current_waypoint()
			if wp.wait_time > 0.0:
				await handle_waypoint_action(wp)
			current_index = (current_index + 1) % waypoints.size()
	
	update_alertness() # Initial update based on patrol/wait
	
	if player:
		var player_global_pos: Vector2 = player.global_position
		var player_in_sight = vision_manager.can_see_point(player_global_pos)
		was_player_seen = was_player_seen or player_in_sight

		# These will store the currently applicable delay/rate for logic and debug output
		var active_cooldown_delay: float = idle_cooldown_delay
		var active_cooldown_rate: float = idle_cooldown_rate

		# Handle alertness changes based on player visibility and state
		if player_in_sight:
			# Stop cooldown if player is seen
			is_in_cooldown = false
			cooldown_timer = 0.0
			
			# Different increase rates based on current state
			if alertness_value < suspicion_threshold:
				alertness_value = min(alertness_value + (initial_alertness_increase_rate * delta), 1.0)
			else:
				alertness_value = min(alertness_value + (alertness_increase_rate * delta), 1.0)
			
		else: # Player not in sight
			# If we've seen the player before and now don't see them, start cooldown timer
			if was_player_seen and !is_in_cooldown:
				cooldown_timer += delta
				
				# Determine which delay to use
				if alertness_state == AlertnessState.SUSPICIOUS:
					active_cooldown_delay = suspicious_cooldown_delay
				else:
					active_cooldown_delay = idle_cooldown_delay
				
				if cooldown_timer >= active_cooldown_delay:
					is_in_cooldown = true
					cooldown_timer = 0.0 # Reset timer as we are now in cooldown
			
			# Only decrease alertness if in cooldown mode
			if is_in_cooldown:
				# Determine which rate to use
				if alertness_value >= suspicion_threshold: # If still suspicious or cooling down from alerted
					active_cooldown_rate = suspicious_cooldown_rate
				else: # Cooling down below suspicious, towards idle
					active_cooldown_rate = idle_cooldown_rate
				
				alertness_value = max(alertness_value - (active_cooldown_rate * delta), 0.0)
				
				if alertness_value <= 0.0:
					alertness_value = 0.0
					was_player_seen = false
					is_in_cooldown = false
		
		# Update state based on alertness value changes from player interaction
		update_alertness()
		
		# Debug output
		var state_str = "IDLE"
		if alertness_value >= alertness_threshold:
			state_str = "ALERTED"
		elif alertness_value >= suspicion_threshold:
			state_str = "SUSPICIOUS"
		
		# Build cooldown status string
		var cooldown_status_text = "Cooldown: " + ("Active" if is_in_cooldown else "Inactive")
		if was_player_seen and !player_in_sight: # Only show timer details if relevant
			if !is_in_cooldown: # Show timer counting up to delay
				cooldown_status_text += ", Timer: %.1f/%.1f (Delay)" % [cooldown_timer, active_cooldown_delay]
			else: # Show that cooldown is active (decreasing alertness)
				cooldown_status_text += ", Rate: %.2f" % active_cooldown_rate
		
		# Create visual bar
		var bar = "[" + ("|" as String).repeat(int(alertness_value * 20)) \
			+ (" " as String).repeat(20 - int(alertness_value * 20)) \
			+ "] %3d%% %-10s (%s)" % [int(alertness_value * 100), state_str, cooldown_status_text]
		print("Alertness: ", bar)

func _process(_delta: float) -> void: # Renamed delta to _delta to address unused parameter warning
	# Update status bar position
	if is_instance_valid(status_bar_instance):
		var status_bar_pos: Vector2 = Vector2.ZERO

		# Center the status bar horizontally above the sprite
		# Assumes status_bar_instance's origin is top-left
		status_bar_pos.x = -status_bar_instance.size.x / 2.0

		# Position below the emote
		# This part requires knowing how your emote_node is structured and positioned.
		# Assuming emote_node.position.y is relative to the sentry,
		# and emote_node has a known height (e.g., from its texture or a bounding box).
		if is_instance_valid(emote_node) and emote_node.visible:
			# Assuming emote_node's Y position is its top, and it has a 'size' property (like Control nodes)
			# or a way to get its height.
			var emote_height: float = 0.0
			if emote_node.has_method("get_rect"): # For Control nodes
				emote_height = emote_node.get_rect().size.y * emote_node.scale.y
			elif emote_node is Sprite2D and emote_node.texture:
				emote_height = emote_node.texture.get_height() * emote_node.scale.y
			# Add other checks if emote_node is a different type

			# emote_node.position.y is where the emote's origin is.
			# If emote is above sentry, emote_node.position.y is negative.
			# The bottom of the emote would be emote_node.position.y + emote_height (if origin is top-left)
			# OR emote_node.position.y if origin is bottom-left and position.y is the bottom line.
			# Let's assume emote_node.position.y is the TOP of the emote relative to sentry.
			var emote_bottom_y: float = emote_node.position.y + emote_height
			status_bar_pos.y = emote_bottom_y + PADDING_BELOW_EMOTE
		elif is_instance_valid(animated_sprite_2d_ref_for_status_bar): # Fallback if emote_node is not valid/visible
			# Fallback: Position above the sprite if emote is not available
			# Assuming sprite's origin is its center, and sprite.texture gives its height.
			var sprite_top_y: float = 0.0
			if animated_sprite_2d_ref_for_status_bar.sprite_frames and animated_sprite_2d_ref_for_status_bar.animation:
				var current_anim_name: StringName = animated_sprite_2d_ref_for_status_bar.animation
				if animated_sprite_2d_ref_for_status_bar.sprite_frames.has_animation(current_anim_name):
					var frame_texture: Texture2D = animated_sprite_2d_ref_for_status_bar.sprite_frames.get_frame_texture(current_anim_name, animated_sprite_2d_ref_for_status_bar.frame)
					if frame_texture:
						sprite_top_y = -frame_texture.get_height() / 2.0 * animated_sprite_2d_ref_for_status_bar.scale.y
			status_bar_pos.y = sprite_top_y + STATUS_BAR_Y_OFFSET_FROM_SPRITE_TOP

		status_bar_instance.position = status_bar_pos
