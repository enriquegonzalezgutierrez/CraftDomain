# ==============================================================================
# Pathfile: res://src/Domain/Quest/Quest.gd
# Description: Pure Domain Resource defining a Quest state machine, objectives,
#              target coordinates, requirements, and completion rewards.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name Quest
extends Resource

enum Status {
	UNSTARTED,
	ACTIVE,
	COMPLETED
}

@export var quest_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var objective_text: String = ""

## Coordinates in global block space for HUD navigation
@export var target_position: Vector3 = Vector3.ZERO
@export var target_range: float = 8.0

## Geographic arrival completion trigger
@export var autocomplete_on_arrival: bool = false

## Next quest in chain upon completion
@export var next_quest_id: String = ""

## Dynamic inventory gathering requirements
@export var required_item_index: int = -1
@export var required_quantity: int = 0

## Reward item ID and quantity granted upon completion
@export var reward_item_index: int = -1
@export var reward_quantity: int = 0

var status: Status = Status.UNSTARTED
var progress_counter: int = 0