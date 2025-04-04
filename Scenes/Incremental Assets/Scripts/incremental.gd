class_name Incremental extends Control

var bloodLabel:RichTextLabel
var clickerButton:Button
var blood:float = 0
var maxBlood:float = 100

func _get_nodes() -> void:
	bloodLabel = get_node("BloodLabel")
	clickerButton = get_node("ClickerButton")

func _ready() -> void:
	_get_nodes()
	_update_labels()

func _generate_blood() -> void:
	blood += 1
	if blood > maxBlood:
		blood = maxBlood
	_update_labels()

func _update_labels() -> void:
	bloodLabel.text = str(blood) + '/' + str(maxBlood)

func _on_clickerButton_pressed() -> void:
	_generate_blood()
