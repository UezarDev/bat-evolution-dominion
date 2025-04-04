class_name Enemy
extends CharacterBody2D

# Preload the PopUpLabel class

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hit_area: Area2D = $Area2D  # An Area2D node for collision detection
@onready var pop_up_label: PackedScene = preload("res://Components/pop_up_label.tscn")

@export var companionship: int = 3
@export var detection_radius: float = 300.0  # How far an enemy can spot bats
@export var attack_speed: float = 1.0        # Time between attacks
@export var group: String = "flies"          # Group for this enemy type
@export var health: int = 3                  # Enemy's starting health
@export var damage: int = 1                  # Enemy's damage
@export var speed: float = 110               # Enemy's normal speed
@export var recovery_time: float = 2.0       # Duration of the hurt status in seconds

# Constants for path adjustment when stuck in a corner.
const MIN_PATH_DISTANCE: float = 30.0   # Minimum acceptable distance to next_path position
const BOUNCE_DISTANCE: float = 150.0    # How far away a bounce should ideally be
const LOCK_DURATION: float = 0.5        # How long to lock the new direction (in seconds)

# States: 0 = normal, 1 = stuck/bouncing, 2 = locked (move straight for a while)
var path_state: int = 0
var lock_timer: float = 0.0

# Timer for attack cooldown
var attack_timer: Timer = Timer.new()
var hurt_timer: Timer = Timer.new()  # Timer for the hurt status
var bats_in_area: Array = []

# Variables for hurt status
var is_hurt: bool = false
var original_speed: float = 0.0

func _ready() -> void:
	add_to_group(group)
	add_to_group("enemies")
	nav_agent.navigation_finished.connect(_on_nav_finished)
	make_path(Vector2(randf_range(0, get_viewport_rect().size.x), 
					  randf_range(0, get_viewport_rect().size.y)))
	
	hit_area.body_entered.connect(_on_body_entered)
	hit_area.body_exited.connect(_on_body_exited)
	set_meta("damage", damage)

	# Add and configure the attack timer
	attack_timer.wait_time = attack_speed
	attack_timer.one_shot = false
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	add_child(attack_timer)
	attack_timer.start()

	# Add and configure the hurt timer
	hurt_timer.wait_time = recovery_time
	hurt_timer.one_shot = true
	hurt_timer.connect("timeout", Callable(self, "_on_hurt_timer_timeout"))
	add_child(hurt_timer)

	# Store the original speed
	original_speed = speed

func _physics_process(delta: float) -> void:
# --- Path Adjustment State Machine ---
	# Get the next path point from the navigation agent.
	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var dist_to_next: float = global_position.distance_to(next_path_pos)

	# Check for nearby bats.
	var target_bat: Bat = detect_bats()
	if target_bat:
		# Compare the bat's health with our own.
		if target_bat.health > health:
			# Bat is stronger: run away.
			var run_dir: Vector2 = (global_position - target_bat.global_position).normalized()
			nav_agent.target_position = global_position + run_dir * detection_radius * 1.5
		else:
			# Bat is weaker: pursue the bat.
			nav_agent.target_position = target_bat.global_position

			# If chasing a bat, ignore the bounce logic.
			var direction: Vector2 = global_position.direction_to(next_path_pos)
			velocity = direction * speed
			if velocity.length() > 0:
				rotation = lerp_angle(rotation, velocity.angle(), delta * 2.0)
			move_and_slide()
			return

	# If we are in the "stuck" state, repeatedly try bouncing until the path is long enough.
	if path_state == 1:
		if dist_to_next < MIN_PATH_DISTANCE:
			# Still too short: bounce off in a random direction.
			var random_offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * BOUNCE_DISTANCE
			nav_agent.target_position = global_position + random_offset
			velocity = Vector2.ZERO
			move_and_slide()
			return
		else:
			# Path is now long enough: switch to locked state.
			path_state = 2
			lock_timer = LOCK_DURATION

	# In locked state, ignore bat detection and simply count down.
	if path_state == 2:
		lock_timer -= delta
		# If still locked, wait until lock timer expires.
		if lock_timer > 0:
			# Continue moving along current direction.
			var direction: Vector2 = global_position.direction_to(next_path_pos)
			velocity = direction * speed
			if velocity.length() > 0:
				rotation = lerp_angle(rotation, velocity.angle(), delta * 2.0)
			move_and_slide()
			return
		else:
			# Lock expired: return to normal state.
			path_state = 0

	# --- Normal Behavior (state 0) ---
	# No bat detected: adjust path with neighbors.
	adjust_path_with_neighbors()

	# Update the next path position and check its distance.
	next_path_pos = nav_agent.get_next_path_position()
	dist_to_next = global_position.distance_to(next_path_pos)

	# If the next path point is too close, switch to stuck state (state 1) and try a bounce.
	if dist_to_next < MIN_PATH_DISTANCE:
		var random_offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * BOUNCE_DISTANCE
		nav_agent.target_position = global_position + random_offset
		path_state = 1
		velocity = Vector2.ZERO
		move_and_slide()
		return


# If path is acceptable, proceed with normal movement.
	var direction: Vector2 = global_position.direction_to(next_path_pos)
	velocity = direction * speed
	if velocity.length() > 0:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 2.0)

	move_and_slide()

func _on_nav_finished() -> void:
	# If no bat is detected, resume wandering.
	if detect_bats() == null:
		make_path(Vector2(randf_range(0, get_viewport_rect().size.x),
						   randf_range(0, get_viewport_rect().size.y)))
	# Reset state when navigation finishes.
	path_state = 0

func make_path(pos: Vector2) -> void:
	nav_agent.target_position = pos

func adjust_path_with_neighbors() -> void:
	var neighbors:Array = get_tree().get_nodes_in_group("flies")
	var separation_force:Vector2 = Vector2.ZERO
	var cohesion_force:Vector2 = Vector2.ZERO
	var count:int = 0
	
	for neighbor:Node in neighbors:
		if neighbor == self:
			continue
		var distance:float = global_position.distance_to(neighbor.global_position)
		if distance < 300:
			separation_force += (global_position - neighbor.global_position).normalized()
			cohesion_force += neighbor.global_position
			count += 1
	
	if count > 0:
		cohesion_force = (cohesion_force / count - global_position).normalized()
		var final_direction:Vector2 = separation_force + cohesion_force * companionship
		nav_agent.target_position += final_direction * 2

# Detect a bat within the detection radius.
func detect_bats() -> Node:
	var target_bat: Node = null
	var closest_distance:float = detection_radius
	for bat:Node in get_tree().get_nodes_in_group("bats"):
		if bat == self:
			continue
		var d:float = global_position.distance_to(bat.global_position)
		if d < detection_radius and d < closest_distance:
			closest_distance = d
			target_bat = bat
	return target_bat

# Collision detection using Area2D.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("bats"):
		# Add the bat to the list of bats in the area
		if body not in bats_in_area:
			bats_in_area.append(body)

		# Apply damage to the enemy
		var damage_amount: int = 1  # Default damage value.
		if body.has_method("get_damage"):
			damage_amount = body.get_damage()
		elif body.has_meta("damage"):
			damage_amount = body.get_meta("damage")
		take_damage(damage_amount)

		# Apply damage to the bat
		do_damage(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("bats"):
		# Remove the bat from the list of bats in the area
		if body in bats_in_area:
			bats_in_area.erase(body)

func _on_attack_timer_timeout() -> void:
	# Remove invalid bats from the area
	bats_in_area = bats_in_area.filter(is_instance_valid)

	# Check if there are valid bats in the area
	if bats_in_area.size() > 0:
		# Attack the first valid bat in the area
		var target_bat = bats_in_area[0]
		do_damage(target_bat)

func do_damage(target: Node) -> void:
	if target and is_instance_valid(target) and target.is_in_group("bats"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif target.has_meta("health"):
			var current_health = target.get_meta("health")
			target.set_meta("health", current_health - damage)

func take_damage(amount: int) -> void:
	var popup: Node = pop_up_label.instantiate()
	popup.position = global_position
	get_parent().add_child(popup)
	popup.spawn_pop_up(amount)
	print("PopUpLabel position: ", popup.global_position)
	print("Popup parent: ", popup.get_parent())

	# Calculate the percentage of health lost
	var health_before = health
	health -= amount
	var health_lost_percentage = float(amount) / float(health_before)

	# Apply hurt status
	apply_hurt_status(health_lost_percentage)

	print("Enemy hit! Remaining health: ", health)
	if health <= 0:
		die()

func apply_hurt_status(health_lost_percentage: float) -> void:
	if not is_hurt:
		is_hurt = true
		# Reduce speed based on the percentage of health lost
		speed = original_speed * (1.0 - health_lost_percentage)
		print("Enemy hurt! Speed reduced to: ", speed)
		hurt_timer.start()

func _on_hurt_timer_timeout() -> void:
	# Reset speed and remove hurt status
	is_hurt = false
	speed = original_speed
	print("Enemy recovered! Speed restored to: ", speed)

func die() -> void:
	queue_free()

func get_damage() -> int:
	return damage
