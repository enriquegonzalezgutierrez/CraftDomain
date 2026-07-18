# ==============================================================================
# Pathfile: res://src/Domain/World/IClimateProfile.gd
# Description: Pure Domain Interface representing the climatological profile
#              of a biome, separating weather rules from terrain generation (ISP).
#              Employs typesafe enums to guarantee Liskov Substitution (LSP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name IClimateProfile
extends RefCounted

## Typesafe climate identifiers checked at compile-time (LSP Compliant)
enum ClimateType {
	SUNNY,
	RAINY,
	SNOWY,
	SANDSTORM,
	FOGGY
}


## Returns the probability weights for each climate type.
## Keys must strictly be ClimateType enums, values must be floats.
func get_climate_weights() -> Dictionary:
	return {
		ClimateType.SUNNY: 1.0,
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
