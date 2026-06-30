# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Resource defining an individual branching choice
#              available to the player inside dialogue trees. It encapsulates
#              the display text, navigation target, and conditional requirements
#              for unlocking or executing the choice.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Exclusively manages the
#                properties of a single dialogue option.
#              - Open-Closed Principle (OCP): Supports extensions via optional
#                requirements (quests, items) without modifying the core structure.
#              REFACTORING: Removed direct references to reward item IDs and quantities.
#              Dialogue nodes offering rewards will now reference a specific Recipe
#              resource that defines the item grant logic.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Dialogue/DialogueChoice.gd
# ==============================================================================
class_name DialogueChoice
extends Resource

## The interactive text displayed on the player's choice button in the UI.
@export var option_text: String = ""

## The unique identifier of the target DialogueNode that this choice navigates to.
## If empty, selecting this choice will close the dialogue overlay.
@export var target_node_id: String = ""

## Optional: The ID of a quest that must be active or completed for this choice to appear.
## If empty, no quest prerequisite is enforced.
@export var required_quest_id: String = ""

## Optional: The ID of a Recipe resource that defines the item(s) to be granted
## to the player upon selecting this choice. If null, no item reward is given.
@export var reward_recipe_id: String = ""
