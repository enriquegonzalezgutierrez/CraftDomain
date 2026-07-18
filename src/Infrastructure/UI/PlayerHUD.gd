# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/PlayerHUD.gd
# Description: Central HUD Orchestrator and UI Coordinator. Handles modal toggles,
#              LOD UI updates, and reactive Domain Event bindings.
#              GRAPHICAL UPGRADE: Programmatically attached and modulated the 
#              Null Void screen-space glitch post-processing layer.
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
const HACKING_TERMINAL_SCENE := preload("res://src/Infrastructure/UI/hacking_terminal_overlay.tscn")
const GLITCH_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/null_void_glitch.gdshader"

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

# Dynamic post-processing overlays (SOLID / Section 7.1 Compliant)
var glitch_overlay: ColorRect
var glitch_material: ShaderMaterial

# INTEGRATION: Binds safely to the Chat Box using a recursive search
var chat_box: ChatBoxWidget

# UI Refresh Throttling Timer (Updates text metrics at 20Hz, stabilizing FPS)
var _ui_update_timer: float = 0.0
const UI_UPDATE_INTERVAL: float = 0.05 

# Dialogues & Popups Coordinator (DIP Aligned)
var dialogue_coordinator: DialogueCoordinator
var _crafting_overlay: CraftingOverlay
var _inventory_overlay: InventoryOverlay
var _world_map_overlay: MapOverlay
var _hacking_overlay: HackingTerminalOverlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Recursively locate the Chat Box in the scene tree to prevent null pointer exceptions
	chat_box = _find_chat_box_recursive(self)
	
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
	_setup_glitch_overlay()
	_connect_domain_signals()
	_connect_network_observers()
	
	# Initial rendering dispatch
	_on_inventory_changed()
	if is_instance_valid(player) and player.get("domain_entity") != null:
		update_health_display(player.domain_entity.health)
	update_active_slot(0)


## Bulletproof Search: Traverses the hierarchy recursively to locate any node 
## extending ChatBoxWidget, preventing hardcoded path dependencies (OCP)
func _find_chat_box_recursive(node: Node) -> ChatBoxWidget:
	if node is ChatBoxWidget:
		return node as ChatBoxWidget
	for child in node.get_children():
		var found := _find_chat_box_recursive(child)
		if is_instance_valid(found):
			return found
	return null


## Setup post-processing: Programmatically attaches the Null Void screen shader
func _setup_glitch_overlay() -> void:
	if not ResourceLoader.exists(GLITCH_SHADER_PATH):
		return
		
	glitch_overlay = ColorRect.new()
	glitch_overlay.name = "NullVoidGlitchOverlay"
	glitch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	glitch_material = ShaderMaterial.new()
	glitch_material.shader = load(GLITCH_SHADER_PATH) as Shader
	glitch_overlay.material = glitch_material
	
	add_child(glitch_overlay)
	# Place it directly over the 3D viewport, below the 2D HUD text/icons (Index 0)
	move_child(glitch_overlay, 0)


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
			
	# Update screen aberration glitch in real-time on the main thread (120Hz)
	_update_null_void_glitch(delta)


func _update_null_void_glitch(delta: float) -> void:
	if not is_instance_valid(glitch_material) or not is_instance_valid(player):
		return
		
	var is_corrupted := false
	var rift_service := GlitchRiftService.instance
	
	if is_instance_valid(rift_service):
		# Thread-safe query checking if player position is within a Glitch Rift
		is_corrupted = rift_service.is_position_corrupted(player.global_position)
		
	var target_intensity: float = 0.38 if is_corrupted else 0.0
	var current_intensity: float = glitch_material.get_shader_parameter("glitch_intensity") as float
	
	# Smoothly interpolate active screen distortion
	var next_intensity := lerp(current_intensity, target_intensity, delta * 5.0)
	glitch_material.set_shader_parameter("glitch_intensity", next_intensity)


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
				update_health_display(3) 
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
	if _is_modal_active() and p_visible:
		return 
		
	if p_visible:
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
			
		_restore_player_control()


func toggle_crafting_workshop(p_visible: bool) -> void:
	if _is_modal_active() and p_visible:
		return 
		
	if p_visible:
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
		_restore_player_control()


func toggle_inventory_backpack(p_visible: bool) -> void:
	if _is_modal_active() and p_visible:
		return 
		
	if p_visible:
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
		_restore_player_control()


func toggle_hacking_terminal(p_visible: bool) -> void:
	if _is_modal_active() and p_visible:
		return
		
	if p_visible:
		_hacking_overlay = HACKING_TERMINAL_SCENE.instantiate() as HackingTerminalOverlay
		_hacking_overlay.closed.connect(func() -> void: toggle_hacking_terminal(false))
		
		# Observer Binding: Completing the hack completes the active campaign quest automatically!
		_hacking_overlay.hacked_successfully.connect(func() -> void:
			var active_q := QuestService.get_active_quest()
			if active_q != null and active_q.quest_id == "cyber_hacker":
				QuestService.complete_active_quest(player)
		)
		
		add_child(_hacking_overlay)
		player.set("is_active", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_hacking_overlay):
			_hacking_overlay.queue_free()
			_hacking_overlay = null
		_restore_player_control()


func _is_modal_active() -> bool:
	return (
		(_pause_widget and _pause_widget.visible) or
		is_instance_valid(_crafting_overlay) or
		is_instance_valid(_inventory_overlay) or
		is_instance_valid(_world_map_overlay) or
		is_instance_valid(_hacking_overlay)
	)


func _restore_player_control() -> void:
	if not _is_modal_active():
		var is_teleporting := false
		var world_ctrl := world_controller as WorldController
		if is_instance_valid(world_ctrl):
			is_teleporting = world_ctrl.is_teleport_spawn
			
		if not is_teleporting:
			player.is_active = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause_menu(p_visible: bool) -> void:
	if is_instance_valid(_pause_widget):
		if p_visible:
			if is_instance_valid(_crafting_overlay): toggle_crafting_workshop(false)
			if is_instance_valid(_inventory_overlay): toggle_inventory_backpack(false)
			if is_instance_valid(_world_map_overlay): toggle_world_map(false)
			if is_instance_valid(_hacking_overlay): toggle_hacking_terminal(false)
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
	var is_chat_typing := false
	if is_instance_valid(chat_box):
		is_chat_typing = chat_box._is_typing
		
	return (
		_is_modal_active() or 
		is_chat_typing or
		(is_instance_valid(dialogue_coordinator) and is_instance_valid(dialogue_coordinator.active_dialogue))
	)


## Toast notification API stub (Delegates execution to sub-widgets dynamically)
func show_quest_notification(_header: String, _quest_title: String) -> void:
	pass
