# ==============================================================================
# Project: CraftDomain
# Description: Guard NPC entity. Inherits from the abstract base class PassiveEntity.
#              OCP COMPLIANT: Completely isolated from other NPC files.
#              REVERTED: Restored the original programmatic 3D voxel block design
#              (with sheathed sword, steel helmet, custom nose, and blinking eyes) 
#              for a classic Minecraft look.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GuardEntity.gd
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3)
	name = "Entity_GUARD"

## Override: Assembles the 3D steel-plated soldier model programmatically
func _build_visual_representation() -> void:
	var robe_color := Color(0.32, 0.32, 0.35) # Steel grey plates
	var sash_color := Color(0.42, 0.12, 0.12) # Crimson red sash
	
	# 1. Torso Robe
	_create_box(_visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), robe_color)
	
	# 2. Head Node
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.25, 0)
	_visual_root.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.05, 0), Color(0.95, 0.75, 0.65)) # Head skin
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, -0.01, -0.21), Color(0.85, 0.65, 0.55)) # Nose
	
	# Blinking Soldier Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.06, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# Steel Helmet on head with a red feather plume
	_create_box(_head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.22, 0), Color(0.48, 0.48, 0.52))
	_create_box(_head_node, Vector3(0.04, 0.28, 0.04), Vector3(0, 0.35, -0.1), Color(0.8, 0.15, 0.15)) 
	
	# 3. Folded arms
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.75, -0.21)
	_visual_root.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), sash_color)
	
	# 4. Sheathed Iron Sword on back
	var sword_joint := Node3D.new()
	sword_joint.name = "IronSwordJoint"
	sword_joint.position = Vector3(-0.3, 0.5, 0.2)
	sword_joint.rotation = Vector3(0, 0, deg_to_rad(-145)) 
	_visual_root.add_child(sword_joint)
	
	_create_box(sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), Color(0.85, 0.85, 0.88)) 
	_create_box(sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), Color(0.85, 0.6, 0.15))  
	_create_box(sword_joint, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.1, 0), Color(0.35, 0.22, 0.15))  

func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.61, 0.575)

func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.805, 0)

func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		var bubble = sb_script.new() as Node3D
		add_child(bubble)
		bubble.call("set_text", "GUARD")

func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("guard_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "guard_intro"
			fallback_node.text = "Hail, traveler! I stand watch over this village bazaar. Rest easy; my steel blade will keep the cave zombies at bay!"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
			
		hud.call("open_dialogue", intro_node, "Guard")

func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.65:
		current_task = TaskState.WANDERING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(4.0, 9.0)
	else:
		current_task = TaskState.IDLE 
		_task_timer = randf_range(2.0, 5.0)

func _can_socialize() -> bool:
	return true
