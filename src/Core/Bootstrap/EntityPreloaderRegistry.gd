# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/EntityPreloaderRegistry.gd
# Description: Static Registry centralizing preloads of scenes and static GLB
#              meshes to eliminate runtime disk I/O blocks (SRP / OCP).
#              REFACTORED: Converted compile-time preloads to runtime load calls
#              to resolve the Godot 4 import deadlock on clean cache builds.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityPreloaderRegistry
extends RefCounted

static var _mobs_scenes: Dictionary = {}  
static var _props_scenes: Dictionary = {} 

# RAM cache for static models to prevent hot I/O blockages
static var _static_models: Dictionary = {}


static func get_mob_scene(mob_id: int) -> PackedScene:
	_ensure_initialized()
	return _mobs_scenes.get(mob_id) as PackedScene


static func get_prop_scene(prop_id: int) -> Variant:
	_ensure_initialized()
	return _props_scenes.get(prop_id)


static func get_skeletal_model(path: String) -> PackedScene:
	_ensure_initialized()
	return _static_models.get(path) as PackedScene


static func _ensure_initialized() -> void:
	if _mobs_scenes.is_empty() and _props_scenes.is_empty():
		_preload_mobs()
		_preload_props()
		_preload_static_meshes_cache()


static func _preload_mobs() -> void:
	_preload_passive_fauna()
	_preload_hostile_husks()
	_preload_civilian_humanoids()


static func _preload_passive_fauna() -> void:
	_mobs_scenes[0] = load("res://src/Infrastructure/Life/pig_entity.tscn")
	_mobs_scenes[1] = load("res://src/Infrastructure/Life/chicken_entity.tscn")
	_mobs_scenes[2] = load("res://src/Infrastructure/Life/sheep_entity.tscn")
	_mobs_scenes[3] = load("res://src/Infrastructure/Life/cow_entity.tscn")
	_mobs_scenes[201] = load("res://src/Infrastructure/Life/turtle_entity.tscn")
	_mobs_scenes[204] = load("res://src/Infrastructure/Life/fox_entity.tscn")
	_mobs_scenes[205] = load("res://src/Infrastructure/Life/bird_entity.tscn")
	_mobs_scenes[206] = load("res://src/Infrastructure/Life/cat_entity.tscn")
	_mobs_scenes[207] = load("res://src/Infrastructure/Life/parrot_entity.tscn")
	_mobs_scenes[208] = load("res://src/Infrastructure/Life/crab_entity.tscn")
	_mobs_scenes[209] = load("res://src/Infrastructure/Life/elephant_entity.tscn")
	_mobs_scenes[210] = load("res://src/Infrastructure/Life/octopus_entity.tscn")
	_mobs_scenes[211] = load("res://src/Infrastructure/Life/raccoon_entity.tscn")
	_mobs_scenes[212] = load("res://src/Infrastructure/Life/growlithe_entity.tscn")
	_mobs_scenes[213] = load("res://src/Infrastructure/Life/monkey_entity.tscn")


static func _preload_hostile_husks() -> void:
	_mobs_scenes[10] = load("res://src/Infrastructure/Life/zombie_entity.tscn")
	_mobs_scenes[11] = load("res://src/Infrastructure/Life/shark_entity.tscn")
	_mobs_scenes[12] = load("res://src/Infrastructure/Life/gargoyle_entity.tscn")
	_mobs_scenes[13] = load("res://src/Infrastructure/Life/goblin_entity.tscn")
	_mobs_scenes[50] = load("res://src/Infrastructure/Life/lithic_lurker_entity.tscn")
	_mobs_scenes[51] = load("res://src/Infrastructure/Life/obsidian_colossus_entity.tscn")
	_mobs_scenes[52] = load("res://src/Infrastructure/Life/weaver_malakor_entity.tscn")


static func _preload_civilian_humanoids() -> void:
	_mobs_scenes[100] = load("res://src/Infrastructure/Life/villager_entity.tscn")
	_mobs_scenes[101] = load("res://src/Infrastructure/Life/merchant_entity.tscn")
	_mobs_scenes[102] = load("res://src/Infrastructure/Life/guard_entity.tscn")
	_mobs_scenes[103] = load("res://src/Infrastructure/Life/farmer_entity.tscn")
	_mobs_scenes[104] = load("res://src/Infrastructure/Life/druid_entity.tscn")
	_mobs_scenes[105] = load("res://src/Infrastructure/Life/miner_entity.tscn")
	_mobs_scenes[106] = load("res://src/Infrastructure/Life/cyber_citizen_entity.tscn")
	_mobs_scenes[107] = load("res://src/Infrastructure/Life/golem_entity.tscn")


static func _preload_props() -> void:
	_preload_structural_props()
	_preload_vegetation_props()


static func _preload_structural_props() -> void:
	_props_scenes[200] = load("res://src/Infrastructure/World/chest_entity.tscn") 
	_props_scenes[202] = load("res://src/Infrastructure/World/streetlight_entity.tscn")
	_props_scenes[203] = load("res://src/Infrastructure/World/campfire_entity.tscn")
	_props_scenes[213] = load("res://src/Infrastructure/World/wishing_well_entity.tscn")
	_props_scenes[215] = load("res://src/Infrastructure/World/barrel_entity.tscn")


static func _preload_vegetation_props() -> void:
	_props_scenes[220] = load("res://src/Infrastructure/World/dandelion_prop.tscn")
	_props_scenes[221] = load("res://src/Infrastructure/World/poppy_prop.tscn")
	_props_scenes[222] = load("res://src/Infrastructure/World/orchid_prop.tscn")
	_props_scenes[223] = load("res://src/Infrastructure/World/tall_grass_prop.tscn")
	_props_scenes[224] = load("res://src/Infrastructure/World/dead_bush_prop.tscn")
	_props_scenes[225] = load("res://src/Infrastructure/World/cactus_prop.tscn")
	_props_scenes[226] = load("res://src/Infrastructure/World/allium_prop.tscn")
	_props_scenes[227] = load("res://src/Infrastructure/World/bluebell_prop.tscn")
	_props_scenes[228] = load("res://src/Infrastructure/World/fern_prop.tscn")
	_props_scenes[229] = load("res://src/Infrastructure/World/sugar_cane_prop.tscn")
	_props_scenes[230] = load("res://src/Infrastructure/World/tulip_red_prop.tscn")
	_props_scenes[231] = load("res://src/Infrastructure/World/tulip_orange_prop.tscn")
	_props_scenes[232] = load("res://src/Infrastructure/World/tulip_pink_prop.tscn")
	_props_scenes[233] = load("res://src/Infrastructure/World/tulip_white_prop.tscn")
	_props_scenes[234] = load("res://src/Infrastructure/World/cornflower_prop.tscn")
	_props_scenes[235] = load("res://src/Infrastructure/World/daisy_prop.tscn")


static func _preload_static_meshes_cache() -> void:
	_static_models["res://assets/models/mobs/cyber.glb"] = load("res://assets/models/mobs/cyber.glb")
	_static_models["res://assets/models/mobs/druid.glb"] = load("res://assets/models/mobs/druid.glb")
	_static_models["res://assets/models/mobs/farmer.glb"] = load("res://assets/models/mobs/farmer.glb")
	_static_models["res://assets/models/mobs/guard.glb"] = load("res://assets/models/mobs/guard.glb")
	_static_models["res://assets/models/mobs/merchant.glb"] = load("res://assets/models/mobs/merchant.glb")
	_static_models["res://assets/models/mobs/miner.glb"] = load("res://assets/models/mobs/miner.glb")
	_static_models["res://assets/models/mobs/villager.glb"] = load("res://assets/models/mobs/villager.glb")
	_static_models["res://assets/models/mobs/zombie.glb"] = load("res://assets/models/mobs/zombie.glb")
