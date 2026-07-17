# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/HackingNodeButton.gd
# Description: Infrastructure UI Widget managing the visual state of a single 
#              hacking puzzle node. Encapsulates StyleBox mutations (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HackingNodeButton
extends Button

const COLOR_CYAN := Color(0.0, 0.95, 0.95, 0.85)
const COLOR_MAGENTA := Color(0.95, 0.0, 0.95, 0.85)
const COLOR_DIM := Color(0.12, 0.12, 0.15, 0.8)


func _ready() -> void:
	_ensure_unique_styleboxes()


func _ensure_unique_styleboxes() -> void:
	# Clone the base style dynamically to allow individual color overrides 
	# without leaking resource changes to sibling nodes.
	var base_style := get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var unique_style := base_style.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("normal", unique_style)
		add_theme_stylebox_override("hover", unique_style)
		add_theme_stylebox_override("pressed", unique_style)


## Updates the node's background and border colors based on its alignment state.
func set_node_state(is_cyan: bool) -> void:
	var style := get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.bg_color = COLOR_CYAN if is_cyan else COLOR_MAGENTA
		style.border_color = style.bg_color.darkened(0.4)


## Dims the node's colors when a lockdown (failure) occurs.
func set_locked_state() -> void:
	var style := get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.bg_color = COLOR_DIM
		style.border_color = Color.BLACK
