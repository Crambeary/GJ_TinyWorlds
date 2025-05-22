extends Node
class_name PlayerDetectionHandler

## Handles detection indicators when player is being seen by enemies
## Displays a hitman-like arrow pointing toward detecting enemies

# Dictionary to track all entities currently detecting the player
# Key: entity node, Value: detection level (0.0 to 1.0)
var detecting_entities: Dictionary = {}
# References to active detection arrows keyed by detecting entity
var active_arrows: Dictionary = {}

# Arrow scene reference
const DETECTION_ARROW_SCENE: PackedScene = preload("res://assets/scenes/ui/detection_arrow.tscn")

func _ready() -> void:
	# Connect to all existing sentries in the scene
	_connect_to_sentries()
	
	# Also connect to sentries that might be added later
	get_tree().node_added.connect(_on_node_added)

## Process detection by multiple entities and update arrows accordingly
func _process(_delta: float) -> void:
	# Update positions and detection levels for all active arrows
	for entity in detecting_entities.keys():
		if is_instance_valid(entity) and active_arrows.has(entity):
			var detection_level = detecting_entities[entity]
			var arrow = active_arrows[entity]
			arrow.update_detection_level(detection_level)

## Called when a new sentry detects the player
func _on_sentry_detected(detector, detection_level: float) -> void:
	if not is_instance_valid(detector):
		return
		
	# Store/update the detection level
	detecting_entities[detector] = detection_level
	
	# Create arrow if it doesn't exist yet
	if not active_arrows.has(detector):
		var new_arrow = DETECTION_ARROW_SCENE.instantiate()
		add_child(new_arrow)
		active_arrows[detector] = new_arrow
		new_arrow.start_detection(detector, detection_level)

## Called when a sentry loses sight of the player
func _on_sentry_detection_lost(detector) -> void:
	if not is_instance_valid(detector):
		return
		
	# Remove from detecting entities
	detecting_entities.erase(detector)
	
	# Force the arrow to show detection level of 0 to make it disappear immediately
	if active_arrows.has(detector):
		# First set detection level to 0 which should trigger immediate disappearance
		active_arrows[detector].update_detection_level(0.0)
		active_arrows[detector].stop_detection()
		
		# Connect to detection_ended to clean up when fully faded
		if not active_arrows[detector].detection_ended.is_connected(_on_arrow_detection_ended):
			active_arrows[detector].detection_ended.connect(_on_arrow_detection_ended.bind(detector))

## Called when an arrow has fully faded out
func _on_arrow_detection_ended(detector) -> void:
	if active_arrows.has(detector):
		var arrow = active_arrows[detector]
		active_arrows.erase(detector)
		arrow.queue_free()

## Connect to any existing sentries in the scene
func _connect_to_sentries() -> void:
	var sentries = get_tree().get_nodes_in_group("sentry")
	for sentry in sentries:
		_connect_sentry_signals(sentry)

## Connect to signals of a specific sentry
func _connect_sentry_signals(sentry: Node) -> void:
	if sentry.has_signal("player_detected") and not sentry.player_detected.is_connected(_on_sentry_detected):
		sentry.player_detected.connect(_on_sentry_detected)
	
	if sentry.has_signal("player_detection_lost") and not sentry.player_detection_lost.is_connected(_on_sentry_detection_lost):
		sentry.player_detection_lost.connect(_on_sentry_detection_lost)

## Check if newly added nodes are sentries and connect to them
func _on_node_added(node: Node) -> void:
	if node.is_in_group("sentry"):
		# Give a small delay for the node to be fully initialized
		await get_tree().process_frame
		_connect_sentry_signals(node)
