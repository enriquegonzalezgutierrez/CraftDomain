# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Civilians)
# Class: DruidEntity
# Description: Physical character controller for the forest guardian Druid.
#              Delegates all wildlife scanning, magical spellcasting timers, 
#              and healing triggers to the decoupled DruidAIBehavior strategy.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, dialogue trees, and magical visual feedback.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
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
	# Druids spawn with 4 Hearts of health (8 HP) and terrestrial boundaries
	super(spawn_pos, 8)
	entity_habitat = 0 # Terrestrial
	humanoid_role = 5 # Druid role
	is_conversational_npc = true
	name = "Entity_DRUID"


func _ready() -> void:
	# Run base class ready lifecycle first to register in 'passives' group
	super()
	
	# Cache components dynamically
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	# Inject the specialized Druid magical overwatch AI strategy
	if is_instance_valid(ai_component):
		ai_component.active_behavior = DruidAIBehavior.new()


## Binds the Skeletal strategy dynamically and registers FBX animation tracks
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "druid/druid_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "druid/druid_walk.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "druid/druid_jump.fbx")
	
	# Bind as standard visual representation
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_DRUID"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Civilian Green (LSP Compliant)


## Symmetrical Quest Eligibility check
func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false # Druids are not targeted by campaign milestones currently


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
		
	# Throttle particle spawning (10Hz) to prevent clutter and CPU stress
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
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	# Add to world parent node to prevent particles moving with the druid
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		
		# Symmetrical start pos: spawn slightly above hand/báculo (approx 1.1m height)
		particles.global_position = global_position + Vector3(0.0, 1.1, 0.0)
		particles.emitting = true
