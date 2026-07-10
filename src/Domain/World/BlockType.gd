# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Value Objects)
# Class: BlockType
# Description: Pure Domain Value Object defining all supported voxel block types.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Encapsulates exclusively the raw block
#   ID enum type mappings.
# - Open-Closed Principle (OCP): No longer hardcodes physical properties (solidity,
#   transparency) inside static tables. These parameters are dynamically retrieved 
#   from the centralized, data-driven `BlockLibrary` definitions, making this class
#   completely closed to modifications when adding new block types.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockType.gd
# ==============================================================================
class_name BlockType
extends RefCounted

## Enumeration of all raw block IDs supported by the voxel meshing engine.
enum Type {
	AIR = 0,
	STONE = 1,
	DIRT = 2,
	GRASS = 3,
	WOOD = 4,
	LEAVES = 5,
	WATER = 6,
	SAND = 7,
	RED_SAND = 8,
	SNOW = 9,
	ICE = 10,
	MUD = 11,
	NEON_CYAN = 12,
	NEON_MAGENTA = 13,
	CLOUD = 14,
	LAVA = 15,
	
	# Agricultural Stages
	CROP_SEED = 18,
	CROP_GROWING = 19,
	CROP_RIPE = 20,
	
	# Extended structural blocks
	COAL_ORE = 21,
	BRICKS = 22,
	GLASS = 23,
	BIRCH_LOG = 24,
	
	# Scenery Highway Blocks
	ROAD = 25,
	
	# Slabs / Half-height Blocks
	STONE_SLAB_BOTTOM = 26,
	STONE_SLAB_TOP = 27,
	
	# Caves & Desert Expansion
	DIAMOND_ORE = 28,
	OAK_PLANKS = 29,
	GLOWSTONE = 30,
	
	# ==========================================================================
	# LOTE 1: PROGRESSIVE MINING ORES & FLORA
	# ==========================================================================
	IRON_ORE = 31,
	GOLD_ORE = 32,
	REDSTONE_ORE = 33,
	OAK_PLANKS_SLAB_BOTTOM = 34,
	RED_MUSHROOM = 35,
	
	# ==========================================================================
	# LOTE 2: REFINED SOLID METALS, OBSIDIAN & FLORA
	# ==========================================================================
	IRON_BLOCK = 36,
	GOLD_BLOCK = 37,
	REDSTONE_BLOCK = 38,
	OBSIDIAN = 39,
	BROWN_MUSHROOM = 40,
	
	# ==========================================================================
	# LOTE 3: WOOD TOP SLABS, FABRIC WOOL, LAPIS & ADOQUINES
	# ==========================================================================
	OAK_PLANKS_SLAB_TOP = 41,
	RED_WOOL = 42,
	BLUE_WOOL = 43,
	LAPIS_ORE = 44,
	MOSSY_COBBLESTONE = 45,
	
	# ==========================================================================
	# LOTE 4: WILD FLOWERS, ADOQUINES & MINIMALIST STONE
	# ==========================================================================
	DANDELION = 46,
	COBBLESTONE = 47,
	MOSSY_COBBLESTONE_SLAB_BOTTOM = 48,
	SOLID_SNOW = 49,
	SMOOTH_STONE = 50,
	
	# ==========================================================================
	# LOTE 5: FLORES, LOSAS CONCRETAS, LADRILLOS NOBLES & ESMERALDAS
	# ==========================================================================
	POPPY = 51,
	SMOOTH_STONE_SLAB_BOTTOM = 52,
	STONE_BRICKS = 53,
	EMERALD_ORE = 54,
	MOSSY_STONE_BRICKS = 55,
	
	# ==========================================================================
	# LOTE 6: LIBRERIAS, PILARES TEMPLO, LOSAS DE CASTILLO & HIELO GLACIAL
	# ==========================================================================
	BOOKSHELF = 56,
	CHISELED_STONE_BRICKS = 57,
	STONE_BRICKS_SLAB_BOTTOM = 58,
	TERRACOTTA = 59,
	ICE_SLAB_BOTTOM = 60,
	
	# ==========================================================================
	# LOTE 7: FLORES DE HIELO, LOSAS GLACIALES, ABETO RUSTICO & LOSAS OSCURAS
	# ==========================================================================
	BLUE_ORCHID = 61,
	ICE_SLAB_TOP = 62,
	SPRUCE_LOG = 63,
	SPRUCE_PLANKS = 64,
	SPRUCE_PLANKS_SLAB_BOTTOM = 65,
	
	# ==========================================================================
	# LOTE 8: LOSAS ALPINAS, ACICULAS PINO & CUARZO DEL NETHER
	# ==========================================================================
	SPRUCE_PLANKS_SLAB_TOP = 66,
	SPRUCE_LEAVES = 67,
	QUARTZ_ORE = 68,
	QUARTZ_BLOCK = 69,
	QUARTZ_SLAB_BOTTOM = 70,
	
	# ==========================================================================
	# LOTE 9: LOSAS CUARZO SUPERIOR, MICELIO ESPORAS & PILARES MARMOL
	# ==========================================================================
	QUARTZ_SLAB_TOP = 71,
	CHISELED_QUARTZ = 72,
	LAPIS_BLOCK = 73,
	MYCELIUM = 74,
	SMOOTH_STONE_SLAB_TOP = 75,
	
	# ==========================================================================
	# LOTE 10: EL GRAN CIERRE - NETHERRACK, CACTUS & LOSAS VIDRIO
	# ==========================================================================
	NETHERRACK = 76,
	NETHER_BRICKS = 77,
	CACTUS = 78,
	MAGMA = 79,
	GLASS_SLAB_BOTTOM = 80
}


## Returns true if the block type occupies physical space (is solid).
## Sourced dynamically from the data-driven BlockLibrary.
static func is_solid(type: Type) -> bool:
	# FIXED: Explicitly typed variable declaration to satisfy strict static compiler
	var def: BlockDefinition = BlockLibrary.get_definition(type) as BlockDefinition
	return def.is_solid if def != null else false


## Returns true if the block type is transparent or semi-transparent.
## Sourced dynamically from the data-driven BlockLibrary.
static func is_transparent(type: Type) -> bool:
	# FIXED: Explicitly typed variable declaration to satisfy strict static compiler
	var def: BlockDefinition = BlockLibrary.get_definition(type) as BlockDefinition
	return def.is_transparent if def != null else false
