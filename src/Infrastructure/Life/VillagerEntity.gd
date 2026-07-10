# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: VillagerEntity
# Description: Physical character controller for the Common Villager NPC.
#              Delegates all group gossip circles, social chat sways, and 
#              daytime/nighttime shelter schedules to the decoupled 
#              VillagerAIBehavior strategy, managing visual chat particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and talking visual chat bubble particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base class.
# - Dependency Inversion Principle (DIP): Injects the VillagerAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/villager/villager_base.fbx"

# ==============================================================================
# MIXAMO ORIENTATION COMPENSATOR (OCP SHIELD)
# Compensates for this specific FBX skeleton export direction by adding 180 degrees
# of offset, aligning his face directly with his walking velocity.
# ==============================================================================
var gaze_rotation_offset: float = PI

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Villagers spawn with 3 Hearts of health (3 HP)
	super(spawn_pos, 3)
	name = "Entity_VILLAGER"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Villager social AI strategy dynamically on ready,
	# completely overriding the default generic schedules assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = VillagerAIBehavior.new()


## Binds the Skeletal strategy dynamically and registers FBX animation tracks
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	# Obsolete Transform-Overrides removed! We strictly trust the .tscn editor values now.
	strategy.set("anim_idle_path", ANIM_DIR + "villager/villager_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "villager/villager_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "villager/villager_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "villager/villager_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_nameplate_color() -> Color:
	return Color(1.0, 1.0, 1.0)


func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _get_humanoid_role() -> int:
	return 0 # ProceduralVoxelRepresentation.RoleType.VILLAGER


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	# Socialize is disabled during emergency escapes (night or storms)
	var is_night: bool = CelestialService.is_night_time_static()
	return not is_night


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass # Hostiles do not panic when hit


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Gold Block (ID 37) on death
	inv.add_item(37, 1)


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
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
			if variety_index == 0:
				return "DIALOGUE_VILLAGER_PLAINS_A"
			elif variety_index == 1:
				return "DIALOGUE_VILLAGER_PLAINS_B"
			else:
				return "DIALOGUE_VILLAGER_PLAINS_C"


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


# ==============================================================================
# TACTICAL PRESENTATION & CHATTING PARTICLES
# ==============================================================================

## Visual Gossip: Directs smooth head tilts and triggers talk audio and dialogue particles
## Note: Invoked via reflective calls by the VillagerAIBehavior strategy
func _play_gossip_chatter() -> void:
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.head_node):
		var chat_tween := create_tween()
		var original_rot_x: float = visual_component.head_node.rotation.x
		
		# Happy head nods
		chat_tween.tween_property(visual_component.head_node, "rotation:x", original_rot_x + 0.12, 0.15).set_trans(Tween.TRANS_SINE)
		chat_tween.chain().tween_property(visual_component.head_node, "rotation:x", original_rot_x, 0.15).set_trans(Tween.TRANS_SINE)
		
	# Play meow-murmur voice statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
	
	# Spawn chatting spheres
	_spawn_gossip_dialogue_particles()


## Spawns tiny unshaded cyan bubble blocks that float upwards (Compile-Free CPU)
func _spawn_gossip_dialogue_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 20.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, 1.0, 0.0) # Float upwards
	
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 1.0) # Cozy Cyan bubble chat
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height + 0.15, -0.1) # above forehead level
	particles.emitting = true
