# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing an interactive Wishing Well.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D visual assembly, collision setup, and interactive coin toss transactions.
#              - Liskov Substitution Principle (LSP): Extends StaticBody3D cleanly 
#                to act as a physical collidable obstacle in the world, automatically 
#                rendering a procedural voxel-box well if the GLB is missing.
#              - Dependency Inversion Principle (DIP): Modifies the player's inventory 
#                strictly through the abstract IInventory interface contract.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WishingWellEntity.gd
# ==============================================================================
class_name WishingWellEntity
extends StaticBody3D

const MODEL_PATH := "res://assets/models/decorations/wishing_well_odyssey.glb"

# Visual and physical node references
var _model_node: Node3D


func _ready() -> void:
	name = "Prop_WISHING_WELL"
	_setup_model()
	_setup_collision()


## Programmatically loads, instantiates, and configures the GLB model with robust fallback support
func _setup_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		_model_node = model_scene.instantiate() as Node3D
		_prune_extraneous_nodes(_model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer V5)
		# ======================================================================
		# 1. Scale model by 1.2563x to increase height from 1.990m to ~2.5m
		_model_node.scale = Vector3(1.2563, 1.2563, 1.2563)
		
		# 2. Origin is centered. Raise Y by +1.2538m to anchor the bottom
		#    stone base perfectly flat on the ground plane
		_model_node.position = Vector3(0.0, 1.2538, 0.0)
		
		# 3. Model is naturally oriented. Rotation set to 0.
		_model_node.rotation_degrees = Vector3(0, 0, 0)
		# ======================================================================
		
		add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		# ======================================================================
		# LSP FALLBACK: Symmetrical procedural voxel construction
		# ======================================================================
		var stone_color := Color(0.5, 0.5, 0.5)
		var water_color := Color(0.1, 0.4, 0.8, 0.8)
		_create_box(self, Vector3(1.4, 1.0, 1.4), Vector3(0.0, 0.5, 0.0), stone_color) 
		_create_box(self, Vector3(1.1, 0.2, 1.1), Vector3(0.0, 0.9, 0.0), water_color) 
		_create_box(self, Vector3(0.1, 1.5, 0.1), Vector3(-0.6, 1.25, 0.0), Color(0.4, 0.25, 0.15)) 
		_create_box(self, Vector3(0.1, 1.5, 0.1), Vector3(0.6, 1.25, 0.0), Color(0.4, 0.25, 0.15))  
		_create_box(self, Vector3(1.6, 0.1, 1.6), Vector3(0.0, 2.0, 0.0), Color(0.15, 0.12, 0.14))  


## Recursively duplicates materials to prevent material-sharing leaks
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		# EXPLICIT CASTING: Prevents static analyzer type inference errors
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
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


## Generates the physical collision box for highlighting and raycast detection
func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "WellCollider"
	var box_shape := BoxShape3D.new()
	
	# Calibrated to the scaled bounding box of the GLB model (2.5m height, 1.8m width, 1.75m depth)
	box_shape.size = Vector3(1.8, 2.5, 1.75)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 1.25, 0.0) # Aligns to ground level
	add_child(col_shape)


## Public Interaction: Deducts 1x Stone coin and grants a random valuable wish reward
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		# Stone Block (ID 1) acts as our copper coin token proxy
		var cost_item_id := 1
		var cost_qty := 1
		
		if inventory.get_item_total_quantity(cost_item_id) >= cost_qty:
			# 1. Deduct the cost
			inventory.consume_item(cost_item_id, cost_qty)
			
			# 2. Play coin clink and water splash spatial SFX (Service Locator)
			AudioService.play_sfx_static("loot_pickup", global_position)
			AudioService.play_sfx_static("block_break", global_position)
			
			# 3. Roll a random wish reward (Diamond Ore, Glowstone, or Fried Chicken!)
			var rewards_pool: Array[int] = [16, 28, 30] # Chicken (16), Diamond (28), Glowstone (30)
			var rolled_item_id := rewards_pool[randi() % rewards_pool.size()]
			inventory.add_item(rolled_item_id, 1)
			
			# Symmetrically fetch name binding
			var reward_name := ""
			if rolled_item_id == 16: reward_name = tr("ITEM_16_DESC").left(14)
			elif rolled_item_id == 28: reward_name = tr("BLOCK_DIAMOND_ORE")
			else: reward_name = tr("BLOCK_GLOWSTONE")
			
			# 4. Display a gold toast notification on the player's HUD
			if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
				hud.call("show_quest_notification", "WISH GRANTED!", "Received: 1x " + reward_name.to_upper())
		else:
			# If the player has no stone coin, flash a helpful tip
			if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
				hud.call("show_quest_notification", "WISHING WELL", "Toss 1x Stone Block (ID 1) to make a wish!")
				AudioService.play_sfx_static("npc_chat", global_position)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
