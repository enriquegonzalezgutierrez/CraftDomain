# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure component managing player gaze raycasting, 
#              targeted block highlighting, voxel mining, placing, 
#              food consumption, and seed planting.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively gaze 
#   interaction mechanics and block modification triggers.
# - Open-Closed Principle (OCP): Item behaviors are decoupled into 
#   parameterized strategies, removing hardcoded logic.
# - Dependency Inversion Principle (DIP): Connects strictly with 
#   abstractions (IInventory, ItemUsageStrategy, IWorldModifier) 
#   instead of concrete scene-tree controllers.
# UX RED/GREEN HOLOGRAPHIC PREVIEW:
# - Added vertical safety padding of 5cm (`-0.05` Y offset) on `player_aabb` 
#   bounds calculations. This guarantees that blocks placed under your feet 
#   will be blocked and highlighted in warning RED, preventing players from 
#   trapping themselves inside solid collision shapes.
# SELF-HEALING VECTOR MATHEMATICS (FIXED):
# - RayCast3D now explicitly hits back-faces. This is a critical fallback 
#   safeguard that prevents the ray from passing through inward-facing normals.
# - Floating-point truncation error fixed: Normal axis values are now mathematically 
#   rounded (`round()`) before casting to integers, preventing `0.9999` from 
#   collapsing to `0` and breaking block placement logic.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

## Dynamic UI targeting reticle highlighters
var highlight_mesh: MeshInstance3D
var placement_highlight_mesh: MeshInstance3D # Dynamic green/red preview for Right-Click builds
var placement_material: StandardMaterial3D # Cached preview material for dynamic color swaps
var raycast: RayCast3D

# Dependencies injected on startup (DIP compliant)
var player: CharacterBody3D
var camera: Camera3D
var world_controller: Node3D
var hud: PlayerHUD

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
	
	# AUTO-INJECTION: Safely extract the parent camera since this node is added as a child of it
	camera = get_parent() as Camera3D
	
	_setup_raycast()
	_setup_highlight_meshes()


## Programmatically instantiates and configures the target detector RayCast3D.
func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "MiningRayCast"
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	
	# BACKFACE FALLBACK SAFEGUARD: Ensures raycast doesn't phase through blocks with inverted winding order
	raycast.hit_back_faces = true 
	
	if is_instance_valid(player):
		raycast.add_exception(player)
		
	add_child(raycast)


## Programmatically instantiates the dual highlighter meshes (White for mining, Green/Red for placement)
func _setup_highlight_meshes() -> void:
	# 1. Setup White Mining Highlight Box
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.name = "TargetHighlight"
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.02, 1.02, 1.02)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.5
	box_mesh.material = mat
	
	highlight_mesh.mesh = box_mesh
	highlight_mesh.top_level = true
	highlight_mesh.visible = false
	add_child(highlight_mesh)

	# 2. Setup Holographic Building Placement Preview Box
	placement_highlight_mesh = MeshInstance3D.new()
	placement_highlight_mesh.name = "PlacementHighlight"
	
	var green_box := BoxMesh.new()
	green_box.size = Vector3(1.015, 1.015, 1.015) # Scaled to avoid clipping Z-fight with white outline
	
	# Instantiate and cache the dynamic material
	placement_material = StandardMaterial3D.new()
	placement_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	placement_material.albedo_color = Color(0.2, 0.95, 0.35, 0.18) # Default green
	placement_material.emission_enabled = true
	placement_material.emission = Color(0.2, 0.95, 0.35)
	placement_material.emission_energy_multiplier = 0.6
	green_box.material = placement_material
	
	placement_highlight_mesh.mesh = green_box
	placement_highlight_mesh.top_level = true
	placement_highlight_mesh.visible = false
	add_child(placement_highlight_mesh)


## Main Loop API: Evaluates targeted colliders and processes mouse click inputs.
func process_interaction() -> void:
	_update_target_highlight()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()


## Positions the dual highlight boxes dynamically based on gaze and active item states.
func _update_target_highlight() -> void:
	if not is_instance_valid(raycast) or not raycast.is_colliding() or not is_instance_valid(camera):
		if is_instance_valid(highlight_mesh):
			highlight_mesh.visible = false
		if is_instance_valid(placement_highlight_mesh):
			placement_highlight_mesh.visible = false
		return
		
	var hit_normal := raycast.get_collision_normal()
	
	# SELF-HEALING VECTOR MATHEMATICS:
	var ray_dir := (raycast.get_collision_point() - camera.global_position).normalized()
	
	# 1. Autocorrect Inverted Normals (If normal points along look vector, flip it outward!)
	if hit_normal.dot(ray_dir) > 0.0:
		hit_normal = -hit_normal
		
	# 2. Ray-Direction Nudge: Move 5cm inside targeted block along the gaze vector (Independent of Normal winding)
	var hit_pos := raycast.get_collision_point() + (ray_dir * 0.05)
	var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
	
	# 1. Update Mining Target Highlight (White Box)
	if is_instance_valid(highlight_mesh):
		highlight_mesh.global_position = Vector3(target_coord) + Vector3(0.5, 0.5, 0.5)
		highlight_mesh.visible = true
		
	# 2. Update Placement Preview (Green/Red Dynamic Box)
	if is_instance_valid(placement_highlight_mesh) and is_instance_valid(player):
		var is_buildable := false
		var active_slot: int = player.get("active_slot_index") as int
		var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
		
		if is_instance_valid(inventory):
			var slot_data := inventory.get_slot_data(active_slot)
			if slot_data != null and slot_data.item_id != -1:
				var item_id := slot_data.item_id
				# Placeable items check: Blocks (1-5), Lava (15) and Seeds (18)
				is_buildable = (item_id >= 1 and item_id <= 5) or item_id == 15 or item_id == 18
				
		if is_buildable:
			# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0 when casting to int!
			var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
			var world_ctrl: WorldController = world_controller as WorldController
			
			if is_instance_valid(world_ctrl) and is_instance_valid(world_ctrl.world_state):
				var world_state := world_ctrl.world_state
				var target_block := world_state.get_block(build_coord)
				
				# Check if space is currently empty (Air or non-solid water)
				var is_spot_free := target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER
				
				# CORRECTED PLAYER COLLISION BOUNDS (WITH 5CM DOWNWARD HYSTERESIS):
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				var player_aabb := AABB(
					player.global_position - Vector3(0.35, 0.05, 0.35),
					Vector3(0.70, 1.85, 0.70)
				)
				var player_collides := player_aabb.intersects(block_aabb)
				
				placement_highlight_mesh.global_position = Vector3(build_coord) + Vector3(0.5, 0.5, 0.5)
				placement_highlight_mesh.visible = true
				
				if is_spot_free and not player_collides:
					# VALID SPOT: Shines in dynamic emerald green
					placement_material.albedo_color = Color(0.2, 0.95, 0.35, 0.18)
					placement_material.emission = Color(0.2, 0.95, 0.35)
				else:
					# BLOCKED SPOT: Shines in warning ruby red
					placement_material.albedo_color = Color(0.95, 0.2, 0.2, 0.18)
					placement_material.emission = Color(0.95, 0.2, 0.2)
		else:
			placement_highlight_mesh.visible = false


## Executes left-click actions: breaking targeted blocks or swinging the sword.
func _mine_or_attack() -> void:
	var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider: Node = raycast.get_collider() as Node
	var active_slot: int = player.get("active_slot_index") as int
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	
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
	var world_ctrl: WorldController = world_controller as WorldController
	if is_instance_valid(world_ctrl) and is_instance_valid(inventory):
		var hit_normal := raycast.get_collision_normal()
		var ray_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		
		# Autocorrect normals on the fly
		if hit_normal.dot(ray_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos: Vector3 = raycast.get_collision_point() + (ray_dir * 0.05)
		var block_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		
		var world_state: WorldState = world_ctrl.world_state
		if is_instance_valid(world_state):
			var mined_type := world_state.get_block(block_coord)
			
			if mined_type == BlockType.Type.AIR:
				return
				
			# Spawn dynamic color-matched break particles
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			
			var target_id := int(mined_type)
			
			# Special Agricultural Harvesting Rules
			if mined_type == BlockType.Type.CROP_RIPE:
				var _un1 := inventory.add_item(20, 1) # Ripe Wheat ID
				var _un2 := inventory.add_item(18, randi_range(1, 2)) # Plump Seeds ID
				target_id = 20 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_HARVEST_SUCCESS_HEADER", "NOTIFICATION_HARVEST_SUCCESS_DESC")
			elif mined_type == BlockType.Type.CROP_SEED or mined_type == BlockType.Type.CROP_GROWING:
				var _un3 := inventory.add_item(18, 1)
				target_id = 18 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_CROP_UPROOTED_HEADER", "NOTIFICATION_CROP_UPROOTED_DESC")
			else:
				# Standard block collection (DIP: Translate BlockType to Item ID on the fly)
				match mined_type:
					BlockType.Type.SAND, BlockType.Type.RED_SAND, BlockType.Type.MUD:
						target_id = 2 # Dirt ID
					BlockType.Type.SNOW, BlockType.Type.ICE, BlockType.Type.NEON_CYAN, BlockType.Type.NEON_MAGENTA:
						target_id = 1 # Stone ID
					BlockType.Type.CLOUD:
						target_id = 5 # Leaves ID
					BlockType.Type.LEAVES:
						target_id = 5 # Leaves ID
						if randf() < 0.25:
							var _un4 := inventory.add_item(18, 1) # Bonus seed drop
				
				var _un5 := inventory.add_item(target_id, 1)
				
			# DIP INVERSION: Update quest progress using the injected provider reference
			var active_q: Quest = quest_service_provider.get_active_quest() as Quest
			if active_q != null and active_q.required_item_index == target_id:
				active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
				
		# Static compile-safe call to rebuild the chunk geometry
		world_ctrl.set_block_globally(block_coord, BlockType.Type.AIR)


## Instantiates a temporary color-matched GPU debris emitter on block destruction.
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
	if block_type == BlockType.Type.AIR:
		return
		
	var def: BlockDefinition = block_library_provider.get_definition(block_type) as BlockDefinition
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
	var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider := raycast.get_collider()
	
	# Interact with villagers, merchants, or guards
	if is_instance_valid(collider) and collider is CharacterBody3D and collider.has_method("interact"):
		collider.call("interact", player)
		return
		
	var active_slot: int = player.get("active_slot_index") as int
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var world_ctrl: WorldController = world_controller as WorldController
	
	if not is_instance_valid(inventory) or not is_instance_valid(world_ctrl):
		return
		
	var slot_data := inventory.get_slot_data(active_slot)
	if slot_data == null or slot_data.item_id == -1 or slot_data.quantity == 0:
		return
		
	var item_id := slot_data.item_id
	var world_state := world_ctrl.world_state
	if not is_instance_valid(world_state):
		return
		
	var strategy: ItemUsageStrategy = ItemStrategyRegistry.get_strategy(item_id) as ItemUsageStrategy
	if strategy != null:
		var hit_normal := raycast.get_collision_normal()
		var ray_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		
		if hit_normal.dot(ray_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos := raycast.get_collision_point() + (ray_dir * 0.05)
		var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		
		# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0!
		var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
		
		# Validate strategy requirements
		if strategy.can_use(player.domain_entity, inventory, target_coord, hit_normal, world_state):
			
			# SPECIAL BOUNDING SHIELD: Prevent placing solid blocks inside player's body
			if strategy is PlaceableBlockStrategy:
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				# Padded player AABB downwards by 5cm (0.05) to prevent self-intersection block traps
				var player_aabb := AABB(
					player.global_position - Vector3(0.35, 0.05, 0.35),
					Vector3(0.70, 1.85, 0.70)
				)
				if player_aabb.intersects(block_aabb):
					return # Prevent trapping the player inside a solid block!
					
			# Execute strategy business rules (Injected through the Domain Adapter abstraction)
			strategy.use(player.domain_entity, inventory, target_coord, hit_normal, world_ctrl.world_modifier)
			
			# Contextual visual toast notifications (Decoupled from core strategy rules)
			if is_instance_valid(hud):
				if strategy is ConsumableItemStrategy:
					hud.update_health_display(player.domain_entity.health)
					hud.show_quest_notification("NOTIFICATION_CONSUME_FOOD_HEADER", "NOTIFICATION_CONSUME_FOOD_DESC")
				elif strategy is PlantableItemStrategy:
					hud.show_quest_notification("NOTIFICATION_PLANTED_SEED_HEADER", "NOTIFICATION_PLANTED_SEED_DESC")
