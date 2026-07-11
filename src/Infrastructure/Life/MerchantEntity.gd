# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Civilians)
# Class: MerchantEntity
# Description: Physical character controller for the Village Merchant NPC.
#              Delegates all marketplace shop-tending and nighttime shelter
#              coin counting to the decoupled MerchantAIBehavior strategy,
#              managing visual glistening metallic gold coin particles on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, custom mesh alignments, and gold coin visual particles.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# - Dependency Inversion Principle (DIP): Injects the MerchantAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/merchant/merchant_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Keep base health matching 3 Hearts (6 HP) and terrestrial boundaries
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
	humanoid_role = 1 # Merchant role
	is_conversational_npc = true
	name = "Entity_MERCHANT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Injects and compiles its specific Mixamo animations strategy (fixes T-Pose)
	_build_visual_representation()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Merchant business AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MerchantAIBehavior.new()


## Binds the Skeletal strategy dynamically and registers FBX animation tracks
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "merchant/merchant_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "merchant/merchant_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "merchant/merchant_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "merchant/merchant_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_MERCHANT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Civilian Green (LSP Compliant)


## Symmetrical Quest Eligibility check
func _is_eligible_for_quest(quest_id: String) -> bool:
	return quest_id == "fuel_fryer"


func _can_socialize() -> bool:
	# Socialize is disabled during nighttime accounting counting
	var is_night: bool = CelestialService.is_night_time_static()
	return not is_night


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueService.get_dialogue_node("merchant_intro")
		if intro_node == null:
			DialogueRegistry.initialize_dialogue_database()
			intro_node = DialogueService.get_dialogue_node("merchant_intro")
			
		if intro_node != null:
			hud.open_dialogue(intro_node, "NPC_NAME_MERCHANT", self)


# ==============================================================================
# TACTICAL PRESENTATION & COIN COUNTING EFFECTS
# ==============================================================================

## Visual Gold Counting: Spawns continuous glistening golden spark coins
## Note: Invoked via reflective calls by the MerchantAIBehavior strategy
func _play_counting_coins() -> void:
	_spawn_golden_coin_particles()


## Spawns glittering physical-looking gold flakes in front of palms (Compile-Free CPU)
func _spawn_golden_coin_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.12, 0.04, 0.12)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 20.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -9.8, 0.0) # Gravity pulls coins down to palms
	
	# Gold color-shards representing coin units
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2) # Warm Gold
	mat.roughness = 0.15 # Metallic specular reflection
	mat.metallic = 0.9
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 1.3
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.4, -0.2) # Held right in front of chest
	particles.emitting = true
