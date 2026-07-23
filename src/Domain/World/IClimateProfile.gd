# ==============================================================================
# Pathfile: res://src/Domain/World/IClimateProfile.gd
# Description: Pure Domain Interface defining the climatological profile of biomes,
#              decoupling weather rules from terrain generators (ISP/LSP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IClimateProfile
extends RefCounted

enum ClimateType {
	SUNNY,      # 100% Clear blue sky, no clouds
	CLOUDY,     # Overcast, beautiful fluffy clouds but no precipitation
	RAINY,      # Grey storm clouds with falling rain particles
	SNOWY,      # Cold overcast clouds with falling snow blizzards
	SANDSTORM,  # Arid dust storm clouds with blowing sand
	FOGGY       # Low ground-hugging mist
}


## Returns the probability weights for each ClimateType.
## Keys must strictly be ClimateType enums, values must be floats.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 1.0,
		ClimateType.CLOUDY: 0.0,
		ClimateType.RAINY: 0.0,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.0
	}


## Returns the maximum wind strength allowed in this climate profile.
func get_max_wind_strength() -> float:
	return 1.0


## Returns the baseline fog density multiplier.
func get_fog_density_multiplier() -> float:
	return 1.0
