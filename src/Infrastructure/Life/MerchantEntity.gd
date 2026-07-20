# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MerchantEntity.gd
# Description: Physical character controller for the passive village Merchant.
#              Updated to use native, highly-portable .glb static meshes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively physical 
#   interactions and visual rigging, delegating trade logic to TradingService.
# - Open-Closed Principle (OCP): Uses the SkeletalVisualRepresentation strategy
#   to load external 3D assets without modifying the physics loop.
# - Method Size Limits (Rule 4.2): All methods strictly kept under 20 lines.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/merchant.glb"

## Compensación de rotación necesaria para el modelo importado de Blender
var gaze_rotation_offset: float = PI


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Inicializa con 6 HP y estado de habitabilidad terrestre
	super(spawn_pos, 6)
	entity_habitat = 0 
	humanoid_role = 1 # Rol de Mercader en el VoxelModelRegistry
	is_conversational_npc = true
	name = "Entity_MERCHANT"


func _ready() -> void:
	# Se registra en el grupo de pasivos para el sistema de alertas
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_build_visual_representation()
	_setup_nameplate_height()
	
	# Inyecta el comportamiento GOAP del mercader al componente de IA
	if is_instance_valid(ai_component):
		ai_component.active_behavior = MerchantAIBehavior.new()


func _build_visual_representation() -> void:
	# DIP: Utilizamos la estrategia de representación esquelética (LSP)
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	visual_representation = strategy as IEntityVisualRepresentation
	
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.body_bob_node):
		visual_representation.build_representation(self, visual_component.body_bob_node)


func _get_entity_name_key() -> String:
	return "NPC_NAME_MERCHANT"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) 


func _is_eligible_for_quest(quest_id: String) -> bool:
	# El mercader es el objetivo central de la misión de suministro de combustible
	return quest_id == "fuel_fryer"


func _can_socialize() -> bool:
	# Regla de negocio: El mercader no atiende clientes durante la noche
	var is_night: bool = CelestialService.is_night_time_static()
	return not is_night


## Punto de entrada de interacción desde el VoxelInteractionComponent del jugador
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if not is_instance_valid(hud):
		return
		
	# Intenta recuperar el nodo de diálogo raíz para el mercader
	var intro_node := DialogueService.get_dialogue_node("merchant_intro")
	
	# Fallback de seguridad: Si la base de datos no está lista, fuerza inicialización
	if intro_node == null:
		DialogueRegistry.initialize_dialogue_database()
		intro_node = DialogueService.get_dialogue_node("merchant_intro")
		
	if intro_node != null:
		hud.open_dialogue(intro_node, "NPC_NAME_MERCHANT", self)
