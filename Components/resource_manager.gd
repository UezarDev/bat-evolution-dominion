class_name ResourceManager
extends Node

# Signals for communication
signal resource_updated(resource_name: String, value: float)
signal max_resource_updated(resource_name: String, value: float)

static var ref: ResourceManager = null
var _managers: Dictionary = {}

func _init() -> void:
	if not ref: ref = self
	else: queue_free()

# Resource management
func register_manager(manager: Node, resource_name: String) -> void:
	_managers[resource_name] = manager

func get_resource(resource_name: String) -> float:
	if _managers.has(resource_name):
		var manager: Node = _managers[resource_name]
		if manager.has_method("get_resource"):
			return manager.call("get_resource")
		elif manager.get("current_value") != null:
			return manager.get("current_value")
	return 0.0

func get_max_resource(resource_name: String) -> float:
	if _managers.has(resource_name):
		var manager: Node = _managers[resource_name]
		if manager.has_method("get_max_resource"):
			return manager.call("get_max_resource")
		elif manager.get("max_value") != null:
			return manager.get("max_value")
	return 0.0

func spend_resource(resource_name: String, amount: float) -> bool:
	if _managers.has(resource_name):
		var manager: Node = _managers[resource_name]
		if manager.has_method("can_spend"):
			var can_spend: bool = manager.call("can_spend", amount)
			if can_spend and manager.has_method("spend"):
				manager.call("spend", amount)
				return true
	return false

# Signal forwarding
func notify_resource_update(resource_name: String, value: float) -> void:
	resource_updated.emit(resource_name, value)

func notify_max_resource_update(resource_name: String, value: float) -> void:
	max_resource_updated.emit(resource_name, value)
