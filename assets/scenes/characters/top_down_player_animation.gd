extends AnimatedSprite2D

var move_vec: Vector2
var last_move_vec: Vector2 = Vector2(0.0, 1.0)

func _process(_delta: float) -> void:
	match move_vec:
		Vector2(-1.0, 0.0):
			play("move_left")
			last_move_vec = Vector2(-1.0, 0.0)
		Vector2(1.0, 0.0):
			play("move_right")
			last_move_vec = Vector2(1.0, 0.0)
		Vector2(0.0, -1.0):
			play("move_up")
			last_move_vec = Vector2(0.0, -1.0)
		Vector2(0.0, 1.0):
			play("move_down")
			last_move_vec = Vector2(0.0, 1.0)
		Vector2(0.0, 0.0):
			match last_move_vec:
				Vector2(-1.0, 0.0):
					play("idle_left")
				Vector2(1.0, 0.0):
					play("idle_right")
				Vector2(0.0, -1.0):
					play("idle_up")
				Vector2(0.0, 1.0):
					play("idle_down")
			
