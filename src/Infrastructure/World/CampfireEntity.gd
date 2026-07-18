# ==============================================================================
# Pathfile: res://src/Infrastructure/World/CampfireEntity.gd
# Description: Infrastructure Static Entity representing an active, cozy Campfire.
#              Manages light flickering calculations and player proximity healing.
#              SOLID CLEANUP: Purged all procedural mesh and particle generation
#              from code (Section 7.6). All visual nodes are declared in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CampfireEntity
extends StaticBody3D

@onready var _fire_light: OmniLight3D = $CampfireLight

# Internal timer for light flickering calculations
var _flicker_time: float = 0.0


func _ready() -> void:
	name = "Prop_CAMPFIRE"
	_flicker_time = randf_range(0.0, 100.0)


## Procedural Flicker: Updates only light energy on the main thread
func _process(delta: float) -> void:
	if is_instance_valid(_fire_light):
		_flicker_time += delta * 15.0
		var noise_val := sin(_flicker_time) * 0.15 + cos(_flicker_time * 0.45) * 0.08
		_fire_light.light_energy = 2.8 + noise_val


## Proximity Healing: Restores player health upon interaction
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var entity_domain := player_node.get("domain_entity") as VoxelEntity
	if is_instance_valid(entity_domain) and entity_domain.health < 3:
		entity_domain.health = min(3, entity_domain.health + 1)
		
		var hud := player_node.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.update_health_display(entity_domain.health)
			hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_HUMANITY_RESTORED"))
			
		AudioService.play_sfx_static("block_break", global_position)
