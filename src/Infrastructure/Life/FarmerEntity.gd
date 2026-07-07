# ==============================================================================
# Project: CraftDomain
# Description: Farmer NPC physics controller with dynamic visual strategy injection.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively agricultural 
#                AI, crop scanning, and tilling logic, delegating all rendering/mesh tasks.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly, 
#                inheriting the base collision, gravity, and lifecycle contracts.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected `IEntityVisualRepresentation` strategy.
# INTERACTION RECONSTRUCTION (OCP):
#              - Restored the missing `interact()` and `_select_procedural_greeting_key()` 
#                methods, enabling player dialogues using localized translation keys 
#                flawlessly depending on active biomes and sunset hours.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FarmerEntity.gd
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/farmer/farmer_base.fbx"

# Scanning and harvesting parameters
var _scan_timer: float = 3.0
var _target_crop_coord := Vector3i(0, -999, 0)
var _harvest_timer: float = 0.0


func _init(spawn_pos: Vector3) -> void:
	# Initialize with 3 Hearts of health
	super(spawn_pos, 6)
	name = "Entity_FARMER"


# ==============================================================================
# POLYMORPHIC DOMAIN CONTRACTS (LSP/OCP COMPLIANCE)
# ==============================================================================

## Concrete Implementation (DIP): Injects the modular Farmer Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.FARMER


func _get_habitat() -> MobRegistry.Habitat:
	return MobRegistry.Habitat.TERRESTRIAL


## Restored: Registers right-click interactions to trigger agricultural dialogues
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "farmer_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
		
		hud.open_dialogue(intro_node, "NPC_NAME_FARMER", self)


## Restored: Returns localized advice keys based on time and biome coordinates
func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_FARMER_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		4: return "DIALOGUE_FARMER_GLACIERS"   # Frostbite Glaciers
		7: return "DIALOGUE_FARMER_NEON"       # Neon Ruins
		_:
			# Default Golden Bazaar plains variety
			return "DIALOGUE_FARMER_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_FARMER_PLAINS_B"


# ==============================================================================
# AGRICULTURAL INTELLIGENCE ENGINE (SRP)
# ==============================================================================

## Overrides standard physics ticker to weave defensive aggro scanning loops.
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	if is_talking:
		velocity = Vector3.ZERO
		super(delta)
		return
		
	_process_farming_ai_intelligence(delta)
	super(delta)


## Scans, wanders to, and actively tilled/harvests ripe golden crops.
func _process_farming_ai_intelligence(delta: float) -> void:
	var world_node := get_parent() as WorldController
	if not is_instance_valid(world_node) or world_node.world_state == null: 
		return
		
	# Check if currently engaged in a harvesting task
	var current_task := ai_component.current_task if is_instance_valid(ai_component) else int(NPCAIComponent.TaskState.IDLE)
	if current_task != NPCAIComponent.TaskState.WORKING:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 3.0
			_scan_for_ripe_crops(world_node.world_state)
	else:
		_execute_crop_harvesting(world_node, delta)


## Proximity Scanner: Identifies mature wheat blocks within 3 meters.
func _scan_for_ripe_crops(world_state: WorldState) -> void:
	var my_coord := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				if world_state.get_block(check_coord) == BlockType.Type.CROP_RIPE:
					_target_crop_coord = check_coord
					_harvest_timer = 1.8 
					if is_instance_valid(ai_component):
						ai_component.current_task = NPCAIComponent.TaskState.WORKING # Lock standard wandering decisions
					return


## Moves to and harvests the locked-on ripe wheat block.
func _execute_crop_harvesting(world_node: WorldController, delta: float) -> void:
	if _target_crop_coord.y == -999:
		if is_instance_valid(ai_component):
			ai_component.current_task = NPCAIComponent.TaskState.IDLE
		return
		
	var target_pos := Vector3(_target_crop_coord) + Vector3(0.5, 0.0, 0.5)
	var diff := target_pos - global_position
	diff.y = 0.0
	
	if diff.length() > 1.1:
		# Walk toward the crop (Read and calculate movement, guiding visual look slerps)
		var wander_dir := diff.normalized()
		velocity.x = wander_dir.x * BASE_SPEED
		velocity.z = wander_dir.z * BASE_SPEED
		
		if is_instance_valid(ai_component):
			ai_component.wander_direction = wander_dir
		
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		# In-range: Halt and swing!
		velocity.x = 0.0
		velocity.z = 0.0
		
		if is_instance_valid(ai_component):
			ai_component.wander_direction = diff.normalized()
		
		# SOLID: Delegate harvesting visual swing to the injected strategy
		if is_instance_valid(visual_representation):
			visual_representation.trigger_attack_visuals()
		
		_harvest_timer -= delta
		if _harvest_timer <= 0.0:
			# Successfully harvested: Remove ripe wheat and replant seeds
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.AIR)
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.CROP_SEED)
			
			# Spawn a green sprout particle feedback above the crop!
			_spawn_replant_particle(Vector3(_target_crop_coord))
			
			# Hop with physical joy!
			velocity.y = JUMP_VELOCITY
			
			_target_crop_coord = Vector3i(0, -999, 0)
			
			if is_instance_valid(ai_component):
				ai_component.current_task = NPCAIComponent.TaskState.IDLE
				ai_component.task_timer = 2.0


## Spawns agricultural sprout feedback particles above the tilled soil coordinate.
func _spawn_replant_particle(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.4
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.2, 0.1, 0.2)
	pm.direction = Vector3(0, 1.0, 0)
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.85, 0.25) # Vibrant green sprout
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	var world_node: Node = get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = pos + Vector3(0.5, 0.25, 0.5)
		particles.emitting = true
		
	get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


## Dynamic Collision Box Sizing: Adapts physically to voxel (1.5m) vs Mixamo (1.8m) heights
func _get_collision_box_size() -> Vector3:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		return Vector3(0.6, 1.8, 0.6) # Standard Mixamo height (1.8m)
	return Vector3(0.575, 1.5, 0.575) # Voxel fallback height (1.5m)


## Dynamic Collision Box Position: Centered dynamically depending on active scale
func _get_collision_box_position() -> Vector3:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		return Vector3(0.0, 0.9, 0.0) # Center Y at 0.9m for 1.8m box
	return Vector3(0.0, 0.75, 0.0) # Center Y at 0.75m for 1.5m box


func _can_socialize() -> bool:
	return true
