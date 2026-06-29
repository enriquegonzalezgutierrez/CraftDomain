# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for drawing the 
#              player's center-screen aiming reticle.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/CrosshairWidget.gd
# ==============================================================================
class_name CrosshairWidget
extends Control

func _ready() -> void:
	name = "CrosshairWidget"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := get_viewport_rect().size / 2.0
	var col := Color(1, 1, 1, 0.85)
	var shadow := Color(0, 0, 0, 0.5)
	
	# Draw shadow/outline first for depth
	draw_circle(center, 3.0, shadow)
	draw_line(center - Vector2(8, 0), center - Vector2(3, 0), shadow, 3.0)
	draw_line(center + Vector2(3, 0), center + Vector2(8, 0), shadow, 3.0)
	draw_line(center - Vector2(0, 8), center - Vector2(0, 3), shadow, 3.0)
	draw_line(center + Vector2(0, 3), center + Vector2(0, 8), shadow, 3.0)

	# Draw bright foreground reticle
	draw_circle(center, 1.5, col)
	draw_line(center - Vector2(7, 0), center - Vector2(4, 0), col, 2.0)
	draw_line(center + Vector2(4, 0), center + Vector2(7, 0), col, 2.0)
	draw_line(center - Vector2(0, 7), center - Vector2(0, 4), col, 2.0)
	draw_line(center + Vector2(0, 4), center + Vector2(0, 7), col, 2.0)
