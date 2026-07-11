# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Dialogue System / Value Objects)
# Class: DialogueNode
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Resource defining an individual dialogue state node,
#              encapsulating NPC speech text and an array of branching choices.
#              FIXED: Swapped choices to untyped Array to bypass Godot's circular 
#              compiler lock.
# ==============================================================================
class_name DialogueNode
extends Resource

## The unique identifier of this dialogue state (e.g., "village_merchant_intro")
@export var node_id: String = ""

## The spoken text displayed on the screen for the NPC
@export_multiline var text: String = ""

## FIXED: Changed to generic Array to prevent Godot 4 compilation race-conditions
@export var choices: Array = []
