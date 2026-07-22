# ==============================================================================
# Pathfile: res://src/Domain/Dialogue/DialogueChoice.gd
# Description: Pure Domain Resource defining an individual branching choice
#              option within interactive dialogue trees.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueChoice
extends Resource

## Interactive localization key or text displayed on the player's choice button.
@export var option_text: String = ""

## Unique identifier of the target DialogueNode navigated to when selected.
## An empty string indicates that selecting this option closes the dialogue.
@export var target_node_id: String = ""

## Optional quest ID prerequisite required for this choice to be visible.
@export var required_quest_id: String = ""

## Optional Recipe ID granted to the player upon choosing this option.
@export var reward_recipe_id: String = ""