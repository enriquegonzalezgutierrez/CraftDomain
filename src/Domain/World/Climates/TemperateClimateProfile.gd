# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/TemperateClimateProfile.gd
# Description: Concrete Climatological Profile representing a temperate climate.
#              Features standard winds, clear atmosphere, and balanced rains.
#              Uses typesafe domain enums to satisfy Liskov Substitution (LSP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name TemperateClimateProfile
extends IClimateProfile


## Symmetrical typed keys using the ClimateType Enum (LSP Compliant)
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.6,
		ClimateType.RAINY: 0.4,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.0


func get_fog_density_multiplier() -> float:
	return 1.0
