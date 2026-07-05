# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing an interactive Ancient Ritual Stone.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D visual assembly, collision setup, and interactive healing transactions.
#              - Liskov Substitution Principle (LSP): Extends StaticBody3D cleanly 
#                to act as a physical collidable obstacle in the world.
#              - Dependency Inversion Principle (DIP): Heals the player's entity 
#                strictly through the VoxelEntity contract.
# INTERACTIVE BLESSING MECHANIC (V5 Telemetry):
#              - Total model height is 0.663m. Scaled by 3.77x to achieve a 
#                realistic majestic monolith height of ~2.5m.
#              - Model origin is centered. Raised the model Y-position by +1.191m 
#                to anchor its stone base perfectly flat on the ground plane.
#              - Right-clicking the stone heals the player instantly to max health,
#                triggering a 20-second cooldown. Shows a countdown if clicked while dormant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/RitualStoneEntity.gd
# ==============================================================================
class_name RitualStoneEntity
extends StaticBody3D

const MODEL_PATH := "res://assets/models/decorations/ritual_stone.glb"

# Visual and physical node references
var _model_node: Node3D
var _bubble: Node3D

# Cooldown state tracking
var _cooldown_timer: float = 0.0
const COOLDOWN_DURATION: float = 20.0


func _ready() -> void:
	name = "Prop_RITUAL_STONE"
	_setup_model()
	_setup_collision()
	_setup_floating_bubble()


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_cooldown_timer = 0.0
			_update_bubble_text("READY")


## Programmatically loads, instantiates, and configures the GLB model
func _setup_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		# Fixed Naming Typo: Assigns directly to the class-member variable
		_model_node = model_scene.instantiate() as Node3D
		_prune_extraneous_nodes(_model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer V5)
		# ======================================================================
		# 1. Scale model by 3.77x to increase height from 0.663m to ~2.5m
		_model_node.scale = Vector3(3.77, 3.77, 3.77)
		
		# 2. Origin is centered. Raise Y by +1.191m to anchor the bottom
		#    stone base perfectly flat on the ground plane
		_model_node.position = Vector3(0.0, 1.191, 0.0)
		
		# 3. Corrected the sideways orientation mesh bug. Applied -90 degrees
		_model_node.rotation_degrees = Vector3(0, -90, 0)
		# ======================================================================
		
		add_child(_model_node)
		_register_glb_materials(_model_node)
	else:
		push_error("[RitualStoneEntity] GLB model not found at path: " + MODEL_PATH)


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
			# Set a glowing turquoise emission color to indicate ancient magic!
			new_mat.emission_enabled = true
			new_mat.emission = Color(0.0, 0.85, 0.85)
			new_mat.emission_energy_multiplier = 0.8
			
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
	col_shape.name = "StoneCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.5, 2.5, 1.5)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 1.25, 0.0) # Aligns to ground level
	add_child(col_shape)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.position = Vector3(0.0, 2.8, 0.0) # Floats above the monolith
		_update_bubble_text("BLESSING")


func _update_bubble_text(msg: String) -> void:
	if is_instance_valid(_bubble):
		_bubble.call("set_text", msg)


## Public Interaction: Grants full healing instantly and triggers active cooldown
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var entity_domain := player_node.get("domain_entity") as VoxelEntity
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(entity_domain):
		if _cooldown_timer <= 0.0:
			if entity_domain.health < 3:
				# 1. Restore health to maximum (3 Hearts)
				entity_domain.health = 3
				_cooldown_timer = COOLDOWN_DURATION
				_update_bubble_text("DORMANT")
				
				# 2. Trigger magical chime spatial SFX (Service Locator)
				AudioService.play_sfx_static("block_break", global_position)
				AudioService.play_sfx_static("loot_pickup")
				
				# 3. Flash a golden blessing notification toast
				if is_instance_valid(hud):
					hud.update_health_display(3)
					if hud.has_method("show_quest_notification"):
						hud.call("show_quest_notification", "DIVINE BLESSING", "Restored to full health!")
			else:
				# If the player is already at full health, show a simple tip
				if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
					hud.call("show_quest_notification", "ANCIENT STONE", "You are already at full health!")
					AudioService.play_sfx_static("npc_chat", global_position)
		else:
			# If dormant, show countdown via floating speech bubble
			_update_bubble_text("RESTING (%ds)" % int(ceil(_cooldown_timer)))
			AudioService.play_sfx_static("npc_chat", global_position)
