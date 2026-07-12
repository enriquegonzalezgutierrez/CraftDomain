# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/FarmerEntity.gd
# Description: Physical character controller representing an agricultural Farmer NPC.
#              DRY biome detection is delegated strictly to BiomeService (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/farmer/farmer_base.fbx"
var gaze_rotation_offset: float = PI
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	humanoid_role = 3 
	is_conversational_npc = true
	name = "Entity_FARMER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FarmerAIBehavior.new()


func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("anim_idle_path", ANIM_DIR + "farmer/farmer_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "farmer/farmer_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "farmer/farmer_harvest.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "farmer/farmer_jump.fbx")
	
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _get_entity_name_key() -> String:
	return "NPC_NAME_FARMER"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false 


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
		
	# Centralized DRY Biome Sensing
	var biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	match biome_id:
		4: return "DIALOGUE_FARMER_GLACIERS"   
		7: return "DIALOGUE_FARMER_NEON"       
		_:
			var variety_index := npc_seed % 2
			if variety_index == 0:
				return "DIALOGUE_FARMER_PLAINS_A"
			return "DIALOGUE_FARMER_PLAINS_B"
