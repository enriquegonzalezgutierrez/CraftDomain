# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: OctopusEntity
# Description: Physical character controller for the aquatic Octopus.
#              It delegates all timed jet propulsions, marine gliding, and 
#              defensive ink-spraying to the decoupled OctopusAIBehavior strategy,
#              managing visual dark ink particles and bubble audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and underwater ink spray visual particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying on its parent physics process and signals.
# - Dependency Inversion Principle (DIP): Injects the OctopusAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/OctopusEntity.gd
# ==============================================================================
class_name OctopusEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Octopus spawns with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_OCTOPUS"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()
	
	# Programmatically instantiates NPCAIComponent if missing from old scenes
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Octopus aquatic pulsing AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = OctopusAIBehavior.new()


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
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

## Returns int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
func _get_habitat() -> int:
	return 2 # Equivalent to MobRegistry.Habitat.AQUATIC


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Sand Block (acting as granular sediment)
	inv.add_item(7, 1)


func _is_avian() -> bool:
	return true # Activates slight procedural swimming tilts


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL PRESENTATION & AQUATIC DEFENSIVE INK SPRAY
# ==============================================================================

## Visual Ink Spray: Spawns thick unshaded charcoal cloud particles to blind threats
## Note: Invoked via reflective calls by the OctopusAIBehavior strategy
func _play_ink_spray() -> void:
	_spawn_black_ink_shroud()


## Instantiates dense unshaded black box meshes that drift slowly underwater (Compile-Free CPU)
func _spawn_black_ink_shroud() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 1.2 # Shroud lingers in currents
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	particles.direction = Vector3(0.0, 0.2, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -0.4, 0.0) # Slow sink in dense water
	
	# Charcoal-black box particles representing the ink mass
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.07) # Thick deep abisal Black
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Add to world parent node to prevent particles moving with the octopus
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 0.2, 0.0)
		particles.emitting = true
		
		# Symmetrical safety cleanup direct connection
		get_tree().create_timer(1.3).timeout.connect(particles.queue_free)
