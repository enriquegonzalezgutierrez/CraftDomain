# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: CyberCitizenEntity
# Description: Physical character controller for the tech-noir Cyber Citizen Android.
#              It delegates all paved road tracking, security rotations, and 
#              diagnostic lasers triggers to the decoupled CyberCitizenAIBehavior 
#              strategy, managing unshaded compile-free laser scanning particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   movement, custom mesh alignments, and laser scan visual feedback.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# BUG FIX:
# - Removed redundant `_setup_floating_bubble()` override, resolving the 
#   "speech bubble at the feet" bug by letting PassiveEntity manage height.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/CyberCitizenEntity.gd
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/cyber/cyber_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity and lasers.
# ==============================================================================
var gaze_rotation_offset: float = PI

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Androids spawn with 5 Hearts of health (10 HP)
	super(spawn_pos, 10)
	name = "Entity_CYBER"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Cyber Citizen Android AI strategy dynamically on ready,
	# completely overriding the default generic civilian schedules.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CyberCitizenAIBehavior.new()


## Binds the Skeletal strategy dynamically to avoid static compiler circular dependency locks
func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(0.8856, 0.8856, 0.8856))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	strategy.set("anim_idle_path", ANIM_DIR + "cyber/cyber_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "cyber/cyber_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "cyber/cyber_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "cyber/cyber_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_humanoid_role() -> int:
	return 0 # Classified as VILLAGER for schedule loops


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "cyber_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		hud.open_dialogue(intro_node, "NPC_NAME_ANDROID", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night: 
		return "DIALOGUE_CYBER_NIGHT"
	return "DIALOGUE_CYBER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_CYBER_PLAINS_B"


func _can_socialize() -> bool:
	# Socialize is disabled during diagnostic sweeps
	if is_instance_valid(ai_component):
		return ai_component.current_task != 6 # TASK_WORKING (Scanning)
	return true


# ==============================================================================
# TACTICAL PRESENTATION & CYBER LASER DIAGNOSTICS
# ==============================================================================

## Visual Laser Scan: Spawns high-intensity data rays straight forward
## Note: Invoked via reflective calls by the CyberCitizenAIBehavior strategy
func _play_security_scan() -> void:
	_spawn_cyan_laser_particles()


## Spawns elongated unshaded data rays from chest scanner level (Compile-Free CPU)
func _spawn_cyan_laser_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.35
	
	# Determine directional heading
	var forward_dir := Vector3.FORWARD
	if is_instance_valid(ai_component):
		forward_dir = ai_component.wander_direction
		
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.08, 0.08, 0.12)
	particles.direction = forward_dir
	particles.spread = 15.0
	particles.initial_velocity_min = 4.5
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0.0, 0.0, 0.0) # Zero gravity laser beam!
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.12) # High-precision laser shards
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.95, 0.95) # Emissive laser Cyan!
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.2) # Chest scan origin
	particles.emitting = true
	
	# Safe memory cleanup direct connection
	get_tree().create_timer(0.45).timeout.connect(particles.queue_free)
