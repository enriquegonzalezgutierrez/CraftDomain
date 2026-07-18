# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/SwampClimateProfile.gd
# Description: Concrete Climatological Profile representing a humid swamp climate.
#              Features stagnant wind conditions, damp mists, and heavy fogs.
#              Uses typesafe domain enums to satisfy Liskov Substitution (LSP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name SwampClimateProfile
extends IClimateProfile


## Symmetrical typed keys using the ClimateType Enum (LSP Compliant)
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.3,
		ClimateType.RAINY: 0.2,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.5       # Thick sulfurous mists are highly probable
	}


func get_max_wind_strength() -> float:
	return 0.35 # Stagnant, heavy air with very little wind movement


func get_fog_density_multiplier() -> float:
	return 2.8 # Super-thick ground hugging mist
