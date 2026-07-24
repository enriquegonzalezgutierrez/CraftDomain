# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/EntityPreloaderRegistry.gd
# Description: Static Registry centralizing preloads of scenes and static GLB
#              meshes to eliminate runtime disk I/O blocks (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityPreloaderRegistry
extends RefCounted

const LIFE_DIR: String = "res://src/Infrastructure/Life/"
const WORLD_DIR: String = "res://src/Infrastructure/World/"
const MODELS_DIR: String = "res://assets/models/mobs/"

static var _mobs_scenes: Dictionary = {}  
static var _props_scenes: Dictionary = {} 
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
	_preload_passive_fauna_a()
	_preload_passive_fauna_b()
	_preload_hostile_husks()
	_preload_civilian_humanoids()


static func _preload_passive_fauna_a() -> void:
	_mobs_scenes[0] = load(LIFE_DIR + "pig_entity.tscn")
	_mobs_scenes[1] = load(LIFE_DIR + "chicken_entity.tscn")
	_mobs_scenes[2] = load(LIFE_DIR + "sheep_entity.tscn")
	_mobs_scenes[3] = load(LIFE_DIR + "cow_entity.tscn")
	_mobs_scenes[201] = load(LIFE_DIR + "turtle_entity.tscn")
	_mobs_scenes[204] = load(LIFE_DIR + "fox_entity.tscn")
	_mobs_scenes[205] = load(LIFE_DIR + "bird_entity.tscn")
	_mobs_scenes[206] = load(LIFE_DIR + "cat_entity.tscn")


static func _preload_passive_fauna_b() -> void:
	_mobs_scenes[207] = load(LIFE_DIR + "parrot_entity.tscn")
	_mobs_scenes[208] = load(LIFE_DIR + "crab_entity.tscn")
	_mobs_scenes[209] = load(LIFE_DIR + "elephant_entity.tscn")
	_mobs_scenes[210] = load(LIFE_DIR + "octopus_entity.tscn")
	_mobs_scenes[211] = load(LIFE_DIR + "raccoon_entity.tscn")
	_mobs_scenes[212] = load(LIFE_DIR + "growlithe_entity.tscn")
	_mobs_scenes[213] = load(LIFE_DIR + "monkey_entity.tscn")
	_mobs_scenes[214] = load(LIFE_DIR + "speedy_hedgehog_entity.tscn")


static func _preload_hostile_husks() -> void:
	_mobs_scenes[10] = load(LIFE_DIR + "zombie_entity.tscn")
	_mobs_scenes[11] = load(LIFE_DIR + "shark_entity.tscn")
	_mobs_scenes[12] = load(LIFE_DIR + "gargoyle_entity.tscn")
	_mobs_scenes[13] = load(LIFE_DIR + "goblin_entity.tscn")
	_mobs_scenes[14] = load(LIFE_DIR + "badnik_crab_entity.tscn")
	_mobs_scenes[50] = load(LIFE_DIR + "lithic_lurker_entity.tscn")
	_mobs_scenes[51] = load(LIFE_DIR + "obsidian_colossus_entity.tscn")
	_mobs_scenes[52] = load(LIFE_DIR + "weaver_malakor_entity.tscn")


static func _preload_civilian_humanoids() -> void:
	_mobs_scenes[100] = load(LIFE_DIR + "villager_entity.tscn")
	_mobs_scenes[101] = load(LIFE_DIR + "merchant_entity.tscn")
	_mobs_scenes[102] = load(LIFE_DIR + "guard_entity.tscn")
	_mobs_scenes[103] = load(LIFE_DIR + "farmer_entity.tscn")
	_mobs_scenes[104] = load(LIFE_DIR + "druid_entity.tscn")
	_mobs_scenes[105] = load(LIFE_DIR + "miner_entity.tscn")
	_mobs_scenes[106] = load(LIFE_DIR + "cyber_citizen_entity.tscn")
	_mobs_scenes[107] = load(LIFE_DIR + "golem_entity.tscn")
	_mobs_scenes[110] = load(LIFE_DIR + "quique_entity.tscn")


static func _preload_props() -> void:
	_preload_structural_props()
	_preload_vegetation_props_a()
	_preload_vegetation_props_b()


static func _preload_structural_props() -> void:
	_props_scenes[200] = load(WORLD_DIR + "chest_entity.tscn") 
	_props_scenes[202] = load(WORLD_DIR + "streetlight_entity.tscn")
	_props_scenes[203] = load(WORLD_DIR + "campfire_entity.tscn")
	_props_scenes[213] = load(WORLD_DIR + "wishing_well_entity.tscn")
	_props_scenes[215] = load(WORLD_DIR + "barrel_entity.tscn")
	_props_scenes[250] = load(WORLD_DIR + "sonic_corkscrew_loop_prop.tscn")
	_props_scenes[251] = load(WORLD_DIR + "sonic_palm_tree_prop.tscn")
	_props_scenes[252] = load(WORLD_DIR + "golden_ring_prop.tscn")
	_props_scenes[253] = load(WORLD_DIR + "speed_spring_pad_prop.tscn")


static func _preload_vegetation_props_a() -> void:
	_props_scenes[220] = load(WORLD_DIR + "dandelion_prop.tscn")
	_props_scenes[221] = load(WORLD_DIR + "poppy_prop.tscn")
	_props_scenes[222] = load(WORLD_DIR + "orchid_prop.tscn")
	_props_scenes[223] = load(WORLD_DIR + "tall_grass_prop.tscn")
	_props_scenes[224] = load(WORLD_DIR + "dead_bush_prop.tscn")
	_props_scenes[225] = load(WORLD_DIR + "cactus_prop.tscn")
	_props_scenes[226] = load(WORLD_DIR + "allium_prop.tscn")
	_props_scenes[227] = load(WORLD_DIR + "bluebell_prop.tscn")
	_props_scenes[228] = load(WORLD_DIR + "fern_prop.tscn")
	_props_scenes[229] = load(WORLD_DIR + "sugar_cane_prop.tscn")


static func _preload_vegetation_props_b() -> void:
	_props_scenes[230] = load(WORLD_DIR + "tulip_red_prop.tscn")
	_props_scenes[231] = load(WORLD_DIR + "tulip_orange_prop.tscn")
	_props_scenes[232] = load(WORLD_DIR + "tulip_pink_prop.tscn")
	_props_scenes[233] = load(WORLD_DIR + "tulip_white_prop.tscn")
	_props_scenes[234] = load(WORLD_DIR + "cornflower_prop.tscn")
	_props_scenes[235] = load(WORLD_DIR + "daisy_prop.tscn")
	_props_scenes[236] = load(WORLD_DIR + "palm_bush_prop.tscn")
	_props_scenes[237] = load(WORLD_DIR + "glowing_mushroom_prop.tscn")
	_props_scenes[238] = load(WORLD_DIR + "sakura_bush_prop.tscn")
	_props_scenes[239] = load(WORLD_DIR + "water_lily_prop.tscn")
	_props_scenes[240] = load(WORLD_DIR + "frost_crystal_flower_prop.tscn")


static func _preload_static_meshes_cache() -> void:
	var models: Array[String] = [
		"cyber.glb", "druid.glb", "farmer.glb", "guard.glb",
		"merchant.glb", "miner.glb", "villager.glb", "zombie.glb", "quique/quique.glb"
	]
	for model_file in models:
		var path := MODELS_DIR + model_file
		_static_models[path] = load(path)
