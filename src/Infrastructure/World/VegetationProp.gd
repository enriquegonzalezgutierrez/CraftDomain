# ==============================================================================
# Pathfile: res://src/Infrastructure/World/VegetationProp.gd
# Description: Base class for non-solid vegetation and wild flora props.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Acts strictly as a typesafe boundary 
#   for vegetation rendering instances, eliminating name-based node lookups.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VegetationProp
extends Node3D


func _ready() -> void:
	pass