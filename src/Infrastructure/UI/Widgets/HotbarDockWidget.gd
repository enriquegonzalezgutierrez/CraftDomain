# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/HotbarDockWidget.gd
# Description: SRP-compliant UI Widget responsible ONLY for updating the hotbar slots,
#              selection outlines, and health/hunger status bars. Layout is defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HotbarDockWidget
extends Control

const TEXTURE_DIR := "res://assets/textures/"

var player: CharacterBody3D
var hud_orchestrator: PlayerHUD

@onready var _hearts_container: HBoxContainer = $VBoxContainer/StatusContainer/HeartsContainer
@onready var _food_container: HBoxContainer = $VBoxContainer/StatusContainer/FoodContainer
@onready var _item_name_toast: Label = $VBoxContainer/ItemNameToast

@onready var _bp_btn: Button = $VBoxContainer/HotbarBG/MarginContainer/HBoxContainer/BackpackBox/BackpackButton
@onready var _cr_btn: Button = $VBoxContainer/HotbarBG/MarginContainer/HBoxContainer/WorkshopBox/WorkshopButton

# Active hotbar slots container references
@onready var _slots_hbox: HBoxContainer = $VBoxContainer/HotbarBG/MarginContainer/HBoxContainer/SlotsHBox

var _hotbar_slots: Array[Panel] = []
var _toast_tween: Tween

# In-memory cache for loaded 2D textures to save CPU reads
static var _textures_cache: Dictionary = {}
static var _item_symbols: Dictionary = {}


static func _static_init() -> void:
	register_item_symbol(15, "🧪") # Lava bucket or fluid vial
	register_item_symbol(16, "🍗") # Fried Chicken
	register_item_symbol(17, "⚔️") # Wooden Sword
	register_item_symbol(18, "🌱") # Crop Seeds
	register_item_symbol(12, "💠") # Cyan warmth
	register_item_symbol(14, "☁️") # Cloud


static func register_item_symbol(item_id: int, symbol_char: String) -> void:
	_item_symbols[item_id] = symbol_char


func _ready() -> void:
	_bp_btn.pressed.connect(_on_backpack_shortcut_pressed)
	_cr_btn.pressed.connect(_on_workshop_shortcut_pressed)
	
	_hotbar_slots.clear()
	for child in _slots_hbox.get_children():
		if child is Panel:
			_hotbar_slots.append(child as Panel)


func _on_backpack_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator):
		hud_orchestrator.toggle_inventory_backpack(true)


func _on_workshop_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator):
		hud_orchestrator.toggle_crafting_workshop(true)


## Emphasizes the active slot smoothly
func update_active_slot(index: int) -> void:
	for i: int in range(_hotbar_slots.size()):
		var slot: Panel = _hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
			
		var tween := create_tween()
		if i == index:
			style.bg_color = Color(0.25, 0.25, 0.28, 0.8)
			style.border_color = Color(1.0, 0.85, 0.2, 1.0) # Gold Highlight
			tween.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
			_show_toast_notification(index)
		else:
			style.bg_color = Color(0.12, 0.12, 0.14, 0.7)
			style.border_color = Color(0, 0, 0, 0) # Transparent border
			tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)


func update_slot_quantity(slot_index: int, item_id: int, quantity: int) -> void:
	if slot_index >= 0 and slot_index < _hotbar_slots.size():
		var slot: Panel = _hotbar_slots[slot_index]
		var icon_container := slot.get_node_or_null("ItemIconContainer") as Control
		var label := slot.get_node_or_null("MarginContainer/QtyLabel") as Label
		
		if is_instance_valid(icon_container):
			var fallback := icon_container.get_node_or_null("FallbackColor") as ColorRect
			var tex_display := icon_container.get_node_or_null("TextureDisplay") as TextureRect
			
			if is_instance_valid(fallback) and is_instance_valid(tex_display):
				if item_id == -1 or quantity <= 0:
					icon_container.visible = false
				else:
					icon_container.visible = true
					var tex: Texture2D = _get_item_texture(item_id)
					
					if tex != null:
						tex_display.texture = tex
						tex_display.visible = true
						fallback.visible = false
						for child: Node in fallback.get_children():
							child.queue_free()
					else:
						tex_display.texture = null
						tex_display.visible = false
						
						var def: BlockDefinition = BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
						fallback.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
						fallback.visible = true
						_apply_special_fallback_decoration(fallback, item_id)
						
		if is_instance_valid(label):
			label.text = "" if item_id == -1 or quantity <= 0 else str(quantity)


func _show_toast_notification(index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_item_name_toast):
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory):
		return
		
	var item_name := inventory.get_slot_item_name(index)
	_item_name_toast.text = item_name.to_upper()
	
	if is_instance_valid(_toast_tween) and _toast_tween.is_running():
		_toast_tween.kill()
		
	_item_name_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_item_name_toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


func update_health_display(hp: int) -> void:
	if not is_instance_valid(_hearts_container) or not is_instance_valid(_food_container):
		return
		
	for child: Node in _hearts_container.get_children():
		child.queue_free()
	for child: Node in _food_container.get_children():
		child.queue_free()
	
	for i: int in range(3):
		var heart := Label.new()
		var hs := LabelSettings.new()
		hs.font_size = 22
		hs.outline_size = 4
		hs.outline_color = Color.BLACK
		if i < hp:
			heart.text = "❤"
			hs.font_color = Color(0.95, 0.15, 0.15)
		else:
			heart.text = "🖤"
			hs.font_color = Color(0.22, 0.22, 0.26)
		heart.label_settings = hs
		_hearts_container.add_child(heart)
		
	var food_count := 0
	if is_instance_valid(player):
		var inv: InventoryComponent = player.get("inventory") as InventoryComponent
		if is_instance_valid(inv):
			food_count = inv.get_item_total_quantity(16)
			
	var display_food := clamp(food_count, 0, 10)
	for i: int in range(display_food):
		var food := Label.new()
		food.text = "🍗"
		var ds := LabelSettings.new()
		ds.font_size = 22
		ds.outline_size = 4
		ds.outline_color = Color.BLACK
		ds.font_color = Color(1.0, 0.7, 0.35) if food_count > 0 else Color(0.22, 0.22, 0.26)
		food.label_settings = ds
		_food_container.add_child(food)


func _get_item_texture(item_id: int) -> Texture2D:
	if _textures_cache.has(item_id):
		return _textures_cache[item_id] as Texture2D
		
	var def := BlockLibrary.get_definition(item_id as BlockType.Type)
	if def != null and def.texture_file_name != "":
		var full_path := TEXTURE_DIR + def.texture_file_name
		if ResourceLoader.exists(full_path):
			var tex := load(full_path) as Texture2D
			if tex is Texture2D:
				_textures_cache[item_id] = tex
				return tex
				
	_textures_cache[item_id] = null 
	return null


func _apply_special_fallback_decoration(fallback_node: Control, item_id: int) -> void:
	for child: Node in fallback_node.get_children():
		child.queue_free()
		
	var symbol := Label.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var ls := LabelSettings.new()
	ls.font_size = 14
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	symbol.label_settings = ls
	
	if _item_symbols.has(item_id):
		symbol.text = _item_symbols[item_id] as String
	else:
		symbol.text = ""
		
	if symbol.text != "":
		fallback_node.add_child(symbol)
