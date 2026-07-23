# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/GlacialClimateProfile.gd
# Description: Concrete Climatological Profile representing a freezing glacial climate.
#              Features high-gale polar winds, cold mist, clouds, and heavy blizzards.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GlacialClimateProfile
extends IClimateProfile


## Returns the probability weights for each ClimateType in glacial biomes.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.30,
		ClimateType.CLOUDY: 0.20,
		ClimateType.RAINY: 0.0,
		ClimateType.SNOWY: 0.50,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.6


func get_fog_density_multiplier() -> float:
	return 1.25
