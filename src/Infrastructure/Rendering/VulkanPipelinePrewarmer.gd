# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/VulkanPipelinePrewarmer.gd
# Description: Infrastructure Service executing Milestone 3. Spawns an invisible 
#              hardware SubViewport and forces the GPU to compile all PBR, Foliage, 
#              Liquid, and Sky shaders before gameplay begins.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates dummy mesh 
#   allocations and frame-wait tracking to guarantee GPU cache saturation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VulkanPipelinePrewarmer
extends Node

signal prewarming_completed

# Wait 3 frames to ensure Vulkan rendering queues have fully flushed to the GPU
const REQUIRED_FRAMES: int = 3

var _viewport: SubViewport
var _frames_elapsed: int = 0
var _shared_mesh: BoxMesh


func _ready() -> void:
	name = "VulkanPipelinePrewarmer"
	_shared_mesh = BoxMesh.new()
	_shared_mesh.size = Vector3(0.01, 0.01, 0.01)
	
	_setup_hardware_viewport()
	_warm_voxel_materials()
	_warm_sky_environment()
	_warm_particle_shaders()
	
	print("[VulkanPrewarmer] Shaders queued. Forcing GPU compilation...")


func _process(_delta: float) -> void:
	_frames_elapsed += 1
	
	if _frames_elapsed >= REQUIRED_FRAMES:
		set_process(false)
		print("[VulkanPrewarmer] GPU pipeline compilation complete. Smooth gameplay secured.")
		prewarming_completed.emit()
		queue_free()


func _setup_hardware_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "PrewarmViewport"
	_viewport.size = Vector2i(64, 64) # Safe tile size bounds
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true # Prevents environment collisions
	add_child(_viewport)
	
	var camera := Camera3D.new()
	camera.name = "PrewarmCamera"
	camera.current = true
	camera.position = Vector3(0.0, 0.0, 1.0)
	_viewport.add_child(camera)


func _warm_voxel_materials() -> void:
	VoxelMaterialFactory.warm_up_material_pipelines()
	
	for b_id: int in BlockLibrary._definitions.keys():
		_instantiate_proxy_mesh(b_id, false) # Standard PBR
		_instantiate_proxy_mesh(b_id, true)  # Distant LODs


func _instantiate_proxy_mesh(b_id: int, is_distant: bool) -> void:
	var mat: Material = VoxelMaterialFactory.get_material(b_id, is_distant)
	if mat == null:
		return
		
	var mi := MeshInstance3D.new()
	mi.mesh = _shared_mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.0, -1.0)
	_viewport.add_child(mi)


func _warm_sky_environment() -> void:
	var env_node: WorldEnvironment = EnvironmentBuilder.build_environment()
	var sun_node: DirectionalLight3D = EnvironmentBuilder.build_sun()
	
	_viewport.add_child(env_node)
	_viewport.add_child(sun_node)


func _warm_particle_shaders() -> void:
	var unshaded_mat := StandardMaterial3D.new()
	unshaded_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var mi := MeshInstance3D.new()
	mi.mesh = _shared_mesh
	mi.material_override = unshaded_mat
	mi.position = Vector3(0.0, 0.0, -1.0)
	_viewport.add_child(mi)
