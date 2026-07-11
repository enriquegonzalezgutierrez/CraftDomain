# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Civilians)
# Class: CyberCitizenEntity
# Description: Physical character controller for the tech-noir Cyber Citizen Android.
#              Delegates all paved road tracking, security rotations, and 
#              diagnostic laser triggers to the decoupled CyberCitizenAIBehavior 
#              strategy, managing unshaded compile-free laser scanning particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   movement, custom mesh alignments, and laser scan visual feedback.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# - Dependency Inversion Principle (DIP): Injects the CyberCitizenAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/cyber/cyber_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Androids spawn with 5 Hearts of health (10 HP) and terrestrial boundaries
	super(spawn_pos, 10)
	entity_habitat = 0 # Terrestrial
	humanoid_role = 0 # Villager role proxy
	is_conversational_npc = true
	name = "Entity_CYBER"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Cyber Citizen Android AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CyberCitizenAIBehavior.new()


## Binds the Skeletal strategy dynamically and registers FBX animation tracks
func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "cyber/cyber_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "cyber/cyber_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "cyber/cyber_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "cyber/cyber_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_ANDROID"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Civilian Green (LSP Compliant)


## Symmetrical Quest Eligibility check
func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false # Androids are not targeted by campaign milestones currently


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


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

## Visual Laser Scan: Spawns high-intensity data data rays straight forward
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
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.2) # Chest scan origin
	particles.emitting = true
