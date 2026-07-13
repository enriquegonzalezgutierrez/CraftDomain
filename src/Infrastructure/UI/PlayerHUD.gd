# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/PlayerHUD.gd
# Description: Central HUD Orchestrator and UI Coordinator. Handles modal toggles,
#              LOD UI updates, and reactive Domain Event bindings.
#              Corrected: Auto-pauses and displays menu dynamically on network code resolved.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerHUD
extends Control

# Dynamic Overlay preloads for runtime instantiation (OCP Compliant)
const CRAFTING_OVERLAY_SCENE := preload("res://src/Infrastructure/UI/CraftingOverlay.tscn")
const INVENTORY_OVERLAY_SCENE := preload("res://src/Infrastructure/UI/InventoryOverlay.tscn")
const WORLD_MAP_OVERLAY_SCENE := preload("res://src/Infrastructure/UI/map_overlay.tscn")
const LOADING_SCREEN_SCENE := preload("res://src/Infrastructure/UI/loading_screen.tscn")

# Dependencies injected by the world bootstrap
var player: CharacterBody3D
var world_controller: Node3D

# Static UI Widget Node References (Bound from .tscn)
@onready var minimap: MinimapWidget = $MinimapWidget
@onready var gps_panel: GPSPanelWidget = $GPSPanelWidget
@onready var quest_panel: QuestTrackerWidget = $QuestTrackerWidget

@onready var _damage_widget: ColorRect = $DamageOverlayWidget
@onready var _hotbar_dock_widget: Control = $HotbarDockWidget
@onready var _pause_widget: Panel = $PauseMenuWidget

# UI Refresh Throttling Timer (Updates text metrics at 20Hz, stabilizing FPS)
var _ui_update_timer: float = 0.0
const UI_UPDATE_INTERVAL: float = 0.05 

# Dialogues & Popups Coordinator (DIP Aligned)
var dialogue_coordinator: DialogueCoordinator
var _crafting_overlay: CraftingOverlay
var _inventory_overlay: InventoryOverlay
var _world_map_overlay: MapOverlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Propagate dependencies down to child widgets safely on ready (LSP/DIP)
	if is_instance_valid(minimap):
		minimap.player = player
		minimap.world_controller = world_controller
	if is_instance_valid(gps_panel):
		gps_panel.player = player
		gps_panel.world_controller = world_controller
	if is_instance_valid(quest_panel):
		quest_panel.player = player
		
	_setup_dialogue_system()
	_connect_domain_signals()
	_connect_network_observers()
	
	# Initial rendering dispatch
	_on_inventory_changed()
	if is_instance_valid(player) and player.get("domain_entity") != null:
		update_health_display(player.domain_entity.health)
	update_active_slot(0)


## Throttled execution loop: Refreshes labels and minimap vectors at 20Hz
func _process(delta: float) -> void:
	_ui_update_timer += delta
	if _ui_update_timer >= UI_UPDATE_INTERVAL:
		_ui_update_timer = 0.0
		
		if is_instance_valid(minimap):
			minimap.update_widget()
		if is_instance_valid(gps_panel):
			gps_panel.update_widget()
		if is_instance_valid(quest_panel):
			quest_panel.update_widget()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_pause_widget) and _pause_widget.visible:
		return
		
	if event.is_action_pressed("craft_item"):
		get_viewport().set_input_as_handled()
		toggle_crafting_workshop(_crafting_overlay == null)
	elif event.is_action_pressed("toggle_backpack"):
		get_viewport().set_input_as_handled()
		toggle_inventory_backpack(_inventory_overlay == null)
	elif event.is_action_pressed("toggle_world_map"):
		get_viewport().set_input_as_handled()
		toggle_world_map(_world_map_overlay == null)


func _setup_dialogue_system() -> void:
	dialogue_coordinator = DialogueCoordinator.new()
	dialogue_coordinator.name = "DialogueCoordinator"
	dialogue_coordinator.player = player
	add_child(dialogue_coordinator)


## Reactive Binding: Hooks visual updates to pure Domain Events (Observer Pattern)
func _connect_domain_signals() -> void:
	if is_instance_valid(player):
		var inv := player.get("inventory") as IInventory
		if is_instance_valid(inv):
			inv.inventory_changed.connect(_on_inventory_changed)
			
		var entity := player.get("domain_entity") as VoxelEntity
		if is_instance_valid(entity):
			entity.took_damage.connect(func(_amount: int) -> void:
				update_health_display(entity.health)
				flash_damage_screen()
			)
			entity.died.connect(func() -> void:
				update_health_display(3) # Resets to maximum HP on respawn
			)


## Connects the HUD to the persistent global Network service to display invites!
func _connect_network_observers() -> void:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var net_service := bootstrap.get("network_service") as NetworkService
		if is_instance_valid(net_service):
			net_service.join_code_updated.connect(_on_join_code_updated)


## Dynamic User Experience flow: Auto-Pauses game to show the Join Code when ready.
func _on_join_code_updated(code: String) -> void:
	if code != "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		toggle_pause_menu(true)


func _on_inventory_changed() -> void:
	if not is_instance_valid(player):
		return
	var inv := player.get("inventory") as InventoryComponent
	if not is_instance_valid(inv):
		return
		
	for i: int in range(8):
		var slot := inv.get_slot_data(i)
		if slot != null:
			update_slot_quantity(i, slot.item_id, slot.quantity)
			
	update_health_display(player.domain_entity.health)


# ==============================================================================
# COORDINATION DELEGATION APIS (DIP/SRP Compliant)
# ==============================================================================

func open_dialogue(node: Resource, speaker_name: String, speaker_node: CharacterBody3D = null) -> void:
	if is_instance_valid(dialogue_coordinator):
		dialogue_coordinator.open_dialogue(node, speaker_name, speaker_node)


func show_loading_screen() -> void:
	if has_node("LoadingScreenOverlay"):
		return
	var loading_screen := LOADING_SCREEN_SCENE.instantiate() as LoadingScreen
	loading_screen.player = player
	add_child(loading_screen)


func toggle_world_map(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_crafting_overlay) or is_instance_valid(_inventory_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_world_map_overlay): return
		_world_map_overlay = WORLD_MAP_OVERLAY_SCENE.instantiate() as MapOverlay
		_world_map_overlay.player = player
		_world_map_overlay.closed.connect(func() -> void: toggle_world_map(false))
		add_child(_world_map_overlay)
		
		player.is_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_world_map_overlay):
			_world_map_overlay.queue_free()
			_world_map_overlay = null
			
		var is_teleporting := false
		var world_ctrl := world_controller as WorldController
		if is_instance_valid(world_ctrl):
			is_teleporting = world_ctrl.is_teleport_spawn
			
		if not is_teleporting:
			player.is_active = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_crafting_workshop(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_inventory_overlay) or is_instance_valid(_world_map_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_crafting_overlay): return
		_crafting_overlay = CRAFTING_OVERLAY_SCENE.instantiate() as CraftingOverlay
		_crafting_overlay.player = player
		_crafting_overlay.closed.connect(func() -> void: toggle_crafting_workshop(false))
		add_child(_crafting_overlay)
		
		player.set("is_active", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_crafting_overlay):
			_crafting_overlay.queue_free()
			_crafting_overlay = null
		player.set("is_active", true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_inventory_backpack(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_crafting_overlay) or is_instance_valid(_world_map_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_inventory_overlay): return
		_inventory_overlay = INVENTORY_OVERLAY_SCENE.instantiate() as InventoryOverlay
		_inventory_overlay.player = player
		_inventory_overlay.closed.connect(func() -> void: toggle_inventory_backpack(false))
		add_child(_inventory_overlay)
		
		player.set("is_active", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_inventory_overlay):
			_inventory_overlay.queue_free()
			_inventory_overlay = null
		player.set("is_active", true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause_menu(p_visible: bool) -> void:
	if is_instance_valid(_pause_widget):
		if p_visible:
			if is_instance_valid(_crafting_overlay): toggle_crafting_workshop(false)
			if is_instance_valid(_inventory_overlay): toggle_inventory_backpack(false)
			if is_instance_valid(_world_map_overlay): toggle_world_map(false)
		_pause_widget.call("toggle_menu", p_visible)


func update_active_slot(active_index: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_active_slot", active_index)


func update_slot_quantity(slot_index: int, item_id: int, quantity: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_slot_quantity", slot_index, item_id, quantity)


func update_health_display(current_hp: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_health_display", current_hp)


func flash_damage_screen() -> void:
	if is_instance_valid(_damage_widget):
		_damage_widget.call("flash")


func is_any_menu_open() -> bool:
	return (
		(_pause_widget and _pause_widget.visible) or
		is_instance_valid(_crafting_overlay) or
		is_instance_valid(_inventory_overlay) or
		is_instance_valid(_world_map_overlay) or 
		(is_instance_valid(dialogue_coordinator) and is_instance_valid(dialogue_coordinator.active_dialogue))
	)


## Toast notification API stub (Delegates execution to sub-widgets dynamically)
func show_quest_notification(_header: String, _quest_title: String) -> void:
	# Toast logic moved to a beautiful custom notification alert in the future,
	# currently handled via standalone toast nodes instantiated on this Canvas.
	pass
