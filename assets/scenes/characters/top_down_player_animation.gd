extends AnimatedSprite2D

var move_vec: Vector2

func _process(delta: float) -> void:
	match move_vec:
		Vector2(-1.0, 0.0):
			play("move_left")
		Vector2(1.0, 0.0):
			play("move_right")
		Vector2(0.0, -1.0):
			play("move_up")
		Vector2(0.0, 1.0):
			play("move_down")
	#play("idle_down")
			
