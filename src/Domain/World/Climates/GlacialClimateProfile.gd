# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/GlacialClimateProfile.gd
# Description: Concrete Climatological Profile representing a freezing glacial climate.
#              Features high-gale polar winds, cold mist, and heavy blizzards.
#              Uses typesafe domain enums to satisfy Liskov Substitution (LSP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name GlacialClimateProfile
extends IClimateProfile


## Symmetrical typed keys using the ClimateType Enum (LSP Compliant)
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.4,
		ClimateType.RAINY: 0.0,
		ClimateType.SNOWY: 0.6,      # Heavy Blizzards are highly probable
		ClimateType.SANDSTORM: 0.0,
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.6 # Mighty polar winds


func get_fog_density_multiplier() -> float:
	return 1.25 # Cold polar environment mist
