# ==============================================================================
# Pathfile: res://src/Infrastructure/World/FallingBlockEntity.gd
# Description: Lightweight presentation entity representing a collapsing block
#              sliding down smoothly via Tweens to its new landing support.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FallingBlockEntity
extends Node3D

var block_type: BlockType.Type
var world_controller: Node3D


## Starts the smooth sliding transition down to the highest solid ground.
func start_fall(p_world_controller: Node3D, p_type: BlockType.Type, target_y: float) -> void:
	world_controller = p_world_controller
	block_type = p_type
	
	_build_mesh_representation()
	
	# Compute falling duration proportionally based on vertical distance
	var fall_tween := create_tween()
	var duration := clampf((global_position.y - target_y) * 0.08, 0.15, 1.2)
	
	fall_tween.tween_property(self, "global_position:y", target_y, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	fall_tween.chain().tween_callback(_on_landed)


## Builds the 1x1x1 solid cube visual representation with its respective PBR texture
func _build_mesh_representation() -> void:
	var def := BlockLibrary.get_definition(block_type) as BlockDefinition
	if def == null:
		return
		
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh_instance.mesh = box_mesh
	
	# Pull offset to match the center pivot of the 1x1x1 grid cell
	mesh_instance.position = Vector3(0.5, 0.5, 0.5)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color_top
	mat.roughness = 0.95
	
	var tex := TextureRegistry.get_block_texture(block_type as int)
	if tex != null:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
	mesh_instance.material_override = mat
	add_child(mesh_instance)


## Triggers the solid landing impact, writing the block back into the solid world state
func _on_landed() -> void:
	if not is_instance_valid(world_controller):
		queue_free()
		return
		
	var land_coord := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	
	# Re-write the block into the solid world grid at its new fallen coordinates
	world_controller.call("set_block_globally", land_coord, block_type)
	
	# Audio and visual landing impact triggers
	AudioService.play_sfx_static("footstep_stone", global_position)
	_spawn_impact_dust_particles()
	
	queue_free()


## Spawns compile-free unshaded dust clouds around the landing base (Section 7.4).
func _spawn_impact_dust_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.4
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.4, 0.05, 0.4)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 60.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	particles.finished.connect(particles.queue_free)
	world_controller.add_child(particles)
	particles.global_position = global_position + Vector3(0.5, 0.05, 0.5)
	particles.emitting = true
