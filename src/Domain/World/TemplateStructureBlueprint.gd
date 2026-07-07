# ==============================================================================
# Project: CraftDomain
# Description: Generic, Data-Driven Structure Blueprint.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the loading, parsing, 
#   and dynamic block placement of pre-designed coordinate templates inside Chunks.
# - Open-Closed Principle (OCP): Completely closed to modifications. Adding 
#   new structures (e.g. Palm Trees, Wells, Portals) takes 0 compiled code; 
#   they are simply loaded from external JSON files at runtime.
# - Liskov Substitution Principle (LSP): Fully implements the `IStructureBlueprint` contract.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/TemplateStructureBlueprint.gd
# ==============================================================================
class_name TemplateStructureBlueprint
extends IStructureBlueprint

var _structure_id: int
var _blocks_data: Array = [] # Stores parsed block offsets: {"x": int, "y": int, "z": int, "type": BlockType.Type}


func _init(p_structure_id: int, template_file_path: String) -> void:
	_structure_id = p_structure_id
	_load_template_from_json(template_file_path)


## Concrete Implementation: Returns the unique identifier representing this structure
func get_structure_id() -> int:
	return _structure_id


## Concrete Implementation: Dynamic Sculpting loop. Parses the loaded coordinate offsets
## and places blocks inside the chunk grid, verifying boundaries.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	if _blocks_data.is_empty() or chunk == null:
		return
		
	# FIX: Explicit static typing on loop block data dictionary
	for block_node: Dictionary in _blocks_data:
		var rx: int = int(block_node.get("x", 0))
		var ry: int = int(block_node.get("y", 0))
		var rz: int = int(block_node.get("z", 0))
		var type_val: int = int(block_node.get("type", 0))
		
		var px := start_x + rx
		var py := ground_y + ry
		var pz := start_z + rz
		
		if chunk.is_within_bounds(px, py, pz):
			chunk.set_block(px, py, pz, type_val as BlockType.Type)


## Dynamic JSON Template Loader: Reads data from disk and compiles it into memory
func _load_template_from_json(file_path: String) -> void:
	_blocks_data.clear()
	
	if not FileAccess.file_exists(file_path):
		push_error("[TemplateStructure] Error: Template file not found: " + file_path)
		return
		
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[TemplateStructure] Error: Could not read template file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[TemplateStructure] JSON Parser error in " + file_path + ". Line: " + str(json.get_error_line()) + " | Msg: " + json.get_error_message())
		return
		
	var raw_array := json.data as Array
	if raw_array == null:
		return
		
	# Format coordinates and safely cast block types
	for node_res: Variant in raw_array:
		var node := node_res as Dictionary
		if node != null and node.has("x") and node.has("y") and node.has("z") and node.has("block"):
			var block_node := {
				"x": int(node["x"]),
				"y": int(node["y"]),
				"z": int(node["z"]),
				"type": int(node["block"]) # BlockType.Type casting ID
			}
			_blocks_data.append(block_node)
			
	print("[TemplateStructure] Preloaded data-driven template: '", file_path, "' (Voxel Nodes Count: ", _blocks_data.size(), ")")
