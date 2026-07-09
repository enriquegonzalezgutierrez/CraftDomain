# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: MerchantEntity
# Description: Physical character controller for the Village Merchant NPC.
#              It delegates all marketplace shop-tending and nighttime shelter
#              coin counting to the decoupled MerchantAIBehavior strategy,
#              managing visual glistening metallic gold coin particles on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, custom mesh alignments, and gold coin visual particles.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the MerchantAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/merchant/merchant_base.fbx"


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Merchants spawn with 3 Hearts of health (6 HP)
	super(spawn_pos, 6)
	name = "Entity_MERCHANT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Injects and compiles its specific Mixamo animations strategy (fixes T-Pose)
	_build_visual_representation()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Merchant business AI strategy dynamically on ready,
	# completely overriding the default generic civilian schedules.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MerchantAIBehavior.new()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(0.8856, 0.8856, 0.8856))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	strategy.set("anim_idle_path", ANIM_DIR + "merchant/merchant_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "merchant/merchant_walk.fbx")
	strategy.set("anim_panic_path", ANIM_DIR + "merchant/merchant_panic.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "merchant/merchant_jump.fbx")
	
	# Bind as standard generic Resource contract
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


# ==============================================================================
# CONVERSATION BARK & DIALOGUES
# ==============================================================================
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueService.get_dialogue_node("merchant_intro")
		if intro_node == null:
			DialogueRegistry.initialize_dialogue_database()
			intro_node = DialogueService.get_dialogue_node("merchant_intro")
			
		if intro_node != null:
			hud.open_dialogue(intro_node, "NPC_NAME_MERCHANT", self)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TRADE"))


func _can_socialize() -> bool:
	# Socialize is disabled during nighttime accounting counting
	var is_night: bool = CelestialService.is_night_time_static()
	return not is_night


# ==============================================================================
# TACTICAL PRESENTATION & COIN COUNTING EFFECTS
# ==============================================================================

## Visual Gold Counting: Spawns continuous glistening golden spark coins
## Note: Invoked via reflective calls by the MerchantAIBehavior strategy
func _play_counting_coins() -> void:
	_spawn_golden_coin_particles()


## Spawns glittering physical-looking gold flakes in front of palms (Compile-Free CPU)
func _spawn_golden_coin_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.12, 0.04, 0.12)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 20.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -9.8, 0.0) # Gravity pulls coins down to palms
	
	# Gold color-shards representing coin units
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2) # Warm Gold
	mat.roughness = 0.15 # Metallic specular reflection
	mat.metallic = 0.9
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 1.3
	mesh.material = mat
	particles.mesh = mesh
	
	add_child(particles)
	particles.position = Vector3(0.0, _collision_height - 0.4, -0.2) # Held right in front of chest
	particles.emitting = true
	
	# Safe memory cleanup direct connection
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)
