# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive Villager NPC, utilizing the 
#              Strategy pattern to load dynamic animations cleanly.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively civilian
#                dialogue, Price scaling, and variety, delegating rendering to strategy.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Replaced static class reference to 'SkeletalVisualRepresentation' with
#                dynamic 'load()' instantiation, permanently immunizing the engine 
#                against circular compile-time locks.
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/villager/villager_base.fbx"


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_VILLAGER"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Safe and non-duplicate visual compiling (Strategy Pattern)
	_setup_graphics_representation()
	_setup_nameplate_height()


func _setup_graphics_representation() -> void:
	# ==========================================================================
	# BULLETPROOF SHIELD: Load Strategy dynamically to avoid static compiler locks
	# ==========================================================================
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(0.8856, 0.8856, 0.8856))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	strategy.set("anim_idle_path", ANIM_DIR + "villager/villager_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "villager/villager_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "villager/villager_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "villager/villager_jump.fbx")
	
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "lost_bazaar":
		QuestService.complete_active_quest(player_node)
		
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "DIALOGUE_VILLAGER_QUEST_COMPLETE"
		DialogueService.register_node(complete_node)
		
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.open_dialogue(complete_node, "NPC_NAME_VILLAGER", self)
	else:
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			var intro_node := DialogueNode.new()
			intro_node.node_id = "villager_intro_temp"
			intro_node.text = _select_procedural_greeting_key()
			hud.open_dialogue(intro_node, "NPC_NAME_VILLAGER", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_VILLAGER_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		0: return "DIALOGUE_VILLAGER_OCEAN"     
		4: return "DIALOGUE_VILLAGER_GLACIERS"   
		7: return "DIALOGUE_VILLAGER_NEON"        
		8: return "DIALOGUE_VILLAGER_SWAMP"       
		9: return "DIALOGUE_VILLAGER_CLOUD"       
		_:
			var variety_index := npc_seed % 3
			match variety_index:
				0: return "DIALOGUE_VILLAGER_PLAINS_A"
				1: return "DIALOGUE_VILLAGER_PLAINS_B"
				_: return "DIALOGUE_VILLAGER_PLAINS_C"


func _detect_current_biome() -> int:
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(int(round(global_position.x)), int(round(global_position.z)), terrain_noise)
				return profile.biome_id
	return default_biome_id


func _can_socialize() -> bool:
	return true
