# ==============================================================================
# Project: CraftDomain
# Description: Villager NPC physics controller with dynamic visual strategy injection.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Inherits PassiveEntity, 
#                matching the base collision, gravity, and lifecycle contracts.
#              - Single Responsibility Principle (SRP): Delegates visual rendering 
#                to the sub-component, and physics movements to the base class.
#              - Dependency Inversion Principle (DIP): Resolves time-of-day queries 
#                statically through the decoupled CelestialService provider.
# HYBRID GRAPHICS PIPELINE & SKELETAL BLENDING:
#              - Attempts to load `assets/models/mobs/villager/villager_base.fbx`.
#              - Programmatically loads separate animation files (idle, walk, panic, jump) 
#                from the same folder, extracts their bone tracks, and 
#                injects them into the main AnimationPlayer at runtime.
#              - Scale is calibrated dynamically to 0.8856x (calculated via 
#                natively-headless analyze_model.gd) to match 1.8m height perfectly.
#              - Panic Fallback: If `villager_panic` is missing, the script automatically 
#                accelerates the `walk` animation speed to simulate sprinting procedurally.
#              - Fallback: Reverts to building procedurally generated voxel-villagers 
#                (with dynamic skin tones, outfits, hats, and hair) if GLB is missing.
#              - Dynamic Collision: Swaps collision shape sizes from 0.8m to 1.8m in 
#                runtime based on asset existence, matching Mixamo sizes.
# JUMP ANIMATION INTEGRATION:
#              - Added dynamic binding and loading support for the new `villager_jump.fbx` track.
#              - Blends the airborne jumping states elegantly inside the Mixamo state controller.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/VillagerEntity.gd
# ==============================================================================
class_name VillagerEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/villager/villager_base.fbx"

# Visual GLB/FBX references
var _model_node: Node3D
var _anim_player: AnimationPlayer


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_VILLAGER"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		_build_glb_representation()
	else:
		_build_procedural_representation()


func _build_glb_representation() -> void:
	var model_scene := load(BASE_MODEL_PATH) as PackedScene
	_model_node = model_scene.instantiate() as Node3D
	
	# Prune Blender's default light and camera nodes
	_prune_extraneous_nodes(_model_node)
	
	# ======================================================================
	# DYNAMIC GEOMETRY CALIBRATION (Fitted via analyze_model.gd telemetry)
	# ======================================================================
	# 1. Scale model by 0.8856x to achieve a perfect humanoid height of ~1.8m
	_model_node.scale = Vector3(0.8856, 0.8856, 0.8856)
	
	# 2. Origin is flat on its feet natively (Y = 0.0)
	_model_node.position = Vector3(0.0, 0.0, 0.0)
	
	# 3. Orient forward
	_model_node.rotation_degrees = Vector3(0, 180, 0) # Face forward (-Z)
	# ======================================================================
	
	visual_component.body_bob_node.add_child(_model_node)
	_register_glb_materials(_model_node)
	
	# Find nested AnimationPlayer inside Mixamo rig hierarchy
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player):
		_load_external_fbx_animations()
		_anim_player.play("idle")


## Programmatically extracts and compiles separate FBX/GLTF animation tracks
func _load_external_fbx_animations() -> void:
	if not is_instance_valid(_anim_player):
		return
		
	# Ensure the default animation library exists
	var anim_library := _anim_player.get_animation_library("")
	if anim_library == null:
		anim_library = AnimationLibrary.new()
		_anim_player.add_animation_library("", anim_library)
		
	# Paths to separate Mixamo FBX animations
	var anim_sources := {
		"idle": ANIM_DIR + "villager/villager_idle.fbx",
		"walk": ANIM_DIR + "villager/villager_walk.fbx",
		"panic": ANIM_DIR + "villager/villager_panic.fbx",
		"jump": ANIM_DIR + "villager/villager_jump.fbx" # <-- Added for jump track
	}
	
	for anim_name: String in anim_sources.keys():
		var path: String = anim_sources[anim_name] as String
		if FileAccess.file_exists(path):
			var anim_scene := load(path) as PackedScene
			if anim_scene != null:
				var temp_instance := anim_scene.instantiate()
				var temp_player := temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
				
				if is_instance_valid(temp_player) and temp_player.get_animation_list().size() > 0:
					var raw_name := temp_player.get_animation_list()[0]
					var animation_resource := temp_player.get_animation(raw_name)
					
					# Force loop mode on idle, walk, and panic tracks
					if anim_name == "idle" or anim_name == "walk" or anim_name == "panic":
						animation_resource.loop_mode = Animation.LOOP_LINEAR
					elif anim_name == "jump":
						animation_resource.loop_mode = Animation.LOOP_NONE
						
					anim_library.add_animation(anim_name, animation_resource)
					print("  -> Bound dynamic FBX animation: '", anim_name, "' from ", path)
					
				temp_instance.queue_free()


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_procedural_representation() -> void:
	var biome_id := _detect_current_biome()
	
	# Extract procedural color parameters calculated on boot by the visual component
	var skin_color: Color = visual_component.variant_skin_color
	var hair_color: Color = visual_component.variant_hair_color
	var robe_color: Color = visual_component.variant_clothing_color
	
	# Fallback accessory colors
	var boots_color := Color(0.12, 0.12, 0.15)       # Dark boots black
	var pants_color := Color(0.18, 0.15, 0.12)       # Dark trousers brown
	var brow_brown := Color(0.18, 0.12, 0.08)        # Unibrow dark brown
	var nose_brown := Color(0.55, 0.42, 0.32)       # Big long nose brown
	var eye_green := Color(0.0, 0.75, 0.35)          # High-contrast emerald eye cian
	
	# 1. Base Legs & Segmented Feet (Attached to the bouncing joint)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(-0.1, 0.14, 0.0), pants_color) # Left leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(0.1, 0.14, 0.0), pants_color)  # Right leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.08, 0.20), Vector3(-0.1, 0.04, -0.02), boots_color) # Left boot
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.08, 0.20), Vector3(0.1, 0.04, -0.02), boots_color)  # Right boot
	
	# 2. Torso Robe (Customized dynamically by biome)
	_build_custom_torso_robe(biome_id, robe_color, pants_color)
	
	# 3. Head Joint Setup (Elongated bald forehead style!)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	# Face blocks (Scaled height to 0.52 to create the iconic bald towering forehead!)
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.52, 0.35), Vector3(0, 0.26, 0), skin_color) # Elongated Face core
	
	# Giant Protruding Nose (Dangling down past its chin)
	visual_component.create_box(visual_component.head_node, Vector3(0.10, 0.26, 0.12), Vector3(0, 0.06, -0.22), nose_brown)
	
	# Prominent Voxel Unibrow (Flat dark-brown plate directly above eyes)
	visual_component.create_box(visual_component.head_node, Vector3(0.28, 0.04, 0.06), Vector3(0, 0.22, -0.19), brow_brown)
	
	# Deep-set Blinking Emerald Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.09, 0.15, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), eye_green) # Left emerald pupil
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.09, 0.15, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), eye_green) # Right emerald pupil
	
	# 4. Folded Arms (Classic Villager folded pose joint)
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Biome-Specific Headwear & Accessories
	_build_custom_headwear(biome_id, hair_color)


## Procedural Torso Customizer: Generates unique clothing shapes and palettes.
func _build_custom_torso_robe(biome_id: int, base_color: Color, accessory_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Stripes)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color.WHITE)
			# Blue stripes overlay
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.75, 0), Color(0.12, 0.45, 0.82))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.25, 0), Color(0.12, 0.45, 0.82))
		1: # Warp Plateau (Mario Plumber Dungarees)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.85, 0.12, 0.12)) # Red shirt
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), Color(0.15, 0.35, 0.72)) # Denim pants
			# Yellow gold buttons
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(-0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.03), Vector3(0.11, 0.45, -0.24), Color(1.0, 0.85, 0.2))
		4: # Frostbite Glaciers (Thermal fur-lined overalls)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.82, 0.82, 0.85)) # Winter white coat
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.10, 0.48), Vector3(0, 0.15, 0), Color(0.98, 0.98, 0.98)) # Fluffy fur trim
		5: # Whispering Redwood Forest (Ranger Green tunic)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.18, 0.45, 0.15))
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.06, 0.48), Vector3(0, 0.45, 0), accessory_color) # Leather belt
		7: # Neon Ruins (Cyberpunk Techwear)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.12, 0.12, 0.15)) # Dark carbon jacket
			# Cybernetic neon pipelines
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.65, 0), Color(0.0, 0.95, 0.95)) # Cyan stripe
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.06, 0.47), Vector3(0, 0.45, 0), Color(0.95, 0.0, 0.95)) # Magenta stripe
		8: # Swamp of Sighs (Murky Mud robes)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.28, 0.22, 0.15)) # Mud brown
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.47, 0.18, 0.47), Vector3(0, 0.32, 0), Color(0.18, 0.15, 0.12)) # Dark patches
		9: # Cloud Kingdom (Sky Clouds Tunic)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.95, 0.98, 1.0)) # Cloud white
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.15, 0.48), Vector3(0, 0.80, 0), Color(1.0, 0.98, 0.85)) # Light gold trim
		_: # Default Plains (High-collared purple tunic)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), base_color)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), accessory_color)
			visual_component.create_box(visual_component.body_bob_node, Vector3(0.12, 0.1, 0.05), Vector3(0, 0.45, -0.25), Color(0.65, 0.65, 0.7))


## Procedural Headwear Customizer: Generates unique caps, visors, halos, and hoods.
func _build_custom_headwear(biome_id: int, hair_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Bandana)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.10, 0.10, 0.15), Vector3(0, 0.42, 0.22), Color(0.12, 0.45, 0.82)) 
		1: # Warp Plateau (Mario Plumber Cap)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.52, 0), Color(0.85, 0.12, 0.12)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.48, -0.22), Color(0.85, 0.12, 0.12)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.12, 0.10, 0.03), Vector3(0, 0.52, -0.20), Color.WHITE) 
		4: # Frostbite Glaciers (Heavy insulated white fur)
			visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.48, 0.39), Vector3(0, 0.26, 0.02), Color(0.82, 0.82, 0.85)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.42, 0.52, 0.10), Vector3(0, 0.26, -0.15), Color(0.98, 0.98, 0.98)) 
		5: # Whispering Redwood Forest (Elven Leaf Crown)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.05, 0.38), Vector3(0, 0.48, 0), Color(0.85, 0.6, 0.15)) 
			visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.14, 0.04), Vector3(0, 0.52, -0.19), Color(0.18, 0.45, 0.15)) 
		7: # Neon Ruins (Cyber Visor)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.10, 0.08), Vector3(0, 0.19, -0.16), Color(0.0, 0.95, 0.95))
		8: # Swamp of Sighs (Murky Mud Tattered Hood)
			visual_component.create_box(visual_component.head_node, Vector3(0.39, 0.48, 0.39), Vector3(0, 0.26, 0.02), Color(0.28, 0.22, 0.15))
			visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.08, 0.32), Vector3(0, 0.48, -0.05), Color(0.18, 0.15, 0.12))
		9: # Cloud Kingdom (Angelic Golden Halo)
			visual_component.create_box(visual_component.head_node, Vector3(0.32, 0.03, 0.32), Vector3(0, 0.58, 0), Color(1.0, 0.85, 0.2)) 
		_: # Default Plains (Aesthetic hair modeling, offset upwards to clear the tall forehead)
			visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.46, 0.03), hair_color)
			visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.20, 0.38), Vector3(-0.18, 0.34, 0.03), hair_color)
			visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.20, 0.38), Vector3(0.18, 0.34, 0.03), hair_color)


## Public Gaze Interaction: Triggers localized village dialogue progression.
func interact(player_node: CharacterBody3D) -> void:
	var active_q := QuestService.get_active_quest()
	
	# Quest completion trigger for "1. The Lost Bazaar"
	if active_q != null and active_q.quest_id == "lost_bazaar":
		QuestService.complete_active_quest(player_node)
		
		var complete_node := DialogueNode.new()
		complete_node.node_id = "villager_quest_complete"
		complete_node.text = "DIALOGUE_VILLAGER_QUEST_COMPLETE"
		DialogueService.register_node(complete_node)
		
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.open_dialogue(complete_node, "NPC_NAME_VILLAGER", self)
	else:
		# Standard procedural dialogue routing
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			var intro_node := DialogueNode.new()
			intro_node.node_id = "villager_intro_temp"
			intro_node.text = _select_procedural_greeting_key()
			
			hud.open_dialogue(intro_node, "NPC_NAME_VILLAGER", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	# DIP Compliance: Safely retrieve time statically
	var is_night: bool = CelestialService.is_night_time_static()
		
	if is_night:
		return "DIALOGUE_VILLAGER_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		0: return "DIALOGUE_VILLAGER_OCEAN"     
		4: return "DIALOGUE_VILLAGER_GLACIERS"   
		7: return "DIALOGUE_VILLAGER_NEON"        
		8: return "DIALOGUE_VILLAGER_SWAMP"       
		9: return "DIALOGUE_VILLAGER_CLOUD"       
		_:
			var variety_index := npc_seed % 3
			match variety_index:
				0: return "DIALOGUE_VILLAGER_PLAINS_A"
				1: return "DIALOGUE_VILLAGER_PLAINS_B"
				_: return "DIALOGUE_VILLAGER_PLAINS_C"


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


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


func _can_socialize() -> bool:
	return true


func _is_avian() -> bool:
	return false


## Overrides standard physics tracker to execute skeletal animations
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	# Apply downward gravity conditionally
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	# Process AI component decision tree calculations
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
	
	_quest_check_timer -= delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = 0.5
		_update_quest_bubble_state()

	# Process Skeletal Animation blended states (Mixamo)
	_process_skeletal_animations(delta)

	move_and_slide()


## Machine-state Controller: Blends Mixamo skeletal joints seamlessly
func _process_skeletal_animations(_delta: float) -> void:
	if not is_instance_valid(_anim_player):
		return
		
	var flat_velocity := Vector2(velocity.x, velocity.z)
	var is_moving := flat_velocity.length_squared() > 0.1
	
	var is_panicking := false
	if is_instance_valid(ai_component):
		is_panicking = ai_component.current_task == NPCAIComponent.TaskState.PANIC
	
	# State blending priority checks
	if not is_on_floor(): # <-- High priority jump check!
		_play_animation_safe("jump", 1.0)
	elif is_panicking and is_moving:
		if _anim_player.has_animation("panic"):
			_play_animation_safe("panic", 1.0)
		else:
			# Fallback: Play walk animation at double speed!
			_play_animation_safe("walk", 1.8)
	elif is_moving and is_on_floor():
		_play_animation_safe("walk", 1.0)
	else:
		_play_animation_safe("idle", 1.0)


## Prevents animation snapping by executing a 0.25s linear crossfade
func _play_animation_safe(anim_name: String, speed: float = 1.0) -> void:
	if is_instance_valid(_anim_player) and _anim_player.has_animation(anim_name):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != anim_name:
			# Execute a 0.25s smooth crossfade blend to prevent bone snapping!
			_anim_player.play(anim_name, 0.25)


## Dynamic Collision Box Sizing: Adapts physically to voxel (0.8m) vs Mixamo (1.8m) heights
func _get_collision_box_size() -> Vector3:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		return Vector3(0.6, 1.8, 0.6) # Standard Mixamo height (1.8m)
	return Vector3(0.6, 0.8, 0.6) # Voxel fallback height (0.8m)


## Dynamic Collision Box Position: Centered dynamically depending on active scale
func _get_collision_box_position() -> Vector3:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		return Vector3(0.0, 0.9, 0.0) # Center Y at 0.9m for 1.8m box
	return Vector3(0.0, 0.4, 0.0) # Center Y at 0.4m for 0.8m box


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)
