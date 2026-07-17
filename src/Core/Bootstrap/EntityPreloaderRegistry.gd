# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/EntityPreloaderRegistry.gd
# Description: Static Registry centralizing all scene preloads, mob registrations,
#              and prop factories, completely freeing Bootstrap from carrying
#              100+ lines of raw asset paths (SRP / OCP).
# SOLID COMPLIANCE: Class limits set under 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 20 lines.
# - Open-Closed Principle (OCP): Registers Act I, III, and IV Boss scenes dynamically (IDs 50, 51 & 52).
# - Thread Safety: Replaced static compile-time initialization (_static_init)
#   with lazy, on-demand runtime loading to prevent editor deadlocks on startup.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityPreloaderRegistry
extends RefCounted

static var _mobs_scenes: Dictionary = {}  
static var _props_scenes: Dictionary = {} 


static func get_mob_scene(mob_id: int) -> PackedScene:
	_ensure_initialized()
	if _mobs_scenes.has(mob_id):
		return _mobs_scenes[mob_id] as PackedScene
	return null


static func get_prop_scene(prop_id: int) -> Variant:
	_ensure_initialized()
	if _props_scenes.has(prop_id):
		return _props_scenes[prop_id]
	return null


static func _ensure_initialized() -> void:
	if _mobs_scenes.is_empty() and _props_scenes.is_empty():
		_preload_mobs()
		_preload_props()


static func _preload_mobs() -> void:
	_preload_passive_fauna()
	_preload_hostile_husks()
	_preload_civilian_humanoids()


static func _preload_passive_fauna() -> void:
	_mobs_scenes[0] = preload("res://src/Infrastructure/Life/pig_entity.tscn")
	_mobs_scenes[1] = preload("res://src/Infrastructure/Life/chicken_entity.tscn")
	_mobs_scenes[2] = preload("res://src/Infrastructure/Life/sheep_entity.tscn")
	_mobs_scenes[3] = preload("res://src/Infrastructure/Life/cow_entity.tscn")
	_mobs_scenes[201] = preload("res://src/Infrastructure/Life/turtle_entity.tscn")
	_mobs_scenes[204] = preload("res://src/Infrastructure/Life/fox_entity.tscn")
	_mobs_scenes[205] = preload("res://src/Infrastructure/Life/bird_entity.tscn")
	_mobs_scenes[206] = preload("res://src/Infrastructure/Life/cat_entity.tscn")
	_mobs_scenes[207] = preload("res://src/Infrastructure/Life/parrot_entity.tscn")
	_mobs_scenes[208] = preload("res://src/Infrastructure/Life/crab_entity.tscn")
	_mobs_scenes[209] = preload("res://src/Infrastructure/Life/elephant_entity.tscn")
	_mobs_scenes[210] = preload("res://src/Infrastructure/Life/octopus_entity.tscn")
	_mobs_scenes[211] = preload("res://src/Infrastructure/Life/raccoon_entity.tscn")
	_mobs_scenes[212] = preload("res://src/Infrastructure/Life/growlithe_entity.tscn")
	_mobs_scenes[213] = preload("res://src/Infrastructure/Life/monkey_entity.tscn")


static func _preload_hostile_husks() -> void:
	_mobs_scenes[10] = preload("res://src/Infrastructure/Life/zombie_entity.tscn")
	_mobs_scenes[11] = preload("res://src/Infrastructure/Life/shark_entity.tscn")
	_mobs_scenes[12] = preload("res://src/Infrastructure/Life/gargoyle_entity.tscn")
	_mobs_scenes[13] = preload("res://src/Infrastructure/Life/goblin_entity.tscn")
	
	# Act I, III, and IV Boss Preloads
	_mobs_scenes[50] = preload("res://src/Infrastructure/Life/lithic_lurker_entity.tscn")
	_mobs_scenes[51] = preload("res://src/Infrastructure/Life/obsidian_colossus_entity.tscn")
	_mobs_scenes[52] = preload("res://src/Infrastructure/Life/weaver_malakor_entity.tscn")


static func _preload_civilian_humanoids() -> void:
	_mobs_scenes[100] = preload("res://src/Infrastructure/Life/villager_entity.tscn")
	_mobs_scenes[101] = preload("res://src/Infrastructure/Life/merchant_entity.tscn")
	_mobs_scenes[102] = preload("res://src/Infrastructure/Life/guard_entity.tscn")
	_mobs_scenes[103] = preload("res://src/Infrastructure/Life/farmer_entity.tscn")
	_mobs_scenes[104] = preload("res://src/Infrastructure/Life/druid_entity.tscn")
	_mobs_scenes[105] = preload("res://src/Infrastructure/Life/miner_entity.tscn")
	_mobs_scenes[106] = preload("res://src/Infrastructure/Life/cyber_citizen_entity.tscn")
	_mobs_scenes[107] = preload("res://src/Infrastructure/Life/golem_entity.tscn")


static func _preload_props() -> void:
	_preload_structural_props()
	_preload_vegetation_props()


static func _preload_structural_props() -> void:
	_props_scenes[200] = preload("res://src/Infrastructure/World/chest_entity.tscn") 
	_props_scenes[202] = preload("res://src/Infrastructure/World/streetlight_entity.tscn")
	_props_scenes[203] = preload("res://src/Infrastructure/World/campfire_entity.tscn")
	_props_scenes[213] = preload("res://src/Infrastructure/World/wishing_well_entity.tscn")
	_props_scenes[215] = preload("res://src/Infrastructure/World/barrel_entity.tscn")


static func _preload_vegetation_props() -> void:
	_props_scenes[220] = preload("res://src/Infrastructure/World/dandelion_prop.tscn")
	_props_scenes[221] = preload("res://src/Infrastructure/World/poppy_prop.tscn")
	_props_scenes[222] = preload("res://src/Infrastructure/World/orchid_prop.tscn")
	_props_scenes[223] = preload("res://src/Infrastructure/World/tall_grass_prop.tscn")
	_props_scenes[224] = preload("res://src/Infrastructure/World/dead_bush_prop.tscn")
	_props_scenes[225] = preload("res://src/Infrastructure/World/cactus_prop.tscn")
	_props_scenes[226] = preload("res://src/Infrastructure/World/allium_prop.tscn")
	_props_scenes[227] = preload("res://src/Infrastructure/World/bluebell_prop.tscn")
	_props_scenes[228] = preload("res://src/Infrastructure/World/fern_prop.tscn")
	_props_scenes[229] = preload("res://src/Infrastructure/World/sugar_cane_prop.tscn")
	_props_scenes[230] = preload("res://src/Infrastructure/World/tulip_red_prop.tscn")
	_props_scenes[231] = preload("res://src/Infrastructure/World/tulip_orange_prop.tscn")
	_props_scenes[232] = preload("res://src/Infrastructure/World/tulip_pink_prop.tscn")
	_props_scenes[233] = preload("res://src/Infrastructure/World/tulip_white_prop.tscn")
	_props_scenes[234] = preload("res://src/Infrastructure/World/cornflower_prop.tscn")
	_props_scenes[235] = preload("res://src/Infrastructure/World/daisy_prop.tscn")