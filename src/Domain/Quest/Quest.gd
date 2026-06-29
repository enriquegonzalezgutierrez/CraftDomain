# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Resource defining an individual Quest state machine,
#              requirements, targets, and rewards.
#              SOLID COMPLIANCE: Added required_item_index and required_quantity 
#              to enable dynamic, non-monotonous gathering, mining, and foraging 
#              objectives without adding hardcoded logic to UI layers (OCP).
#              UX UPGRADE: Added progress_counter to track fresh quest objectives
#              and completely eliminate quest-skipping cascades.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Quest/Quest.gd
# ==============================================================================
class_name Quest
extends Resource

## Structural states of a quest
enum Status {
	UNSTARTED,
	ACTIVE,
	COMPLETED
}

@export var quest_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var objective_text: String = ""

# Coordinates in global block space for auto-guided HUD navigation
@export var target_position: Vector3 = Vector3.ZERO
@export var target_range: float = 8.0

# Geographic exploration/arrival trigger
@export var autocomplete_on_arrival: bool = false

# Autonomous chain linking
@export var next_quest_id: String = ""

# SOLID OCP Upgrade: Generic inventory/mining requirements to break monotony!
@export var required_item_index: int = -1
@export var required_quantity: int = 0

# Rewards
@export var reward_item_index: int = -1
@export var reward_quantity: int = 0

# State
var status: Status = Status.UNSTARTED

# Dynamic runtime progress (Resets cleanly on startup, preventing pre-existing cascades)
var progress_counter: int = 0
