extends Node2D

var player: Node2D
@onready var vision_manager: VisionManager = $VisionManager
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


@export var path_group_name: String = "Priest1"
@onready var waypoints: Array = get_tree().get_first_node_in_group(path_group_name).get_children()
var current_index: int = 0
enum STATE {PATROL, WAIT, CHASE, RETURN}
@export var current_state = STATE.PATROL

@export var speed: float = 10.0

func get_current_waypoint():
	return waypoints[current_index] as Marker2D
	
func handle_waypoint_action(wp):
	match wp.action:
		"wait":
			print("waiting for ", wp.wait_time, " seconds")
			current_state = STATE.WAIT
			await get_tree().create_timer(wp.wait_time, false).timeout
			current_state = STATE.PATROL
		_:
			pass
	
func set_vision_direction(direction: Vector2) -> void:
	direction = direction * -1 # Invert Vector2 Values
	vision_manager.rotation = direction.angle()
	
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	var target = get_current_waypoint().global_position
	var dir: Vector2 = (target - global_position).normalized()
	if dir.x <= 0:
		animated_sprite_2d.flip_h = true
	else:
		animated_sprite_2d.flip_h = false
		
	if current_state == STATE.PATROL:
		set_vision_direction(dir)
		position += dir * speed * delta
	
		if global_position.distance_to(target) < 1:
			var wp = get_current_waypoint()
			if wp.wait_time > 0.0:
				await handle_waypoint_action(wp)
			current_index = (current_index + 1) % waypoints.size()
	
	
	if player:
		var player_global_pos: Vector2 = player.global_position
		var player_in_sight = vision_manager.can_see_point(player_global_pos)
		if player_in_sight:
			print("See Player")
