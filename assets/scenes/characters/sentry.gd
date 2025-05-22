extends Node2D

# Signals for player detection system
# signal player_detected(detector, detection_level) # Existing, commented out as new system doesn't emit yet (ID: 27ee0f31-4da0-4d7c-8d46-5e6f9fd1a8b8)
# signal player_detection_lost(detector) # Existing, commented out as new system doesn't emit yet (ID: 491641b9-3ee0-4761-9913-083f3b17a209)
signal player_fully_detected(sentry_node) # New signal for when DETECTED state is reached

var player: Node2D
@onready var vision_manager: VisionManager = $VisionManager
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var question_mark: Node2D = $Emotes/QuestionMark
@onready var exclamation: Node2D = $Emotes/Exclamation
@onready var emote_node: Node2D = $Emotes
@onready var animated_sprite_2d_ref_for_status_bar: AnimatedSprite2D = $AnimatedSprite2D

# Preload the status bar scene.
const STATUS_BAR_SCENE: PackedScene = preload("res://assets/scenes/ui/status_bar.tscn")
var status_bar_instance: StatusBar

# CONFIGURATION for status bar positioning
const STATUS_BAR_Y_OFFSET_FROM_SPRITE_TOP: float = -10.0
const PADDING_BELOW_EMOTE: float = 2.0

# --- NEW Alertness System Variables ---
enum SentryState { IDLE, SUSPICIOUS, ALERT, DETECTED }
@export var current_sentry_state: SentryState = SentryState.IDLE:
	set(new_state):
		if current_sentry_state != new_state:
			var old_state = current_sentry_state
			current_sentry_state = new_state
			_on_sentry_state_changed(old_state, new_state)

var suspicion_points: float = 0.0
var alert_points: float = 0.0
const MAX_METER_POINTS: float = 100.0

@export var suspicion_increase_rate: float = 25.0 # Points per second
@export var alert_increase_rate: float = 33.33    # Points per second

# --- Cooldowns --- 
@export var alert_decay_rate: float = 20.0
@export var suspicion_decay_rate: float = 10.0
@export var cooldown_start_delay: float = 2.0 # General delay before normal decay (SUSPICIOUS, ALERT)
var current_cooldown_delay_timer: float = 0.0

# DETECTED State Specific Cooldown
@export var detected_linger_duration: float = 5.0 # Seconds to stay in DETECTED after losing sight
var detected_linger_timer: float = 0.0

const ALERT_DURATION_AFTER_DETECTED: float = 30.0 # Fixed 30 seconds
var alert_after_detected_timer: float = 0.0
var is_in_alert_after_detected_cooldown: bool = false

var is_player_currently_visible: bool = false # This should be updated by VisionManager

# --- Pathing and Movement (largely from original) ---
@export var path_group_name: String = "Sentry1"
@onready var waypoints: Array = [] # Initialize empty, fill in _ready
var current_index: int = 0
var dir: Vector2

# Assuming IdleTasks is still relevant for patrol/wait logic not directly tied to alertness bar
enum IdleTasks {PATROL, WAIT, INSPECT, RETURN_TO_PATROL} 
@export var idle_task_state = IdleTasks.PATROL
var current_wait_timer: float = 0.0
var _has_waited_at_current_waypoint: bool = false # Flag to ensure wait happens once per visit

@export var speed: float = 10.0

# --- Helper Functions (largely from original) ---
func get_enum_name(enum_dict: Dictionary, value: int) -> String:
	for name in enum_dict.keys():
		if enum_dict[name] == value:
			return name
	return "Unknown"

func get_current_waypoint():
	if waypoints.is_empty() or current_index < 0 or current_index >= waypoints.size():
		return null
	return waypoints[current_index] as Marker2D
	
func handle_waypoint_action(waypoint_node: Node2D) -> void:
	# print_debug("Sentry: Reached waypoint: ", waypoint_node.name) # Temporarily commented for diagnosis
	# Check if the waypoint_node has a 'wait_time' property directly
	if waypoint_node.has_meta("wait_time") or "wait_time" in waypoint_node: # Check meta for editor-set, or direct property
		var wait_duration: float = waypoint_node.get("wait_time") if "wait_time" in waypoint_node else waypoint_node.get_meta("wait_time")
		# print_debug("Sentry: Waypoint ", waypoint_node.name, " has 'wait_time' variable. Duration: ", wait_duration)
		if wait_duration > 0 and not _has_waited_at_current_waypoint:
			idle_task_state = IdleTasks.WAIT
			current_wait_timer = wait_duration
			# print_debug("Sentry: ==> SETTING STATE TO WAIT. Timer: ", current_wait_timer)
		elif _has_waited_at_current_waypoint:
			# print_debug("Sentry: Waypoint ", waypoint_node.name, " already waited this visit. Resuming patrol.")
			idle_task_state = IdleTasks.PATROL # Ensure patrol state if already waited
		else: # wait_duration is 0 or less
			# print_debug("Sentry: Waypoint ", waypoint_node.name, " wait_duration is not > 0. Resuming patrol.")
			idle_task_state = IdleTasks.PATROL
	else:
		# print_debug("Sentry: Waypoint ", waypoint_node.name, " does NOT have 'wait_time' variable or meta. Resuming patrol.")
		# No wait time, or waypoint doesn't support it, continue patrolling
		idle_task_state = IdleTasks.PATROL

# --- Core Logic --- 
func _ready() -> void:
	var path_nodes = get_tree().get_nodes_in_group(path_group_name)
	if not path_nodes.is_empty():
		# Assuming the first node is the parent path, and its children are waypoints
		# Adjust if your path structure is different
		if path_nodes[0].get_child_count() > 0:
			waypoints = path_nodes[0].get_children()
		else:
			push_warning("Sentry: Path group '%s' found, but no waypoints (children) under the first node." % path_group_name)
	else:
		push_warning("Sentry: Path group '%s' not found or empty." % path_group_name)

	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		push_error("Sentry: Player node not found in group 'player'!")

	if STATUS_BAR_SCENE:
		status_bar_instance = STATUS_BAR_SCENE.instantiate() as StatusBar
		if status_bar_instance:
			add_child(status_bar_instance)
			# Initial state setup for status bar via current_sentry_state setter
			current_sentry_state = SentryState.IDLE # Trigger setter for initial UI update
			suspicion_points = 0
			alert_points = 0
			_update_layered_status_bar() # Explicit call to ensure it's set up
		else:
			push_error("Sentry: Failed to instantiate STATUS_BAR_SCENE!")
	else:
		push_error("Sentry: STATUS_BAR_SCENE is null! Preload likely failed.")

	# Connect VisionManager signals here if they exist
	# Example: vision_manager.player_visibility_changed.connect(_on_player_visibility_changed)

func _physics_process(delta: float) -> void:
	_process_detection(delta) # Handle alertness logic
	_process_movement(delta)   # Handle movement logic
	_process_animations()      # Handle animation updates

func _process(_delta: float) -> void:
	_update_status_bar_positioning()

func _process_movement(delta: float) -> void:
	if current_sentry_state == SentryState.DETECTED or current_sentry_state == SentryState.ALERT:
		# Potentially chase player or move to last known position
		# For now, let's assume it stops or has specific alert movement
		if is_instance_valid(player):
			dir = (player.global_position - global_position).normalized()
			# Add chase logic or look at player logic here
		return # Override patrol/idle movement when alert/detected

	if idle_task_state == IdleTasks.PATROL and not waypoints.is_empty():
		var wp_node = get_current_waypoint()
		if not is_instance_valid(wp_node):
			# print_debug("Invalid waypoint, resetting patrol or stopping.")
			return
		var target_pos = wp_node.global_position
		dir = (target_pos - global_position).normalized()
		global_position += dir * speed * delta
		if is_instance_valid(vision_manager):
			# vision_manager.front_direction = dir # This was incorrect as front_direction is an enum
			# If vision_manager.front_direction is DIRECTIONS.LEFT (meaning -X is forward),
			# we want -X to align with 'dir'. So, +X should align with 'dir.rotated(PI)'.
			# The node's rotation sets the orientation of its +X axis.
			if vision_manager.front_direction == vision_manager.DIRECTIONS.LEFT:
				vision_manager.rotation = dir.angle() + PI
			elif vision_manager.front_direction == vision_manager.DIRECTIONS.RIGHT:
				vision_manager.rotation = dir.angle()
			elif vision_manager.front_direction == vision_manager.DIRECTIONS.DOWN:
				vision_manager.rotation = dir.angle() - PI/2 # or +3PI/2
			elif vision_manager.front_direction == vision_manager.DIRECTIONS.UP:
				vision_manager.rotation = dir.angle() + PI/2 # or -3PI/2
			# Fallback or if front_direction is not one of the above, assume it's aligned with how dir.angle() works (like RIGHT)
			# else: 
			# vision_manager.rotation = dir.angle() # Default if unsure, might need adjustment

		if global_position.distance_to(target_pos) < 1.0: # Threshold for reaching waypoint
			handle_waypoint_action(wp_node)
			# Only advance to the next waypoint if we are not currently set to WAIT
			if idle_task_state != IdleTasks.WAIT:
				current_index = (current_index + 1) % waypoints.size()
				_has_waited_at_current_waypoint = false # Reset flag for the new waypoint
				# print_debug("Sentry: Advanced to next waypoint index: ", current_index, ". Reset has_waited flag.")
	elif idle_task_state == IdleTasks.WAIT:
		# Standing still, maybe look around or specific idle animation
		# The actual waiting timer is handled in _process_detection
		pass
	elif idle_task_state == IdleTasks.INSPECT:
		# Go to a point of interest or look around
		pass

func _process_animations() -> void:
	if not is_instance_valid(animated_sprite_2d):
		return
	
	var animation_to_play = "idle_down" # Default
	var flip = false

	if dir.x < -0.1:
		flip = true
		animation_to_play = "walk_side" if idle_task_state == IdleTasks.PATROL else "idle_side"
	elif dir.x > 0.1:
		flip = false
		animation_to_play = "walk_side" if idle_task_state == IdleTasks.PATROL else "idle_side"
	elif dir.y < -0.1:
		animation_to_play = "walk_up" if idle_task_state == IdleTasks.PATROL else "idle_up"
	elif dir.y > 0.1:
		animation_to_play = "walk_down" if idle_task_state == IdleTasks.PATROL else "idle_down"
	else: # No significant direction, play idle based on current animation or default
		if animated_sprite_2d.animation.begins_with("walk"):
			animation_to_play = animated_sprite_2d.animation.replace("walk", "idle")
		else:
			animation_to_play = animated_sprite_2d.animation # Keep current idle if no dir

	animated_sprite_2d.flip_h = flip
	if animated_sprite_2d.animation != animation_to_play:
		animated_sprite_2d.play(animation_to_play)


func _on_sentry_state_changed(_old_state: SentryState, new_state: SentryState) -> void:
	# print_debug("Sentry state: %s -> %s" % [SentryState.find_key(_old_state), SentryState.find_key(new_state)]) # Temporarily commented for diagnosis
	match new_state:
		SentryState.IDLE:
			question_mark.visible = false
			exclamation.visible = false
			idle_task_state = IdleTasks.PATROL
		SentryState.SUSPICIOUS:
			question_mark.visible = true
			exclamation.visible = false
			# idle_task_state = IdleTasks.INSPECT # Or some other behavior
		SentryState.ALERT:
			question_mark.visible = false
			exclamation.visible = true
			# idle_task_state = IdleTasks.INSPECT # Or chase behavior starts
		SentryState.DETECTED:
			question_mark.visible = false
			exclamation.visible = true # Could be a different emote for fully detected
			emit_signal("player_fully_detected", self)
			# Override movement to chase or engage

	_update_layered_status_bar()

func _update_layered_status_bar() -> void:
	if not is_instance_valid(status_bar_instance):
		printerr("Sentry: status_bar_instance is not valid in _update_layered_status_bar!")
		return
	# print_debug("Sentry _update_layered_status_bar: Sending to StatusBar: State=", SentryState.find_key(current_sentry_state), " Susp=", suspicion_points, " Alert=", alert_points) # Commented out: Too frequent

	var bar_state_to_pass: StatusBar.BarState
	match current_sentry_state:
		SentryState.IDLE: bar_state_to_pass = StatusBar.BarState.IDLE
		SentryState.SUSPICIOUS: bar_state_to_pass = StatusBar.BarState.SUSPICIOUS
		SentryState.ALERT: bar_state_to_pass = StatusBar.BarState.ALERT
		SentryState.DETECTED: bar_state_to_pass = StatusBar.BarState.DETECTED
		_: 
			bar_state_to_pass = StatusBar.BarState.IDLE
			push_error("Sentry: Unknown current_sentry_state in _update_layered_status_bar!")
	
	status_bar_instance.set_meter_state(bar_state_to_pass, suspicion_points, alert_points)

func _process_detection(delta: float) -> void:
	# print_debug("Sentry _process_detection: Player visible = ", is_player_currently_visible, ", State = ", SentryState.find_key(current_sentry_state)) # General, can be spammy

	var previous_state = current_sentry_state

	if is_player_currently_visible:
		# print_debug("Sentry _process_detection: Player IS VISIBLE. Current Susp: ", suspicion_points, " Alert: ", alert_points, " State: ", SentryState.find_key(current_sentry_state)) # Commented out: Too frequent
		# Reset cooldown delay timer since player is visible
		current_cooldown_delay_timer = 0.0
		detected_linger_timer = -1 # Stop linger timer if player re-sighted
		# Increase suspicion points
		suspicion_points = clampf(suspicion_points + suspicion_increase_rate * delta, 0.0, MAX_METER_POINTS)
		# If suspicion points are full, increase alert points
		if suspicion_points >= MAX_METER_POINTS:
			alert_points = clampf(alert_points + alert_increase_rate * delta, 0.0, MAX_METER_POINTS)
			# Transition to ALERT
			if current_sentry_state != SentryState.ALERT and current_sentry_state != SentryState.DETECTED:
				current_sentry_state = SentryState.ALERT
			# If alert points are full, transition to DETECTED
			if alert_points >= MAX_METER_POINTS:
				if current_sentry_state != SentryState.DETECTED:
					current_sentry_state = SentryState.DETECTED
		# If not yet alert, check for SUSPICIOUS state
		elif suspicion_points > 0:
			if current_sentry_state == SentryState.IDLE:
				current_sentry_state = SentryState.SUSPICIOUS
	else: # Player is NOT visible
		# print_debug("Sentry _process_detection: Player NOT VISIBLE.")
		# Handle DETECTED linger state first
		if current_sentry_state == SentryState.DETECTED:
			if detected_linger_timer < detected_linger_duration:
				detected_linger_timer += delta
			else:
				# Transition from DETECTED to ALERT (cooldown part 1)
				current_sentry_state = SentryState.ALERT
				alert_points = MAX_METER_POINTS # Keep alert bar full
				suspicion_points = MAX_METER_POINTS # Keep suspicion bar full
				alert_after_detected_timer = 0.0 # Start the 30s ALERT timer
				is_in_alert_after_detected_cooldown = true
		# Handle ALERT state (specifically the 30s cooldown after DETECTED)
		elif current_sentry_state == SentryState.ALERT and is_in_alert_after_detected_cooldown:
			if alert_after_detected_timer < ALERT_DURATION_AFTER_DETECTED:
				alert_after_detected_timer += delta
				alert_points = MAX_METER_POINTS # Keep full during this phase
				suspicion_points = MAX_METER_POINTS
			else:
				# Cooldown from ALERT (after DETECTED) to IDLE is complete
				current_sentry_state = SentryState.IDLE
				suspicion_points = 0
				alert_points = 0
				is_in_alert_after_detected_cooldown = false
		# Handle normal cooldown (not from detected linger)
		elif current_sentry_state == SentryState.ALERT:
			current_cooldown_delay_timer += delta
			if current_cooldown_delay_timer >= cooldown_start_delay:
				alert_points = max(0, alert_points - alert_decay_rate * delta)
				if alert_points == 0 and current_sentry_state == SentryState.ALERT:
					current_sentry_state = SentryState.SUSPICIOUS # Drop to suspicious
				# Decay suspicion points only if not in ALERT or if alert points are zero
				# (Suspicion bar stays full during ALERT until alert points deplete)
				if current_sentry_state == SentryState.SUSPICIOUS:
					suspicion_points = max(0, suspicion_points - suspicion_decay_rate * delta)
					if suspicion_points == 0:
						current_sentry_state = SentryState.IDLE
		elif current_sentry_state == SentryState.SUSPICIOUS:
			current_cooldown_delay_timer += delta
			if current_cooldown_delay_timer >= cooldown_start_delay:
				suspicion_points = max(0, suspicion_points - suspicion_decay_rate * delta)
				if suspicion_points == 0:
					current_sentry_state = SentryState.IDLE
		elif current_sentry_state == SentryState.IDLE:
			suspicion_points = 0
			alert_points = 0
			current_cooldown_delay_timer = 0.0 # Reset timers
			detected_linger_timer = 0.0
			alert_after_detected_timer = 0.0
			is_in_alert_after_detected_cooldown = false

	# If state changed, call the handler
	if previous_state != current_sentry_state:
		_on_sentry_state_changed(previous_state, current_sentry_state)

	# Handle Idle Task Timers (like waypoint waiting)
	if idle_task_state == IdleTasks.WAIT:
		current_wait_timer -= delta
		# print_debug("Sentry: Waiting at waypoint. Timer: ", current_wait_timer) # Can be too spammy
		if current_wait_timer <= 0:
			idle_task_state = IdleTasks.PATROL # Resume patrol
			current_wait_timer = 0
			_has_waited_at_current_waypoint = true # Mark that we've waited at this waypoint for this visit
			# print_debug("Sentry: ==> Wait timer FINISHED at waypoint. Resuming patrol. Has waited flag SET.")
		else:
			# print_debug("Sentry: Still waiting at waypoint. Skipping detection/cooldown.") # Also spammy
			return # Still waiting, skip other detection/cooldown logic for this frame

func _update_status_bar_positioning() -> void:
	if not is_instance_valid(status_bar_instance) or not is_instance_valid(animated_sprite_2d_ref_for_status_bar):
		return

	# Calculate base X position (center of the sprite)
	var base_x_pos: float = animated_sprite_2d_ref_for_status_bar.global_position.x

	# Calculate Y position for status bar
	var y_pos: float
	var sprite_frame_tex = animated_sprite_2d_ref_for_status_bar.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	if not sprite_frame_tex:
		return # Cannot get texture, abort positioning
	
	var sprite_top_global_y: float = animated_sprite_2d_ref_for_status_bar.global_position.y - \
							 (sprite_frame_tex.get_height() / 2.0) * animated_sprite_2d_ref_for_status_bar.global_scale.y

	if emote_node.visible and (question_mark.visible or exclamation.visible):
		# Position below the emote node (assuming emote_node's global_position.y is its top)
		# This requires emote_node to have a predictable height or its origin at its bottom for PADDING_BELOW_EMOTE to work as intended.
		# A more robust way would be to get the emote's actual bounding box bottom.
		# For now, using emote_node.global_position.y as a reference point. If it's the center, adjust PADDING.
		y_pos = emote_node.global_position.y + PADDING_BELOW_EMOTE # This might need adjustment based on emote's origin
	else:
		y_pos = sprite_top_global_y + STATUS_BAR_Y_OFFSET_FROM_SPRITE_TOP

	status_bar_instance.global_position = Vector2(base_x_pos, y_pos)
	# Ensure it's not rotated with the parent Sentry (Node2D)
	# Control nodes use 'rotation' (radians) or 'rotation_degrees'
	# To counteract parent's global_rotation, set local rotation to its negative.
	status_bar_instance.rotation = -global_rotation 


# --- Player Visibility Update --- 
# This function should be called by your VisionManager or detection system
func set_player_visibility(p_is_player_seen: bool) -> void: # Renamed parameter
	is_player_currently_visible = p_is_player_seen # Use renamed parameter
	# print_debug("Sentry: set_player_visibility called with: ", p_is_player_seen, ". Current state: ", SentryState.find_key(current_sentry_state)) # Temporarily commented for diagnosis

	if not p_is_player_seen: # Use renamed parameter
		# Player just lost from sight, reset general cooldown delay timer to start counting now
		# Specific timers like detected_linger_timer are handled in _process_detection
		current_cooldown_delay_timer = 0.0
		
		# If player was DETECTED and is now lost, start the detected_linger_timer
		if current_sentry_state == SentryState.DETECTED:
			detected_linger_timer = 0.0 # Reset and start counting in _process_detection
	else:
		# Player just became visible
		# Reset cooldown timers as progression will now happen
		current_cooldown_delay_timer = 0.0
		detected_linger_timer = 0.0
		alert_after_detected_timer = 0.0
		# If was in special alert cooldown, player being seen cancels it.
		is_in_alert_after_detected_cooldown = false 

# --- VisionManager Callbacks (if VisionManager uses signals instead of direct calls) ---
# func _on_vision_manager_target_sighted(target: Node2D) -> void:
# 	set_player_visibility(true)
#
# func _on_vision_manager_target_lost_sight(target: Node2D) -> void:
# 	set_player_visibility(false)
