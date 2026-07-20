# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/ObsidianColossusEntity.gd
# Description: Physical character controller for the Obsidian Colossus Act III Boss.
#              REFACTORED: Purged procedural mesh builders to use native .glb.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ObsidianColossusEntity
extends PassiveEntity

const STOMP_DAMAGE: int = 4
const STOMP_RADIUS_SQ: float = 16.0 
const SHAKE_RADIUS_SQ: float = 225.0 
const BOSS_MAX_HEALTH: int = 24

const META_STATE = "colossus_state"

var player: CharacterBody3D
var _model_node: Node3D

func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, BOSS_MAX_HEALTH)
	entity_habitat = 0 
	name = "Entity_OBSIDIAN_COLOSSUS"

func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	
	_model_node = get_node_or_null("Visuals/BodyBobJoint/obsidian_colossus") as Node3D
	if is_instance_valid(_model_node):
		GLBModelSanitizer.sanitize_model(_model_node)
		
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ObsidianColossusAIBehavior.new()

func _get_entity_name_key() -> String:
	return "NPC_NAME_OBSIDIAN_COLOSSUS"

func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 

func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D

func _play_colossus_awaken_growl() -> void:
	AudioService.play_sfx_static("zombie_groan", global_position, 80.0)

func _play_rage_ignite_roar() -> void:
	AudioService.play_sfx_static("gargoyle_screech", global_position, 80.0)
	_spawn_rage_spark_embers()

func _execute_lava_stomp_attack() -> void:
	AudioService.play_sfx_static("footstep_stone", global_position, 80.0)
	_spawn_magma_explosion_particles()
	
	if not is_instance_valid(player):
		return
		
	var dist_sq := global_position.distance_squared_to(player.global_position)
	_apply_stomp_proximity_effects(dist_sq)

func _apply_stomp_proximity_effects(dist_sq: float) -> void:
	if dist_sq < SHAKE_RADIUS_SQ:
		var intensity := clampf(1.0 - (dist_sq / SHAKE_RADIUS_SQ), 0.3, 1.0)
		player.set("_shake_intensity", intensity)
		
	if dist_sq <= STOMP_RADIUS_SQ and player.has_method("take_damage"):
		var push_dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(push_dir.x * 12.0, 5.0, push_dir.z * 12.0)
		player.call("take_damage", STOMP_DAMAGE, knockback)

func take_damage(amount: int, _knockback_force: Vector3, attacker: Node = null) -> void:
	if domain_entity.is_dead:
		return
		
	super(amount, Vector3.ZERO, attacker)
	AudioService.play_sfx_static("hit_sword", global_position)
	_spawn_rage_spark_embers()
	
	var damage_ratio := 1.0 - (float(domain_entity.health) / float(BOSS_MAX_HEALTH))
	var target_emission := 3.0 + (damage_ratio * 4.0)
	
	if is_instance_valid(_model_node):
		_apply_magma_emission(_model_node, target_emission)

func _apply_magma_emission(node: Node, energy: float) -> void:
	if node is MeshInstance3D:
		var mat := node.material_override as StandardMaterial3D
		if is_instance_valid(mat) and mat.emission_enabled and mat.emission == Color(1.0, 0.35, 0.0):
			mat.emission_energy_multiplier = energy
			
	for child in node.get_children():
		_apply_magma_emission(child, energy)

func _drop_loot(inv: IInventory) -> void:
	inv.add_item(39, 3)
	inv.add_item(15, 2)

func _physics_tick(_delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var state := 0
	if has_meta(META_STATE):
		state = get_meta(META_STATE) as int
		
	if state == 2: 
		if Engine.get_physics_frames() % 16 == 0:
			_spawn_rage_spark_embers()

func _spawn_magma_explosion_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_magma_particle_properties(particles)
	_configure_magma_mesh_material(particles)
	
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0.2, 0.2, 0.2)
	particles.emitting = true

func _configure_magma_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 24
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.7
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_radius = 2.0
	particles.emission_ring_inner_radius = 1.0
	particles.emission_ring_height = 0.1
	particles.emission_ring_axis = Vector3.UP
	particles.direction = Vector3.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)

func _configure_magma_mesh_material(particles: CPUParticles3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.0) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)

func _spawn_rage_spark_embers() -> void:
	var particles := CPUParticles3D.new()
	_configure_rage_particle_properties(particles)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.0) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.position = Vector3(0.0, 2.0, 0.0)
	particles.emitting = true

func _configure_rage_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0