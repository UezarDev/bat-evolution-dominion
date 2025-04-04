extends RichTextLabel

const ResourceManager = preload("res://Components/resource_manager.gd")

@export var _resource_name: String = "resource"  # Name of the resource to track
@export var _display_format: String = "%s/%s"  # Exported format string for display

func _ready() -> void:
    bbcode_enabled = true
    if ResourceManager.ref:
        ResourceManager.ref.resource_updated.connect(_on_resource_updated)
        ResourceManager.ref.max_resource_updated.connect(_on_resource_updated)
    _update_text()

func format_number(n: float) -> String:
    # Suffixes for thousands, millions, etc.
    const suffixes: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx",
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
    var scaled: float = n / pow(1000, index)
    
    if scaled < 100:
        # For numbers between 1 and 100, use two decimals → 4 digits.
        return "%.2f%s" % [scaled, suffixes[index]]
    else:
        # For numbers 100 or more, use one decimal → 4 digits.
        return "%.1f%s" % [scaled, suffixes[index]]

func _on_resource_updated(resource_name: String, _value: float) -> void:
    if resource_name == _resource_name:
        _update_text()

func _update_text() -> void:
    if ResourceManager.ref:
        var current: float = ResourceManager.ref.get_resource(_resource_name)
        var max_val: float = ResourceManager.ref.get_max_resource(_resource_name)
        text = _display_format % [format_number(current), format_number(max_val)]
