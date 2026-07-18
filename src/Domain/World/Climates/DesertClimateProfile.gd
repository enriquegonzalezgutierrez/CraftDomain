# ==============================================================================
# Pathfile: res://src/Domain/World/Climates/DesertClimateProfile.gd
# Description: Concrete Climatological Profile representing an arid desert climate.
#              Features high-frequency wind devils, high heat, and heavy sandstorms.
#              Uses typesafe domain enums to satisfy Liskov Substitution (LSP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name DesertClimateProfile
extends IClimateProfile


## Symmetrical typed keys using the ClimateType Enum (LSP Compliant)
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 0.7,
		ClimateType.RAINY: 0.0,
		ClimateType.SNOWY: 0.0,
		ClimateType.SANDSTORM: 0.3,  # Intense sandstorms are highly probable
		ClimateType.FOGGY: 0.0
	}


func get_max_wind_strength() -> float:
	return 1.8 # High-gale desert winds


func get_fog_density_multiplier() -> float:
	return 0.2 # Dry heat, air remains extremely clear by default
