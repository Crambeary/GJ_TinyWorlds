extends Node2D

var player: Node2D
@onready var vision_manager: VisionManager = $VisionManager
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var question_mark: Node2D = $Emotes/QuestionMark
@onready var exclamation: Node2D = $Emotes/Exclamation


@export var path_group_name: String = "Sentry1"
@onready var waypoints: Array = get_tree().get_first_node_in_group(path_group_name).get_children()
var current_index: int = 0
var dir: Vector2
enum IdleTasks {PATROL, WAIT, INSPECT, RETURN}
enum AlertnessState {IDLE, SUSPICIOUS, ALERTED}
@export var idle_task = IdleTasks.PATROL
@export var alertness_state = AlertnessState.IDLE
# Alertness ranges from 0.0 (completely calm) to 1.0 (fully alerted)
@export_range(0.0, 1.0, 0.01) var alertness_value: float = 0.0

# Thresholds as percentages (0.0-1.0)
@export_range(0.0, 1.0, 0.05) var suspicion_threshold: float = 0.3
@export_range(0.0, 1.0, 0.05) var alertness_threshold: float = 0.7

# Rate of change per second
@export var initial_alertness_increase_rate: float = 0.2  # Slow initial increase
@export var alertness_increase_rate: float = 0.5          # Faster increase once suspicious/alerted
@export var cooldown_delay: float = 2.0                   # Seconds before cooldown starts
@export var cooldown_rate: float = 0.1                   # Rate of cooldown after delay

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
	player = get_tree().get_first_node_in_group("player")

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
	
	update_alertness()
	
	if player:
		var player_global_pos: Vector2 = player.global_position
		var player_in_sight = vision_manager.can_see_point(player_global_pos)
		was_player_seen = was_player_seen or player_in_sight

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
			
		else:
			# If we've seen the player before and now don't see them, start cooldown timer
			if was_player_seen and !is_in_cooldown:
				cooldown_timer += delta
				if cooldown_timer >= cooldown_delay:
					is_in_cooldown = true
					cooldown_timer = 0.0
			
			# Only decrease alertness if in cooldown mode
			if is_in_cooldown:
				alertness_value = max(alertness_value - (cooldown_rate * delta), 0.0)
				if alertness_value <= 0.0:
					alertness_value = 0.0
					was_player_seen = false
					is_in_cooldown = false
		
		# Update state based on alertness
		update_alertness()
		
		# Debug output
		var state = "IDLE"
		if alertness_value >= alertness_threshold:
			state = "ALERTED"
		elif alertness_value >= suspicion_threshold:
			state = "SUSPICIOUS"
		
		# Build cooldown status string
		var cooldown_status = "Cooldown: " + ("Active" if is_in_cooldown else "Inactive")
		if was_player_seen:
			cooldown_status += ", Timer: %.1f/%.1f" % [cooldown_timer, cooldown_delay]
		
		# Create visual bar
		var bar = "[" + ("|" as String).repeat(int(alertness_value * 20)) \
			+ (" " as String).repeat(20 - int(alertness_value * 20)) \
			+ "] %3d%% %-10s (%s)" % [int(alertness_value * 100), state, cooldown_status]
		print("Alertness: ", bar)
