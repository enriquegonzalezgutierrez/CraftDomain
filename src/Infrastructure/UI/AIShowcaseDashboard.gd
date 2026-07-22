# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/AIShowcaseDashboard.gd
# Description: Infrastructure UI Presenter managing the developer AI testing 
#              dashboard, entity spawner controls, and live telemetry feeds.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AIShowcaseDashboard
extends CanvasLayer

const THROTTLE_INTERVAL_SEC: float = 0.05
const SPAWN_PAD_Y_ALTITUDE: float = 11.0

const MOB_TRANSLATION_MAP: Dictionary = {
	0: "NPC_NAME_PIG", 1: "NPC_NAME_CHICKEN", 2: "NPC_NAME_SHEEP", 3: "NPC_NAME_COW",
	10: "NPC_NAME_ZOMBIE", 11: "NPC_NAME_SHARK", 12: "NPC_NAME_GARGOYLE", 13: "NPC_NAME_GOBLIN",
	50: "NPC_NAME_LITHIC_LURKER", 51: "NPC_NAME_OBSIDIAN_COLOSSUS", 52: "NPC_NAME_WEAVER_MALAKOR",
	100: "NPC_NAME_VILLAGER", 101: "NPC_NAME_MERCHANT", 102: "NPC_NAME_GUARD", 103: "NPC_NAME_FARMER",
	104: "NPC_NAME_DRUID", 105: "NPC_NAME_MINER", 106: "NPC_NAME_ANDROID", 107: "NPC_NAME_GOLEM",
	201: "NPC_NAME_TURTLE", 204: "NPC_NAME_FOX", 205: "NPC_NAME_BIRD", 206: "NPC_NAME_CAT",
	207: "NPC_NAME_PARROT", 208: "NPC_NAME_CRAB", 209: "NPC_NAME_ELEPHANT", 210: "NPC_NAME_OCTOPUS",
	211: "NPC_NAME_RACCOON", 212: "NPC_NAME_GROWLITHE", 213: "NPC_NAME_MONKEY"
}

@onready var _spawn_catalog_vbox: VBoxContainer = %SpawnCatalogVBox
@onready var _telemetry_label: Label = %TelemetryLabel
@onready var _chicken_checkbox: CheckButton = %ChickenCheckbox
@onready var _storm_checkbox: CheckButton = %StormCheckbox
@onready var _slowmo_slider: HSlider = %SlowmoSlider
@onready var _override_button: Button = %OverrideButton
@onready var _spawn_zombie_btn: Button = %SpawnZombieButton
@onready var _exit_btn: Button = %ExitButton

var _showcase_room: AIShowcaseRoom = null
var _active_subject: CharacterBody3D = null
var _ui_accumulated_time: float = 0.0

var _current_override_index: int = 0
var _override_states: Array[int] = [-1, 0, 1, 5, 6]


func _ready() -> void:
	_showcase_room = get_parent() as AIShowcaseRoom
	if is_instance_valid(_showcase_room):
		_showcase_room.subject_spawned.connect(_on_subject_spawned)
		_showcase_room.subject_despawned.connect(_on_subject_despawned)
		
	_connect_ui_signals()
	_populate_mobs_catalog()


func _process(delta: float) -> void:
	if _active_subject == null:
		return
		
	_ui_accumulated_time += delta
	if _ui_accumulated_time >= THROTTLE_INTERVAL_SEC:
		_ui_accumulated_time = 0.0
		_update_live_telemetry_display()


func _connect_ui_signals() -> void:
	_chicken_checkbox.toggled.connect(_on_lure_chicken_toggled)
	_storm_checkbox.toggled.connect(_on_rain_overcast_toggled)
	_override_button.pressed.connect(_on_override_pressed)
	_spawn_zombie_btn.pressed.connect(_on_spawn_zombie_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)
	_slowmo_slider.value_changed.connect(func(v: float) -> void: Engine.time_scale = v)


func _populate_mobs_catalog() -> void:
	var keys: Array = MobRegistry._spawners.keys()
	keys.sort()
	
	for spawn_id: int in keys:
		var translation_key := _get_mob_translation_key(spawn_id)
		if translation_key != "INVENTORY_UNKNOWN":
			_instantiate_catalog_button(spawn_id, translation_key)


func _instantiate_catalog_button(spawn_id: int, translation_key: String) -> void:
	var btn := Button.new()
	btn.text = " " + tr("SHOWCASE_SPAWN_PREFIX") + " " + tr(translation_key).to_upper()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	
	btn.pressed.connect(func() -> void:
		if is_instance_valid(_showcase_room):
			_showcase_room.spawn_test_subject(spawn_id)
	)
	_spawn_catalog_vbox.add_child(btn)


func _on_subject_spawned(subject: CharacterBody3D) -> void:
	_active_subject = subject
	_current_override_index = 0
	_update_override_button_label()
	_ui_accumulated_time = THROTTLE_INTERVAL_SEC


func _on_subject_despawned() -> void:
	_active_subject = null
	_telemetry_label.text = tr("SHOWCASE_TELEMETRY_EMPTY")


func _on_lure_chicken_toggled(button_pressed: bool) -> void:
	if is_instance_valid(_showcase_room) and is_instance_valid(_showcase_room.player):
		var inventory: InventoryComponent = _showcase_room.player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			var slot_data := inventory.get_slot_data(6) 
			if is_instance_valid(slot_data):
				slot_data.item_id = 16 if button_pressed else -1
				slot_data.quantity = 1 if button_pressed else 0
			inventory.inventory_changed.emit()


func _on_rain_overcast_toggled(button_pressed: bool) -> void:
	if is_instance_valid(_showcase_room):
		var weather_node := _showcase_room.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node):
			weather_node.set("current_weather", 1 if button_pressed else 0)


func _on_spawn_zombie_pressed() -> void:
	if MobRegistry.has_mob(10) and is_instance_valid(_showcase_room):
		var zombie_pos := Vector3(3.5, SPAWN_PAD_Y_ALTITUDE + 3.0, 3.5)
		var zombie := MobRegistry.create_mob(10, zombie_pos) as CharacterBody3D
		if is_instance_valid(zombie):
			_showcase_room.add_child(zombie)


func _on_override_pressed() -> void:
	if _active_subject == null: return
	var ai: Object = _active_subject.get("ai_component") as Object
	if not is_instance_valid(ai): return
	
	_current_override_index = (_current_override_index + 1) % _override_states.size()
	var state_id := _override_states[_current_override_index]
	
	if state_id == -1: ai.call("disable_manual_override")
	else: ai.call("force_manual_task", state_id)
		
	_update_override_button_label()
	if _active_subject.has_method("_update_quest_bubble_state"):
		_active_subject.call("_update_quest_bubble_state")
		
	AudioService.play_sfx_static("ui_click")


func _update_override_button_label() -> void:
	var state_id := _override_states[_current_override_index]
	match state_id:
		-1: _override_button.text = "🤖 " + tr("SHOWCASE_MODE_AUTO").to_upper()
		0:  _override_button.text = "💤 " + tr("SHOWCASE_TASK_IDLE")
		1:  _override_button.text = "👣 " + tr("SHOWCASE_TASK_WANDER")
		5:  _override_button.text = "☠️ " + tr("SHOWCASE_TASK_PANIC")
		6:  _override_button.text = "🛠️ " + tr("SHOWCASE_TASK_WORKING")


func _update_live_telemetry_display() -> void:
	var ai: Object = _active_subject.get("ai_component") as Object
	var domain_entity: Object = _active_subject.get("domain_entity")
	
	var task_str := _get_task_state_name(ai.get("current_task") as int) if is_instance_valid(ai) else "SHOWCASE_TASK_IDLE"
	var current_hp := domain_entity.get("health") as int if is_instance_valid(domain_entity) else 0
	var state_details := _gather_active_behavior_metadata()
	
	_telemetry_label.text = _format_telemetry_string(task_str, current_hp, state_details)


func _format_telemetry_string(task_str: String, current_hp: int, state_details: String) -> String:
	var host_pos: Vector3 = _active_subject.global_position
	var spawn_id_val: int = _active_subject.get("spawn_id") if "spawn_id" in _active_subject else -1
	var subject_key := _get_mob_translation_key(spawn_id_val)
	var hearts_count := floori(float(current_hp) / 2.0) if current_hp > 0 else 0
	
	return (
		tr("SHOWCASE_TEL_NAME") + ": %s\n" % tr(subject_key) +
		tr("SHOWCASE_TEL_HEALTH") + ": %d Hearts (%d HP)\n" % [hearts_count, current_hp] +
		tr("SHOWCASE_TEL_COORDS") + ": [ X: %d, Y: %d, Z: %d ]\n" % [int(round(host_pos.x)), int(round(host_pos.y)), int(round(host_pos.z))] +
		tr("SHOWCASE_TEL_TASK") + ": %s\n\n" % tr(task_str) +
		tr("SHOWCASE_TEL_META_HEADER") + "\n" +
		(state_details if state_details != "" else tr("SHOWCASE_TEL_STANDARD") + "\n")
	)


func _gather_active_behavior_metadata() -> String:
	var state_details := ""
	var ai: Object = _active_subject.get("ai_component") as Object
	if is_instance_valid(ai) and ai.get("active_behavior") != null:
		var behavior: IAIBehavior = ai.get("active_behavior") as IAIBehavior
		if is_instance_valid(behavior) and behavior.has_method("get_active_state_name"):
			var state_key := behavior.call("get_active_state_name", _active_subject) as String
			state_details += "• %s: %s\n" % [tr("SHOWCASE_TEL_META_HEADER").to_upper(), tr("SHOWCASE_TASK_" + state_key.to_upper()).to_upper()]
	return state_details


func _get_mob_translation_key(spawn_id: int) -> String:
	return MOB_TRANSLATION_MAP.get(spawn_id, "INVENTORY_UNKNOWN") as String


func _get_task_state_name(task_val: int) -> String:
	match task_val:
		0: return "SHOWCASE_TASK_IDLE"
		1: return "SHOWCASE_TASK_WANDER"
		2: return "SHOWCASE_TASK_EXAMINE"
		3: return "SHOWCASE_TASK_GREET"
		4: return "SHOWCASE_TASK_CHAT"
		5: return "SHOWCASE_TASK_PANIC"
		6: return "SHOWCASE_TASK_WORKING"
		_: return "SHOWCASE_TASK_IDLE"


func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")
