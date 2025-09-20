extends CharacterBody2D

@export var speed := 100

@export var my_velocity := Vector2(0., 0.):
	set(velo):
		velocity = velo  # to set mine
		my_velocity = velo  # to set theirs
	

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	if is_multiplayer_authority():
		position = Vector2(60 * (name.to_int()), 70)
		

func _process(_delta: float) -> void:
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
	if !is_multiplayer_authority(): return	
	var input_vector := Input.get_vector("left", "right", "up", "down")
	velocity = input_vector * speed
	my_velocity = velocity
