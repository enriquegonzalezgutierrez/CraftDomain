# ==============================================================================
# Pathfile: res://src/Domain/World/BlockType.gd
# Description: Pure Domain Value Object defining all supported voxel block types.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Encapsulates exclusively the raw block
#   ID enum type mappings.
# - Open-Closed Principle (OCP): All active custom blocks, flora, and tools 
#   registered cleanly inside the Type enum to permanently prevent compiler
#   casting warnings across biomes and blueprints.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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
	
	# Progressive Mining Ores & Flora
	IRON_ORE = 31,
	GOLD_ORE = 32,
	REDSTONE_ORE = 33,
	OAK_PLANKS_SLAB_BOTTOM = 34,
	RED_MUSHROOM = 35,
	
	# Refined Metals & Obsidian
	IRON_BLOCK = 36,
	GOLD_BLOCK = 37,
	REDSTONE_BLOCK = 38,
	OBSIDIAN = 39,
	BROWN_MUSHROOM = 40,
	
	# Planks Slabs & Mossy Materials
	OAK_PLANKS_SLAB_TOP = 41,
	RED_WOOL = 42,
	BLUE_WOOL = 43,
	LAPIS_ORE = 44,
	MOSSY_COBBLESTONE = 45,
	
	# Wild Flora
	DANDELION = 46,
	COBBLESTONE = 47,
	MOSSY_COBBLESTONE_SLAB_BOTTOM = 48,
	SOLID_SNOW = 49,
	SMOOTH_STONE = 50,
	
	# Flowers & Bricks
	POPPY = 51,
	SMOOTH_STONE_SLAB_BOTTOM = 52,
	STONE_BRICKS = 53,
	EMERALD_ORE = 54,
	MOSSY_STONE_BRICKS = 55,
	
	# Libraries & Pillars
	BOOKSHELF = 56,
	CHISELED_STONE_BRICKS = 57,
	STONE_BRICKS_SLAB_BOTTOM = 58,
	TERRACOTTA = 59,
	ICE_SLAB_BOTTOM = 60,
	
	# Orchid & Spruce
	BLUE_ORCHID = 61,
	ICE_SLAB_TOP = 62,
	SPRUCE_LOG = 63,
	SPRUCE_PLANKS = 64,
	SPRUCE_PLANKS_SLAB_BOTTOM = 65,
	
	# Spruce Planks Slab & Quartz
	SPRUCE_PLANKS_SLAB_TOP = 66,
	SPRUCE_LEAVES = 67,
	QUARTZ_ORE = 68,
	QUARTZ_BLOCK = 69,
	QUARTZ_SLAB_BOTTOM = 70,
	
	# Quartz Slab Top & Lapis Block
	QUARTZ_SLAB_TOP = 71,
	CHISELED_QUARTZ = 72,
	LAPIS_BLOCK = 73,
	MYCELIUM = 74,
	SMOOTH_STONE_SLAB_TOP = 75,
	
	# Netherrack & Glass Slab
	NETHERRACK = 76,
	NETHER_BRICKS = 77,
	CACTUS = 78,
	MAGMA = 79,
	GLASS_SLAB_BOTTOM = 80,
	
	# ==========================================================================
	# REGISTERED CUSTOM OCP BLOCKS & FLORA (Warnings Solved)
	# ==========================================================================
	BIRCH_PLANKS = 81,
	DEAD_BUSH = 82,
	CHERRY_LOG = 83,
	CYBER_PANEL = 84,
	TALL_GRASS = 85,
	DIAMOND_BLOCK = 88,
	AMETHYST_BLOCK = 89,
	ANCIENT_RUNES = 91,
	GLOWING_FUNGUS = 92,
	GRANITE_BLOCK = 93,
	METAL_GRATE = 94,
	MOSS_STONE = 95,
	REDWOOD_LOG = 96,
	ROOF_TILES = 97,
	WARNING_STRIPES = 98,
	WOODEN_PLANKS = 99,
	ALLIUM_FLOWER = 100,
	BLUEBELL_FLOWER = 101,
	CORNFLOWER = 102,
	DAISY_FLOWER = 103,
	FERN = 104,
	SUGAR_CANE = 105,
	TULIP_RED = 106,
	TULIP_ORANGE = 107,
	TULIP_PINK = 108,
	TULIP_WHITE = 109
}


## Returns true if the block type occupies physical space (is solid).
## Sourced dynamically from the data-driven BlockLibrary with absolute liquid safety checks.
static func is_solid(type: Type) -> bool:
	# Absolute Safety Guardrail: Air and liquids must NEVER possess physical collision
	if type == Type.AIR or type == Type.WATER or type == Type.LAVA:
		return false
		
	var def: BlockDefinition = BlockLibrary.get_definition(type) as BlockDefinition
	return def.is_solid if def != null else false


## Returns true if the block type is transparent or semi-transparent.
## Sourced dynamically from the data-driven BlockLibrary.
static func is_transparent(type: Type) -> bool:
	# Absolute Safety Guardrail: Air and liquids are always transparent
	if type == Type.AIR or type == Type.WATER or type == Type.LAVA:
		return true
		
	var def: BlockDefinition = BlockLibrary.get_definition(type) as BlockDefinition
	return def.is_transparent if def != null else false
