# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure component responsible for managing player gaze 
#              raycasting, targeted block highlighting, voxel mining, placing, 
#              food consumption, and seed planting.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively gaze 
#                interaction mechanics and block modification triggers.
#              - Dependency Inversion Principle (DIP): Rather than hardcoding 
#                static references to global singletons, it holds injectable 
#                references to the block library and quest service.
#              - i18n Overhaul: Replaced all hardcoded notification toast strings 
#                with clean localization keys.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

# Sibling dependencies injected by the Player Controller on startup
var player: PlayerController
var camera: Camera3D
var world_controller: Node3D
var hud: PlayerHUD

# Nodes constructed and managed locally
var raycast: RayCast3D
var highlight_mesh: MeshInstance3D

# ==============================================================================
# DEPENDENCY INVERSION (DIP): Injectable service providers
# ==============================================================================
## Injectable reference to the block library provider (Defaults to BlockLibrary class).
var block_library_provider: Object = BlockLibrary

## Injectable reference to the active quest service provider (Defaults to QuestService class).
var quest_service_provider: Object = QuestService

# Gaze raycast interaction reach distance limit
const REACH_DISTANCE: float = 5.0


func _ready() -> void:
	name = "VoxelInteractionComponent"
	_setup_raycast()
	_setup_highlight_mesh()


## Programmatically instantiates and configures the target selector RayCast3D.
func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "MiningRayCast"
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	
	if is_instance_valid(player):
		raycast.add_exception(player)
		
	add_child(raycast)


## Programmatically instantiates and configures the 3D target highlighter box.
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


## Main Loop API: Evaluates targeted colliders and processes mouse click inputs.
func process_interaction() -> void:
	_update_target_highlight()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()


## Positions the 3D highlight box over the currently targeted voxel coordinates.
func _update_target_highlight() -> void:
	if is_instance_valid(highlight_mesh) and is_instance_valid(raycast) and raycast.is_colliding():
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.5)
		var target_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		highlight_mesh.global_position = Vector3(target_coord) + Vector3(0.5, 0.5, 0.5)
		highlight_mesh.visible = true
	elif is_instance_valid(highlight_mesh):
		highlight_mesh.visible = false


## Executes left-click actions: breaking targeted blocks or swinging the sword.
func _mine_or_attack() -> void:
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding(): 
		return
		
	var collider := raycast.get_collider()
	var active_slot := player.active_slot_index
	var inventory := player.get("inventory") as InventoryComponent
	
	# COMBAT CODE: Hit hostile or passive character bodies if holding the sword (ID 17)
	if is_instance_valid(inventory) and is_instance_valid(collider) and collider is CharacterBody3D:
		var slot_data := inventory.get_slot_data(active_slot)
		if slot_data != null and slot_data.item_id == 17:
			if collider.get("domain_entity") is VoxelEntity:
				var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
				knockback_dir.y = 2.5
				if collider.has_method("take_damage"):
					collider.call("take_damage", 1, knockback_dir)
				return

	# MINING CODE: Remove block from the grid and add it to the inventory
	if is_instance_valid(world_controller) and is_instance_valid(inventory):
		var hit_pos: Vector3 = raycast.get_collision_point() - (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		
		var world_state = world_controller.get("world_state") as WorldState
		if is_instance_valid(world_state):
			var mined_type := world_state.get_block(block_coord)
			
			# Spawn dynamic color-matched break particles
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			
			var target_id := int(mined_type)
			
			# Special Agricultural Harvesting Rules (Using localized keys)
			if mined_type == BlockType.Type.CROP_RIPE:
				inventory.add_item(20, 1) # Ripe Wheat ID
				inventory.add_item(18, randi_range(1, 2)) # Plump Seeds ID
				player._sync_hud_counters()
				target_id = 20 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_HARVEST_SUCCESS_HEADER", "NOTIFICATION_HARVEST_SUCCESS_DESC")
			elif mined_type == BlockType.Type.CROP_SEED or mined_type == BlockType.Type.CROP_GROWING:
				inventory.add_item(18, 1)
				player._sync_hud_counters()
				target_id = 18 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_CROP_UPROOTED_HEADER", "NOTIFICATION_CROP_UPROOTED_DESC")
			else:
				# Standard block collection
				inventory.add_block_by_type(mined_type)
				player._sync_hud_counters()
				
				# Normalise block mappings back to basic inventory items
				match mined_type:
					BlockType.Type.SAND, BlockType.Type.RED_SAND, BlockType.Type.MUD:
						target_id = 2 
					BlockType.Type.SNOW, BlockType.Type.ICE, BlockType.Type.NEON_CYAN, BlockType.Type.NEON_MAGENTA:
						target_id = 1 
					BlockType.Type.CLOUD:
						target_id = 5 
						
			# DIP INVERSION: Update quest progress using the injected provider reference
			var active_q = quest_service_provider.get_active_quest()
			if active_q != null and active_q.required_item_index == target_id:
				active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
				
		world_controller.call("set_block_globally", block_coord, BlockType.Type.AIR)


## Instantiates a temporary color-matched GPU debris emitter on block destruction.
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
	if block_type == BlockType.Type.AIR:
		return
		
	# DIP INVERSION: Look up definition using the injected provider reference
	var def = block_library_provider.get_definition(block_type)
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
	get_tree().create_timer(0.6).timeout.connect(_cleanup_particles.bind(particles))


func _cleanup_particles(particles_node: GPUParticles3D) -> void:
	if is_instance_valid(particles_node):
		particles_node.queue_free()


## Executes right-click actions: placing blocks, planting crops, or speaking with NPCs.
func _build_or_interact() -> void:
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding(): 
		return
		
	var collider := raycast.get_collider()
	
	# Interact with villagers, merchants, or guards
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
	
	# HEALING CASE: Consume 1x Fried Chicken (Item ID 16) to restore health (Using localized keys)
	if item_id == 16:
		if player.domain_entity.health < 3:
			slot_data.quantity -= 1
			if slot_data.quantity <= 0:
				slot_data.item_id = -1
			player.domain_entity.health = min(3, player.domain_entity.health + 1)
			if is_instance_valid(hud):
				hud.update_health_display(player.domain_entity.health)
				hud.show_quest_notification("NOTIFICATION_CONSUME_FOOD_HEADER", "NOTIFICATION_CONSUME_FOOD_DESC")
			player._sync_hud_counters()
		return

	# SEED PLANTING: Plant crop seeds on top of solid soil blocks (Item ID 18: Crop Seed) (Using localized keys)
	if item_id == 18:
		var hit_normal := raycast.get_collision_normal()
		if hit_normal.y == 1.0: # Top face interactions only
			var hit_pos := raycast.get_collision_point() - (hit_normal * 0.5)
			var soil_coord := Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
			var soil_type := world_state.get_block(soil_coord)
			
			if soil_type == BlockType.Type.GRASS or soil_type == BlockType.Type.DIRT:
				var crop_coord := soil_coord + Vector3i(0, 1, 0)
				if world_state.get_block(crop_coord) == BlockType.Type.AIR:
					slot_data.quantity -= 1
					if slot_data.quantity <= 0:
						slot_data.item_id = -1
					player._sync_hud_counters()
					
					world_controller.call("set_block_globally", crop_coord, BlockType.Type.CROP_SEED)
					if is_instance_valid(hud):
						hud.show_quest_notification("NOTIFICATION_PLANTED_SEED_HEADER", "NOTIFICATION_PLANTED_SEED_DESC")
					return
		return

	# Standard block placement
	var is_block_selected = player.is_item_selected
	if is_block_selected:
		var build_type := slot_data.item_id as BlockType.Type
		var build_pos: Vector3 = raycast.get_collision_point() + (raycast.get_collision_normal() * 0.5)
		var block_coord := Vector3i(floor(build_pos.x), floor(build_pos.y), floor(build_pos.z))
		
		# Prevent placing blocks inside the player's bounding collision capsule
		var player_feet := Vector3i(floor(player.global_position.x), floor(player.global_position.y), floor(player.global_position.z))
		var player_head := Vector3i(floor(player.global_position.x), floor(player.global_position.y + 0.9), floor(player.global_position.z))
		if block_coord == player_feet or block_coord == player_head: 
			return
			
		slot_data.quantity -= 1
		if slot_data.quantity <= 0:
			slot_data.item_id = -1
			
		player._sync_hud_counters()
		world_controller.call("set_block_globally", block_coord, build_type)
