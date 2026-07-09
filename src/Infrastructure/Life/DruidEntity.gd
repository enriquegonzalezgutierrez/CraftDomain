# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: DruidEntity
# Description: Physical character controller for the forest guardian Druid.
#              It delegates all wildlife scanning, magical spellcasting timers, 
#              and healing triggers to the decoupled DruidAIBehavior strategy,
#              focusing strictly on dialogs, physical translations, and 
#              unshaded compile-free éter particles generation.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, dialogue trees, and magical visual feedback.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, calling super() on ready to maintain lifecycle setups.
# - Dependency Inversion Principle (DIP): Injects the DruidAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/DruidEntity.gd
# ==============================================================================
class_name DruidEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Druids spawn with 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_DRUID"


func _ready() -> void:
	# Run base class ready lifecycle first to register in 'passives' group
	super()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Druid magical overwatch AI strategy dynamically on ready,
	# completely overriding the default generic civilian schedules.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = DruidAIBehavior.new()


## Concrete Implementation (DIP): Injects the modular Druid Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.DRUID


func _get_habitat() -> int:
	return 0 # 0 = Habitat.TERRESTRIAL


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "druid_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_DRUID", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		return "DIALOGUE_DRUID_NIGHT"
		
	return "DIALOGUE_DRUID_PLAINS_A" if (npc_seed % 2 == 0) else "DIALOGUE_DRUID_PLAINS_B"


func _can_socialize() -> bool:
	# Socialize is disabled during ritual channeling
	if is_instance_valid(ai_component):
		return ai_component.current_task != 6 # TASK_WORKING (Casting)
	return true


# ==============================================================================
# MAGICAL PRESENTATION & EMERALD ÉTER CASTING
# ==============================================================================

## Visual Magical Spell: Directs look gaze and spawns a stream of healing emerald éter particles
## Note: Invoked via reflective calls by the DruidAIBehavior strategy
func _play_healing_visuals(target_node: Node3D) -> void:
	if not is_instance_valid(target_node):
		return
		
	# Throttle particle spawning: spawn particles at 10Hz to prevent clutter and CPU stress
	var frame_stamp := Engine.get_physics_frames()
	if frame_stamp % 12 == 0:
		_spawn_magical_heal_particle(target_node.global_position)


## Spawns a tilled green éter particle packet directed towards the target coordinates
func _spawn_magical_heal_particle(target_pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.55
	
	# Calculate directional trajectory vector pointing to target
	var direction_vec := (target_pos - global_position).normalized()
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = direction_vec
	particles.spread = 25.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -1.0, 0.0) # Slow drift down
	
	# Bright emerald-green box particles representing botanical éter!
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.95, 0.35) # High-vibrancy botanical green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Extremely fast compile-free
	mesh.material = mat
	particles.mesh = mesh
	
	# Add to world parent node to prevent particles moving with the druid
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(particles)
		
		# Symmetrical start pos: spawn slightly above hand/báculo (approx 1.1m height)
		particles.global_position = global_position + Vector3(0.0, 1.1, 0.0)
		particles.emitting = true
		
		# Symmetrical safety cleanup direct connection
		get_tree().create_timer(0.65).timeout.connect(particles.queue_free)
