class_name Bat
extends CharacterBody2D

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hit_area: Area2D = $Area2D
@onready var pop_up_label: PackedScene = preload("res://Components/pop_up_label.tscn")

@onready var attack_timer: Timer = Timer.new()
@onready var hurt_timer: Timer = Timer.new()

@export var companionship: int = 6
@export var detection_radius: float = 300.0  # How far a bat can detect enemies
@export var health: int = 5                  # Bat's starting health
@export var damage: int = 1                  # Bat's damage
@export var attack_speed: float = 1.0        # Time between attacks
@export var speed: float = 100               # Bat's normal speed
@export var recovery_time: float = 2.0       # Duration of the hurt status in seconds

var enemies_in_area: Array = []  # Track enemies inside the area
var is_hurt: bool = false
var original_speed: float = 0.0

func _ready() -> void:
	add_to_group("bats")

	# Set collision layers and masks so bats ignore each other:
	collision_layer = 1 << 0  # layer 1 (for bats)
	collision_mask = 1 << 1   # only collide with layer 2 (e.g., enemies)

	# Uncomment if you want to use nav_agent signals:
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
	# Check for nearby enemies
	var target_enemy:Enemy = detect_enemy()
	if target_enemy:
		if target_enemy.health < health:
			nav_agent.target_position = target_enemy.global_position
		else:
			var run_dir: Vector2 = (global_position - target_enemy.global_position).normalized()
			nav_agent.target_position = global_position + run_dir * detection_radius

	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_pos)
	
	# Update the built-in velocity property (do not create a new local variable)
	velocity = direction * speed

	if velocity.length() > 0:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 15.0)
	
	# Only adjust path if no enemy is detected:
	if detect_enemy() == null:
		adjust_path_with_neighbors()

	# Check if the bat is close enough to the target position
	if global_position.distance_to(nav_agent.target_position) < 10.0:  # "Close enough" threshold
		_on_nav_finished()
	
	# Use the built-in velocity property for movement.
	move_and_slide()

func _on_nav_finished() -> void:
	# If no enemy is in range, resume wandering.
	if detect_enemy() == null:
		make_path(Vector2(randf_range(0, get_viewport_rect().size.x),
			randf_range(0, get_viewport_rect().size.y)))

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("move"):
		return
	make_path(get_global_mouse_position())

func make_path(pos: Vector2) -> void:
	nav_agent.target_position = pos

func adjust_path_with_neighbors() -> void:
	var neighbors:Array = get_tree().get_nodes_in_group("bats")
	var separation_force:Vector2 = Vector2.ZERO
	var cohesion_force:Vector2 = Vector2.ZERO
	var count:int = 0

	for neighbor:Bat in neighbors:
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

func detect_enemy() -> Enemy:
	var target_enemy: Enemy = null
	var closest_distance:float = detection_radius
	for enemy:Enemy in get_tree().get_nodes_in_group("enemies"):
		var d:float = global_position.distance_to(enemy.global_position)
		if d < detection_radius and d < closest_distance:
			closest_distance = d
			target_enemy = enemy
	return target_enemy

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		# Store the enemy in the area if not already present
		if body not in enemies_in_area:
			enemies_in_area.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("enemies"):
		# Remove the enemy from the area when it leaves
		if body in enemies_in_area:
			enemies_in_area.erase(body)

func _on_attack_timer_timeout() -> void:
	# Remove invalid enemies from the area
	enemies_in_area = enemies_in_area.filter(is_instance_valid)

	# Check if there are valid enemies in the area
	if enemies_in_area.size() > 0:
		# Attack the first valid enemy in the area
		var target_enemy:Enemy = enemies_in_area[0]
		do_damage(target_enemy)

func do_damage(target: Enemy) -> void:
	if target and is_instance_valid(target) and target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif target.has_meta("health"):
			var current_health:int = target.get_meta("health")
			target.set_meta("health", current_health - damage)

func take_damage(amount: int) -> void:
	var popup: PopUpLabel = pop_up_label.instantiate()
	popup.position = global_position
	get_parent().add_child(popup)
	popup.spawn_pop_up(amount, Color(0.8, 0, 0))

	# Calculate the percentage of health lost
	var health_before:int = health
	health -= amount
	var health_lost_percentage:float = float(amount) / float(health_before)

	# Apply hurt status
	apply_hurt_status(health_lost_percentage)

	print("Bat hit! Remaining health: ", health)
	if health <= 0:
		die()

func apply_hurt_status(health_lost_percentage: float) -> void:
	if not is_hurt:
		is_hurt = true
		# Reduce speed based on the percentage of health lost
		speed = original_speed * (1.0 - health_lost_percentage)
		print("Bat hurt! Speed reduced to: ", speed)
		hurt_timer.start()

func _on_hurt_timer_timeout() -> void:
	# Reset speed and remove hurt status
	is_hurt = false
	speed = original_speed
	print("Bat recovered! Speed restored to: ", speed)

func die() -> void:
	queue_free()

func get_damage() -> int:
	return damage
