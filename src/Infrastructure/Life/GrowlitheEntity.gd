# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: GrowlitheEntity
# Description: Physical character controller for the loyal canine Growlithe.
#              It delegates all magma sniffing, territorial heat seeking, and
#              fiery barks to the decoupled CanineAIBehavior strategy, managing
#              visual incandescent flame embers and bark audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and snout fire bark visual particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the CanineAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GrowlitheEntity.gd
# ==============================================================================
class_name GrowlitheEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Growlithes spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_GROWLITHE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target scans
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Growlithe canine AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CanineAIBehavior.new()


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
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as raw fire-meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL FLAME BARKING & MAGMA SNIFFING PRESENTATION
# ==============================================================================

## Visual Flame Bark: Plays alert bark audio and spawns glowing fire embers
## Note: Invoked via reflective calls by the CanineAIBehavior strategy
func _play_flame_bark() -> void:
	# Playful vertical hop
	velocity.y = 2.8
	
	# Play meow-bark alert sound statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
	
	# Emit fiery embers from snout
	_spawn_flame_bark_particles()


## Spawns tiny unshaded orange fire boxes that drift upwards (Compile-Free CPU)
func _spawn_flame_bark_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 10
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.55
	
	# Calculate directional forward heading
	var forward_dir := Vector3.FORWARD
	if is_instance_valid(ai_component):
		forward_dir = ai_component.wander_direction
		
	# Tilt trajectory vector slightly upwards
	forward_dir = (forward_dir + Vector3(0.0, 0.4, 0.0)).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.10
	particles.direction = forward_dir
	particles.spread = 20.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, 2.5, 0.0) # Hot embers float upwards!
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04) # Tiny hot ember units
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.0) # Bright orange
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.15) # Snout level
	particles.emitting = true
	
	# Safe memory cleanup डायरेक्ट connection
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)
