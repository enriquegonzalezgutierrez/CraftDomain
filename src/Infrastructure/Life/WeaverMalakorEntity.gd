# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/WeaverMalakorEntity.gd
# Description: Physical character controller for Weaver Malakor, the final campaign 
#              boss (Act IV). Coordinates gravity inversions, dynamic arena 
#              voxel fracturing, and unshaded static laser beams.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical combat 
#   impacts, raycasting line-sights, and particle setups. Decisions fully delegated to AI.
# - Liskov Substitution Principle (LSP): Fully compatible with the base class 
#   contracts, migrating cleanly to the "hostiles" group.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeaverMalakorEntity
extends PassiveEntity

const BEAM_DAMAGE: int = 2
const ARENA_FLOOR_Y: int = 21
const BOSS_MAX_HEALTH: int = 24 # Final Boss health pool

var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, BOSS_MAX_HEALTH)
	entity_habitat = 0 # Terrestrial
	name = "Entity_WEAVER_MALAKOR"


func _ready() -> void:
	# Register in the hostile group for O(1) targeting loops
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_build_visual_representation()
	_locate_player()
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_OBSIDIAN_COLOSSUS" # Fallback key or "NPC_NAME_MALAKOR" in translation packs


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) # Hostile Boss Crimson Red


## OCP Compliance: Bypasses the VoxelModelRegistry Enums to construct the 
## boss directly, keeping the system closed to modifications.
func _build_visual_representation() -> void:
	var builder := WeaverMalakorModelBuilder.new()
	
	# Pass dummy colors (the builder uses hardcoded boss palette internally)
	builder.build_model(visual_component, Color.BLACK, Color.BLACK, Color.BLACK, 0)
	
	# Adjust dynamic physical hitboxes based on the builder's specifications
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


# ==============================================================================
# BOSS MECHANICS & IMPACT HANDLING (SRP Compliant)
# ==============================================================================

## Called by WeaverMalakorAIBehavior when entering CHASING state from SLEEP
func _play_malakor_awaken_voice() -> void:
	AudioService.play_sfx_static("gargoyle_screech", global_position, 80.0)


## Called by WeaverMalakorAIBehavior during Phase 1: Fires unshaded static laser
func _fire_static_laser_beam(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node): return
	AudioService.play_sfx_static("cyber_laser", global_position, 60.0)
	
	# Linecast check: Verify if the laser is obstructed by solid player covers
	if _is_laser_path_obstructed(player_node.global_position):
		return
		
	_spawn_static_beam_particles(player_node.global_position)
	player_node.call("take_damage", BEAM_DAMAGE, Vector3.ZERO)


## Called by WeaverMalakorAIBehavior when entering Phase 2: Inverts gravity
func _trigger_gravity_inversion() -> void:
	AudioService.play_sfx_static("gargoyle_screech", global_position, 80.0)
	_spawn_gravity_vortex_particles()
	
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_ctrl := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_ctrl):
			# Set upward gravity acceleration to force glider deployment
			player_ctrl.set("gravity", -9.8 * 0.4) 
			player_ctrl.set("is_glider_deployed", true)


## Called by WeaverMalakorAIBehavior periodically during Phase 2: Summons minions
func _spawn_gargoyle_servant(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node): return
	AudioService.play_sfx_static("zombie_groan", global_position, 40.0)
	
	var spawn_pos := global_position + Vector3(randf_range(-4, 4), 2.0, randf_range(-4, 4))
	var servant := MobRegistry.create_mob(12, spawn_pos) as CharacterBody3D # 12 = Gothic Gargoyle
	if is_instance_valid(servant):
		get_parent().add_child(servant)
		servant.set("_combat_target", player_node)


## Called by WeaverMalakorAIBehavior periodically during Phase 3: Mutates floor
func _trigger_arena_voxel_shift() -> void:
	var world_ctrl := get_parent()
	if is_instance_valid(world_ctrl) and world_ctrl.has_method("set_block_globally"):
		var rx := randi_range(-6, 6)
		var rz := randi_range(-6, 6)
		var target_coord := Vector3i(rx, ARENA_FLOOR_Y, rz)
		
		# Turn solid cloud/stone floor into empty space (unweaving reality!)
		world_ctrl.call("set_block_globally", target_coord, BlockType.Type.AIR)
		AudioService.play_sfx_static("block_break", Vector3(target_coord))


# ==============================================================================
# INTERNAL PRIVATE UTILITIES (Strict SRP/OCP Compliance)
# ==============================================================================

func _is_laser_path_obstructed(target_pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	# Chest-level laser launch origin
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.5, 0.0), target_pos)
	query.collision_mask = 1 # Solid block layer
	query.exclude = [get_rid()]
	return not space_state.intersect_ray(query).is_empty()


func _spawn_static_beam_particles(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 14
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.4
	
	var beam_dir := (target_pos - global_position).normalized()
	particles.direction = beam_dir
	particles.spread = 10.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 12.0
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.0, 0.95) # Static magenta
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.0, 0.95)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3(0.0, 1.5, 0.0)
	particles.emitting = true


func _spawn_gravity_vortex_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 6.0
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.95, 0.95) # Gravity cyan
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.position = Vector3(0.0, 0.5, 0.0)
	particles.emitting = true


func _drop_loot(inv: IInventory) -> void:
	# Epic campaign drops: 1x Wooden Sword, 32x Cloud Blocks, 1x Geothermal Charcoal
	inv.add_item(17, 1)
	inv.add_item(14, 32)
	inv.add_item(5, 1)
