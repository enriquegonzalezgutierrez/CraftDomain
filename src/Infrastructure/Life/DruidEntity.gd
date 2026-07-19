# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/DruidEntity.gd
# Description: Physical character controller for the forest guardian Druid.
#              Provides specialized state behaviors and conversational dialogs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DruidEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/druid/druid_base.glb"
var gaze_rotation_offset: float = PI


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 0 
	humanoid_role = 5 
	is_conversational_npc = true
	name = "Entity_DRUID"


func _ready() -> void:
	super()
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = DruidAIBehavior.new()


func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("anim_idle_path", ANIM_DIR + "druid/druid_idle.glb")
	strategy.set("anim_walk_path", ANIM_DIR + "druid/druid_walk.glb")
	strategy.set("anim_jump_path", ANIM_DIR + "druid/druid_jump.glb")
	
	visual_representation = strategy as IEntityVisualRepresentation
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_entity_name_key() -> String:
	return "NPC_NAME_DRUID"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false 


func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_DRUID", self)


func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	var _biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	var variety_index := npc_seed % 2
	if variety_index == 0:
		return "DIALOGUE_DRUID_PLAINS_A"
	return "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	if is_instance_valid(ai_component):
		return ai_component.current_task != 6 
	return true


func _play_healing_visuals(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 12 == 0:
		_spawn_magical_heal_particle(target_node.global_position)


func _spawn_magical_heal_particle(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.55
	
	var direction_vec := (target_pos - global_position).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = direction_vec
	particles.spread = 25.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -1.0, 0.0) 
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.95, 0.35) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 1.1, 0.0)
		particles.emitting = true
