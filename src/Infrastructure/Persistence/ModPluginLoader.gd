# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/ModPluginLoader.gd
# Description: Infrastructure service responsible for compiling and loading 
#              external GDScript block strategies and AI behaviors on boot (OCP).
#              Updated: Integrated ModSandboxChecker to block malicious code.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ModPluginLoader
extends RefCounted


## Dynamically compiles and registers external .gd block scripts inside a mod directory.
static func load_block_plugins(mod_dir_path: String) -> void:
	var blocks_path := mod_dir_path + "blocks/"
	if not DirAccess.dir_exists_absolute(blocks_path):
		return # No custom block plugins declared in this mod
		
	var dir := DirAccess.open(blocks_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_plugins_count := 0
	
	while file_name != "":
		if not dir.current_is_dir():
			# Sanitize Godot production remapping suffixes (LSP/OCP safe)
			var sanitized_name := file_name.replace(".remap", "").replace(".gdc", ".gd")
			
			if sanitized_name.ends_with(".gd"):
				var absolute_path := blocks_path + sanitized_name
				if _compile_and_register_block_plugin(absolute_path):
					loaded_plugins_count += 1
					
		file_name = dir.get_next()
		
	dir.list_dir_end()
	if loaded_plugins_count > 0:
		print("[ModPluginLoader] Successfully compiled %d block plugins from: %s" % [loaded_plugins_count, mod_dir_path.get_file()])


static func _compile_and_register_block_plugin(file_path: String) -> bool:
	# 1. SECURITY SHIELD: Scan plain text for malicious OS APIs before RAM compilation!
	if not ModSandboxChecker.is_script_safe_for_compilation(file_path):
		return false
		
	# 2. Load the script resource dynamically into memory
	if not ResourceLoader.exists(file_path):
		return false
		
	var script_resource := load(file_path) as GDScript
	if script_resource == null:
		push_error("[ModPluginLoader ERROR] Failed to load GDScript file: " + file_path)
		return false
		
	# 3. Safely instantiate the script object verifying its inheritance (DIP)
	var block_instance := script_resource.new() as BlockDefinition
	if block_instance == null:
		push_error("[ModPluginLoader ERROR] Compiled script does not inherit from BlockDefinition: " + file_path)
		return false
		
	# 4. Register the definition dynamically into BlockLibrary
	BlockLibrary.register_definition(block_instance)
	
	# If the custom block declares a valid texture file name, cache it immediately in TextureRegistry
	_register_plugin_textures_if_declared(block_instance, file_path.get_base_dir())
	
	return true


static func _register_plugin_textures_if_declared(block: BlockDefinition, base_dir: String) -> void:
	if block.texture_file_name == "":
		return
		
	var tex_path := base_dir + "/textures/" + block.texture_file_name
	if ResourceLoader.exists(tex_path):
		var texture := load(tex_path) as Texture2D
		if texture != null:
			TextureRegistry.register_custom_texture(block.type, texture)
