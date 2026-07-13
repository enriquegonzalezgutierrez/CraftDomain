# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/EntityPreloaderRegistry.gd
# Description: Static Registry centralizing all scene preloads, mob registrations,
#              and prop factories, completely freeing Bootstrap from carrying
#              100+ lines of raw asset paths (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityPreloaderRegistry
extends RefCounted

# Cached PackedScenes preloaded statically in RAM on startup to prevent in-game lag spikes (OCP)
static var _mobs_scenes: Dictionary = {}  # mob_id (int) -> PackedScene
static var _props_scenes: Dictionary = {} # prop_id (int) -> PackedScene


static func _static_init() -> void:
	_preload_mobs()
	_preload_props()


## Returns the preloaded PackedScene for a given Mob ID (returns null if missing)
static func get_mob_scene(mob_id: int) -> PackedScene:
	if _mobs_scenes.has(mob_id):
		return _mobs_scenes[mob_id] as PackedScene
	return null


## Returns the preloaded Script/Scene for a given Prop ID (returns null if missing)
static func get_prop_scene(prop_id: int) -> Variant:
	if _props_scenes.has(prop_id):
		return _props_scenes[prop_id]
	return null


static func _preload_mobs() -> void:
	_mobs_scenes[0] = preload("res://src/Infrastructure/Life/pig_entity.tscn")
	_mobs_scenes[1] = preload("res://src/Infrastructure/Life/chicken_entity.tscn")
	_mobs_scenes[2] = preload("res://src/Infrastructure/Life/sheep_entity.tscn")
	_mobs_scenes[3] = preload("res://src/Infrastructure/Life/cow_entity.tscn")
	_mobs_scenes[10] = preload("res://src/Infrastructure/Life/zombie_entity.tscn")
	_mobs_scenes[11] = preload("res://src/Infrastructure/Life/shark_entity.tscn")
	_mobs_scenes[12] = preload("res://src/Infrastructure/Life/gargoyle_entity.tscn")
	_mobs_scenes[13] = preload("res://src/Infrastructure/Life/goblin_entity.tscn")
	_mobs_scenes[100] = preload("res://src/Infrastructure/Life/villager_entity.tscn")
	_mobs_scenes[101] = preload("res://src/Infrastructure/Life/merchant_entity.tscn")
	_mobs_scenes[102] = preload("res://src/Infrastructure/Life/guard_entity.tscn")
	_mobs_scenes[103] = preload("res://src/Infrastructure/Life/farmer_entity.tscn")
	_mobs_scenes[104] = preload("res://src/Infrastructure/Life/druid_entity.tscn")
	_mobs_scenes[105] = preload("res://src/Infrastructure/Life/miner_entity.tscn")
	_mobs_scenes[106] = preload("res://src/Infrastructure/Life/cyber_citizen_entity.tscn")
	_mobs_scenes[107] = preload("res://src/Infrastructure/Life/golem_entity.tscn")
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


static func _preload_props() -> void:
	# BIND SCENE HOOKS: All interactive scenery props are preloaded statically as .tscn files
	_props_scenes[200] = preload("res://src/Infrastructure/World/chest_entity.tscn") 
	_props_scenes[202] = preload("res://src/Infrastructure/World/streetlight_entity.tscn")
	_props_scenes[203] = preload("res://src/Infrastructure/World/campfire_entity.tscn")
	_props_scenes[213] = preload("res://src/Infrastructure/World/wishing_well_entity.tscn")
	_props_scenes[215] = preload("res://src/Infrastructure/World/barrel_entity.tscn")
