# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/ModPluginLoader.gd
# Description: Infrastructure service responsible for compiling and loading 
#              external GDScript block strategies and AI behaviors on boot (OCP).
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 15 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ModPluginLoader
extends RefCounted


static func load_block_plugins(mod_dir_path: String) -> void:
	var blocks_path: String = mod_dir_path + "blocks/"
	if not DirAccess.dir_exists_absolute(blocks_path):
		return 
		
	var dir := DirAccess.open(blocks_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	_iterate_block_plugins(dir, blocks_path)
	dir.list_dir_end()


static func _iterate_block_plugins(dir: DirAccess, blocks_path: String) -> void:
	var file_name: String = dir.get_next()
	var loaded_plugins_count: int = 0
	
	while file_name != "":
		if not dir.current_is_dir():
			var sanitized_name: String = file_name.replace(".remap", "").replace(".gdc", ".gd")
			if sanitized_name.ends_with(".gd"):
				var full_path: String = blocks_path + sanitized_name
				if _compile_and_register_block_plugin(full_path):
					loaded_plugins_count += 1
		file_name = dir.get_next()
		
	if loaded_plugins_count > 0:
		print("[ModPluginLoader] Successfully compiled %d block plugins." % loaded_plugins_count)


static func _compile_and_register_block_plugin(file_path: String) -> bool:
	if not ModSandboxChecker.is_script_safe_for_compilation(file_path):
		return false
		
	if not ResourceLoader.exists(file_path):
		return false
		
	var script_resource: GDScript = load(file_path) as GDScript
	if script_resource == null:
		push_error("[ModPluginLoader ERROR] Failed to load GDScript file: " + file_path)
		return false
		
	return _instantiate_and_bind_plugin(script_resource, file_path)


static func _instantiate_and_bind_plugin(script_resource: GDScript, file_path: String) -> bool:
	var block_instance: BlockDefinition = script_resource.new() as BlockDefinition
	if block_instance == null:
		push_error("[ModPluginLoader ERROR] Compiled script is not a BlockDefinition: " + file_path)
		return false
		
	BlockLibrary.register_definition(block_instance)
	_register_plugin_textures_if_declared(block_instance, file_path.get_base_dir())
	return true


static func _register_plugin_textures_if_declared(block: BlockDefinition, base_dir: String) -> void:
	if block.texture_file_name == "":
		return
		
	var tex_path: String = base_dir + "/textures/" + block.texture_file_name
	if ResourceLoader.exists(tex_path):
		var texture: Texture2D = load(tex_path) as Texture2D
		if texture != null:
			TextureRegistry.register_custom_texture(block.type, texture)
