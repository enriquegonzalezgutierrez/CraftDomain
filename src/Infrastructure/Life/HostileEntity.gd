# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/HostileEntity.gd
# Description: Physical character controller representing a hostile Cave Zombie.
#              Updated to use native, highly-portable .glb static meshes.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HostileEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/zombie.glb"
const SPEECH_BUBBLE_SCENE := preload("res://src/Infrastructure/UI/speech_bubble.tscn")

const META_ZOMBIE_STATE = "zombie_local_state"

var player: CharacterBody3D
var _quest_bubble: Node3D
var _model_node: Node3D

const COOLDOWN_GROAN_MIN_SEC: float = 10.0
const COOLDOWN_GROAN_MAX_SEC: float = 22.0

var _groan_timer: float = randf_range(3.0, 10.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	name = "Entity_ZOMBIE"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") 
	
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/zombie") as Node3D
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	_setup_quest_bubble()
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ZombieAIBehavior.new()


func _setup_graphics_representation() -> void:
	if ResourceLoader.exists(BASE_MODEL_PATH):
		_build_glb_representation()
	else:
		_build_procedural_representation()


func _build_glb_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		_build_procedural_representation()
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _build_procedural_representation() -> void:
	var skin_color := Color(0.45, 0.55, 0.42) 
	var shirt_color := Color(0.12, 0.45, 0.55) 
	var pants_color := Color(0.24, 0.22, 0.32) 
	
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(-0.1, 0.275, 0.0), pants_color)
		visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(0.1, 0.275, 0.0), pants_color)
		visual_component.create_box(visual_component.body_bob_node, Vector3(0.44, 0.75, 0.32), Vector3(0, 0.925, 0), shirt_color)
		
		visual_component.head_node = Node3D.new()
		visual_component.head_node.name = "HumanHead"
		visual_component.head_node.position = Vector3(0, 1.3, 0)
		visual_component.body_bob_node.add_child(visual_component.head_node)
		visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.38, 0.35), Vector3(0, 0.19, 0), skin_color)
		visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.15, 0.08), Vector3(0.0, 0.12, -0.21), skin_color * 0.9)


func _setup_quest_bubble() -> void:
	var active_q := QuestService.get_active_quest() as Quest
	if active_q != null and active_q.quest_id == "plains_defender":
		_quest_bubble = SPEECH_BUBBLE_SCENE.instantiate() as Node3D
		_quest_bubble.name = "QuestBubble"
		add_child(_quest_bubble)
		_quest_bubble.call("set_text", tr("BUBBLE_TARGET_MONSTER"))
		_quest_bubble.position = Vector3(0.0, _collision_height + 0.65, 0.0)


func _get_entity_name_key() -> String:
	return "NPC_NAME_ZOMBIE"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


func _get_humanoid_role() -> int:
	return -1 


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.consume_item(15, 1) 
	
	var active_q := QuestService.get_active_quest() as Quest
	if active_q != null and active_q.quest_id == "plains_defender":
		var _un := inv.add_item(active_q.reward_item_index, active_q.reward_quantity)
		if is_instance_valid(player):
			QuestService.complete_active_quest(player)


func _play_zombie_groan() -> void:
	AudioService.play_sfx_static("zombie_groan", global_position)


func _play_spotted_roar(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var look_dir := (player_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	AudioService.play_sfx_static("zombie_groan", global_position)


func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_zombie_combat_physics(delta)


func _process_zombie_combat_physics(_delta: float) -> void:
	var state := 0 
	if has_meta(META_ZOMBIE_STATE):
		state = get_meta(META_ZOMBIE_STATE) as int
		
	match state:
		1: 
			velocity.x = 0.0
			velocity.z = 0.0
			_set_scars_emission(2.8)
		2: 
			_set_scars_emission(0.0)
			if Engine.get_physics_frames() % 10 == 0:
				_spawn_static_glitch_particles()
		3: 
			velocity.x = 0.0
			velocity.z = 0.0
			_set_scars_emission(0.0)
		_:
			_set_scars_emission(0.0)


func _set_scars_emission(energy: float) -> void:
	if is_instance_valid(_model_node):
		_traverse_and_apply_scars_emission(_model_node, energy)


func _traverse_and_apply_scars_emission(node: Node, energy: float) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var mat := node.get_surface_override_material(i) as BaseMaterial3D
			if is_instance_valid(mat):
				mat.emission_enabled = energy > 0.01
				mat.emission = Color(0.95, 0.0, 0.95) 
				mat.emission_energy_multiplier = energy
				
	for child in node.get_children():
		_traverse_and_apply_scars_emission(child, energy)


func _spawn_static_glitch_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_glitch_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.0, 0.95) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.05, 0.0)
	particles.emitting = true


func _configure_glitch_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 4
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.2, 0.05, 0.2)
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.2
	particles.gravity = Vector3(0.0, -4.0, 0.0)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 2.5, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)
			_apply_corruptive_impact_vignette()


func _apply_corruptive_impact_vignette() -> void:
	if is_instance_valid(player):
		player.set("_shake_intensity", 0.35)
		
		var hud := player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("flash_damage_screen"):
			hud.call("flash_damage_screen")


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_groan_timer -= delta
		if _groan_timer <= 0.0:
			_groan_timer = randf_range(COOLDOWN_GROAN_MIN_SEC, COOLDOWN_GROAN_MAX_SEC)
			_play_zombie_groan()