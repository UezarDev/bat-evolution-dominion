class_name GeneratorBlood
extends Node

static var ref : GeneratorBlood

func _init() -> void:
	if not ref:
		ref = self
	else:
		self.queue_free()

signal resource_generated(amount:int)
signal generator_stopped()
signal generator_started()

var _generated_resource_per_tick : int = 1
var _tick_duration : float = 2

@onready var _timer : Timer = get_node("Timer")

func _ready() -> void:
	_timer.wait_time = _tick_duration
	_timer.timeout.connect(_on_Timer_timeout)
	start()

func start() -> void:
	_timer.start()
	generator_started.emit()

func stop() -> void:
	_timer.stop()
	generator_stopped.emit()

func is_active() -> bool:
	return not _timer.is_stopped()

func _generate_resource() -> void:
	ManagerBlood.ref.create_resource(_generated_resource_per_tick)

	resource_generated.emit(_generated_resource_per_tick)

func _on_Timer_timeout() -> void:
	_generate_resource()


func get_property(property_name: String) -> Variant:
	match property_name:
		"_generated_resource_per_second":
			return _generated_resource_per_tick / _tick_duration
		_:
			print_debug("Property '%s' not found in GeneratorBlood." % property_name)
			return null
