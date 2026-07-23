# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/TemperateClimateProfile.gd
# Description: Concrete Climatological Profile representing a temperate climate.
#              Features standard winds, clear atmosphere, and balanced rains/clouds.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TemperateClimateProfile
extends IClimateProfile


## Returns the probability weights for each ClimateType in temperate biomes.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.50,
		ClimateType.CLOUDY: 0.25,
		ClimateType.RAINY: 0.25,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.0


func get_fog_density_multiplier() -> float:
	return 1.0
