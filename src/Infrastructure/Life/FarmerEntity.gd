# ==============================================================================
# Project: CraftDomain
# Description: Farmer NPC physics controller. Automatically scans, wanders to,
#              and harvests mature golden crops to replant them, while generating
#              specialized outfits dynamically based on its home biome.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity,
#                overriding behavior, task routing, and visualization loops.
#              - Single Responsibility Principle (SRP): Handles exclusively crop 
#                scanning, agricultural AI work, and harvesting hoe animations.
#              - Open-Closed Principle (OCP) & i18n: Exclusively uses translation 
#                keys to prevent hardcoded string leakage in codebase.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FarmerEntity.gd
# ==============================================================================
class_name FarmerEntity
extends PassiveEntity

# Scanning and harvesting parameters
var _scan_timer: float = 3.0
var _target_crop_coord := Vector3i(0, -999, 0)
var _harvest_timer: float = 0.0

# Handheld tool joint
var _hoe_joint: Node3D


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_FARMER"


## Concrete Implementation: Assembles a detailed farmer, combining 
## customized dungarees and straw hats based on the home biome.
func _build_visual_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Fallback Colors
	var shirt_color := variant_clothing_color
	var denim_color := Color(0.20, 0.35, 0.55)       # Denim Blue overalls
	var strap_color := Color(0.35, 0.22, 0.15)       # Leather straps
	var skin_color := variant_skin_color             # Procedural skin tone
	var hat_color := Color(0.88, 0.78, 0.42)        # Straw yellow hat
	var boots_color := Color(0.18, 0.14, 0.11)       # Muddy boots
	var iron_color := Color(0.50, 0.50, 0.52)        # Raw steel
	
	# Determine specialized colors based on biome
	match biome_id:
		4: # Frostbite Glaciers (Thermal fur-lined overalls)
			denim_color = Color(0.85, 0.85, 0.90)
			hat_color = Color(0.98, 0.98, 0.98)
		7: # Neon Ruins (Cybertech cyber-overalls)
			denim_color = Color(0.12, 0.12, 0.15)
			strap_color = Color(0.0, 0.95, 0.95) # Glowing cyan straps
			hat_color = Color(0.95, 0.0, 0.95)   # Glowing magenta cyber-hat
		8: # Swamp of Sighs (Muddy green overalls)
			denim_color = Color(0.18, 0.28, 0.15)
			boots_color = Color(0.10, 0.08, 0.05)
		9: # Cloud Kingdom (Sky white cloud overalls)
			denim_color = Color(0.95, 0.98, 1.0)
			hat_color = Color(1.0, 0.95, 0.7)
			
	# 1. Base Legs & Feet
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), boots_color)
	
	# 2. Clothed Torso Shirt & Overalls
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color)
	_create_box(_body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.375, 0), denim_color) # Overalls
	_create_box(_body_bob_node, Vector3(0.32, 0.18, 0.05), Vector3(0, 0.60, -0.21), denim_color) # Front bib flap
	
	# Suspender straps
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(-0.13, 0.74, 0), strap_color) 
	_create_box(_body_bob_node, Vector3(0.06, 0.22, 0.49), Vector3(0.13, 0.74, 0), strap_color)  
	
	# 3. Head Joint & Customized Hat Styles
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color) # Face
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Blinking Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.2, 0.2, 0.2))
	
	# Specialized Hat styles (Farmer cap vs wide-brim straw hat)
	if biome_id == 1: # Plumber Cap for Steps biome
		_create_box(_head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), denim_color)
		_create_box(_head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.32, -0.22), denim_color)
	else:
		# Classic Wide-Brim Straw/Field Hat
		_create_box(_head_node, Vector3(0.65, 0.03, 0.65), Vector3(0, 0.36, 0), hat_color) 
		_create_box(_head_node, Vector3(0.24, 0.10, 0.24), Vector3(0, 0.42, 0), hat_color) 
	
	# 4. Arms Folded / Clothed sleeves
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), shirt_color)
	
	# 5. Handheld Tool: Harvesting Hoe (Mounted on right shoulder)
	_hoe_joint = Node3D.new()
	_hoe_joint.name = "HarvestHoeJoint"
	_hoe_joint.position = Vector3(0.18, 0.52, 0.24)
	_hoe_joint.rotation = Vector3(0, 0, deg_to_rad(45)) 
	_body_bob_node.add_child(_hoe_joint)
	
	_create_box(_hoe_joint, Vector3(0.04, 0.52, 0.04), Vector3(0, 0, 0), strap_color) # Handle shaft
	_create_box(_hoe_joint, Vector3(0.06, 0.06, 0.14), Vector3(0, 0.24, -0.06), iron_color) # Socket metal
	_create_box(_hoe_joint, Vector3(0.10, 0.18, 0.04), Vector3(0, 0.21, -0.12), iron_color) # Blade


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", "FARMER")


## Public Gaze Interaction: Localized dialogue trees.
## REFACTORING: Replaced hardcoded dialogue text with dynamic i18n translation keys.
func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("farmer_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "farmer_intro"
			fallback_node.text = "DIALOGUE_FARMER_INTRO"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
		hud.call("open_dialogue", intro_node, "Farmer")


## Main Loop ticker.
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
	_process_farming_ai_intelligence(delta)
	super(delta)


## Scans, wanders to, and actively till/harvests ripe golden crops.
func _process_farming_ai_intelligence(delta: float) -> void:
	var world_node := get_parent() as WorldController
	if not is_instance_valid(world_node) or world_node.world_state == null: 
		return
		
	# Check if currently engaged in a harvesting task
	if current_task != TaskState.WORKING:
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
					current_task = TaskState.WORKING # Lock standard wandering tasks
					print("[FarmerAI] Locked onto ripe wheat at: ", _target_crop_coord)
					return


## Moves to and harvests the locked-on ripe wheat block.
func _execute_crop_harvesting(world_node: WorldController, delta: float) -> void:
	if _target_crop_coord.y == -999:
		current_task = TaskState.IDLE
		return
		
	var target_pos := Vector3(_target_crop_coord) + Vector3(0.5, 0.0, 0.5)
	var diff := target_pos - global_position
	diff.y = 0.0
	
	if diff.length() > 1.1:
		# Walk toward the crop
		_wander_direction = diff.normalized()
		velocity.x = _wander_direction.x * BASE_SPEED
		velocity.z = _wander_direction.z * BASE_SPEED
		
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		# In-range: Stop moving, face the crop, and harvest!
		velocity.x = 0.0
		velocity.z = 0.0
		_wander_direction = diff.normalized()
		
		# Animate: Swing the hoe up and down to till the soil
		_animate_harvesting_hoe(delta)
		
		_harvest_timer -= delta
		if _harvest_timer <= 0.0:
			# Successfully harvested: Remove ripe wheat and replant seeds
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.AIR)
			world_node.set_block_globally(_target_crop_coord, BlockType.Type.CROP_SEED)
			print("[FarmerAI] Harvested and replanted seed at: ", _target_crop_coord)
			
			# Spawn a green sprout particle feedback above the crop!
			_spawn_replant_particle(Vector3(_target_crop_coord))
			
			# Hop with physical joy!
			velocity.y = JUMP_VELOCITY
			
			# Sheathe hoe and reset state
			_reset_hoe_transforms()
			_target_crop_coord = Vector3i(0, -999, 0)
			current_task = TaskState.IDLE
			_task_timer = 2.0


## Animate: Rotates the hoe joint dynamically forward and down to mimic digging.
func _animate_harvesting_hoe(delta: float) -> void:
	if is_instance_valid(_hoe_joint):
		# Interpolate the joint into the farmer's hands
		_hoe_joint.position = _hoe_joint.position.lerp(Vector3(0.18, 0.52, -0.32), delta * 8.0)
		
		# Swing back and forth based on high-frequency sin waves
		var swing_offset := sin(_animation_time * 12.0) * 0.45
		_hoe_joint.rotation.x = lerp(_hoe_joint.rotation.x, deg_to_rad(45) + swing_offset, delta * 12.0)
		_hoe_joint.rotation.y = lerp(_hoe_joint.rotation.y, deg_to_rad(-45), delta * 8.0)
		_hoe_joint.rotation.z = lerp(_hoe_joint.rotation.z, deg_to_rad(0), delta * 8.0)


## Animate: Returns the hoe tool back to its resting position on the shoulder.
func _reset_hoe_transforms() -> void:
	if is_instance_valid(_hoe_joint):
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_hoe_joint, "position", Vector3(0.18, 0.52, 0.24), 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_hoe_joint, "rotation", Vector3(0, 0, deg_to_rad(45)), 0.25).set_trans(Tween.TRANS_SINE)


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
	
	var world_node = get_parent()
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
	var world_controller = get_parent()
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller) and "generator" in world_controller:
		var generator = world_controller.get("generator")
		if generator != null:
			var terrain_noise = generator.get("_terrain_noise")
			if terrain_noise != null:
				var profile = BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.75:
		current_task = TaskState.EXAMINING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(3.0, 7.0)
	elif roll < 0.90:
		current_task = TaskState.WANDERING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(2.0, 4.0)
	else:
		current_task = TaskState.IDLE 
		_task_timer = randf_range(1.0, 2.5)


func _can_socialize() -> bool:
	return current_task != TaskState.WORKING
