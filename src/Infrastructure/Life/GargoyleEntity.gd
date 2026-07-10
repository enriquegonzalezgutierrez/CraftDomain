# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GargoyleEntity
# Description: Physical character controller for the hostile nocturnal Gargoyle.
#              Delegates all state machine decisions, chasing vectors, and 
#              attack cooldowns to the decoupled GargoyleAIBehavior strategy, 
#              focusing on physical translations and visual flight animations.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical movement, 
#   gravity damping during active flight, and visual billboarding.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, utilizing inherited dynamic height solvers.
# - Open-Closed Principle (OCP): Nameplate tracking calculations are fully 
#   dynamic, adapting automatically to any scale configured in the .tscn editor.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GargoyleEntity.gd
# ==============================================================================
class_name GargoyleEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# Visual animation and model references
var _animation_time: float = 0.0
var _model_node: Node3D
var _anim_player: AnimationPlayer

# Physical flight configurations (decoupled from decisions)
const SPEED: float = 3.0

# Visual model baseline Y-coordinate (Y-axis origin when stone statue)
const MODEL_BASE_Y: float = 0.8982


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Gargoyles spawn with 6 Hearts of health (high stone defense: 12 HP)
	super(spawn_pos, 12)
	name = "Entity_GARGOYLE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/gargoyle") as Node3D
	
	# ==========================================================================
	# T-POSE & TANGENT FIX: Extract the embedded GLB AnimationPlayer 
	# and apply the material shield to suppress C++ console errors.
	# ==========================================================================
	if is_instance_valid(_model_node):
		_anim_player = _model_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_register_glb_materials(_model_node)
	
	_locate_player()
	
	# Fetch nameplate configurations from inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GargoyleAIBehavior.new()


## Recursively duplicates and sanitizes materials across ALL mesh surfaces (Tangent Shield)
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Multi-Surface Sweep: Sanitize every material index on the mesh
		for i: int in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
				
			if mat is BaseMaterial3D:
				var new_mat := mat.duplicate() as BaseMaterial3D
				# TANGENT WARNING SHIELD
				new_mat.normal_enabled = false
				new_mat.anisotropy_enabled = false
				new_mat.clearcoat_enabled = false
				new_mat.heightmap_enabled = false
				node.set_surface_override_material(i, new_mat)
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15) # Red warning nameplate


func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Stone Block on death
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


## Symmetrical transition updating stone shaders/emission visual overlays
func _set_gargoyle_stone_appearance(is_stone: bool) -> void:
	if is_instance_valid(_model_node):
		_traverse_and_apply_stone_appearance(_model_node, is_stone)


func _traverse_and_apply_stone_appearance(node: Node, is_stone: bool) -> void:
	if node is MeshInstance3D:
		var mat: BaseMaterial3D = node.material_override as BaseMaterial3D
		if is_instance_valid(mat):
			if is_stone:
				mat.albedo_color = Color(0.48, 0.48, 0.50) # Solid grey statue
				mat.roughness = 1.0
			else:
				mat.albedo_color = Color(1.0, 1.0, 1.0) # Restored textures
				mat.roughness = 0.5
				
	for child in node.get_children():
		_traverse_and_apply_stone_appearance(child, is_stone)


## Tactical Action bite: Inflicts damage and applies diagonal knockback
func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


# ==============================================================================
# MAIN GEOMETRIC PRESENTATION & FLIGHT BOBBING OSCILLATION
# ==============================================================================

func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		# Read nocturnal state from metadata safely (DIP)
		var state: int = 0
		if has_meta(GargoyleAIBehavior.META_STATE):
			state = get_meta(GargoyleAIBehavior.META_STATE) as int
		
		if state == 1: # AWAKE / FLYING
			# ==================================================================
			# PLAY FLIGHT ANIMATION
			# ==================================================================
			if is_instance_valid(_anim_player):
				var anims := _anim_player.get_animation_list()
				if anims.size() > 0:
					var target_anim := anims[0] # Grab default GLB animation
					if _anim_player.current_animation != target_anim or not _anim_player.is_playing():
						_anim_player.play(target_anim)
						
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			# Smooth hover bobbing oscillation
			var hover_bob := sin(_animation_time * 5.0) * 0.25
			_model_node.position.y = 2.5 + hover_bob
			
			if is_moving:
				_model_node.rotation.z = sin(_animation_time * 14.0) * 0.18
				_model_node.rotation.x = deg_to_rad(12.0) # Pitch forward
			else:
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
		else: # STONE STATUE (Sits flat on floor)
			# ==================================================================
			# FREEZE ANIMATION (Turned into stone!)
			# ==================================================================
			if is_instance_valid(_anim_player):
				_anim_player.stop() 
				
			_model_node.position.y = lerp(_model_node.position.y, MODEL_BASE_Y, delta * 5.0)
			_model_node.rotation = lerp(_model_node.rotation, Vector3(0.0, deg_to_rad(90.0), 0.0), delta * 5.0)
			
		# ======================================================================
		# UNIVERSAL DYNAMIC NAMEPLATE POSITIONER (OCP / SOLID COMPLIANT)
		# ======================================================================
		if is_instance_valid(_nameplate):
			var relative_offset := _model_node.position.y - MODEL_BASE_Y
			_nameplate.position.y = _collision_height + 0.35 + relative_offset


# ==============================================================================
# UN-THROTTLED PHYSICS ENGINE (GRAVITY AND STEP- avoidance)
# ==============================================================================

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Read state from metadata to calculate physical gravity vectors safely
	var state: int = 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int

	if state == 0: # STONE (Acts as a heavy brick, falls to ground)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
	else: # AWAKE (Active flight neutral Y damping)
		velocity.y = move_toward(velocity.y, 0.0, SPEED * delta)

	# Execute un-throttled physics translation and step-up checks
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)

	move_and_slide()
