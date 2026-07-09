# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: DruidEntity
# Description: Physical character controller for the forest guardian Druid.
#              It delegates all wildlife scanning, magical spellcasting timers, 
#              and healing triggers to the decoupled DruidAIBehavior strategy,
#              focusing strictly on dialogs, physical translations, and 
#              unshaded compile-free éter particles generation.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, dialogue trees, and magical visual feedback.
# BUG FIX:
# - Removed redundant `_setup_floating_bubble()` override, resolving the 
#   "speech bubble at the feet" bug by letting PassiveEntity manage height.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/DruidEntity.gd
# ==============================================================================
class_name DruidEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/druid/druid_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Druids spawn with 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_DRUID"


func _ready() -> void:
	# Run base class ready lifecycle first to register in 'passives' group
	super()
	
	# Cache components dynamically
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# ==========================================================================
	# T-POSE FIX: INYECTAR LAS ANIMACIONES ESQUELÉTICAS DE MIXAMO
	# ==========================================================================
	_build_visual_representation()
	
	# Inject the specialized Druid magical overwatch AI strategy
	if is_instance_valid(ai_component):
		ai_component.active_behavior = DruidAIBehavior.new()


## Enlaza la estrategia de animación esquelética y carga las pistas FBX
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(1.0, 1.0, 1.0))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	# Load concrete animation tracks
	strategy.set("anim_idle_path", ANIM_DIR + "druid/druid_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "druid/druid_walk.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "druid/druid_jump.fbx")
	
	# Bind as standard visual representation
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


## Concrete Implementation (DIP): Injects the modular Druid Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return 5 # Matches ProceduralVoxelRepresentation.RoleType.DRUID


func _get_habitat() -> int:
	return 0 # 0 = Habitat.TERRESTRIAL


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_DRUID", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	# Socialize is disabled during ritual channeling
	if is_instance_valid(ai_component):
		return ai_component.current_task != 6 # TASK_WORKING (Casting)
	return true


# ==============================================================================
# MAGICAL PRESENTATION & EMERALD ÉTER CASTING
# ==============================================================================

## Visual Magical Spell: Directs look gaze and spawns a stream of healing emerald éter particles
## Note: Invoked via reflective calls by the DruidAIBehavior strategy
func _play_healing_visuals(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
		
	# Throttle particle spawning: spawn particles at 10Hz to prevent clutter and CPU stress
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 12 == 0:
		_spawn_magical_heal_particle(target_node.global_position)


## Spawns a tilled green éter particle packet directed towards the target coordinates
func _spawn_magical_heal_particle(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.55
	
	# Calculate directional trajectory vector pointing to target
	var direction_vec := (target_pos - global_position).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = direction_vec
	particles.spread = 25.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -1.0, 0.0) # Slow drift down
	
	# Bright emerald-green box particles representing botanical éter!
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.95, 0.35) # High-vibrancy botanical green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Extremely fast compile-free
	mesh.material = mat
	particles.mesh = mesh
	
	# Add to world parent node to prevent particles moving with the druid
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		
		# Symmetrical start pos: spawn slightly above hand/báculo (approx 1.1m height)
		particles.global_position = global_position + Vector3(0.0, 1.1, 0.0)
		particles.emitting = true
		
		# Symmetrical safety cleanup direct connection
		get_tree().create_timer(0.65).timeout.connect(particles.queue_free)
