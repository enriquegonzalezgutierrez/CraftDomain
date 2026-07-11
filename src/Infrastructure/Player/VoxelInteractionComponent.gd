# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Player Interactions
# Class: VoxelInteractionComponent
# Description: Component managing player gaze raycasting, targeted block 
#              highlighting, voxel progressive mining, placing, 
#              food consumption, and seed planting.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Exclusively manages gaze 
#   interaction mechanics and block modification triggers.
# - Open-Closed Principle (OCP): EXTREME REFACTOR. Completely removed the 
#   hardcoded `MINED_BLOCK_TO_ITEM_DROP` dictionary. Block drops are now 
#   queried polymorphically from the block's active definition in the Domain.
# - Dependency Inversion Principle (DIP): Connects strictly with 
#   abstractions (IInventory, ItemUsageStrategy, IWorldModifier) 
#   instead of concrete scene-tree controllers.
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

# Sibling node references (Strictly untyped to prevent compiler circular lock)
var player: CharacterBody3D
var world_controller: Node3D
var raycast: RayCast3D

# Pure Domain Voxel Damage Service (SRP)
var _damage_service: BlockDamageService

# 3D Visual overlay mesh representing cracks
var _cracking_mesh: MeshInstance3D
var _cracking_textures: Array[Texture2D] = []

# Tracker coordinate currently targeted by the raycast
var _last_targeted_coord: Vector3i = Vector3i(0, -999, 0)


func _ready() -> void:
	name = "VoxelInteractionComponent"
	_damage_service = BlockDamageService.new()
	
	_preload_cracking_textures()
	_setup_raycast()
	_setup_cracking_mesh_overlay()


## Preloads progressive cracking textures into RAM to prevent in-game lag spikes
func _preload_cracking_textures() -> void:
	_cracking_textures.clear()
	for i: int in range(4):
		var path := "res://assets/textures/cracks_%d.png" % i
		if ResourceLoader.exists(path):
			_cracking_textures.append(load(path) as Texture2D)
		else:
			# Fallback empty texture if generation assets are missing
			_cracking_textures.append(PlaceholderTexture2D.new())


func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "InteractionRayCast"
	raycast.target_position = Vector3(0, 0, -5.0) # 5-meter reach distance
	raycast.enabled = true
	raycast.collision_mask = 1 # Collides with static terrain blocks
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.hit_back_faces = true
	
	add_child(raycast)
	if is_instance_valid(player):
		player.set("raycast", raycast)


## Instantiates an unshaded, transparent box mesh floated 1.004x larger than a standard block
func _setup_cracking_mesh_overlay() -> void:
	_cracking_mesh = MeshInstance3D.new()
	_cracking_mesh.name = "VisualCrackingOverlay"
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.004, 1.004, 1.004) # Slightly larger to prevent Z-fighting
	_cracking_mesh.mesh = box_mesh
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Low cost, bypasses real-time shadows
	_cracking_mesh.material_override = mat
	_cracking_mesh.visible = false
	
	# Add directly to camera parent node to inherit world transformations
	add_child(_cracking_mesh)


func _process(delta: float) -> void:
	# 1. Process block self-healing updates
	if is_instance_valid(_damage_service):
		var healed_coords := _damage_service.process_healing(delta)
		for coord: Vector3i in healed_coords:
			if coord == _last_targeted_coord:
				_hide_cracking_overlay()


func process_interaction() -> void:
	_update_target_highlight()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()


## Positions the highlighting reticle and green/red preview boxes on targeted block faces.
func _update_target_highlight() -> void:
	if not is_instance_valid(raycast) or not raycast.is_colliding() or not is_instance_valid(camera):
		if is_instance_valid(highlight_mesh):
			highlight_mesh.visible = false
		if is_instance_valid(placement_highlight_mesh):
			placement_highlight_mesh.visible = false
		_hide_cracking_overlay()
		return
		
	var hit_normal := raycast.get_collision_normal()
	var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
	
	if hit_normal.dot(r_dir) > 0.0:
		hit_normal = -hit_normal
		
	var hit_pos := raycast.get_collision_point() + (r_dir * 0.05)
	var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
	
	# Hide cracking overlay if the player moves their gaze to a different coordinate
	if target_coord != _last_targeted_coord:
		_last_targeted_coord = target_coord
		_update_cracking_overlay(target_coord)
	
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
				is_buildable = (item_id >= 1 and item_id <= 5) or item_id == 15 or item_id == 18 or item_id == 26 or (item_id >= 28 and item_id <= 30)
				
		if is_buildable:
			var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
			var world_ctrl := world_controller as WorldController
			
			if is_instance_valid(world_ctrl) and is_instance_valid(world_ctrl.world_state):
				var world_state := world_ctrl.world_state
				var target_block := world_state.get_block(build_coord)
				
				var is_spot_free := target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER
				var aimed_block := world_state.get_block(target_coord)
				
				var is_mergeable_bottom: bool = aimed_block == BlockType.Type.STONE_SLAB_BOTTOM and int(round(hit_normal.y)) == 1
				var is_mergeable_top: bool = aimed_block == BlockType.Type.STONE_SLAB_TOP and int(round(hit_normal.y)) == -1
				
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				var player_aabb := AABB(
					player.global_position - Vector3(0.35, 0.05, 0.35),
					Vector3(0.70, 1.85, 0.70)
				)
				var player_collides := player_aabb.intersects(block_aabb)
				
				placement_highlight_mesh.global_position = Vector3(build_coord) + Vector3(0.5, 0.5, 0.5)
				placement_highlight_mesh.visible = true
				
				if (is_spot_free and not player_collides) or is_mergeable_bottom or is_mergeable_top:
					placement_material.albedo_color = Color(0.2, 0.95, 0.35, 0.18)
					placement_material.emission = Color(0.2, 0.95, 0.35)
				else:
					placement_material.albedo_color = Color(0.95, 0.2, 0.2, 0.18)
					placement_material.emission = Color(0.95, 0.2, 0.2)
		else:
			placement_highlight_mesh.visible = false


## Executes left-click actions: mining targeted blocks progressively or swinging the sword.
func _mine_or_attack() -> void:
	var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if is_instance_valid(player) and player.has_method("swing_sword"):
		player.swing_sword()
	
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider: Node = raycast.get_collider() as Node
	var active_slot: int = player.get("active_slot_index") as int if is_instance_valid(player) else 0
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent if is_instance_valid(player) else null
	
	var slot_data := inventory.get_slot_data(active_slot) if is_instance_valid(inventory) else null
	var item_id := slot_data.item_id if slot_data != null else -1
	
	# COMBAT LOGIC: Hit character bodies with the sword
	if is_instance_valid(inventory) and is_instance_valid(collider) and collider is CharacterBody3D:
		if item_id == 17:
			var entity_domain := collider.get("domain_entity")
			if is_instance_valid(entity_domain) and entity_domain is VoxelEntity:
				var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
				knockback_dir.y = 2.5
				if collider.has_method("take_damage"):
					collider.call("take_damage", 1, knockback_dir, player)
				return

	# Block mining safeguard
	if item_id == 16 or item_id == 17 or item_id == 18:
		return

	# PROGRESSIVE MINING LOGIC
	var world_ctrl: WorldController = world_controller as WorldController
	if is_instance_valid(world_ctrl) and is_instance_valid(inventory):
		var hit_normal := raycast.get_collision_normal()
		var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		
		if hit_normal.dot(r_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos: Vector3 = raycast.get_collision_point() + (r_dir * 0.05)
		var block_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		
		var world_state_ref: WorldState = world_ctrl.world_state
		if is_instance_valid(world_state_ref):
			var mined_type := world_state_ref.get_block(block_coord)
			
			if mined_type == BlockType.Type.AIR:
				return
				
			# ----------------==================================================
			# DYNAMIC RESILIENCE HIT EVALUATION (SOLID Progressive Mining)
			# --------------------------------==================================
			var remaining_hits := _damage_service.register_hit(block_coord, mined_type)
			
			if remaining_hits > 0:
				# Block is still solid: spawn impact debris, play impact thud, update cracks
				_spawn_mining_particles(Vector3(block_coord), mined_type)
				AudioService.play_sfx_static("block_place", Vector3(block_coord)) 
				_update_cracking_overlay(block_coord)
				return 
				
			# ----------------==================================================
			# BLOCK BROKEN: Clean up records and trigger final shatter drops
			# ----------------==================================================
			_hide_cracking_overlay()
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			
			var target_id := int(mined_type)
			
			if mined_type == BlockType.Type.CROP_RIPE:
				var _un1 := inventory.add_item(20, 1)
				var _un2 := inventory.add_item(18, randi_range(1, 2))
				target_id = 20 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_HARVEST_SUCCESS_HEADER", "NOTIFICATION_HARVEST_SUCCESS_DESC")
			elif mined_type == BlockType.Type.CROP_SEED or mined_type == BlockType.Type.CROP_GROWING:
				var _un3 := inventory.add_item(18, 1)
				target_id = 18 
				if is_instance_valid(hud):
					hud.show_quest_notification("NOTIFICATION_CROP_UPROOTED_HEADER", "NOTIFICATION_CROP_UPROOTED_DESC")
			else:
				# OCP COMPLIANCE: Query BlockDefinition polymorphically for drops!
				var def := block_library_provider.get_definition(mined_type) as BlockDefinition
				if def != null:
					target_id = def.get_drop_item_id()
					var qty := def.get_drop_quantity()
					var _un4 := inventory.add_item(target_id, qty)
				
				if mined_type == BlockType.Type.LEAVES and randf() < 0.25:
					var _un5 := inventory.add_item(18, 1)
				
			var active_q: Quest = quest_service_provider.get_active_quest() as Quest
			if active_q != null and active_q.required_item_index == target_id:
				active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
				
		world_ctrl.set_block_globally(block_coord, BlockType.Type.AIR)


## Synchronizes the cracking overlay texture based on the current damage ratio
func _update_cracking_overlay(coord: Vector3i) -> void:
	if not is_instance_valid(_damage_service) or not is_instance_valid(_cracking_mesh):
		return
		
	var ratio := _damage_service.get_damage_ratio(coord)
	if ratio <= 0.01:
		_hide_cracking_overlay()
		return
		
	# Float the cracking box exactly over the block's world coordinates
	_cracking_mesh.global_position = Vector3(coord) + Vector3(0.5, 0.5, 0.5)
	_cracking_mesh.visible = true
	
	# Determine progressive texture index [0 to 3] based on damage percentage
	var tex_index := clampi(floori(ratio * 4.0), 0, 3)
	
	var mat: StandardMaterial3D = _cracking_mesh.material_override as StandardMaterial3D
	if is_instance_valid(mat) and _cracking_textures.size() > tex_index:
		mat.albedo_texture = _cracking_textures[tex_index]


func _hide_cracking_overlay() -> void:
	if is_instance_valid(_cracking_mesh):
		_cracking_mesh.visible = false


## Instantiates a temporary, compile-free CPU debris emitter on block destruction.
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
	if block_type == BlockType.Type.AIR:
		return
		
	var def: BlockDefinition = block_library_provider.get_definition(block_type) as BlockDefinition
	if def == null:
		return
		
	var particles := CPUParticles3D.new()
	particles.name = "MinedDebrisParticles"
	particles.emitting = false
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.35, 0.35, 0.35)
	particles.direction = Vector3(0.0, 1.0, 0.0) 
	particles.spread = 50.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.5
	particles.gravity = Vector3(0.0, -9.8, 0.0) 
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color_top
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	if is_instance_valid(world_controller):
		world_controller.add_child(particles)
		particles.global_position = global_pos + Vector3(0.5, 0.5, 0.5)
		
	particles.emitting = true


## Executes right-click actions: placing blocks, planting crops, or speaking with NPCs.
func _build_or_interact() -> void:
	var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel):
		viewmodel.play_swing_animation()
	
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider := raycast.get_collider()
	
	if is_instance_valid(collider) and collider is CharacterBody3D and collider.has_method("interact"):
		collider.call("interact", player)
		return
		
	var active_slot: int = player.get("active_slot_index") as int if is_instance_valid(player) else 0
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent if is_instance_valid(player) else null
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
		var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		
		if hit_normal.dot(r_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos := raycast.get_collision_point() + (r_dir * 0.05)
		var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		
		var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
		
		var fractional_y := hit_pos.y - floori(hit_pos.y)
		var modifier := world_ctrl.world_modifier
		if modifier != null:
			modifier.set("last_hit_fractional_y", fractional_y)
		
		if strategy.can_use(player.domain_entity, inventory, target_coord, hit_normal, world_state):
			
			if strategy is PlaceableBlockStrategy:
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				var player_aabb := AABB(
					player.global_position - Vector3(0.35, 0.05, 0.35),
					Vector3(0.70, 1.85, 0.70)
				)
				if player_aabb.intersects(block_aabb):
					return
					
			strategy.use(player.domain_entity, inventory, target_coord, hit_normal, world_ctrl.world_modifier)
			
			if is_instance_valid(hud):
				if strategy is ConsumableItemStrategy:
					hud.update_health_display(player.domain_entity.health)
					hud.show_quest_notification("NOTIFICATION_CONSUME_FOOD_HEADER", "NOTIFICATION_CONSUME_FOOD_DESC")
				elif strategy is PlantableItemStrategy:
					hud.show_quest_notification("NOTIFICATION_PLANTED_SEED_HEADER", "NOTIFICATION_PLANTED_SEED_DESC")


# ==============================================================================
# FALLBACK HELPER GETTERS
# ==============================================================================

var highlight_mesh: MeshInstance3D:
	get:
		var p_hud := player.get("hud") as PlayerHUD if is_instance_valid(player) else null
		if is_instance_valid(p_hud):
			return p_hud.get_node_or_null("PlayerCamera/TargetHighlight") as MeshInstance3D
		return null

var placement_highlight_mesh: MeshInstance3D:
	get:
		var p_hud := player.get("hud") as PlayerHUD if is_instance_valid(player) else null
		if is_instance_valid(p_hud):
			return p_hud.get_node_or_null("PlayerCamera/PlacementHighlight") as MeshInstance3D
		return null

var placement_material: StandardMaterial3D:
	get:
		if is_instance_valid(placement_highlight_mesh) and placement_highlight_mesh.mesh != null:
			return placement_highlight_mesh.mesh.material as StandardMaterial3D
		return null

var camera: Camera3D:
	get:
		if is_instance_valid(player):
			return player.get("camera") as Camera3D
		return null

var hud: PlayerHUD:
	get:
		if is_instance_valid(player):
			return player.get("hud") as PlayerHUD
		return null

var block_library_provider: Object:
	get:
		return BlockLibrary

var quest_service_provider: Object:
	get:
		return QuestService
