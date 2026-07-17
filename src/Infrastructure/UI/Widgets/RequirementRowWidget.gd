# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/RequirementRowWidget.gd
# Description: Infrastructure UI Widget representing a single material 
#              requirement row within the Crafting Blueprint details panel.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates label formatting 
#                and validity color-coding entirely from the main overlay.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RequirementRowWidget
extends Panel

const COLOR_SATISFIED := Color(0.25, 0.85, 0.35)
const COLOR_DEFICIENT := Color(0.92, 0.15, 0.15)

@onready var _label: Label = $RequirementLabel


func _ready() -> void:
	pass


## Initializes the requirement row text and evaluation color logic
func initialize_requirement(item_name: String, current_qty: int, required_qty: int) -> void:
	if not is_instance_valid(_label):
		return
		
	var is_satisfied: bool = current_qty >= required_qty
	var glyph: String = "   ✔  " if is_satisfied else "   ✘  "
	
	_label.text = glyph + "%d / %d  %s" % [current_qty, required_qty, item_name.to_upper()]
	
	var ls := _label.label_settings
	if ls != null:
		ls.font_color = COLOR_SATISFIED if is_satisfied else COLOR_DEFICIENT
