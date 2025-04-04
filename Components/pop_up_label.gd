class_name PopUpLabel
extends RichTextLabel

@export var _display_format: String = "-%s"
@export var life_time: float = 0.5
@export var min_speed: float = 50.0  # Minimum speed for random movement
@export var max_speed: float = 150.0  # Maximum speed for random movement

var life_timer: Timer = Timer.new()
var velocity: Vector2 = Vector2.ZERO  # Random movement direction and speed

func _ready() -> void:
	# Add and configure the life timer
	life_timer.wait_time = life_time
	life_timer.connect("timeout", Callable(self, "_on_life_timer_timeout"))
	add_child(life_timer)
	life_timer.start()

	# Set a random direction and speed
	var angle: float = randf_range(0, PI * 2)  # Random angle in radians
	var speed: float = randf_range(min_speed, max_speed)  # Random speed
	velocity = Vector2(cos(angle), sin(angle)) * speed

	# Ensure the label is visible
	visible = true

func spawn_pop_up(n: int, color: Color = Color(1, 1, 1)) -> void:
	# Use BBCode to set the text color
	bbcode_enabled = true  # Enable BBCode
	text = "[color=%s]%s[/color]" % [color.to_html(), _display_format % n]
	print("PopUpLabel spawned with text: ", text)

func _physics_process(delta: float) -> void:
	# Move in the random direction
	position += velocity * delta

	# Fade out over time
	var alpha: float = modulate.a - (delta / life_time)  # Reduce alpha based on life time
	modulate = Color(modulate.r, modulate.g, modulate.b, clamp(alpha, 0.0, 1.0))

func _on_life_timer_timeout() -> void:
	queue_free()
