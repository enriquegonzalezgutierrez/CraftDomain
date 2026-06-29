# ==============================================================================
# Project: CraftDomain
# Description: Pure Infrastructure Registry responsible for programmatically
#              defining, registering, and seeding English and Spanish translation 
#              tables into Godot's TranslationServer at boot.
#              SOLID COMPLIANCE: Adheres strictly to OCP, closed to core code 
#              modification, allowing simple addition of future locales.
#              i18n ADDITION: Localized all 10 survival item descriptions, 
#              active campaign quests, objective logs, and notification toasts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/TranslationRegistry.gd
# ==============================================================================
class_name TranslationRegistry
extends RefCounted

## Registers English (en) and Spanish (es) translations programmatically on boot
static func initialize_translations() -> void:
	print("[TranslationRegistry] Initializing language tables programmatically...")
	
	_setup_english_locale()
	_setup_spanish_locale()

static func _setup_english_locale() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	
	# Blocks Names
	translation.add_message("BLOCK_AIR", "Air")
	translation.add_message("BLOCK_STONE", "Stone Block")
	translation.add_message("BLOCK_DIRT", "Dirt Block")
	translation.add_message("BLOCK_GRASS", "Grass Block")
	translation.add_message("BLOCK_WOOD", "Wood Log")
	translation.add_message("BLOCK_LEAVES", "Leaves")
	translation.add_message("BLOCK_WATER", "Water")
	translation.add_message("BLOCK_SAND", "Sand")
	translation.add_message("BLOCK_RED_SAND", "Red Sand")
	translation.add_message("BLOCK_SNOW", "Snow")
	translation.add_message("BLOCK_ICE", "Ice")
	translation.add_message("BLOCK_MUD", "Mud")
	translation.add_message("BLOCK_NEON_CYAN", "Neon Cyan")
	translation.add_message("BLOCK_NEON_MAGENTA", "Neon Magenta")
	translation.add_message("BLOCK_CLOUD", "Cloud")
	translation.add_message("BLOCK_LAVA", "Lava")
	translation.add_message("BLOCK_CROP_SEED", "Crop Seed")
	translation.add_message("BLOCK_CROP_GROWING", "Young Sprout")
	translation.add_message("BLOCK_CROP_RIPE", "Ripe Wheat")

	# Items & Inventory Names
	translation.add_message("ITEM_FRIED_CHICKEN", "Fried Chicken")
	translation.add_message("ITEM_WOODEN_SWORD", "Wooden Sword")
	translation.add_message("INVENTORY_EMPTY", "Empty")
	translation.add_message("INVENTORY_UNKNOWN", "Unknown Block")
	translation.add_message("INVENTORY_INFINITE", "Infinite Quantity")
	
	# UI Inspector Strings
	translation.add_message("INVENTORY_EMPTY_TITLE", "Backpack Inspector")
	translation.add_message("INVENTORY_EMPTY_DESC", "Click any backpack item to inspect its usage instructions and operational details.")
	translation.add_message("ITEM_USAGE_PREFIX", "USAGE")
	translation.add_message("ITEM_STOCKED_PREFIX", "STOCKED")
	
	# English Items Lore/Descriptions (SRP/OCP Compliant)
	translation.add_message("ITEM_1_DESC", "Smooth, heavy grey stone blocks mined from deep caves... useful for structured defensive walls.")
	translation.add_message("ITEM_1_USE", "Press Right-Click to build solid structures.")
	translation.add_message("ITEM_2_DESC", "Rich brown fertile soil. Can be placed or tilled... organic base of the Golden Bazaar plains.")
	translation.add_message("ITEM_2_USE", "Press Right-Click to place blocks.")
	translation.add_message("ITEM_3_DESC", "Vibrant, green grass turf. Perfect for establishing landscaping boundaries.")
	translation.add_message("ITEM_3_USE", "Press Right-Click to place blocks.")
	translation.add_message("ITEM_4_DESC", "Sturdy oak logs chopped from ancient forests... crucial material for dynamic workshop blueprints.")
	translation.add_message("ITEM_4_USE", "Used in the workshop to craft wooden planks and combat broadswords.")
	translation.add_message("ITEM_5_DESC", "Lush, green shrubbery leaves... harvested from trees. Can drop seeds on gathering.")
	translation.add_message("ITEM_5_USE", "Use in composting recipes or for building decorative garden canopies.")
	translation.add_message("ITEM_15_DESC", "A secure iron bucket containing glowing, dynamic orange lava fuel.")
	translation.add_message("ITEM_15_USE", "Hold and press Right-Click to place flowing lava. Can be traded with the Merchant.")
	translation.add_message("ITEM_16_DESC", "A fresh, crispy drumstick fried using dynamic lava fuel... highly therapeutic.")
	translation.add_message("ITEM_16_USE", "Eat from the backpack to fully restore 1 Heart.")
	translation.add_message("ITEM_17_DESC", "A sturdy, hand-crafted oak sword... infinite durability. Essential for plains defense.")
	translation.add_message("ITEM_17_USE", "Press Left-Click (or E) to swing and defeat hostile zombies.")
	translation.add_message("ITEM_18_DESC", "Plump wheat seeds. Can be planted on grass or dirt blocks to grow wheat fields.")
	translation.add_message("ITEM_18_USE", "Equip and Right-Click on top of grass/dirt blocks. Crops grow over time!")
	translation.add_message("ITEM_20_DESC", "Golden, sun-ripened wheat grains harvested from mature crops... essential baking material.")
	translation.add_message("ITEM_20_USE", "Gather enough grains to craft advanced survival rations.")

	# Biomes Names
	translation.add_message("BIOME_BAY_OF_SAILS", "Bay of Sails (Spawn Ocean)")
	translation.add_message("BIOME_WARP_PLATEAU", "Warp Plateau (Mario Steps)")
	translation.add_message("BIOME_GOLDEN_BAZAAR", "Golden Bazaar (Village Plains)")
	translation.add_message("BIOME_CRAGGY_MINES", "Craggy Peaks & Caves")
	translation.add_message("BIOME_FROSTBITE_GLACIERS", "Frostbite Glaciers (North Cap)")
	translation.add_message("BIOME_REDWOOD_FOREST", "Whispering Redwood Forest")
	translation.add_message("BIOME_RED_BADLANDS", "Red Sandstone Canyons")
	translation.add_message("BIOME_NEON_RUINS", "Neon Ruins (Cyber Basin)")
	translation.add_message("BIOME_SWAMP_OF_SIGHS", "Swamp of Sighs (Mist Bay)")
	translation.add_message("BIOME_CLOUD_KINGDOM", "Cloud Kingdom (Floating Isles)")

	# Core HUD UI
	translation.add_message("HUD_ACTIVE_MISSION", "➔ ACTIVE MISSION")
	translation.add_message("HUD_PAUSE_TITLE", "GAME PAUSED")
	translation.add_message("HUD_PAUSE_RESUME", "RESUME GAME")
	translation.add_message("HUD_PAUSE_SETTINGS", "SETTINGS")
	translation.add_message("HUD_PAUSE_QUIT", "QUIT TO MAIN MENU")
	translation.add_message("HUD_TOOLTIP_BACKPACK", "Open Backpack Inventory [I]")
	translation.add_message("HUD_TOOLTIP_WORKSHOP", "Open Crafting Workshop [C]")

	# Main Menu
	translation.add_message("MENU_PLAY_WORLD", "PLAY WORLD")
	translation.add_message("MENU_CONTINUE", "CONTINUE GAME")
	translation.add_message("MENU_NEW_GAME", "NEW GAME (RESET)")
	translation.add_message("MENU_SETTINGS", "SETTINGS")
	translation.add_message("MENU_EXIT", "EXIT GAME")
	translation.add_message("MENU_RESET_WARNING_TITLE", "⚠️ OVERWRITE PROGRESS?")
	translation.add_message("MENU_RESET_WARNING_DESC", "Warning: Starting a new game will permanently delete your saved castle, inventory blocks, and quest progression on disk. This cannot be undone.")
	translation.add_message("MENU_RESET_CONFIRM", "DELETE & OVERWRITE")
	translation.add_message("MENU_RESET_CANCEL", "CANCEL")

	# Settings Menu
	translation.add_message("SETTINGS_TITLE", "SETTINGS")
	translation.add_message("SETTINGS_MUSIC", "Music Volume")
	translation.add_message("SETTINGS_SFX", "Effects Volume")
	translation.add_message("SETTINGS_RESOLUTION", "Display Resolution")
	translation.add_message("SETTINGS_RESOLUTION_720", "Windowed (1280 x 720)")
	translation.add_message("SETTINGS_RESOLUTION_1080", "Windowed (1920 x 1080)")
	translation.add_message("SETTINGS_RESOLUTION_FULLSCREEN", "Fullscreen")
	translation.add_message("SETTINGS_APPLY", "APPLY")
	translation.add_message("SETTINGS_LANGUAGE", "Interface Language")
	translation.add_message("SETTINGS_BACK", "BACK")

	# Dynamic JSON Quests Titles Localizer (Map strings loaded from JSON)
	translation.add_message("The Lost Bazaar", "The Lost Bazaar")
	translation.add_message("Thatch Harvesting", "Thatch Harvesting")
	translation.add_message("Organic Composting", "Organic Composting")
	translation.add_message("Fuel the Fryer", "Fuel the Fryer")
	translation.add_message("Plains Defender", "Plains Defender")
	translation.add_message("Cloud Ascent", "Cloud Ascent")

	# Dynamic JSON Quests Objective Logs Localizer
	translation.add_message("Travel to the Golden Bazaar coordinates to meet the merchant. Look at your GPS and Minimap to find the path.", "Travel to the Golden Bazaar coordinates to meet the merchant. Look at your GPS and Minimap to find the path.")
	translation.add_message("Collect 10 leaf blocks to help repair the village roofs. Punch tree leaves to harvest them.", "Collect 10 leaf blocks to help repair the village roofs. Punch tree leaves to harvest them.")
	translation.add_message("Craft 3 soil blocks in your blueprint workshop (C Key) by combining leaves and dirt.", "Craft 3 soil blocks in your blueprint workshop (C Key) by combining leaves and dirt.")
	translation.add_message("Bring 1 Lava Bucket (Slot 6) to the Merchant. Select the Lava Bucket and Right-Click him.", "Bring 1 Lava Bucket (Slot 6) to the Merchant. Select the Lava Bucket and Right-Click him.")
	translation.add_message("Defeat the mountain zombie outside the castle gates. Select your wooden sword (Slot 8) and Left-Click him.", "Defeat the mountain zombie outside the castle gates. Select your wooden sword (Slot 8) and Left-Click him.")
	translation.add_message("Ascend high into the sky! Build upwards up to height Y=18 using your blocks.", "Ascend high into the sky! Build upwards up to height Y=18 using your blocks.")

	# HUD Quest Tracker Helpers
	translation.add_message("QUEST_CURRENT_HEIGHT", "Current Height")
	translation.add_message("QUEST_PROGRESS", "Progress")
	translation.add_message("QUEST_REACHED_INTERACT", "REACHED: Right-Click Target!")
	translation.add_message("QUEST_DISTANCE_PREFIX", "Distance")
	translation.add_message("CAMPAIGN_COMPLETE_TOAST_HEADER", "Campaign Complete")
	translation.add_message("QUEST_COMPLETED_TOAST_HEADER", "Quest Completed")

	TranslationServer.add_translation(translation)

static func _setup_spanish_locale() -> void:
	var translation := Translation.new()
	translation.locale = "es"
	
	# Bloques
	translation.add_message("BLOCK_AIR", "Aire")
	translation.add_message("BLOCK_STONE", "Bloque de Piedra")
	translation.add_message("BLOCK_DIRT", "Bloque de Tierra")
	translation.add_message("BLOCK_GRASS", "Bloque de Césped")
	translation.add_message("BLOCK_WOOD", "Tronco de Madera")
	translation.add_message("BLOCK_LEAVES", "Hojas")
	translation.add_message("BLOCK_WATER", "Agua")
	translation.add_message("BLOCK_SAND", "Arena")
	translation.add_message("BLOCK_RED_SAND", "Arena Roja")
	translation.add_message("BLOCK_SNOW", "Nieve")
	translation.add_message("BLOCK_ICE", "Hielo")
	translation.add_message("BLOCK_MUD", "Lodo")
	translation.add_message("BLOCK_NEON_CYAN", "Neón Cian")
	translation.add_message("BLOCK_NEON_MAGENTA", "Neón Magenta")
	translation.add_message("BLOCK_CLOUD", "Nube")
	translation.add_message("BLOCK_LAVA", "Lava")
	translation.add_message("BLOCK_CROP_SEED", "Semilla de Cultivo")
	translation.add_message("BLOCK_CROP_GROWING", "Brote Joven")
	translation.add_message("BLOCK_CROP_RIPE", "Trigo Maduro")

	# Items e Inventario
	translation.add_message("ITEM_FRIED_CHICKEN", "Pollo Frito")
	translation.add_message("ITEM_WOODEN_SWORD", "Espada de Madera")
	translation.add_message("INVENTORY_EMPTY", "Vacío")
	translation.add_message("INVENTORY_UNKNOWN", "Bloque Desconocido")
	translation.add_message("INVENTORY_INFINITE", "Cantidad Infinita")
	
	# UI Inspector Strings (Spanish)
	translation.add_message("INVENTORY_EMPTY_TITLE", "Inspector de Mochila")
	translation.add_message("INVENTORY_EMPTY_DESC", "Haz clic en cualquier objeto de la mochila para inspeccionar sus instrucciones de uso.")
	translation.add_message("ITEM_USAGE_PREFIX", "USO")
	translation.add_message("ITEM_STOCKED_PREFIX", "CANTIDAD")
	
	# Spanish Items Lore/Descriptions (SRP/OCP Compliant)
	translation.add_message("ITEM_1_DESC", "Bloques de piedra gris lisa y pesada extraídos de cuevas profundas... útiles para murallas defensivas.")
	translation.add_message("ITEM_1_USE", "Presiona Clic-Derecho para construir estructuras sólidas.")
	translation.add_message("ITEM_2_DESC", "Tierra fértil marrón. Puede colocarse o labrarse... base orgánica de las praderas del Bazar Dorado.")
	translation.add_message("ITEM_2_USE", "Presiona Clic-Derecho para colocar bloques.")
	translation.add_message("ITEM_3_DESC", "Césped verde y vibrante. Perfecto para establecer jardines o delimitar zonas.")
	translation.add_message("ITEM_3_USE", "Presiona Clic-Derecho para colocar bloques.")
	translation.add_message("ITEM_4_DESC", "Madera de roble maciza talada de bosques antiguos... material crucial para las recetas del taller.")
	translation.add_message("ITEM_4_USE", "Úsala en el taller de crafteo para fabricar tablones de madera o espadas.")
	translation.add_message("ITEM_5_DESC", "Frondoso follaje de hojas verdes... recolectado de los árboles. Puede soltar semillas al romperlas.")
	translation.add_message("ITEM_5_USE", "Utilízalas en recetas de compostaje o para construir tejados decorativos.")
	translation.add_message("ITEM_15_DESC", "Un cubo de hierro seguro que contiene lava geotérmica ardiente.")
	translation.add_message("ITEM_15_USE", "Equípala y presiona Clic-Derecho para colocar lava, o dásela al Mercader para comerciar.")
	translation.add_message("ITEM_16_DESC", "Un muslo de pollo crujiente frito sobre lava geotérmica... muy terapéutico.")
	translation.add_message("ITEM_16_USE", "Consúmelo directamente desde la mochila para restaurar 1 Corazón.")
	translation.add_message("ITEM_17_DESC", "Una espada de roble robusta hecha a mano... durabilidad infinita. Esencial para la defensa.")
	translation.add_message("ITEM_17_USE", "Presiona Clic-Izquierdo (o E) para golpear y derrotar a los zombis.")
	translation.add_message("ITEM_18_DESC", "Semillas de trigo. Pueden plantarse sobre bloques de césped o tierra para cosechar campos de trigo.")
	translation.add_message("ITEM_18_USE", "Equípalas y haz Clic-Derecho sobre la tierra. ¡Crecen con el tiempo!")
	translation.add_message("ITEM_20_DESC", "Granos de trigo dorados cosechados de tus cultivos maduros... ingrediente esencial de supervivencia.")
	translation.add_message("ITEM_20_USE", "Reúne suficientes granos para fabricar raciones de comida avanzadas.")

	# Biomas
	translation.add_message("BIOME_BAY_OF_SAILS", "Bahía de Velas (Océano Spawn)")
	translation.add_message("BIOME_WARP_PLATEAU", "Meseta Warp (Escaleras Mario)")
	translation.add_message("BIOME_GOLDEN_BAZAAR", "Bazar Dorado (Praderas Aldea)")
	translation.add_message("BIOME_CRAGGY_MINES", "Picos Escarpados y Cuevas")
	translation.add_message("BIOME_FROSTBITE_GLACIERS", "Glaciares Frostbite (Polo Norte)")
	translation.add_message("BIOME_REDWOOD_FOREST", "Bosque de Secuoyas Susurrantes")
	translation.add_message("BIOME_RED_BADLANDS", "Cañones de Arenisca Roja")
	translation.add_message("BIOME_NEON_RUINS", "Ruinas de Neón (Cuenca Cyber)")
	translation.add_message("BIOME_SWAMP_OF_SIGHS", "Pantano de los Suspiros")
	translation.add_message("BIOME_CLOUD_KINGDOM", "Reino de las Nubes (Islas Flotantes)")

	# Interfaz HUD Core
	translation.add_message("HUD_ACTIVE_MISSION", "➔ MISIÓN ACTIVA")
	translation.add_message("HUD_PAUSE_TITLE", "JUEGO PAUSADO")
	translation.add_message("HUD_PAUSE_RESUME", "REANUDAR JUEGO")
	translation.add_message("HUD_PAUSE_SETTINGS", "AJUSTES")
	translation.add_message("HUD_PAUSE_QUIT", "SALIR AL MENÚ PRINCIPAL")
	translation.add_message("HUD_TOOLTIP_BACKPACK", "Abrir Mochila [I]")
	translation.add_message("HUD_TOOLTIP_WORKSHOP", "Abrir Taller de Crafteo [C]")

	# Menú Principal
	translation.add_message("MENU_PLAY_WORLD", "JUGAR MUNDO")
	translation.add_message("MENU_CONTINUE", "CONTINUAR PARTIDA")
	translation.add_message("MENU_NEW_GAME", "NUEVA PARTIDA (RESET)")
	translation.add_message("MENU_SETTINGS", "AJUSTES")
	translation.add_message("MENU_EXIT", "SALIR DEL JUEGO")
	translation.add_message("MENU_RESET_WARNING_TITLE", "⚠️ ¿SOBREESCRIBIR PROGRESO?")
	translation.add_message("MENU_RESET_WARNING_DESC", "Advertencia: Comenzar una nueva partida eliminará permanentemente tu castillo, inventario y progreso guardado en el disco. Esto no se puede deshacer.")
	translation.add_message("MENU_RESET_CONFIRM", "BORRAR Y SOBREESCRIBIR")
	translation.add_message("MENU_RESET_CANCEL", "CANCELAR")

	# Menú Ajustes
	translation.add_message("SETTINGS_TITLE", "AJUSTES")
	translation.add_message("SETTINGS_MUSIC", "Volumen de Música")
	translation.add_message("SETTINGS_SFX", "Volumen de Efectos")
	translation.add_message("SETTINGS_RESOLUTION", "Resolución de Pantalla")
	translation.add_message("SETTINGS_RESOLUTION_720", "Ventana (1280 x 720)")
	translation.add_message("SETTINGS_RESOLUTION_1080", "Ventana (1920 x 1080)")
	translation.add_message("SETTINGS_RESOLUTION_FULLSCREEN", "Pantalla Completa")
	translation.add_message("SETTINGS_APPLY", "APLICAR")
	translation.add_message("SETTINGS_LANGUAGE", "Idioma de la Interfaz")
	translation.add_message("SETTINGS_BACK", "VOLVER")

	# Dynamic JSON Quests Titles Localizer (Spanish)
	translation.add_message("The Lost Bazaar", "El Bazar Perdido")
	translation.add_message("Thatch Harvesting", "Cosecha de Paja")
	translation.add_message("Organic Composting", "Compostaje Orgánico")
	translation.add_message("Fuel the Fryer", "Alimenta la Freidora")
	translation.add_message("Plains Defender", "Defensor de las Praderas")
	translation.add_message("Cloud Ascent", "Ascenso a las Nubes")

	# Dynamic JSON Quests Objective Logs Localizer (Spanish)
	translation.add_message("Travel to the Golden Bazaar coordinates to meet the merchant. Look at your GPS and Minimap to find the path.", "Viaja a las coordenadas del Bazar Dorado para encontrarte con el mercader. Mira tu GPS y Minimapa para hallar el camino.")
	translation.add_message("Collect 10 leaf blocks to help repair the village roofs. Punch tree leaves to harvest them.", "Reúne 10 bloques de hojas para ayudar a reparar los techos de la aldea. Golpea las hojas de los árboles para cosecharlas.")
	translation.add_message("Craft 3 soil blocks in your blueprint workshop (C Key) by combining leaves and dirt.", "Fabrica 3 bloques de tierra en tu taller (Tecla C) combinando hojas y tierra.")
	translation.add_message("Bring 1 Lava Bucket (Slot 6) to the Merchant. Select the Lava Bucket and Right-Click him.", "Lleva 1 Cubo de Lava (Ranura 6) al Mercader. Selecciona el Cubo de Lava y haz Clic-Derecho sobre él.")
	translation.add_message("Defeat the mountain zombie outside the castle gates. Select your wooden sword (Slot 8) and Left-Click him.", "Derrota al zombi de la montaña fuera de las puertas del castillo. Selecciona tu espada de madera (Ranura 8) y haz Clic-Izquierdo.")
	translation.add_message("Ascend high into the sky! Build upwards up to height Y=18 using your blocks.", "¡Asciende alto en el cielo! Construye hacia arriba hasta la altura Y=18 usando tus bloques.")

	# HUD Quest Tracker Helpers (Spanish)
	translation.add_message("QUEST_CURRENT_HEIGHT", "Altura Actual")
	translation.add_message("QUEST_PROGRESS", "Progreso")
	translation.add_message("QUEST_REACHED_INTERACT", "ALCANZADO: ¡Clic-Derecho al Objetivo!")
	translation.add_message("QUEST_DISTANCE_PREFIX", "Distancia")
	translation.add_message("CAMPAIGN_COMPLETE_TOAST_HEADER", "Campaña Completada")
	translation.add_message("QUEST_COMPLETED_TOAST_HEADER", "Misión Completada")

	TranslationServer.add_translation(translation)
