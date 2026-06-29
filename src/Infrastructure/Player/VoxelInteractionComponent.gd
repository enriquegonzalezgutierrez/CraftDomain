# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure component responsible for handling player gaze
#              raycasting, target highlighting, block mining, placements,
#              consumable eating, and dynamic agricultural planting/harvesting.
#              SOLID COMPLIANCE: Strictly satisfies the Single Responsibility 
#              Principle (SRP) by isolating block interactions from physics controllers.
#              MEMORY SECURITY FIX: Bound particles directly to the timer using
#              a native method to eliminate lambda memory leaks on game exit.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

# Sibling dependencies injected by the Player on startup (DIP compliant)
var player: PlayerController
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
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding(): 
		return
		
	var collider := raycast.get_collider()
	var active_slot := player.active_slot_index
	var inventory := player.get("inventory") as InventoryComponent
	
	# COMBAT CASE: Equip sword (ID 17 sitting in any active slot) and hit entities
	if is_instance_valid(inventory) and is_instance_valid(collider) and collider is CharacterBody3D:
		var slot_data := inventory.get_slot_data(active_slot)
		if slot_data != null and slot_data.item_id == 17:
			if collider.get("domain_entity") is VoxelEntity:
				var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
				knockback_dir.y = 2.5
				if collider.has_method("take_damage"):
					collider.call("take_damage", 1, knockback_dir)
				return

	# MINING CASE: Chop and collect voxels polymorphically
	if is_instance_valid(world_controller) and is_instance_valid(inventory):
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		var world_state = world_controller.get("world_state") as WorldState
		if is_instance_valid(world_state):
			var mined_type := world_state.get_block(block_coord)
			
			# Spawn dynamic, color-matching physics particles before removal
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			
			# FASE A: Special Harvesting Rules
			if mined_type == BlockType.Type.CROP_RIPE:
				# Harvest Success: Gives 1x Wheat (ID 20) and 1-2x Seeds (ID 18)
				var _w_success := inventory.add_item(20, 1)
				var _s_success := inventory.add_item(18, randi_range(1, 2))
				player._sync_hud_counters()
				if is_instance_valid(hud):
					hud.show_quest_notification("Harvest Success", "Gathered 1x Ripe Wheat and Seeds!")
			elif mined_type == BlockType.Type.CROP_SEED or mined_type == BlockType.Type.CROP_GROWING:
				# Early Uproot: Refund only 1x Seed (ID 18)
				var _s_success := inventory.add_item(18, 1)
				player._sync_hud_counters()
				if is_instance_valid(hud):
					hud.show_quest_notification("Crop Uprooted", "Refunded 1x Crop Seed.")
			else:
				# Standard Voxel Block collection
				inventory.add_block_by_type(mined_type)
				player._sync_hud_counters()
				
		world_controller.call("set_block_globally", block_coord, BlockType.Type.AIR)

## Programmatic, GPU-optimized voxel debris emitter
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
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
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.35, 0.35)
	pm.direction = Vector3(0.0, 1.0, 0.0) 
	pm.spread = 50.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0.0, -9.8, 0.0) 
	
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = def.color_top
	mat.roughness = 0.8
	mesh.material = mat
	
	particles.draw_pass_1 = mesh
	
	if is_instance_valid(world_controller):
		world_controller.add_child(particles)
		particles.global_position = global_pos + Vector3(0.5, 0.5, 0.5)
		
	particles.emitting = true
	
	# MEMORY FIX: Bind particles reference cleanly
	get_tree().create_timer(0.6).timeout.connect(_cleanup_particles.bind(particles))

func _cleanup_particles(particles_node: GPUParticles3D) -> void:
	if is_instance_valid(particles_node):
		particles_node.queue_free()

## Executes block construction, item consumption, or NPC interactions
func _build_or_interact() -> void:
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding(): 
		return
		
	var collider := raycast.get_collider()
	
	# NPC INTERACTION CASE: Speak with Villagers, Merchants, or Guards
	if is_instance_valid(collider) and collider is CharacterBody3D and collider.has_method("interact"):
		collider.call("interact", player)
		player._sync_hud_counters()
		return
		
	var active_slot := player.active_slot_index
	var inventory := player.get("inventory") as InventoryComponent
	
	if not is_instance_valid(inventory) or not is_instance_valid(world_controller):
		return
		
	var slot_data := inventory.get_slot_data(active_slot)
	if slot_data == null or slot_data.item_id == -1 or slot_data.quantity == 0:
		return
		
	var item_id := slot_data.item_id
	var world_state := world_controller.get("world_state") as WorldState
	
	# HEALING CASE: Consume 1x Fried Chicken (Item ID 16) to restore health
	if item_id == 16:
		if player.domain_entity.health < 3:
			slot_data.quantity -= 1
			if slot_data.quantity <= 0:
				slot_data.item_id = -1
			player.domain_entity.health = min(3, player.domain_entity.health + 1)
			if is_instance_valid(hud):
				hud.update_health_display(player.domain_entity.health)
				hud.show_quest_notification("Yummy!", "Consumed 1x Fried Chicken. Healed 1 Heart.")
			player._sync_hud_counters()
		return

	# FASE A: SEED PLANTING CASE (Item ID 18 - Crop Seed)
	if item_id == 18:
		# Check if we clicked the TOP face of a Grass (3) or Dirt (2) block
		var hit_normal := raycast.get_collision_normal()
		if hit_normal.y == 1.0: # Top face click only!
			var hit_pos := raycast.get_collision_point() - (hit_normal * 0.5)
			var soil_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
			var soil_type := world_state.get_block(soil_coord)
			
			if soil_type == BlockType.Type.GRASS or soil_type == BlockType.Type.DIRT:
				var crop_coord := soil_coord + Vector3i(0, 1, 0)
				# Ensure space above soil is completely empty (AIR)
				if world_state.get_block(crop_coord) == BlockType.Type.AIR:
					# Consume seed and update HUD
					slot_data.quantity -= 1
					if slot_data.quantity <= 0:
						slot_data.item_id = -1
					player._sync_hud_counters()
					
					# Plant the seed block globally!
					world_controller.call("set_block_globally", crop_coord, BlockType.Type.CROP_SEED)
					if is_instance_valid(hud):
						hud.show_quest_notification("Planted Seed", "Sowed 1x Crop Seed on tilled soil!")
					return
		return

	# STANDARD CONSTRUCTION CASE: Place selected block in the 3D voxel grid
	var is_block_selected = player.is_item_selected
	if is_block_selected:
		var build_type := slot_data.item_id as BlockType.Type
		var build_pos: Vector3 = raycast.get_collision_point() + (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(build_pos.x), floor(build_pos.y), floor(build_pos.z))
		
		# Prevent placing blocks inside player's capsule collider boundary (safeguard)
		var player_feet := Vector3i(floor(player.global_position.x), floor(player.global_position.y), floor(player.global_position.z))
		var player_head := Vector3i(floor(player.global_position.x), floor(player.global_position.y + 0.9), floor(player.global_position.z))
		if block_coord == player_feet or block_coord == player_head: 
			return
			
		slot_data.quantity -= 1
		if slot_data.quantity <= 0:
			slot_data.item_id = -1
			
		player._sync_hud_counters()
		world_controller.call("set_block_globally", block_coord, build_type)
