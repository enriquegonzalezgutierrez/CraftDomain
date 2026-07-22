# ==============================================================================
# Pathfile: res://src/Domain/Dialogue/DialogueNode.gd
# Description: Pure Domain Resource representing a dialogue conversation state,
#              encapsulating NPC speech text and branching choices.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueNode
extends Resource

## Unique identifier of this dialogue state (e.g., "merchant_intro")
@export var node_id: String = ""

## Spoken localization key or text displayed for the speaker NPC
@export_multiline var text: String = ""

## List of branching choices available at this node state
@export var choices: Array = []