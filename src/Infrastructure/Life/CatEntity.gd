# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: CatEntity
# Description: Physical character controller for the domestic companion Cat.
#              Delegates player-following vectors, campfire snuggling loops,
#              and zombie hiss warnings to the CatAIBehavior strategy,
#              managing visual exclamation particles, meow audio cues.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, local audio vocal timers, and warning visual particles.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name CatEntity
extends PassiveEntity

# --- TACTICAL AUDIO COOLDOWN TIMERS (SRP / OCP Compliant) ---
const COOLDOWN_MEOW_MIN_SEC: float = 15.0
const COOLDOWN_MEOW_MAX_SEC: float = 30.0

# Start with a random initial offset on spawn so they don't sync up
var _meow_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Cats spawn with 2 Hearts of health (4 HP) and terrestrial boundaries
	super(spawn_pos, 4)
	entity_habitat = 0 # Terrestrial
	name = "Entity_CAT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Cat companion AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = CatAIBehavior.new()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_CAT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft feline meat proxy)
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


# ==============================================================================
# TACTICAL PRESENTATION & SENSORY WARNING ALARM FEEDBACK
# ==============================================================================

## Visual/Audio Cat Vocalization: Plays the designated 3D spatial cozy meow
func _play_cat_vocal() -> void:
	AudioService.play_sfx_static("cat_meow", global_position, 40.0)


## Visual Alarm: Instantiates warning alert, locks gaze onto zombie and triggers sparks
## Note: Invoked via reflective calls by the CatAIBehavior strategy
func _play_alarm_hiss(zombie_node: CharacterBody3D) -> void:
	if not is_instance_valid(zombie_node):
		return
		
	# Hop startled in the air
	velocity.y = 3.5
	
	# Force brief head gaze lock towards the approaching enemy
	var look_dir := (zombie_node.global_position - global_position).normalized()
	look_dir.y = 0.0
	if is_instance_valid(ai_component):
		ai_component.wander_direction = look_dir
		
	# Play meow chirp sound statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
	
	# Spawn angry warning sparks above head
	_spawn_hiss_alert_particles()


## Spawns tiny exclamation/warning particles above the cat's ears (Compile-Free CPU)
func _spawn_hiss_alert_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, 1.5, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.15, 0.15) # Angry alarm Red sparks!
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	# Native leak-free automatic cleanup on complete emission (Milestone 7)
	particles.finished.connect(particles.queue_free)
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height + 0.1, 0.0)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Process ambient meow timer locally in the presenter to decouple audio
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5: # TASK_PANIC = 5
		is_panicking = true
		
	if not is_panicking:
		_meow_timer -= delta
		if _meow_timer <= 0.0:
			_meow_timer = randf_range(COOLDOWN_MEOW_MIN_SEC, COOLDOWN_MEOW_MAX_SEC)
			_play_cat_vocal()
