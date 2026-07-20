# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/CyberCitizenEntity.gd
# Description: Physical character controller for the tech-noir Cyber Citizen Android.
#              Updated to use native, highly-portable .glb static meshes.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberCitizenEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/cyber.glb"
var gaze_rotation_offset: float = PI
var player: CharacterBody3D

func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 10)
	entity_habitat = 0 
	humanoid_role = 0 
	is_conversational_npc = true
	name = "Entity_CYBER"

func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CyberCitizenAIBehavior.new()

func _setup_graphics_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)

func _get_entity_name_key() -> String:
	return "NPC_NAME_ANDROID"

func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)

func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false 

func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D

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
		
	var _biome_id := BiomeService.get_biome_id_at_position(global_position, get_parent())
	var variety_index := npc_seed % 2
	if variety_index == 0:
		return "DIALOGUE_CYBER_PLAINS_A"
	return "DIALOGUE_CYBER_PLAINS_B"

func _can_socialize() -> bool:
	if is_instance_valid(ai_component):
		return ai_component.current_task != 6 
	return true

func _play_security_scan() -> void:
	_spawn_cyan_laser_particles()

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
	particles.gravity = Vector3(0.0, 0.0, 0.0) 
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.12) 
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.95, 0.95) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.2, -0.2) 
	particles.emitting = true