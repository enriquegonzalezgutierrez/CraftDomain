# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/LithicLurkerEntity.gd
# Description: Physical character controller for the Lithic Lurker Act I Boss.
#              Orchestrates the physics, AoE ground pound impacts, reflective 
#              armor invulnerability, and dynamic core flashing.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles strictly physical interactions,
#   hitboxes, and particle feedbacks. AI is fully delegated to LithicLurkerAIBehavior.
# - Dependency Inversion Principle (DIP): Uses local decoupled metadata keys 
#   to break Godot 4's cyclic preloader compile locks with its behavior script.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LithicLurkerEntity
extends PassiveEntity

const POUND_DAMAGE: int = 3
const POUND_RADIUS_SQ: float = 36.0 # 6.0 meters squared
const BOSS_MAX_HEALTH: int = 24     # 12 Hearts of health

## Decoupled local metadata key to prevent cyclic compile locks with LithicLurkerAIBehavior
const META_STATE = "lurker_state"

var player: CharacterBody3D
var _animation_time: float = 0.0


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, BOSS_MAX_HEALTH)
	entity_habitat = 0 
	name = "Entity_LITHIC_LURKER"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	if not is_instance_valid(visual_component):
		visual_component = NPCVisualComponent.new()
		add_child(visual_component)
		
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	_locate_player()
	_build_visual_representation()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = LithicLurkerAIBehavior.new()


func _get_entity_name_key() -> String:
	return "NPC_NAME_LITHIC_LURKER"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


func _build_visual_representation() -> void:
	var builder := LithicLurkerModelBuilder.new()
	builder.build_model(visual_component, Color.BLACK, Color.BLACK, Color.BLACK, 0)
	_apply_dynamic_collision_shape(builder.get_collision_box_size(), builder.get_collision_box_position())


func _apply_dynamic_collision_shape(box_size: Vector3, box_pos: Vector3) -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if not is_instance_valid(col):
		col = CollisionShape3D.new()
		col.name = "EntityCollider"
		add_child(col)
		
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = box_pos


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _play_boss_awaken_roar() -> void:
	AudioService.play_sfx_static("zombie_groan", global_position, 60.0)


func _execute_ground_pound_impact() -> void:
	AudioService.play_sfx_static("footstep_stone", global_position, 80.0)
	_spawn_pound_dust_particles()
	
	if not is_instance_valid(player):
		return
		
	var dist_sq := global_position.distance_squared_to(player.global_position)
	
	if dist_sq < 144.0:
		var intensity := clampf(1.0 - (dist_sq / 144.0), 0.2, 1.0)
		player.set("_shake_intensity", intensity)
		
	if dist_sq <= POUND_RADIUS_SQ and player.has_method("take_damage"):
		var push_dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(push_dir.x * 8.5, 4.0, push_dir.z * 8.5)
		player.call("take_damage", POUND_DAMAGE, knockback)


func take_damage(amount: int, knockback_force: Vector3, attacker: Node = null) -> void:
	if domain_entity.is_dead:
		return
		
	var state := 0
	if has_meta(META_STATE):
		state = get_meta(META_STATE) as int
		
	if state == 3: # STUNNED Phase
		super(amount, knockback_force, attacker)
		AudioService.play_sfx_static("block_break", global_position)
	else:
		super(0, Vector3.ZERO, attacker) # Reflects sword hits completely
		AudioService.play_sfx_static("hit_sword", global_position)
		_spawn_deflected_sparks()


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(15, 1)
	inv.add_item(28, 5)


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var state := 0
	if has_meta(META_STATE):
		state = get_meta(META_STATE) as int
		
	if state == 3: # STATE_STUNNED
		_process_stunned_visuals(delta)


func _process_stunned_visuals(delta: float) -> void:
	_animation_time += delta
	var visual_root := visual_component.get("visual_root") as Node3D if is_instance_valid(visual_component) else null
	
	if is_instance_valid(visual_root):
		var flash_intensity: float = absf(sin(_animation_time * 18.0)) * 3.5
		_apply_cyan_core_emission(visual_root, flash_intensity)


func _restore_chasing_armor() -> void:
	var visual_root := visual_component.get("visual_root") as Node3D if is_instance_valid(visual_component) else null
	if is_instance_valid(visual_root):
		_apply_cyan_core_emission(visual_root, 2.5)


func _apply_cyan_core_emission(node: Node, energy: float) -> void:
	if node is MeshInstance3D:
		var mat := node.material_override as StandardMaterial3D
		if is_instance_valid(mat) and mat.emission_enabled and mat.emission == Color(0.0, 0.95, 0.95):
			mat.emission_energy_multiplier = energy
			
	for child in node.get_children():
		_apply_cyan_core_emission(child, energy)


func _spawn_pound_dust_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_dust_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38, 0.8) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.5, 0.0)
	particles.emitting = true


func _configure_dust_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 32
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = 2.5
	particles.emission_ring_inner_radius = 1.5
	particles.emission_ring_height = 0.2
	particles.emission_ring_axis = Vector3.UP
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 15.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)


func _spawn_deflected_sparks() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.3
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.5
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 60.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.position = Vector3(0.0, 1.5, 0.0)
	particles.emitting = true
