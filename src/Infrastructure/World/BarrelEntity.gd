# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing an interactive Breakable Barrel.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D visual assembly, collision setup, and interactive breaking transactions.
#              - Liskov Substitution Principle (LSP): Extends StaticBody3D cleanly 
#                to act as a physical collidable obstacle in the world.
#              - Dependency Inversion Principle (DIP): Modifies the player's inventory 
#                strictly through the abstract IInventory interface contract.
# INTERACTIVE BREAKABLE LOOT MECHANIC (V5 Telemetry & i18n):
#              - Total model height is 0.900m. Scale set to 1.0x (perfect size).
#              - Model origin is already perfectly at the bottom base (Y = 0.0).
#                No vertical offset is required (position.y = 0.0).
#              - Right-clicking the barrel breaks it, spawning wood debris, 
#                and drops a random provision (Seeds or Fried Chicken) before self-freeing.
#              - Replaced all hardcoded string notifications with `tr()` wrappers.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/BarrelEntity.gd
# ==============================================================================
class_name BarrelEntity
extends StaticBody3D

const MODEL_PATH := "res://assets/models/decorations/barrel.glb"

# Visual and physical node references
var _model_node: Node3D


func _ready() -> void:
	name = "Prop_BARREL"
	_setup_model()
	_setup_collision()


## Programmatically loads, instantiates, and configures the GLB model
func _setup_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		_model_node = model_scene.instantiate() as Node3D
		_prune_extraneous_nodes(_model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer V5)
		# ======================================================================
		# 1. Scale model at 1.0x (already perfect physical barrel height)
		_model_node.scale = Vector3(1.0, 1.0, 1.0)
		
		# 2. Origin is already perfectly at the base. No vertical offset needed
		_model_node.position = Vector3(0.0, 0.0, 0.0)
		
		# 3. Model is naturally oriented. Rotation set to 0
		_model_node.rotation_degrees = Vector3(0, 0, 0)
		# ======================================================================
		
		add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		push_error("[BarrelEntity] GLB model not found at path: " + MODEL_PATH)


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
	col_shape.name = "BarrelCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.72, 0.90, 0.72)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.45, 0.0) # Aligns to ground level
	add_child(col_shape)


## Public Interaction: Breaks the barrel, spawns wood debris particles, and grants a random provision
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		# 1. Play wood shatter and loot collection spatial SFX (Service Locator)
		AudioService.play_sfx_static("footstep_wood", global_position)
		AudioService.play_sfx_static("loot_pickup")
		
		# 2. Roll a random provision reward: Crop Seeds (18) or Fried Chicken (16)
		var rolled_item_id := 18 if randf() > 0.5 else 16
		inventory.add_item(rolled_item_id, 1)
		
		# Dynamically localized item names
		var reward_name := tr("BLOCK_CROP_SEED") if rolled_item_id == 18 else tr("ITEM_FRIED_CHICKEN")
		
		# 3. Display a gold toast notification on the player's HUD with localized i18n keys
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call(
				"show_quest_notification", 
				tr("NOTIFICATION_BARREL_SHATTERED_HEADER"), 
				tr("NOTIFICATION_FOUND_PREFIX") + " 1x " + reward_name.to_upper()
			)
			
		# 4. Spawn wood debris breaking particles
		_spawn_wood_break_particles()
		
		# 5. Disable collider immediately to prevent double-interactions
		var collider := get_node_or_null("BarrelCollider")
		if is_instance_valid(collider):
			collider.queue_free()
			
		# 6. Smoothly shrink and free the barrel from memory
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)


## Instantiates a temporary, color-matched wood breaking particle system
func _spawn_wood_break_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.5
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.4, 0.3)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.15) # Wood Oak Brown
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		parent_node.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 0.45, 0.0)
		particles.emitting = true
		get_tree().create_timer(0.7).timeout.connect(particles.queue_free)
