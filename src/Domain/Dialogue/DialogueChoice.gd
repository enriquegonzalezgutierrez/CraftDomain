# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Resource defining an individual branching choice
#              available to the player inside dialogue trees.
#              Strictly DDD compliant (pure data, completely agnostic of UI nodes).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Dialogue/DialogueChoice.gd
# ==============================================================================
class_name DialogueChoice
extends Resource

## The interactive text displayed on the player's choice button
@export var option_text: String = ""

## The unique identifier of the target DialogueNode that this choice navigates to
@export var target_node_id: String = ""

## Optional: The ID of a quest required to unlock this specific choice
@export var required_quest_id: String = ""

## Optional: The ID of an item rewarded to the player upon selecting this choice
@export var reward_item_id: String = ""

## Optional: The quantity of the rewarded item
@export var reward_quantity: int = 1
