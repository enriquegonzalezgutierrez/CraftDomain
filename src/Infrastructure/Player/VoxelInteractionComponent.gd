# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# Description: Component managing first-person raycasting, target highlights,
#              mining ticks, placing blocks, eating, and planting.
#              Delegates crack rendering to BlockCrackingVisuals (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

var player: CharacterBody3D
var world_controller: Node3D
var raycast: RayCast3D

# Decoupled Sub-Components (SRP Compliant)
var _damage_service: BlockDamageService
var _cracking_visuals: BlockCrackingVisuals

var _last_targeted_coord := Vector3i(0, -999, 0)


func _ready() -> void:
	name = "VoxelInteractionComponent"
	_damage_service = BlockDamageService.new()
	
	_setup_raycast()
	_setup_cracking_visuals()


func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "InteractionRayCast"
	raycast.target_position = Vector3(0, 0, -5.0) # 5-meter reach distance
	raycast.enabled = true
	raycast.collision_mask = 1 
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.hit_back_faces = true
	
	add_child(raycast)
	if is_instance_valid(player):
		player.set("raycast", raycast)


func _setup_cracking_visuals() -> void:
	_cracking_visuals = BlockCrackingVisuals.new()
	add_child(_cracking_visuals)


func _process(delta: float) -> void:
	if is_instance_valid(_damage_service):
		var healed_coords := _damage_service.process_healing(delta)
		for coord: Vector3i in healed_coords:
			if coord == _last_targeted_coord and is_instance_valid(_cracking_visuals):
				_cracking_visuals.hide_cracking_overlay()


func process_interaction() -> void:
	_update_target_highlight()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()


func _update_target_highlight() -> void:
	if not is_instance_valid(raycast) or not raycast.is_colliding() or not is_instance_valid(camera):
		_clear_all_highlights()
		return
		
	var hit_normal := raycast.get_collision_normal()
	var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
	if hit_normal.dot(r_dir) > 0.0:
		hit_normal = -hit_normal
		
	var hit_pos := raycast.get_collision_point() + (r_dir * 0.05)
	var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
	
	if target_coord != _last_targeted_coord:
		_last_targeted_coord = target_coord
		if is_instance_valid(_cracking_visuals):
			var ratio := _damage_service.get_damage_ratio(target_coord)
			_cracking_visuals.update_cracking_overlay(target_coord, ratio)
	
	if is_instance_valid(highlight_mesh):
		highlight_mesh.global_position = Vector3(target_coord) + Vector3(0.5, 0.5, 0.5)
		highlight_mesh.visible = true
		
	_process_placement_preview(target_coord, hit_normal)


func _clear_all_highlights() -> void:
	if is_instance_valid(highlight_mesh):
		highlight_mesh.visible = false
	if is_instance_valid(placement_highlight_mesh):
		placement_highlight_mesh.visible = false
	if is_instance_valid(_cracking_visuals):
		_cracking_visuals.hide_cracking_overlay()


func _process_placement_preview(target_coord: Vector3i, hit_normal: Vector3) -> void:
	if not is_instance_valid(placement_highlight_mesh) or not is_instance_valid(player):
		return
		
	var is_buildable := false
	var active_slot: int = player.get("active_slot_index") as int
	var inventory_comp: InventoryComponent = player.get("inventory") as InventoryComponent
	
	if is_instance_valid(inventory_comp):
		var slot_data := inventory_comp.get_slot_data(active_slot)
		if slot_data != null and slot_data.item_id != -1:
			var strategy := ItemStrategyRegistry.get_strategy(slot_data.item_id)
			is_buildable = (strategy != null and not (strategy is ConsumableItemStrategy))
			
	if is_buildable:
		var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
		var world_ctrl := world_controller as WorldController
		
		if is_instance_valid(world_ctrl) and is_instance_valid(world_ctrl.world_state):
			var ws := world_ctrl.world_state
			var target_block := ws.get_block(build_coord)
			var is_spot_free := target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER
			
			var aimed_block := ws.get_block(target_coord)
			var is_mergeable_bottom: bool = aimed_block == BlockType.Type.STONE_SLAB_BOTTOM and int(round(hit_normal.y)) == 1
			var is_mergeable_top: bool = aimed_block == BlockType.Type.STONE_SLAB_TOP and int(round(hit_normal.y)) == -1
			
			var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
			var player_aabb := AABB(player.global_position - Vector3(0.35, 0.05, 0.35), Vector3(0.70, 1.85, 0.70))
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


func _mine_or_attack() -> void:
	var viewmodel_node: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel_node):
		viewmodel_node.play_swing_animation()
	if is_instance_valid(player) and player.has_method("swing_sword"):
		player.swing_sword()
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider: Node = raycast.get_collider() as Node
	var active_slot: int = player.get("active_slot_index") as int
	var inventory_comp: InventoryComponent = player.get("inventory") as InventoryComponent
	var slot_data := inventory_comp.get_slot_data(active_slot) if is_instance_valid(inventory_comp) else null
	var item_id := slot_data.item_id if slot_data != null else -1
	
	if is_instance_valid(collider) and (collider is CharacterBody3D):
		_process_combat_strike(collider, item_id)
		return
		
	var active_tool_type: PlayerViewModel.ToolType = PlayerViewModel.get_tool_type_for_item(item_id)
	if active_tool_type != PlayerViewModel.ToolType.NONE and active_tool_type != PlayerViewModel.ToolType.SWORD:
		_process_mining_strike(inventory_comp)


func _process_combat_strike(collider: Node, item_id: int) -> void:
	if item_id == 17: # Sword
		var entity_domain: VoxelEntity = collider.get("domain_entity") as VoxelEntity
		if is_instance_valid(entity_domain):
			var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
			knockback_dir.y = 2.5
			if collider.has_method("take_damage"):
				collider.call("take_damage", 1, knockback_dir, player)


func _process_mining_strike(inventory_comp: InventoryComponent) -> void:
	var world_ctrl := world_controller as WorldController
	if is_instance_valid(world_ctrl):
		var hit_normal := raycast.get_collision_normal()
		var r_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		if hit_normal.dot(r_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos: Vector3 = raycast.get_collision_point() + (r_dir * 0.05)
		var block_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		var ws := world_ctrl.world_state
		var mined_type := ws.get_block(block_coord) if is_instance_valid(ws) else BlockType.Type.AIR
		
		if mined_type == BlockType.Type.AIR:
			return
			
		var remaining_hits := _damage_service.register_hit(block_coord, mined_type)
		if remaining_hits > 0:
			_spawn_mining_particles(Vector3(block_coord), mined_type)
			AudioService.play_sfx_static("block_place", Vector3(block_coord)) 
			if is_instance_valid(_cracking_visuals):
				var ratio := _damage_service.get_damage_ratio(block_coord)
				_cracking_visuals.update_cracking_overlay(block_coord, ratio)
			return 
			
		if is_instance_valid(_cracking_visuals):
			_cracking_visuals.hide_cracking_overlay()
			
		_spawn_mining_particles(Vector3(block_coord), mined_type)
		_process_block_drops(mined_type, block_coord, inventory_comp)
		world_ctrl.set_block_globally(block_coord, BlockType.Type.AIR)


func _process_block_drops(mined_type: BlockType.Type, _block_coord: Vector3i, inventory_comp: InventoryComponent) -> void:
	var def := block_library_provider.get_definition(mined_type) as BlockDefinition
	if def != null:
		var drop_id := def.get_drop_item_id()
		var qty := def.get_drop_quantity()
		
		if mined_type == BlockType.Type.CROP_RIPE:
			inventory_comp.add_item(20, 1) 
			inventory_comp.add_item(18, randi_range(1, 2)) 
			if is_instance_valid(hud):
				hud.show_quest_notification("NOTIFICATION_HARVEST_SUCCESS_HEADER", "NOTIFICATION_HARVEST_SUCCESS_DESC")
		elif mined_type == BlockType.Type.CROP_SEED or mined_type == BlockType.Type.CROP_GROWING:
			inventory_comp.add_item(18, 1) 
			if is_instance_valid(hud):
				hud.show_quest_notification("NOTIFICATION_CROP_UPROOTED_HEADER", "NOTIFICATION_CROP_UPROOTED_DESC")
		else:
			inventory_comp.add_item(drop_id, qty)
			
		if mined_type == BlockType.Type.LEAVES and randf() < 0.25:
			inventory_comp.add_item(18, 1) 
		
		var active_q: Quest = quest_service_provider.get_active_quest() as Quest
		if active_q != null and active_q.required_item_index == drop_id:
			active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + qty)


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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color_top
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	
	if is_instance_valid(world_controller):
		world_controller.add_child(particles)
		particles.global_position = global_pos + Vector3(0.5, 0.5, 0.5)
	particles.emitting = true


func _build_or_interact() -> void:
	var viewmodel_node: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel_node):
		viewmodel_node.play_swing_animation()
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider := raycast.get_collider()
	if is_instance_valid(collider) and (collider is CharacterBody3D) and collider.has_method("interact"):
		collider.call("interact", player)
		return
		
	var active_slot: int = player.get("active_slot_index") as int
	var inventory_comp: InventoryComponent = player.get("inventory") as InventoryComponent
	var world_ctrl: WorldController = world_controller as WorldController
	
	if not is_instance_valid(inventory_comp) or not is_instance_valid(world_ctrl):
		return
		
	var slot_data := inventory_comp.get_slot_data(active_slot)
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
		
		if strategy.can_use(player.domain_entity, inventory_comp, target_coord, hit_normal, world_state):
			if strategy is PlaceableBlockStrategy:
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				var player_aabb := AABB(player.global_position - Vector3(0.35, 0.05, 0.35), Vector3(0.70, 1.85, 0.70))
				if player_aabb.intersects(block_aabb):
					return
					
			strategy.use(player.domain_entity, inventory_comp, target_coord, hit_normal, world_ctrl.world_modifier)
			
			if is_instance_valid(hud):
				if strategy is ConsumableItemStrategy:
					hud.update_health_display(player.domain_entity.health)
					hud.show_quest_notification("NOTIFICATION_CONSUME_FOOD_HEADER", "NOTIFICATION_CONSUME_FOOD_DESC")
				elif strategy is PlantableItemStrategy:
					hud.show_quest_notification("NOTIFICATION_PLANTED_SEED_HEADER", "NOTIFICATION_PLANTED_SEED_DESC")


# ==============================================================================
# FALLBACK HELPER GETTERS (Strict DIP Compliance)
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
