# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the Merchant NPC, utilizing the Strategy
#              pattern to load dynamic animations cleanly.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively merchant
#                dialogues and trading, delegating rendering to the Strategy.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Replaced static class reference to 'SkeletalVisualRepresentation' with
#                dynamic 'load()' instantiation, permanently immunizing the engine 
#                against circular compile-time locks.
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/merchant/merchant_base.fbx"


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
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


## Binds the Skeletal strategy dynamically, avoiding static compiler circular dependency locks
func _build_visual_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	strategy.set("scale_multiplier", Vector3(0.8856, 0.8856, 0.8856))
	strategy.set("position_offset", Vector3.ZERO)
	strategy.set("rotation_offset", Vector3(0, 180, 0))
	
	# Concrete Merchant Animation clips on disk
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
	return true
