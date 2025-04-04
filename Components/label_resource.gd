extends RichTextLabel

@export var _manager: NodePath  # Exported NodePath to reference any singleton
@export var _display_format: String = "%s/%s"  # Exported format string for display
@export var _properties: Array[String] = ["resource", "max_resource"]  # Properties to fetch and display

func _ready() -> void:
	bbcode_enabled = true
	if _manager:
		var manager_instance:Node = get_node_or_null(_manager)
		if manager_instance:
			# Connect signals dynamically if they exist
			if manager_instance.has_signal("resource_updated"):
				manager_instance.resource_updated.connect(_on_resource_updated)
			if manager_instance.has_signal("max_resource_updated"):
				manager_instance.max_resource_updated.connect(_on_resource_updated)
	_update_text()

func format_number(n: float) -> String:
	# Suffixes for thousands, millions, etc.
	const suffixes:Array= ["", "K", "M", "B", "T", "Qa", "Qi", "Sx",
	"Sp", "Oc", "No", "Dc", "Udc", "Ddc", "Tdc", "Qadc", "Qidc",
	"Sxdc", "Spdc", "Ocdc", "Nmdc", "Vg"]
	
	# If the number is less than 1000, no suffix is applied.
	if n < 1000:
		if n < 100:
			return "%.2f" % n  # e.g., "99.99" (4 digits: 9,9,9,9)
		else:
			return "%.1f" % n  # e.g., "100.0" (4 digits: 1,0,0,0)
	
	# For numbers 1000 or above, choose an appropriate suffix.
	var index: int = int(floor(log(n) / log(1000)))
	index = clamp(index, 1, suffixes.size() - 1)
	var scaled:float = n / pow(1000, index)
	
	if scaled < 100:
		# For numbers between 1 and 100, use two decimals → 4 digits.
		return "%.2f%s" % [scaled, suffixes[index]]
	else:
		# For numbers 100 or more, use one decimal → 4 digits.
		return "%.1f%s" % [scaled, suffixes[index]]


func _update_text() -> void:
	if _manager:
		var manager_instance:Node = get_node_or_null(_manager)
		if manager_instance:
			# Fetch properties dynamically based on _properties array
			var values:Array = []
			for property_name:String in _properties:
				var value:Variant = manager_instance.get_property(property_name) if manager_instance.has_method("get_property") else ""
				values.append(format_number(value))
			# Format the text using the fetched values
			text = _display_format % values 

func _on_resource_updated() -> void:
	_update_text()
