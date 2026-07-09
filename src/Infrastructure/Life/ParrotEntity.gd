# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: ParrotEntity
# Description: Physical character controller for the flying Tropical Parrot.
#              It delegates all thermal soaring, landing scans, and leaf perching
#              to the decoupled AvianAIBehavior strategy, managing wing flap
#              oscillations and resolving C++ double connection signals errors.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, coordinate-facing rotations, and wing flap sways.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying on parent signal connections polymorphically.
# - Dependency Inversion Principle (DIP): Injects the AvianAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# BUG FIX:
# - Added `_register_glb_materials()` to strip tangent and normal-map rendering
#   requirements from the GLB mesh, completely suppressing the Godot C++ shader 
#   warning spam in the console.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ParrotEntity.gd
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

# Visual animation trackers
var _animation_time: float = 0.0
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Parrots spawn with 1 Heart of health (2 HP, fragile)
	super(spawn_pos, 2)
	name = "Entity_PARROT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Cache the 3D model child node to apply flight sways in real-time
	_model_node = get_node_or_null("Visuals/BodyBobJoint/parrot") as Node3D
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	if is_instance_valid(_model_node):
		_register_glb_materials(_model_node)
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Avian flight/perch AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AvianAIBehavior.new()


## Recursively duplicates materials to prevent material-sharing leaks and tangent errors
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0)
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0)
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	if is_instance_valid(_nameplate):
		# Aligns nameplate correctly above the flight height baseline
		_nameplate.position.y = 1.05


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft avian meat proxy)
	inv.add_item(16, 1)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================
func _is_avian() -> bool:
	return true


func _can_fly() -> bool:
	return true # Bypasses gravity void-clamping inside base class PassiveEntity


func _can_socialize() -> bool:
	return true


# ==============================================================================
# PROCEDURAL FLIGHT ANIMATIONS & ALTIMETRICAL ROTATIONS
# ==============================================================================
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		# Read flight state from metadata safely (DIP)
		var flight_state := 0 # Default STATE_SOARING
		if has_meta(AvianAIBehavior.META_STATE):
			flight_state = get_meta(AvianAIBehavior.META_STATE) as int
			
		if flight_state == 2: # STATE_PERCHED (Resting flat on top of leaves)
			_model_node.position.y = 0.0
			_model_node.rotation.z = 0.0
			_model_node.rotation.x = 0.0
			
			# Synchronize Nameplate's height flatly above leaves
			if is_instance_valid(_nameplate):
				_nameplate.position.y = 0.65
		else:
			# FLIGHT FLAPPING ACTIVE STATE
			_animation_time += delta
			
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			# Smooth thermal hover bobbing
			var hover_bob := sin(_animation_time * 3.5) * 0.22
			
			var is_showcase := false
			var current_node := get_parent()
			while current_node != null:
				if current_node is SubViewport and current_node.name != "root":
					is_showcase = true
					break
				current_node = current_node.get_parent()
				
			if is_showcase:
				_model_node.position.y = 0.0 # Sinks to floor inside showroom
			else:
				_model_node.position.y = hover_bob
			
			if is_moving:
				# High-frequency Z-axis rotation roll to simulate flapping wings
				_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
				_model_node.rotation.x = deg_to_rad(12.0) # Pitch forward
			else:
				# Slow resting glide sways
				_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
				_model_node.rotation.x = 0.0
				
			# Synchronize Nameplate's height dynamically with flight bobbing sways!
			if is_instance_valid(_nameplate):
				_nameplate.position.y = _model_node.position.y + 0.85
