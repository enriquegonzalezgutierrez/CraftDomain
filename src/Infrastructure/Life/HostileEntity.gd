# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Class: HostileEntity
# Description: Physical character controller representing a hostile Cave Zombie.
#              Schedules animation rigging, handles loot drops, and registers its 
#              specialized ZombieAIBehavior strategy dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical body 
#   movement structures and target visual attachments, delegating pathing and 
#   pursuit routines to the injected ZombieAIBehavior.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   parent class, utilizing its base physics processes and gravity vectors transparently.
# - Dependency Inversion Principle (DIP): Receives its behavioral decision tree 
#   via dynamic strategy injection on startup.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name HostileEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/zombie/zombie_base.fbx"

# Sibling node references
var player: CharacterBody3D

# UI overlays
var _quest_bubble: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Initialize with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_ZOMBIE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for target scans
	add_to_group("hostiles")
	
	# Cache components pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Execute hybrid graphics compilation pipeline (FBX vs Procedural Voxel)
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	_setup_quest_bubble()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Programmatically instantiates NPCAIComponent if missing from old scenes
	# ==========================================================================
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ZombieAIBehavior.new()


## Determines visual presentation dynamically based on file existence
func _setup_graphics_representation() -> void:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		_build_glb_representation()
	else:
		_build_procedural_representation()


func _build_glb_representation() -> void:
	var model_scene := load(BASE_MODEL_PATH) as PackedScene
	if model_scene == null:
		_build_procedural_representation()
		return
		
	var model_node := model_scene.instantiate() as Node3D
	_prune_extraneous_nodes(model_node)
	
	# Calibration calculated via headless model analyzer
	model_node.scale = Vector3(1.6635, 1.6635, 1.6635)
	model_node.position = Vector3(0.0, 0.0, 0.0)
	model_node.rotation_degrees = Vector3(0, 180, 0) # Face forward along -Z
	
	visual_component.body_bob_node.add_child(model_node)
	_register_glb_materials(model_node)


## Symmetrical Fallback: Sculpts custom voxel character out of color boxes
func _build_procedural_representation() -> void:
	var skin_color := Color(0.45, 0.55, 0.42) # Rotting green skin
	var shirt_color := Color(0.12, 0.45, 0.55) # Tattered blue shirt
	var pants_color := Color(0.24, 0.22, 0.32) # Dark trousers
	
	# Legs and Torso
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(-0.1, 0.275, 0.0), pants_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(0.1, 0.275, 0.0), pants_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.44, 0.75, 0.32), Vector3(0, 0.925, 0), shirt_color)
	
	# Head (Zombified bald skull)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.3, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.38, 0.35), Vector3(0, 0.19, 0), skin_color)
	visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.15, 0.08), Vector3(0.0, 0.12, -0.21), skin_color * 0.9)


func _setup_quest_bubble() -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
		if sb_script != null:
			_quest_bubble = sb_script.new() as Node3D
			_quest_bubble.name = "QuestBubble"
			add_child(_quest_bubble)
			_quest_bubble.call("set_text", tr("BUBBLE_TARGET_MONSTER"))
			_quest_bubble.position = Vector3(0.0, _collision_height + 0.65, 0.0)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# Overrides nameplate color return value to warning crimson red
# ==============================================================================
func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15)


func _get_habitat() -> int:
	return 0 # TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Spawns dynamic drops directly into the player's backpack using DIP contracts
func _drop_loot(inv: IInventory) -> void:
	inv.consume_item(15, 1) # Deduct 1x Lava Bucket from player
	
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var _un := inv.add_item(active_q.reward_item_index, active_q.reward_quantity)
		if is_instance_valid(player):
			QuestService.complete_active_quest(player)


# ==============================================================================
# SKELETAL RENDERING UTILITIES
# ==============================================================================

## Recursively duplicates materials to prevent material-sharing leaks
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)
