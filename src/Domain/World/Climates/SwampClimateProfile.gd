# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/SwampClimateProfile.gd
# Description: Concrete Climatological Profile representing a humid swamp climate.
#              Features stagnant wind, damp mists, clouds, and heavy fogs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SwampClimateProfile
extends IClimateProfile


## Returns the probability weights for each ClimateType in swamp biomes.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.20,
		ClimateType.CLOUDY: 0.15,
		ClimateType.RAINY: 0.15,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.50
	}


func get_max_wind_strength() -> float:
	return 0.35


func get_fog_density_multiplier() -> float:
	return 2.8
