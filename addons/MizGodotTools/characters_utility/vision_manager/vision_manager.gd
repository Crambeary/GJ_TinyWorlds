class_name VisionManager extends Node2D

@onready var ray_cast_2d = $RayCast2D

@export var sentry_character: Node2D # Assign the Sentry character node here
@export var target_node: Node2D      # Assign the Player node (or other target) here

@export var cant_see_past_dist = 500.0
@export var always_see_within_dist = 100.0
@export var sight_arc = 60.0 # in degrees

enum DIRECTIONS {RIGHT, DOWN, LEFT, UP}
@export var front_direction = DIRECTIONS.LEFT #which way does this character face by default

@export var debug_view = false
var did_los_check = false # used for debug view

var _is_target_currently_visible: bool = false

signal target_sighted(target: Node2D)
signal target_lost_sight(target: Node2D)

func _ready() -> void:
	if not is_instance_valid(sentry_character):
		push_warning("VisionManager: 'sentry_character' not assigned. Cannot update Sentry visibility.")
	elif not sentry_character.has_method("set_player_visibility"):
		push_warning("VisionManager: Assigned 'sentry_character' does not have a 'set_player_visibility' method.")

	# Try to auto-assign target_node if not already set in editor
	if not is_instance_valid(target_node):
		print_debug("VisionManager: 'target_node' not assigned in editor. Attempting to find node in group 'player'.")
		var players_in_scene = get_tree().get_nodes_in_group("player")
		if not players_in_scene.is_empty():
			target_node = players_in_scene[0] # Assign the first player found
			print_debug("VisionManager: Automatically assigned 'target_node' to: ", target_node.name)
		else:
			push_warning("VisionManager: 'target_node' not assigned and no node found in group 'player'. Vision checks will not occur.")
	elif not is_instance_valid(target_node):
		# This case should ideally not be hit if the above logic works, but as a fallback:
		push_warning("VisionManager: 'target_node' is invalid after attempt to assign. Vision checks will not occur.")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target_node):
		# If target was visible but now is invalid (e.g., freed)
		if _is_target_currently_visible:
			_is_target_currently_visible = false
			print("VisionManager: Target became invalid, was visible. Informing Sentry.")
			if is_instance_valid(sentry_character) and sentry_character.has_method("set_player_visibility"):
				sentry_character.set_player_visibility(false)
			emit_signal("target_lost_sight", null) # Pass null or a placeholder if target_node is gone
		return

	var can_see_now: bool = can_see_point(target_node.global_position)

	if can_see_now and not _is_target_currently_visible:
		_is_target_currently_visible = true
		print("VisionManager: Target SIGHTED. Informing Sentry.")
		if is_instance_valid(sentry_character) and sentry_character.has_method("set_player_visibility"):
			print("VisionManager: Calling sentry.set_player_visibility(true)")
			sentry_character.set_player_visibility(true)
		emit_signal("target_sighted", target_node)
	elif not can_see_now and _is_target_currently_visible:
		_is_target_currently_visible = false
		print("VisionManager: Target LOST. Informing Sentry.")
		if is_instance_valid(sentry_character) and sentry_character.has_method("set_player_visibility"):
			print("VisionManager: Calling sentry.set_player_visibility(false)")
			sentry_character.set_player_visibility(false)
		emit_signal("target_lost_sight", target_node)

func can_see_point(point: Vector2):
	did_los_check = false
	queue_redraw()
	
	if point_outside_max_sight_range(point):
		return false
	
	if !has_los_to_point(point):
		return false
	
	var dist_to_point = global_position.distance_squared_to(point)
	if dist_to_point < always_see_within_dist * always_see_within_dist:
		return true
	
	var dir_to_point = point - global_position
	var angle = get_forward_vector().angle_to(dir_to_point)
	if abs(rad_to_deg(angle)) > sight_arc/2.0:
		return false
	return true

func get_forward_vector() -> Vector2:
	match front_direction:
		DIRECTIONS.RIGHT:
			return global_transform.x
		DIRECTIONS.LEFT:
			return -global_transform.x
		DIRECTIONS.DOWN:
			return global_transform.y
	return -global_transform.y # up

func get_local_forward_vector() -> Vector2:
	match front_direction:
		DIRECTIONS.RIGHT:
			return Vector2.RIGHT
		DIRECTIONS.LEFT:
			return Vector2.LEFT
		DIRECTIONS.DOWN:
			return Vector2.DOWN
	return Vector2.UP

func point_outside_max_sight_range(point: Vector2):
	var dist_to_point = global_position.distance_squared_to(point)
	return dist_to_point > cant_see_past_dist * cant_see_past_dist

func has_los_to_point(point: Vector2):
	did_los_check = true
	ray_cast_2d.enabled = true
	ray_cast_2d.target_position = ray_cast_2d.to_local(point)
	ray_cast_2d.force_raycast_update()
	var has_los = !ray_cast_2d.is_colliding()
	if !debug_view: # have to leave enabled to get collision point in debug
		ray_cast_2d.enabled = false
	return has_los

func _draw():
	var half_arc = deg_to_rad(sight_arc) / 2.0
	var fwd = get_local_forward_vector()
	if !debug_view:
		# Draw solid cone for normal view
		var points = PackedVector2Array()
		points.append(Vector2.ZERO)  # Center point
		var point_count = max(8, sight_arc / 10)  # Adjust point count based on arc size
		for i in point_count + 1:
			var angle = lerp(-half_arc, half_arc, float(i) / point_count) + PI  # Add 180 degrees (PI radians)
			points.append(Vector2(cos(angle), sin(angle)) * 15)
		draw_polygon(points, [Color(1, 1, 1, 0.3)])  # Semi-transparent white
		return
	draw_circle(Vector2.ZERO, always_see_within_dist, Color.GREEN, false, 1)
	draw_circle(Vector2.ZERO, cant_see_past_dist, Color.RED, false, 1)
	draw_line(Vector2.ZERO, fwd.rotated( half_arc)*cant_see_past_dist, Color.YELLOW)
	draw_line(Vector2.ZERO, fwd.rotated(-half_arc)*cant_see_past_dist, Color.YELLOW)
	draw_arc(Vector2.ZERO, cant_see_past_dist, fwd.angle() + half_arc, fwd.angle() - half_arc, 10, Color.YELLOW, 1)
	
	var end_pos = ray_cast_2d.to_global(ray_cast_2d.target_position)
	if ray_cast_2d.is_colliding():
		end_pos = ray_cast_2d.get_collision_point()
	if did_los_check:
		draw_line(Vector2.ZERO, to_local(end_pos), Color.LIGHT_BLUE, 1)
