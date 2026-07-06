# ==============================================================================
# Project: CraftDomain
# Description: Merchant NPC physics controller with dynamic visual strategy injection.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles exclusively merchant 
#                conversational dialogues and trade transaction routing.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity cleanly.
#              - Dependency Inversion Principle (DIP): Visual structures are completely 
#                delegated to the injected `IEntityVisualRepresentation` strategy.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MerchantEntity.gd
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 3) # 3 Hearts of health
	name = "Entity_MERCHANT"


## Concrete Implementation (DIP): Injects the modular Merchant Role ID into the strategy compiler
func _get_humanoid_role() -> int:
	return ProceduralVoxelRepresentation.RoleType.MERCHANT


## Public Gaze Interaction: Triggers centralized trading dialogue overlays.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueService.get_dialogue_node("merchant_intro")
		if intro_node == null:
			print("[MerchantEntity] Dialogue database was null! Building dynamic database...")
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


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	# FIX: Explicit static typing on world controller reference
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		# FIX: Explicit static typing on world generator reference
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			# FIX: Explicit static typing on terrain noise provider
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
