# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for rendering the 
#              full-screen red flash vignette when the player takes damage.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/DamageOverlayWidget.gd
# ==============================================================================
class_name DamageOverlayWidget
extends ColorRect

func _ready() -> void:
	name = "DamageOverlayWidget"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.8, 0.0, 0.0, 0.0) # Start fully transparent
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Triggers a high-impact, short-lived screen flash animation.
func flash() -> void:
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "color:a", 0.45, 0.08).set_trans(Tween.TRANS_SINE)
	flash_tween.chain().tween_property(self, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
