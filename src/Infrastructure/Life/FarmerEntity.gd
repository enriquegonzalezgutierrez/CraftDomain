# ==============================================================================
# Project: CraftDomain
# Description: Farmer NPC entity. Inherits from the abstract base class PassiveEntity.
#              OCP COMPLIANT: Completely isolated from other NPC files.
#              UPDATED: Added a dedicated agricultural task allocator to make
#              farmers actively farm crops 75% of the time.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FarmerEntity.gd
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1)
	name = "Entity_FARMER"

## Override: Assembles the 3D Farmer model with a custom straw hat
func _build_visual_representation() -> void:
	var robe_color := Color(0.68, 0.58, 0.42) # Straw yellow/linen robe
	var sash_color := Color(0.25, 0.15, 0.1)  # Dark brown sash
	
	# 1. Torso Robe
	_create_box(_visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), robe_color)
	
	# 2. Head Node
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.25, 0)
	_visual_root.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.05, 0), Color(0.95, 0.75, 0.65)) # Head skin
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, -0.01, -0.21), Color(0.85, 0.65, 0.55)) # Nose
	
	# Wide flat Straw Hat on head
	_create_box(_head_node, Vector3(0.65, 0.04, 0.65), Vector3(0, 0.24, 0), Color(0.88, 0.78, 0.42))
	_create_box(_head_node, Vector3(0.22, 0.12, 0.22), Vector3(0, 0.3, 0), Color(0.85, 0.72, 0.35))
	
	# 3D Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# 3. Folded arms
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.75, -0.21)
	_visual_root.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), sash_color)

## Override: Setup physical human boundaries
func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.61, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.805, 0)

## Override: Attach floating billboard name tags
func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		var bubble = sb_script.new() as Node3D
		add_child(bubble)
		bubble.call("set_text", "FARMER")

## Override: Trigger custom farmer-role dialog tree
func interact(player: CharacterBody3D) -> void:
	var hud = player.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("farmer_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "farmer_intro"
			fallback_node.text = "Hello! I am tending these crops to keep the market well stocked. The soil of the Golden Bazaar is rich and bountiful!"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
			
		hud.call("open_dialogue", intro_node, "Farmer")

## Override: Farmers love to tend the crops and spend 75% of their time examining blocks!
func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.75:
		current_task = TaskState.EXAMINING # Tending fields / Farming
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(3.0, 7.0)
	elif roll < 0.90:
		current_task = TaskState.WANDERING # Move to another crop spot
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(2.0, 4.0)
	else:
		current_task = TaskState.IDLE # Resting
		_task_timer = randf_range(1.0, 2.5)

## Override: Farmers stop and greet the player when they approach
func _can_socialize() -> bool:
	return true
