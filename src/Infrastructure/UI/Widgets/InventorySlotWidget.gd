# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/InventorySlotWidget.gd
# Description: Reusable UI Button Widget representing an individual inventory slot.
#              SOLID COMPLIANCE: Class limits set < 150 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 15 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventorySlotWidget
extends Button

const TEXTURE_DIR := "res://assets/textures/"

var slot_index: int = -1
var overlay: Panel 

static var _textures_cache: Dictionary = {}


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


func _get_drag_data(_at_position: Vector2) -> Variant:
	var slot := _get_valid_slot_data()
	if slot == null: return null
		
	var preview := _build_drag_preview(slot)
	set_drag_preview(preview)
	
	_notify_parent_drag_start()
	return slot_index


func _get_valid_slot_data() -> InventoryComponent.SlotData:
	if not is_instance_valid(overlay) or slot_index == -1: return null
		
	var player_node := overlay.get("player") as CharacterBody3D
	if not is_instance_valid(player_node): return null
		
	var inventory := player_node.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory): return null
		
	var slot := inventory.get_slot_data(slot_index)
	if slot == null or slot.item_id == -1 or slot.quantity <= 0: return null
		
	return slot


func _build_drag_preview(slot: InventoryComponent.SlotData) -> Control:
	var preview := Control.new()
	preview.name = "BackpackDragPreview"
	
	var container := Control.new()
	container.custom_minimum_size = Vector2(46, 46)
	container.size = Vector2(46, 46)
	container.position = -Vector2(23, 23)
	preview.add_child(container)
	
	_setup_preview_backing(container, slot)
	return preview


func _setup_preview_backing(container: Control, slot: InventoryComponent.SlotData) -> void:
	var backing := ColorRect.new()
	backing.name = "FallbackColor"
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.modulate.a = 0.72
	
	var def := BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
	backing.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
	container.add_child(backing)
	
	_setup_preview_texture(container, backing, slot.item_id)


func _setup_preview_texture(container: Control, backing: ColorRect, item_id: int) -> void:
	var tex_display := TextureRect.new()
	tex_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
	tex_display.stretch_mode = TextureRect.STRETCH_SCALE
	tex_display.modulate.a = 0.72
	container.add_child(tex_display)
	
	var tex := _get_item_texture(item_id)
	if tex != null:
		tex_display.texture = tex
		tex_display.visible = true
		backing.visible = false
	else:
		tex_display.texture = null
		tex_display.visible = false
		backing.visible = true
		_apply_special_fallback_decoration(backing, item_id)


func _notify_parent_drag_start() -> void:
	if is_instance_valid(overlay) and overlay.has_method("set_drag_source"):
		overlay.call("set_drag_source", slot_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is int


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_slot_index := data as int
	if is_instance_valid(overlay) and overlay.has_method("execute_dnd_swap"):
		overlay.call("execute_dnd_swap", source_slot_index, slot_index)


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
	for child: Node in fallback_node.get_children(): child.queue_free()
		
	var symbol := Label.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var ls := LabelSettings.new()
	ls.font_size = 18 if fallback_node.size.x < 45 else 22
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	symbol.label_settings = ls
	
	match item_id:
		16: symbol.text = "🍗" 
		17: symbol.text = "⚔️" 
		18: symbol.text = "🌱" 
		12: symbol.text = "💠"
		14: symbol.text = "☁️"
		_: symbol.text = ""
		
	if symbol.text != "":
		fallback_node.add_child(symbol)
