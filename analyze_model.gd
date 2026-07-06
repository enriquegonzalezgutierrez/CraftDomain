# ==============================================================================
# Tool: Godot 4 Headless Model Analyzer & Telemetry Diagnostics
# Description: Command-line script to inspect FBX and GLB skeletal meshes.
#              Extracts precise physical bounding box sizes, offsets, and skeleton 
#              animation lists directly using Godot's native rendering servers.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively asset 
#                geometry telemetry extraction.
# VALUE TYPE PASSING RESOLUTION:
#              - Fixed a GDScript value-type pass-by-value limitation where 
#                AABB structures inside threads are duplicated. Bounding boxes 
#                are now merged into a class-scope variable, guaranteeing correct 
#                matrix math calculations.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://analyze_model.gd
# ==============================================================================
extends SceneTree

# Global variables (Class scope to prevent local pass-by-value copy errors)
var _root_node: Node3D
var _combined_aabb := AABB()
var _has_valid_mesh := false
var _animation_list: Array[String] = []


func _init() -> void:
	print("================================================================================")
	print("             CRAFTDOMAIN STATIC FBX/GLB MODEL ANALYZER V1.0.0")
	print("================================================================================")
	
	var args := OS.get_cmdline_args()
	var target_path := ""
	
	# Locate the targeted model file in the arguments pipeline
	for arg: String in args:
		if arg.ends_with(".fbx") or arg.ends_with(".glb"):
			target_path = arg
			break
			
	if target_path == "":
		push_error("[Analyzer ERROR] Please specify a valid .fbx or .glb file as an argument.")
		quit(1)
		return
		
	if not FileAccess.file_exists(target_path):
		push_error("[Analyzer ERROR] Specified file does not exist on disk: " + target_path)
		quit(1)
		return
		
	_analyze_target_asset(target_path)
	quit(0)


func _analyze_target_asset(file_path: String) -> void:
	print("[Analyzer] Opening asset: ", file_path.get_file())
	
	var model_scene := load(file_path) as PackedScene
	if model_scene == null:
		push_error("[Analyzer ERROR] Godot failed to import the file.")
		return
		
	_root_node = model_scene.instantiate() as Node3D
	if _root_node == null:
		push_error("[Analyzer ERROR] Failed to instantiate the 3D model node.")
		return
		
	_combined_aabb = AABB()
	_has_valid_mesh = false
	_animation_list.clear()
	
	# Scan hierarchy
	_scan_hierarchy_recursive(_root_node)
	
	# Output results
	print("\n--------------------------------------------------------------------------------")
	print("🌐 SCENE HIERARCHY SUMMARY:")
	print("--------------------------------------------------------------------------------")
	print("  Root Node Name: '", _root_node.name, "' [Class: ", _root_node.get_class(), "]")
	
	var anim_player := _root_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(anim_player):
		print("  Skeletal AnimationPlayer: FOUND")
		print("    -> Available Tracks: ", anim_player.get_animation_list())
	else:
		print("  Skeletal AnimationPlayer: NOT FOUND (Static Mesh)")
		
	if _has_valid_mesh:
		var w := _combined_aabb.size.x
		var h := _combined_aabb.size.y
		var d := _combined_aabb.size.z
		var min_y := _combined_aabb.position.y
		
		print("\n--------------------------------------------------------------------------------")
		print("📐 GEOMETRY & BOUNDING BOX METRICS:")
		print("--------------------------------------------------------------------------------")
		print("  * Absolute Min Vertex: ", _combined_aabb.position)
		print("  * Absolute Max Vertex: ", _combined_aabb.position + _combined_aabb.size)
		print("  * Dimensions (Godot grid):")
		print("    -> Width  (X): ", sprintf("%.4f", w), " meters")
		print("    -> Height (Y): ", sprintf("%.4f", h), " meters")
		print("    -> Depth  (Z): ", sprintf("%.4f", d), " meters")
		
		print("\n--------------------------------------------------------------------------------")
		print("⚙️ SUGGESTED CODE CALIBRATIONS FOR ENTITY SCRIPT:")
		print("--------------------------------------------------------------------------------")
		
		# Detect pivot displacement
		if abs(min_y) > 0.02:
			print("  ⚠️  [PIVOT SHIFT DETECTED] The model's origin is NOT on its feet (Min Y is ", sprintf("%.4f", min_y), "m).")
			print("  -> Set this offset on the 3D model node inside '_build_glb_representation()':")
			print("     model_node.position = Vector3(0.0, ", sprintf("%.4f", -min_y), ", 0.0)")
		else:
			print("  ✔  [PIVOT OK] The model's origin sits flat on its feet (Y = 0.0).")
			print("  -> Set this offset inside '_build_glb_representation()':")
			print("     model_node.position = Vector3(0.0, 0.0, 0.0)")
			
		# Calibration output based on standard targets
		print("\n  📐 SUGGESTED HEIGHT MULTIPLIERS:")
		print("    * Humanoid / Zombie (1.8m):")
		print("      -> Scale multiplier: Vector3(", sprintf("%.4f", 1.8 / h), ", ", sprintf("%.4f", 1.8 / h), ", ", sprintf("%.4f", 1.8 / h), ")")
		print("    * Medium Mob (0.75m):")
		print("      -> Scale multiplier: Vector3(", sprintf("%.4f", 0.75 / h), ", ", sprintf("%.4f", 0.75 / h), ", ", sprintf("%.4f", 0.75 / h), ")")
		print("    * Small Pet / Bird (0.35m):")
		print("      -> Scale multiplier: Vector3(", sprintf("%.4f", 0.35 / h), ", ", sprintf("%.4f", 0.35 / h), ", ", sprintf("%.4f", 0.35 / h), ")")
		print("    * Colossal Giant / Boss (3.5m):")
		print("      -> Scale multiplier: Vector3(", sprintf("%.4f", 3.5 / h), ", ", sprintf("%.4f", 3.5 / h), ", ", sprintf("%.4f", 3.5 / h), ")")
	else:
		print("\n  ❌ [ERROR] No valid mesh instances discovered in the scene hierarchy.")
		
	print("================================================================================\n")
	_root_node.free()


func _scan_hierarchy_recursive(node: Node) -> void:
	if node is VisualInstance3D:
		var vi := node as VisualInstance3D
		var local_aabb := vi.get_aabb()
		
		# Fallback to mesh resource boundaries if instance aabb is null
		if local_aabb.size == Vector3.ZERO and "mesh" in vi and vi.get("mesh") != null:
			var mesh_res = vi.get("mesh")
			if mesh_res != null:
				local_aabb = mesh_res.get_aabb()
				
		var relative_transform := _get_relative_transform(node)
		var transformed_aabb := relative_transform * local_aabb
		
		print("  * Diagnostics on Mesh '", vi.name, "':")
		print("    -> Instance AABB size: ", local_aabb.size)
		print("    -> Transformed size:   ", transformed_aabb.size)
		
		if transformed_aabb.size != Vector3.ZERO:
			if not _has_valid_mesh:
				_combined_aabb.position = transformed_aabb.position
				_combined_aabb.size = transformed_aabb.size
				_has_valid_mesh = true
			else:
				_combined_aabb = _combined_aabb.merge(transformed_aabb)
				
	for child in node.get_children():
		_scan_hierarchy_recursive(child)


func _get_relative_transform(node: Node) -> Transform3D:
	var t := Transform3D()
	var current := node
	while current != null and current != _root_node:
		if current is Node3D:
			t = current.transform * t
		current = current.get_parent()
	return t


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player_recursive(child)
		if is_instance_valid(found):
			return found
	return null


func sprintf(format_str: String, val: float) -> String:
	return format_str % val