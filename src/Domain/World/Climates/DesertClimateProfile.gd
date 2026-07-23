# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/DesertClimateProfile.gd
# Description: Concrete Climatological Profile representing an arid desert climate.
#              Features high-frequency wind, intense heat, clouds, and sandstorms.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DesertClimateProfile
extends IClimateProfile


## Returns the probability weights for each ClimateType in desert biomes.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.60,
		ClimateType.CLOUDY: 0.10,
		ClimateType.RAINY: 0.0,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.30,
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.8


func get_fog_density_multiplier() -> float:
	return 0.2
