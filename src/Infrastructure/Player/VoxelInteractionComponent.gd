# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure component responsible ONLY for handling player 
#              gaze raycasting, targeted voxel highlighting, block mining,
#              block construction, eating consumables, and NPC interactions.
#              SOLID COMPLIANCE: Strictly satisfies the Single Responsibility 
#              Principle (SRP) by decoupling voxel interactions from PlayerController.
#              UPGRADED: Integrated dynamic GPUParticles3D voxel debris systems 
#              matching the exact color of the mined block for visceral feedback.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

# Sibling dependencies injected by the Player on startup (DIP compliant)
var player: CharacterBody3D
var camera: Camera3D
var world_controller: Node3D
var hud: PlayerHUD

# Nodes constructed and managed locally (SRP compliant)
var raycast: RayCast3D
var highlight_mesh: MeshInstance3D

# Interaction configurations
const REACH_DISTANCE: float = 5.0

func _ready() -> void:
	name = "VoxelInteractionComponent"
	_setup_raycast()
	_setup_highlight_mesh()

## Programmatically instantiates and registers the target selector RayCast3D
func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "MiningRayCast"
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	
	# Exclude player from self-collisions to prevent physics glitching
	if is_instance_valid(player):
		raycast.add_exception(player)
		
	add_child(raycast)

## Programmatically instantiates and registers the 3D target highlighter BoxMesh
func _setup_highlight_mesh() -> void:
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.name = "TargetHighlight"
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.02, 1.02, 1.02)
	highlight_mesh.mesh = box_mesh
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.5
	box_mesh.material = mat
	
	highlight_mesh.top_level = true
	highlight_mesh.visible = false
	add_child(highlight_mesh)

## Main API: Orchestrates gaze calculations and inputs every frame
func process_interaction() -> void:
	_update_target_highlight()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()

## Repositions the voxel highlight mesh in 3D grid space
func _update_target_highlight() -> void:
	if is_instance_valid(highlight_mesh) and is_instance_valid(raycast) and raycast.is_colliding():
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.5)
		var target_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		highlight_mesh.global_position = Vector3(target_coord) + Vector3(0.5, 0.5, 0.5)
		highlight_mesh.visible = true
	elif is_instance_valid(highlight_mesh):
		highlight_mesh.visible = false

## Executes mining block removal or direct weapon hit scans
func _mine_or_attack() -> void:
	var viewmodel = player.get("viewmodel")
	if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
		viewmodel.call("play_swing_animation")
	
	if not raycast.is_colliding(): 
		return
		
	var collider = raycast.get_collider()
	var active_slot: int = player.get("active_slot_index")
	
	# COMBAT CASE: Equip sword (Slot 7) and hit physics entities (Zombies, Fauna)
	if active_slot == 7 and is_instance_valid(collider) and collider is CharacterBody3D:
		if collider.get("domain_entity") is VoxelEntity:
			var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
			knockback_dir.y = 2.5
			if collider.has_method("take_damage"):
				collider.call("take_damage", 1, knockback_dir)
			return

	# MINING CASE: Chop and collect voxels polymorphically
	if is_instance_valid(world_controller):
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		var world_state = world_controller.get("world_state")
		if is_instance_valid(world_state):
			var mined_type: BlockType.Type = world_state.call("get_block", block_coord)
			
			# Spawn dynamic, color-matching physics particles before removal
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			
			var inventory = player.get("inventory")
			if inventory is InventoryComponent:
				inventory.add_block_by_type(mined_type)
				player.call("_sync_hud_counters")
				
		world_controller.call("set_block_globally", block_coord, BlockType.Type.AIR)

# ==============================================================================
# UPGRADE: Programmatic, GPU-optimized voxel debris emitter
# ==============================================================================
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
	# Avoid spawning debris for air or invalid blocks
	if block_type == BlockType.Type.AIR:
		return
		
	var def := BlockLibrary.get_definition(block_type)
	if def == null:
		return
		
	var particles := GPUParticles3D.new()
	particles.name = "MinedDebrisParticles"
	particles.emitting = false
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	# Center emitter inside the bounds of the targeted voxel
	particles.global_position = global_pos + Vector3(0.5, 0.5, 0.5)
	
	# Configure particle movement physical process
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.35, 0.35)
	pm.direction = Vector3(0.0, 1.0, 0.0) # Upwards explosion blast
	pm.spread = 50.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0.0, -9.8, 0.0) # Gravity fall
	
	# Scale variation curve
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	
	particles.process_material = pm
	
	# Generate a miniature voxel-chunk geometry
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = def.color_top
	mat.roughness = 0.8
	mesh.material = mat
	
	particles.draw_pass_1 = mesh
	
	# Attach emitter to the scene tree safely
	if is_instance_valid(world_controller):
		world_controller.add_child(particles)
		
	particles.emitting = true
	
	# Auto-free completed particle nodes to prevent leaks
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

## Executes block construction, item consumption, or NPC interactions
func _build_or_interact() -> void:
	var viewmodel = player.get("viewmodel")
	if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
		viewmodel.call("play_swing_animation")
	
	if not raycast.is_colliding(): 
		return
		
	var collider = raycast.get_collider()
	
	# NPC INTERACTION CASE: Speak with Villagers, Merchants, or Guards
	if is_instance_valid(collider) and collider is CharacterBody3D and collider.has_method("interact"):
		collider.call("interact", player)
		player.call("_sync_hud_counters")
		return
		
	# HEALING CASE: Consume 1x Fried Chicken (Slot 6) to restore health
	var active_slot: int = player.get("active_slot_index")
	var inventory = player.get("inventory")
	
	if active_slot == 6 and is_instance_valid(inventory):
		if inventory.can_modify_slot_quantity(6, -1) and player.domain_entity.health < 3:
			inventory.modify_slot_quantity(6, -1)
			player.domain_entity.health = min(3, player.domain_entity.health + 1)
			if is_instance_valid(hud):
				hud.update_health_display(player.domain_entity.health)
			player.call("_sync_hud_counters")
		return

	# CONSTRUCTION CASE: Place selected block in the 3D voxel grid
	var is_block_selected: bool = player.get("is_item_selected")
	if is_block_selected and is_instance_valid(world_controller) and is_instance_valid(inventory):
		var inv_comp := inventory as InventoryComponent
		var build_type: BlockType.Type = inv_comp.get_slot_build_type(active_slot)
		
		if not inventory.can_modify_slot_quantity(active_slot, -1): 
			return
			
		var build_pos: Vector3 = raycast.get_collision_point() + (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(build_pos.x), floor(build_pos.y), floor(build_pos.z))
		
		# Prevent placing blocks inside player's capsule collider boundary (safeguard)
		var player_feet := Vector3i(floor(player.global_position.x), floor(player.global_position.y), floor(player.global_position.z))
		var player_head := Vector3i(floor(player.global_position.x), floor(player.global_position.y + 0.9), floor(player.global_position.z))
		if block_coord == player_feet or block_coord == player_head: 
			return
			
		inventory.modify_slot_quantity(active_slot, -1)
		player.call("_sync_hud_counters")
		world_controller.call("set_block_globally", block_coord, build_type)
