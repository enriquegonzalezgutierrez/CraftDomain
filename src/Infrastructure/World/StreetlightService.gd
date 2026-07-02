# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for scanning, registering,
#              and dynamically toggling village streetlights during day/night shifts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/StreetlightService.gd
# ==============================================================================
class_name StreetlightService
extends RefCounted

# Dependencies injected on initialization
var world_controller: Node3D
var world_state: WorldState

# Active registered streetlights coordinates: Array[Vector3i]
var _streetlight_coords: Array[Vector3i] = []
var _streetlights_active: bool = false

# Dictionary tracking spawned active OmniLight3D nodes in the world: Vector3i -> OmniLight3D
var _active_lights: Dictionary = {}

# ==============================================================================
# ENGINE PORTABILITY CONSTANTS
# Map raw integer values of RenderingServer.VideoAdapterType to bypass 
# version-specific compiler parser discrepancies across Godot 4.x.
# ==============================================================================
const ADAPTER_TYPE_INTEGRATED := 1
const ADAPTER_TYPE_CPU := 4


func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state


## Scans a newly loaded chunk. If it contains a village house, registers its lamppost coordinates.
func register_streetlights_for_chunk(chunk: Chunk) -> void:
	var chunk_pos := chunk.position
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if not has_house:
		return
		
	# The streetlight is placed procedurally inside the cabin chunk at local X=2, Z=10.
	# We search for the STONE block (lantern) placed on top of the WOOD post (height 3)
	var start_x := 2
	var start_z := 10
	var chunk_offset := Vector3i(chunk_pos * Chunk.SIZE)
	
	for y: int in range(1, Chunk.SIZE):
		var block_type := chunk.get_block(start_x, y, start_z)
		if block_type == BlockType.Type.STONE:
			var below_block := chunk.get_block(start_x, y - 1, start_z)
			if below_block == BlockType.Type.WOOD:
				var global_lantern_pos := chunk_offset + Vector3i(start_x, y, start_z)
				_streetlight_coords.append(global_lantern_pos)
				
				# Always spawn the physical 3D lantern immediately upon chunk load (Day or Night!)
				_spawn_light_at_coord(global_lantern_pos, _streetlights_active)
				
				# Ensure correct initial state on load if spawned mid-night
				if _streetlights_active:
					world_controller.call("set_block_globally", global_lantern_pos, BlockType.Type.NEON_CYAN)
				break


## Unregisters streetlights associated with an unloaded chunk pos to prevent memory leaks.
func unregister_streetlights_for_chunk(chunk_pos: Vector3i) -> void:
	var chunk_offset := chunk_pos * Chunk.SIZE
	var filtered_coords: Array[Vector3i] = []
	
	# FIX: Explicit static typing `Vector3i` on coordinates iterator
	for coord: Vector3i in _streetlight_coords:
		var relative_pos := coord - chunk_offset
		var is_inside := relative_pos.x >= 0 and relative_pos.x < Chunk.SIZE and relative_pos.z >= 0 and relative_pos.z < Chunk.SIZE
		if not is_inside:
			filtered_coords.append(coord)
		else:
			# If the chunk is unloaded, manually free its active light node
			_remove_light_at_coord(coord)
			
	_streetlight_coords = filtered_coords


## Evaluates the daylight state. If shifted, dynamically updates all registered lamppost blocks.
func update_streetlights_state(is_night: bool) -> void:
	if is_night != _streetlights_active:
		_streetlights_active = is_night
		print("[StreetlightService] Twilight shift. Toggling 3D Streetlights: ", "ON" if is_night else "OFF")
		
		# Night lamp uses glowing NEON_CYAN. Day lamp uses standard inactive STONE.
		var lantern_material_type: BlockType.Type = BlockType.Type.NEON_CYAN if is_night else BlockType.Type.STONE
		
		# FIX: Explicit static typing `Vector3i` on coordinates iterator
		for coord: Vector3i in _streetlight_coords:
			world_controller.call("set_block_globally", coord, lantern_material_type)
			
			# Animate the dynamic glow and light emission on twilight shifts (Observer Pattern)
			_animate_light_transition(coord, is_night)


## Internal Helper: Spawns and configures a warm physical OmniLight3D at target coordinate
func _spawn_light_at_coord(coord: Vector3i, is_night_start: bool) -> void:
	if _active_lights.has(coord) or not is_instance_valid(world_controller):
		return
		
	var light := OmniLight3D.new()
	light.name = "StreetLight_%d_%d_%d" % [coord.x, coord.y, coord.z]
	
	# Warm high-pressure sodium streetlamp color tint
	light.light_color = Color(1.0, 0.72, 0.3)
	light.light_energy = 2.2 if is_night_start else 0.0 # Starts unlit if day
	light.light_indirect_energy = 1.0
	light.omni_range = 12.0 # Spreads 12 meters
	light.omni_attenuation = 1.35 # Soft, realistic decay curve
	
	# ==========================================================================
	# DYNAMIC HARDWARE COMPATIBILITY PORT:
	# Disables point shadows on CPU/Integrated GPUs, saving massive fillrate, 
	# but preserves gorgeous shadows on Dedicated GPUs.
	# ==========================================================================
	var adapter_type: int = RenderingServer.get_video_adapter_type()
	var is_low_end: bool = (adapter_type == ADAPTER_TYPE_INTEGRATED or 
							adapter_type == ADAPTER_TYPE_CPU)
	
	if is_low_end:
		light.shadow_enabled = false
	else:
		# High-performance shadows configurations for Dedicated GPUs
		light.shadow_enabled = true
		light.shadow_bias = 0.05
		light.shadow_blur = 1.5
	# ==========================================================================
	
	# ==========================================================================
	# PROCEDURAL 3D RETRO LANTERN ASSEMBLY
	# Models a gorgeous hanging blacksmith lantern underneath the block.
	# ==========================================================================
	var container := Node3D.new()
	container.name = "LanternMesh"
	light.add_child(container)
	
	# 1. Glass glowing core (Yellow/Orange incandescence)
	var core := MeshInstance3D.new()
	core.name = "GlassCore"
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.24, 0.32, 0.24)
	core.mesh = core_mesh
	
	var core_mat := ORMMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.72, 0.3)
	core_mat.roughness = 0.9
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.72, 0.3)
	core_mat.emission_energy_multiplier = 1.8 if is_night_start else 0.0 # Unlit if day
	
	core.material_override = core_mat
	container.add_child(core)
	
	# 2. Outer Iron frame casing (Surrounds the glass core)
	var casing := MeshInstance3D.new()
	casing.name = "OuterIronFrame"
	var casing_mesh := BoxMesh.new()
	casing_mesh.size = Vector3(0.28, 0.36, 0.28)
	casing.mesh = casing_mesh
	
	var casing_mat := ORMMaterial3D.new()
	casing_mat.albedo_color = Color(0.12, 0.12, 0.15) # Black iron
	casing_mat.roughness = 0.85
	casing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # Allows glass core projection
	
	casing.material_override = casing_mat
	container.add_child(casing)
	
	# 3. Small Iron Ring (Attaches to the wood pole hanger)
	var iron_ring := MeshInstance3D.new()
	iron_ring.name = "IronRing"
	var ring_mesh := BoxMesh.new()
	ring_mesh.size = Vector3(0.04, 0.08, 0.04)
	iron_ring.mesh = ring_mesh
	iron_ring.material_override = casing_mat
	iron_ring.position = Vector3(0.0, 0.22, 0.0)
	container.add_child(iron_ring)
	
	# Shift the entire lantern assembly 0.58 meters down to float under the post
	container.position = Vector3(0.0, -0.58, 0.0)
	# ==========================================================================
	
	# Position exactly in the center of the lantern block (X+0.5, Y+0.5, Z+0.5)
	light.position = Vector3(coord) + Vector3(0.5, 0.5, 0.5)
	world_controller.add_child(light)
	_active_lights[coord] = light


## Smoothly ignites or dims the light energy and the glass core emission during twilight shifts.
func _animate_light_transition(coord: Vector3i, is_night: bool) -> void:
	if not _active_lights.has(coord):
		return
		
	var light := _active_lights[coord] as OmniLight3D
	if not is_instance_valid(light):
		return
		
	var core := light.get_node_or_null("LanternMesh/GlassCore") as MeshInstance3D
	if not is_instance_valid(core):
		return
		
	var core_mat := core.material_override as ORMMaterial3D
	if not is_instance_valid(core_mat):
		return
		
	# Smoothly interpolate parameters (2.0 seconds transition simulating gas ignition)
	var target_light_energy := 2.2 if is_night else 0.0
	var target_emission_energy := 1.8 if is_night else 0.0
	
	var tween := world_controller.create_tween().set_parallel(true)
	tween.tween_property(light, "light_energy", target_light_energy, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_mat, "emission_energy_multiplier", target_emission_energy, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Internal Helper: Instant deletion (used on chunk unloads)
func _remove_light_at_coord(coord: Vector3i) -> void:
	if _active_lights.has(coord):
		var light: OmniLight3D = _active_lights[coord] as OmniLight3D
		if is_instance_valid(light):
			light.queue_free()
		_active_lights.erase(coord)
