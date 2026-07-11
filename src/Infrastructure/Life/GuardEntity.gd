# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Defenders)
# Class: GuardEntity
# Description: Physical character controller representing a village defender Guard.
#              Schedules modular skeletal animation rigging and dynamically registers 
#              its specialized GuardAIBehavior strategy.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical body 
#   movement structures, sheathed weapon positions, and conversational interactions.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/guard/guard_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Initialize with 5 Hearts of health for elite durability (10 HP) and terrestrial boundaries
	super(spawn_pos, 10)
	entity_habitat = 0 # Terrestrial
	humanoid_role = 2 # Guard role
	is_conversational_npc = true
	name = "Entity_GUARD"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Register in the shared alert network
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.register_defender(self)
	
	# Cache components pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized guard overwatch strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GuardAIBehavior.new()


## Binds the Skeletal strategy dynamically and registers FBX animation tracks
func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "guard/guard_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "guard/guard_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "guard/guard_attack.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "guard/guard_jump.fbx")
	
	# Bind as standard visual representation
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_GUARD"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Symmetrical Protector Green (Friendly)


## Symmetrical Quest Eligibility check
func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false # Guards are not targeted by campaign milestones currently


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	var combat_target: CharacterBody3D = null
	if has_meta(GuardAIBehavior.META_TARGET):
		var target_val: Variant = get_meta(GuardAIBehavior.META_TARGET)
		if typeof(target_val) == TYPE_OBJECT:
			var target_obj: Object = target_val
			if is_instance_valid(target_obj) and target_obj is CharacterBody3D:
				combat_target = target_obj as CharacterBody3D
				
	return combat_target == null


func _is_avian() -> bool:
	return false


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


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
		intro_node.node_id = "guard_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		
		hud.open_dialogue(intro_node, "NPC_NAME_GUARD", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_GUARD_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		4: return "DIALOGUE_GUARD_GLACIERS"   
		7: return "DIALOGUE_GUARD_NEON"       
		_:
			var variety_index := npc_seed % 2
			if variety_index == 0:
				return "DIALOGUE_GUARD_PLAINS_A"
			return "DIALOGUE_GUARD_PLAINS_B"


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
