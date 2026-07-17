# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/InventorySlotWidget.gd
# Description: Infrastructure UI Button representing an individual inventory slot.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles only its own state
#                and mouse/touch drag and drop inputs.
#              - Rule 7.1: Zero procedural child instantiations. Queries static 
#                declarative nodes from its .tscn scene tree instead.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventorySlotWidget
extends Button

const STYLE_SLOT_NORMAL := preload("res://assets/themes/style_slot_normal.tres")
const STYLE_SLOT_SELECTED := preload("res://assets/themes/style_slot_selected.tres")
const STYLE_SLOT_ACTIVE := preload("res://assets/themes/style_slot_active.tres")
const STYLE_SLOT_HOVER := preload("res://assets/themes/style_slot_hover.tres")
const LABEL_SETTINGS_SYMBOL := preload("res://assets/themes/label_settings_symbol.tres")
const TEXTURE_DIR := "res://assets/textures/"

@onready var _icon_container: Control = $ItemIconContainer
@onready var _fallback_color: ColorRect = $ItemIconContainer/FallbackColor
@onready var _texture_display: TextureRect = $ItemIconContainer/TextureDisplay
@onready var _qty_label: Label = $QtyLabel

var slot_index: int = -1
var overlay: Panel = null

static var _textures_cache: Dictionary = {}
static var _item_symbols: Dictionary = {
	15: "🧪", 16: "🍗", 17: "⚔️", 18: "🌱", 12: "💠", 14: "☁️", 210: "🪶"
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_hover_animations()


func _setup_hover_animations() -> void:
	item_rect_changed.connect(func() -> void:
		pivot_offset = size / 2.0
	)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(hover: bool) -> void:
	var target_scale := Vector2(1.05, 1.05) if hover else Vector2(1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", target_scale, 0.08).set_trans(Tween.TRANS_SINE)


## Initializes the slot with dynamic states and queries slot data from player
func initialize_slot(index: int, overlay_ref: Panel, is_selected: bool, is_active: bool) -> void:
	slot_index = index
	overlay = overlay_ref
	
	_apply_slot_style(is_selected, is_active)
	_populate_slot_visuals()


## Specialized display mode for the details inspector (Disables mouse interactions)
func initialize_display_only(item_id: int, quantity: int) -> void:
	slot_index = -1
	overlay = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_apply_slot_style(false, false)
	_update_slot_graphics(item_id, quantity)


func _apply_slot_style(is_selected: bool, is_active: bool) -> void:
	var style := STYLE_SLOT_NORMAL
	if is_selected:
		style = STYLE_SLOT_SELECTED
	elif is_active:
		style = STYLE_SLOT_ACTIVE
		
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", STYLE_SLOT_HOVER)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _populate_slot_visuals() -> void:
	if not is_instance_valid(overlay): return
	var player_node: CharacterBody3D = overlay.get("player") as CharacterBody3D
	if not is_instance_valid(player_node): return
	
	var inventory: InventoryComponent = player_node.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory): return
	
	var slot := inventory.get_slot_data(slot_index)
	_update_slot_graphics(slot.item_id, slot.quantity)


func _update_slot_graphics(item_id: int, quantity: int) -> void:
	if item_id == -1 or quantity <= 0:
		_icon_container.visible = false
		_qty_label.text = ""
		return
		
	_icon_container.visible = true
	_qty_label.text = tr("INVENTORY_INFINITE_SHORT") if quantity == -1 else str(quantity)
	
	_apply_icon_visuals(item_id)


func _apply_icon_visuals(item_id: int) -> void:
	var tex := _get_item_texture(item_id)
	if tex != null:
		_texture_display.texture = tex
		_texture_display.visible = true
		_fallback_color.visible = false
		_clear_symbol_nodes()
	else:
		_texture_display.texture = null
		_texture_display.visible = false
		var def := BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
		_fallback_color.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
		_fallback_color.visible = true
		_apply_special_fallback_decoration(item_id)


func _clear_symbol_nodes() -> void:
	for child: Node in _fallback_color.get_children():
		child.queue_free()


func _apply_special_fallback_decoration(item_id: int) -> void:
	_clear_symbol_nodes()
	if not _item_symbols.has(item_id): return
		
	var symbol := Label.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.label_settings = LABEL_SETTINGS_SYMBOL
	symbol.text = _item_symbols[item_id] as String
	
	_fallback_color.add_child(symbol)


func _get_item_texture(item_id: int) -> Texture2D:
	if _textures_cache.has(item_id):
		return _textures_cache[item_id] as Texture2D
		
	var def := BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
	if def != null and def.texture_file_name != "":
		var full_path := TEXTURE_DIR + def.texture_file_name
		if ResourceLoader.exists(full_path):
			var tex := load(full_path) as Texture2D
			if tex is Texture2D:
				_textures_cache[item_id] = tex
				return tex
				
	_textures_cache[item_id] = null
	return null


# ==============================================================================
# DRAG AND DROP HANDLERS (DIP Compliant)
# ==============================================================================

func _get_drag_data(_at_position: Vector2) -> Variant:
	var slot := _get_valid_slot_data()
	if slot == null: return null
		
	var preview := _build_drag_preview(slot)
	set_drag_preview(preview)
	
	if is_instance_valid(overlay) and overlay.has_method("set_drag_source"):
		overlay.call("set_drag_source", slot_index)
		
	return slot_index


func _get_valid_slot_data() -> InventoryComponent.SlotData:
	if not is_instance_valid(overlay) or slot_index == -1: return null
		
	var player_node: CharacterBody3D = overlay.get("player") as CharacterBody3D
	if not is_instance_valid(player_node): return null
	
	var inventory: InventoryComponent = player_node.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory): return null
		
	var slot := inventory.get_slot_data(slot_index)
	if slot == null or slot.item_id == -1 or slot.quantity <= 0: return null
		
	return slot


func _build_drag_preview(slot: InventoryComponent.SlotData) -> Control:
	var preview := Control.new()
	var container := Control.new()
	container.custom_minimum_size = Vector2(46, 46)
	container.size = Vector2(46, 46)
	container.position = -Vector2(23, 23)
	preview.add_child(container)
	
	_setup_preview_backing(container, slot)
	return preview


func _setup_preview_backing(container: Control, slot: InventoryComponent.SlotData) -> void:
	var backing := ColorRect.new()
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.modulate.a = 0.72
	
	var def := BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
	backing.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
	container.add_child(backing)
	
	_setup_preview_texture(container, backing, slot.item_id)


func _setup_preview_texture(container: Control, backing: ColorRect, item_id: int) -> void:
	var text_display := TextureRect.new()
	text_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	text_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
	text_display.stretch_mode = TextureRect.STRETCH_SCALE
	text_display.modulate.a = 0.72
	container.add_child(text_display)
	
	var tex := _get_item_texture(item_id)
	if tex != null:
		text_display.texture = tex
		text_display.visible = true
		backing.visible = false
	else:
		text_display.texture = null
		text_display.visible = false
		backing.visible = true
		
		# Symmetrical fallback decoration inside the dragging preview
		var helper_label := Label.new()
		helper_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		helper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		helper_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		helper_label.label_settings = LABEL_SETTINGS_SYMBOL
		if _item_symbols.has(item_id):
			helper_label.text = _item_symbols[item_id] as String
		backing.add_child(helper_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is int


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot_index := data as int
	if is_instance_valid(overlay) and overlay.has_method("execute_dnd_swap"):
		overlay.call("execute_dnd_swap", source_slot_index, slot_index)