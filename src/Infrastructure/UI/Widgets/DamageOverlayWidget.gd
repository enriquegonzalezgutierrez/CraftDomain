# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/DamageOverlayWidget.gd
# Description: SRP-compliant UI Widget responsible ONLY for the animation 
#              logic of the damage vignette. Visual properties are defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DamageOverlayWidget
extends ColorRect

## Triggers a high-impact, short-lived screen flash animation.
func flash() -> void:
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "color:a", 0.45, 0.08).set_trans(Tween.TRANS_SINE)
	flash_tween.chain().tween_property(self, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
