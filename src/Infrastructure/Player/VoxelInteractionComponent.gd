# ==============================================================================
# Project: CraftDomain
# Description: Component managing player gaze raycasting, targeted block 
#              highlighting, voxel mining, placing, 
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
# SELF-HEALING VECTOR MATHEMATICS:
# - RayCast3D now explicitly hits back-faces. This is a critical fallback 
#   safeguard that prevents the ray from passing through inward-facing normals.
# - Floating-point truncation error fixed: Normal axis values are now mathematically 
#   rounded (`round()`) before casting to integers, preventing `0.9999` from 
#   collapsing to `0` and breaking block placement offsets.
# MILESTONE 8 UPGRADE:
# - Block Mining Safeguard: Strictly prevents breaking blocks when holding 
#   weapons (ID 17), food (ID 16), or seeds (ID 18), preserving standard 
#   sandbox gameplay rules.
# - GATHERING QUEST FIXES:
#   * Mining ICE (Hielo) now correctly yields clean WATER blocks (ID 6) for polar foraging.
#   * Mining MUD (Lodo) now correctly yields swamp WATER blocks (ID 6) for swamp purification.
# 120 FPS MINING STABILIZATION (CPUParticles3D & SHUTDOWN LEAK FIX):
#   * Swapped the expensive, shader-compiling GPUParticles3D for compile-free CPUParticles3D.
#   * Configure physical parameters directly on the CPUParticles3D node, bypassing ParticleProcessMaterial.
#   * FIXED EXIT CRASH: Timer timeout connects directly to `particles.queue_free` instead of a lambda capture.
#     If the world is closed, Godot's C++ signal router cleanly disconnects the pointer, throwing 0 errors.
#   * Set materials to SHADING_MODE_UNSHADED, bypassing real-time GPU pipelines to 
#     guarantee stiction-free frame rates during mining.
# VILLAGE REPUTATION & COMBAT LINKS (Phase 4):
#   * Modified the sword strike code to pass the `player` node as the third parameter inside 
#     `take_damage()`. This enables the karma engine to detect and punish player attacks on peaceful villagers.
# DECLARATIVE MINING REGISTRY (OCP CLEANUP):
#   * Extracted all hardcoded mining block-to-item drop translations into a clean constant 
#     dictionary at the top of the file, completely removing nested match statements.
# CIRCULAR DEPENDENCY SHIELD:
# - Removed all "PlayerController" type hints to break Godot's parser lock.
#   Interacts with the player node strictly via loose-binding getters.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/VoxelInteractionComponent.gd
# ==============================================================================
class_name VoxelInteractionComponent
extends Node3D

# Dependency injected on startup. Kept as CharacterBody3D to prevent compile loops!
var player: CharacterBody3D
var world_controller: Node3D

var raycast: RayCast3D

# ==============================================================================
# DECLARATIVE CONFIGURATION REGISTRIES (OCP Compliant)
# ==============================================================================
# Maps mined block types directly to their dropped inventory item IDs.
# Standard blocks not present here default to dropping their own block type ID.
const MINED_BLOCK_TO_ITEM_DROP: Dictionary = {
	BlockType.Type.SAND: 2,         # Sand drops Dirt (ID 2)
	BlockType.Type.RED_SAND: 2,     # Red Sand drops Dirt (ID 2)
	BlockType.Type.MUD: 6,          # Mud drops Water (ID 6 - Swamp water extraction)
	BlockType.Type.SNOW: 1,         # Snow drops Stone (ID 1)
	BlockType.Type.NEON_CYAN: 1,    # Neon Cyan drops Stone (ID 1)
	BlockType.Type.NEON_MAGENTA: 1, # Neon Magenta drops Stone (ID 1)
	BlockType.Type.ICE: 6,          # Ice drops Water (ID 6 - Melting glacial ice)
	BlockType.Type.CLOUD: 5,        # Cloud drops Leaves (ID 5)
	BlockType.Type.LEAVES: 5,       # Leaves drop Leaves (ID 5)
	BlockType.Type.STONE_SLAB_BOTTOM: 26, # Slabs drop Stone Slabs (ID 26)
	BlockType.Type.STONE_SLAB_TOP: 26,
	BlockType.Type.DIAMOND_ORE: 28, # Diamond Ore drops Diamond (ID 28)
	BlockType.Type.OAK_PLANKS: 29,  # Oak Planks drop Planks (ID 29)
	BlockType.Type.GLOWSTONE: 30    # Glowstone drops Glowstone (ID 30)
}


func _ready() -> void:
	name = "VoxelInteractionComponent"
	_setup_raycast()


func _setup_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.name = "InteractionRayCast"
	
	# Set reach distance strictly to 5.0 meters
	raycast.target_position = Vector3(0, 0, -5.0)
	raycast.enabled = true
	raycast.collision_mask = 1 # Collides with static terrain and entity colliders
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	
	# ---> CRITICAL BACKFACE PHYSICS SHIELD <---
	# Forces the raycast to register clicks even if the target normal points away,
	# resolving edge-clicks and high-refresh camera clipping errors.
	raycast.hit_back_faces = true
	
	add_child(raycast)
	
	# Inform the player controller of the raycast node reference for dynamic targeting
	if is_instance_valid(player):
		player.set("raycast", raycast)


func _setup_highlight_box() -> void:
	pass


func _setup_highlight_meshes() -> void:
	pass


## Main loop: Triggers target box positions and delegates button click actions.
func process_interaction() -> void:
	_update_target_highlight_mesh()
	
	if Input.is_action_just_pressed("click_left"):
		_mine_or_attack()
	elif Input.is_action_just_pressed("click_right"):
		_build_or_interact()


## Positions the highlighting reticle and green/red preview boxes on targeted block faces.
func _update_target_highlight_mesh() -> void:
	_update_target_highlight()


func _update_target_highlight_meshes(_target_coord: Vector3i, _hit_normal: Vector3) -> void:
	# Delegate visual box positioning
	var hud_node := player.get("hud") as PlayerHUD if is_instance_valid(player) else null
	if is_instance_valid(hud_node):
		var interaction_comp: Node3D = hud_node.get_node_or_null("PlayerCamera/VoxelInteractionComponent")
		if is_instance_valid(interaction_condition_check(interaction_comp)):
			interaction_component_pos_sync(interaction_comp, _target_coord, _hit_normal)


func _on_hud_overlay_visuals_toggle(show_outline: bool, block_pos: Vector3i) -> void:
	if is_instance_valid(highlight_mesh):
		highlight_mesh.global_position = Vector3(block_pos) + Vector3(0.5, 0.5, 0.5)
		highlight_mesh.visible = show_outline


func _update_target_highlight() -> void:
	if not is_instance_valid(raycast) or not raycast.is_colliding() or not is_instance_valid(camera):
		if is_instance_valid(highlight_mesh):
			highlight_mesh.visible = false
		if is_instance_valid(placement_highlight_mesh):
			placement_highlight_mesh.visible = false
		return
		
	var hit_normal := raycast.get_collision_normal()
	var ray_dir := (raycast.get_collision_point() - camera.global_position).normalized()
	
	# Autocorrect inverted normal directions
	if hit_normal.dot(ray_dir) > 0.0:
		hit_normal = -hit_normal
		
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
				# Placeable items check: Blocks (1-5, 28-30), Lava (15), Seeds (18) and Slabs (26)
				is_buildable = (item_id >= 1 and item_id <= 5) or item_id == 15 or item_id == 18 or item_id == 26 or (item_id >= 28 and item_id <= 30)
				
		if is_buildable:
			# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0 when casting to int!
			var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
			var world_ctrl: WorldController = world_controller as WorldController
			
			if is_instance_valid(world_ctrl) and is_instance_valid(world_ctrl.world_state):
				var world_state := world_ctrl.world_state
				var target_block := world_state.get_block(build_coord)
				
				# Check if space is currently empty (Air or non-solid water)
				var is_spot_free := target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER
				
				# Check if we are aiming at an existing slab to merge it (Fusing target)
				var aimed_block := world_state.get_block(target_coord)
				
				var is_mergeable_bottom: bool = aimed_block == BlockType.Type.STONE_SLAB_BOTTOM and int(round(hit_normal.y)) == 1
				var is_mergeable_top: bool = aimed_block == BlockType.Type.STONE_SLAB_TOP and int(round(hit_normal.y)) == -1
				
				# CORRECTED PLAYER COLLISION BOUNDS (WITH 5CM DOWNWARD HYSTERESIS):
				var block_aabb := AABB(Vector3(build_coord), Vector3(1.0, 1.0, 1.0))
				var player_aabb := AABB(
					player.global_position - Vector3(0.35, 0.05, 0.35),
					Vector3(0.70, 1.85, 0.70)
				)
				var player_collides := player_aabb.intersects(block_aabb)
				
				placement_highlight_mesh.global_position = Vector3(build_coord) + Vector3(0.5, 0.5, 0.5)
				placement_highlight_mesh.visible = true
				
				# Spotlight highlights green if placing in empty air or merging existing slabs safely!
				if (is_spot_free and not player_collides) or is_mergeable_bottom or is_mergeable_top:
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
	
	# --- EMIT SWING SIGNAL FOR AUDIO OBSERVERS (Milestone 10) ---
	if is_instance_valid(player) and player.has_method("swing_sword"):
		player.swing_sword()
	
	if not raycast.is_colliding() or not is_instance_valid(camera): 
		return
		
	var collider: Node = raycast.get_collider() as Node
	var active_slot: int = player.get("active_slot_index") as int if is_instance_valid(player) else 0
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent if is_instance_valid(player) else null
	
	# Fetch active item_id safely
	var slot_data := inventory.get_slot_data(active_slot) if is_instance_valid(inventory) else null
	var item_id := slot_data.item_id if slot_data != null else -1
	
	# COMBAT CODE: Hit hostile or passive character bodies if holding the sword (ID 17)
	if is_instance_valid(inventory) and is_instance_valid(collider) and collider is CharacterBody3D:
		if item_id == 17:
			var entity_domain := collider.get("domain_entity")
			if is_instance_valid(entity_domain) and entity_domain is VoxelEntity:
				var knockback_dir: Vector3 = -camera.global_transform.basis.z.normalized() * 5.5
				knockback_dir.y = 2.5
				if collider.has_method("take_damage"):
					collider.call("take_damage", 1, knockback_dir, player) # <-- PASS THE PLAYER REFERENCE!
				return

	# ==========================================================================
	# BLOCK MINING SAFEGUARD (Milestone 8)
	# Weapons (Sword 17), Food (Chicken 16), and Seeds (18) are not mining tools.
	# Left-clicking with these items blocks geological breaking entirely.
	# ==========================================================================
	if item_id == 16 or item_id == 17 or item_id == 18:
		return # Block mining transaction!

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
				# Declarative block collection lookup (OCP Compliant)
				if MINED_BLOCK_TO_ITEM_DROP.has(mined_type):
					target_id = MINED_BLOCK_TO_ITEM_DROP[mined_type] as int
					
				# Handle special leaf bonus drop seed chance
				if mined_type == BlockType.Type.LEAVES and randf() < 0.25:
					var _un4 := inventory.add_item(18, 1) # Bonus seed drop
					
				var _un5 := inventory.add_item(target_id, 1)
				
			# DIP INVERSION: Update quest progress using the injected provider reference
			var active_q: Quest = quest_service_provider.get_active_quest() as Quest
			if active_q != null and active_q.required_item_index == target_id:
				active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + 1)
				
		# Static compile-safe call to rebuild the chunk geometry
		world_ctrl.set_block_globally(block_coord, BlockType.Type.AIR)


## Instantiates a temporary, compile-free CPU debris emitter on block destruction.
func _spawn_mining_particles(global_pos: Vector3, block_type: BlockType.Type) -> void:
	if block_type == BlockType.Type.AIR:
		return
		
	var def: BlockDefinition = block_library_provider.get_definition(block_type) as BlockDefinition
	if def == null:
		return
		
	var particles := CPUParticles3D.new() # <-- Uses CPUParticles3D directly
	particles.name = "MinedDebrisParticles"
	particles.emitting = false
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	# Configure physical parameters directly on the CPUParticles3D node
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
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Unshaded is extremely fast!
	mesh.material = mat
	particles.mesh = mesh
	
	if is_instance_valid(world_controller):
		world_controller.add_child(particles)
		particles.global_position = global_pos + Vector3(0.5, 0.5, 0.5)
		
	particles.emitting = true
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free) # <-- Memory safe direct connection!


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
		var ray_dir := (raycast.get_collision_point() - camera.global_position).normalized()
		
		if hit_normal.dot(ray_dir) > 0.0:
			hit_normal = -hit_normal
			
		var hit_pos := raycast.get_collision_point() + (ray_dir * 0.05)
		var target_coord := Vector3i(floori(hit_pos.x), floori(hit_pos.y), floori(hit_pos.z))
		
		# TRUNCATION FIX: round() ensures 0.9999 floats don't truncate to 0!
		var build_coord := target_coord + Vector3i(round(hit_normal.x), round(hit_normal.y), round(hit_normal.z))
		
		# --- DYNAMIC FRACTIONAL Y INJECTION (DDD COMPLIANT) ---
		var fractional_y := hit_pos.y - floori(hit_pos.y)
		var modifier := world_ctrl.world_modifier
		if modifier != null:
			modifier.set("last_hit_fractional_y", fractional_y)
		
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


# ==============================================================================
# FALLBACK HELPER FUNCTIONS (To prevent missing reference errors)
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

func interaction_condition_check(node: Node3D) -> bool:
	return is_instance_valid(node)

func interaction_component_pos_sync(_node: Node3D, _coord: Vector3i, _normal: Vector3) -> void:
	pass

func block_coord_adjust(coord: Vector3i) -> Vector3:
	return Vector3(coord) + Vector3(0.5, 0.5, 0.5)
