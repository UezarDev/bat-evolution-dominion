class_name ManagerBlood
extends Node

static var ref : ManagerBlood

const ResourceManager = preload("res://Components/resource_manager.gd")

func _init() -> void:
	if not ref: ref = self
	else: queue_free()

signal resource_updated
signal max_resource_updated
signal resource_created(amount:float)
signal resource_spent(amount:float)

var _max_resource: float = 1240
var _resource: float = 0


# Generic get method
func get_property(property_name: String) -> Variant:
	match property_name:
		"resource":
			return _resource
		"max_resource":
			return _max_resource
		_:
			push_warning("Property '%s' not found in ManagerBlood." % property_name)
			return null

func set_max_resource(value: float) -> void:
	_max_resource = value
	ResourceManager.ref.notify_max_resource_update("blood", value)
	max_resource_updated.emit()
	

func create_resource(amount: float) -> void:
	if amount <= 0 or _resource == _max_resource:
		return
	if _resource + amount > _max_resource:
		amount = _max_resource - _resource
		_resource = _max_resource
	else:
		_resource += amount

	resource_created.emit(amount)
	resource_updated.emit()
	

func can_spend(amount: float) -> bool:
	if amount < 0 or amount > _resource:
		return false
	return true

func spend_resource(amount: float) -> Error:
	if amount < 0 or amount > _resource:
		return Error.FAILED
	_resource -= amount

	resource_spent.emit(amount)
	resource_updated.emit()
	

	return Error.OK

var smoothed_blood: float = 0.0

func _process(delta: float) -> void:
	# Apply smoothing using a low-pass filter (exponential moving average)
	smoothed_blood = lerp(smoothed_blood, _resource / _max_resource, delta * 3.0)
	smoothed_blood = clamp(smoothed_blood, 0.0, 1.0)
	var _material: ShaderMaterial = ($"../BloodContainer" as CanvasItem).material
	# Update the shader with the smoothed blood ratio
	_material.set_shader_parameter("smoothed_blood", smoothed_blood)
