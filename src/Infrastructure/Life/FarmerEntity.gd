# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Civilians)
# Class: FarmerEntity
# Description: Physical character controller representing an agricultural Farmer NPC. 
#              Schedules modular skeletal animation rigging and dynamically registers 
#              its specialized farming AI behavior.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical body 
#   movement structures, harvesting hoe joints, and conversational interactions.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/farmer/farmer_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Initialize with 3 Hearts of health (6 HP) and terrestrial boundaries
	super(spawn_pos, 6)
	entity_habitat = 0 # Terrestrial
	humanoid_role = 3 # Farmer role
	is_conversational_npc = true
	name = "Entity_FARMER"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Injects and compiles its specific Mixamo animations strategy (fixes T-Pose)
	_build_visual_representation()
	_locate_player()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized farming strategy dynamically into the AI component
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FarmerAIBehavior.new()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "farmer/farmer_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "farmer/farmer_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "farmer/farmer_harvest.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "farmer/farmer_jump.fbx")
	
	# Bind as standard visual representation
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_FARMER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Civilian Green (LSP Compliant)


## Symmetrical Quest Eligibility check
func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false # Farmers are not targeted by campaign milestones currently


# ==============================================================================
# PHYSICAL LIFE-CYCLE & GAZE INTERACTIONS
# ==============================================================================

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	if is_talking:
		velocity = Vector3.ZERO
		super(delta)
		return
		
	super(delta)


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "farmer_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		
		hud.open_dialogue(intro_node, "NPC_NAME_FARMER", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_FARMER_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		4: return "DIALOGUE_FARMER_GLACIERS"   
		7: return "DIALOGUE_FARMER_NEON"       
		_:
			var variety_index := npc_seed % 2
			if variety_index == 0:
				return "DIALOGUE_FARMER_PLAINS_A"
			return "DIALOGUE_FARMER_PLAINS_B"


func _detect_current_biome() -> int:
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator_node: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator_node != null:
			var terrain_noise: FastNoiseLite = generator_node.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(int(round(global_position.x)), int(round(global_position.z)), terrain_noise) as BiomeService.BiomeProfile
				return profile.biome_id
				
	return default_biome_id
