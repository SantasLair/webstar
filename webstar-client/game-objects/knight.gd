extends CharacterBody2D

@export var speed := 100

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _process(_delta: float) -> void:
	if !is_multiplayer_authority(): return
	
	if velocity.x < 0:
		$AnimatedSprite2D.flip_h = true  # Face left
	elif velocity.x > 0:
		$AnimatedSprite2D.flip_h = false # Face right

	if velocity != Vector2.ZERO:
		$AnimatedSprite2D.play("run")
		move_and_slide()
	else:
		$AnimatedSprite2D.play("idle")


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("left", "right", "up", "down")
	velocity = input_vector * speed
