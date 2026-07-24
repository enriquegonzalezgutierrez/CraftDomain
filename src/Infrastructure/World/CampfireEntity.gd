# ==============================================================================
# Pathfile: res://src/Infrastructure/World/CampfireEntity.gd
# Description: Infrastructure Static Entity representing an active, cozy Campfire.
#              Manages light flickering calculations, player proximity healing,
#              and volumetric 3D cartoon flame rendering.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CampfireEntity
extends StaticBody3D

const FLAME_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/cartoon_3d_fire.gdshader"

@onready var _fire_light: OmniLight3D = $CampfireLight

var _flicker_time: float = 0.0
var _flame_mesh: MeshInstance3D


func _ready() -> void:
	name = "Prop_CAMPFIRE"
	_flicker_time = randf_range(0.0, 100.0)
	
	_sanitize_campfire_glb()
	_setup_volumetric_flame_mesh()


func _sanitize_campfire_glb() -> void:
	var model_node := get_node_or_null("Visuals/BodyBobJoint/campfire") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)


func _setup_volumetric_flame_mesh() -> void:
	if not ResourceLoader.exists(FLAME_SHADER_PATH):
		return
		
	_flame_mesh = MeshInstance3D.new()
	_flame_mesh.name = "Volumetric3DFlame"
	
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.35
	cyl.height = 0.75
	_flame_mesh.mesh = cyl
	_flame_mesh.position = Vector3(0.0, 0.45, 0.0)
	
	var mat := ShaderMaterial.new()
	mat.shader = load(FLAME_SHADER_PATH) as Shader
	_flame_mesh.material_override = mat
	
	add_child(_flame_mesh)


func _process(delta: float) -> void:
	_update_light_flicker(delta)


func _update_light_flicker(delta: float) -> void:
	if is_instance_valid(_fire_light):
		_flicker_time += delta * 15.0
		var noise_val := sin(_flicker_time) * 0.15 + cos(_flicker_time * 0.45) * 0.08
		_fire_light.light_energy = 2.8 + noise_val


func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var entity_domain := player_node.get("domain_entity") as VoxelEntity
	if is_instance_valid(entity_domain) and entity_domain.health < 3:
		_restore_player_health(player_node, entity_domain)


func _restore_player_health(player_node: CharacterBody3D, entity_domain: VoxelEntity) -> void:
	entity_domain.health = min(3, entity_domain.health + 1)
	
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		hud.update_health_display(entity_domain.health)
		hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_HUMANITY_RESTORED"))
		
	AudioService.play_sfx_static("block_break", global_position)
