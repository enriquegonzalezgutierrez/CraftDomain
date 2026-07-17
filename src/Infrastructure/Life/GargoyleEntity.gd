# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/GargoyleEntity.gd
# Description: Physical character controller for the hostile nocturnal Gargoyle.
#              Manages day/night petrification state transitions and flight physics.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GargoyleEntity
extends PassiveEntity

const SPEED: float = 3.0
const MODEL_BASE_Y: float = 0.8982

var player: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer

var _animation_time: float = 0.0
var _model_base_rot: Vector3 = Vector3.ZERO


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 12)
	entity_habitat = 0 
	name = "Entity_GARGOYLE"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/gargoyle") as Node3D
	
	if is_instance_valid(_model_node):
		_anim_player = _model_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_model_base_rot = _model_node.rotation
		GLBModelSanitizer.sanitize_model(_model_node)
		
	_locate_player()
	_execute_lifecycle_initialization()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GargoyleAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_GARGOYLE"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


func _is_avian() -> bool:
	return true 


func _can_fly() -> bool:
	var state := 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int
	return state == 1 


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1)


func _set_gargoyle_stone_appearance(is_stone: bool) -> void:
	if is_instance_valid(_model_node):
		_traverse_and_apply_stone_appearance(_model_node, is_stone)


func _traverse_and_apply_stone_appearance(node: Node, is_stone: bool) -> void:
	if node is MeshInstance3D:
		var mat := node.material_override as BaseMaterial3D
		if is_instance_valid(mat):
			if is_stone:
				mat.albedo_color = Color(0.48, 0.48, 0.50)
				mat.roughness = 1.0
			else:
				mat.albedo_color = Color(1.0, 1.0, 1.0)
				mat.roughness = 0.5
				
	for child in node.get_children():
		_traverse_and_apply_stone_appearance(child, is_stone)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var state := 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int
		
	if state == 1: 
		_process_gargoyle_flight_physics(delta)
	else: 
		velocity.x = 0.0
		velocity.z = 0.0


func _process_gargoyle_flight_physics(delta: float) -> void:
	_animation_time += delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := flat_velocity.length_squared() > 0.1
	
	var target_y := 2.5 + sin(_animation_time * 4.0) * 0.22
	velocity.y = lerp(velocity.y, (target_y - _model_node.position.y) * 5.0, delta * 6.0)
	
	if is_moving:
		if Engine.get_physics_frames() % 12 == 0:
			_spawn_basalt_dust_particles()
			AudioService.play_sfx_static("footstep_stone", global_position)


func _spawn_basalt_dust_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.6, 0.1, 0.4)
	particles.direction = Vector3.DOWN
	particles.spread = 15.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38, 0.7) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
			
	if is_instance_valid(_model_node):
		var state := 0
		if has_meta(GargoyleAIBehavior.META_STATE):
			state = get_meta(GargoyleAIBehavior.META_STATE) as int
		
		if state == 1: 
			if is_instance_valid(_anim_player):
				var anims := _anim_player.get_animation_list()
				if anims.size() > 0:
					var target_anim: String = anims[0]
					if _anim_player.current_animation != target_anim or not _anim_player.is_playing():
						_anim_player.play(target_anim)
						
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			var hover_bob := sin(_animation_time * 5.0) * 0.25
			_model_node.position.y = 2.5 + hover_bob
			
			if is_moving:
				_model_node.rotation.z = sin(_animation_time * 16.0) * 0.18
				_model_node.rotation.x = deg_to_rad(12.0)
			else:
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
		else: 
			if is_instance_valid(_anim_player):
				_anim_player.stop()
				
			_model_node.position.y = lerp(_model_node.position.y, MODEL_BASE_Y, delta * 5.0)
			_model_node.rotation = _model_node.rotation.lerp(_model_base_rot, delta * 5.0)
			
		if is_instance_valid(_nameplate):
			var relative_offset := _model_node.position.y - MODEL_BASE_Y
			_nameplate.position.y = _collision_height + 0.35 + relative_offset


func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	var state := 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int

	if state == 0: 
		_process_petrified_state(delta)
	else: 
		_process_awakened_state(delta)

	_apply_absolute_boundary_forcefield(delta)
	_process_timers_and_gaze(delta)
	move_and_slide()


func _process_petrified_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Corrected physical solution: Apply the downward snap to the gargoyle physics
		velocity.y = -1.2


func _process_awakened_state(delta: float) -> void:
	velocity.y = move_toward(velocity.y, 0.0, SPEED * delta)
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)


func _process_timers_and_gaze(delta: float) -> void:
	quest_check_timer -= delta
	if quest_check_timer <= 0.0:
		quest_check_timer = 0.5
		_update_quest_bubble_state()
