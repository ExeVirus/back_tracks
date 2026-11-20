local MODNAME = core.get_current_modname()

-----------------------------------------
-- Register Base Nodes (5 textures)
-----------------------------------------
core.register_node(MODNAME .. ":sand", {
	description = "Sand",
	tiles = {"sand.png"},
	groups = {crumbly = 3, sand = 1, oddly_breakable_by_hand = 2},
    paramtype = "light",
})

core.register_node(MODNAME .. ":desert_sand", {
	description = "Desert Sand",
	tiles = {"desert_sand.png"},
	groups = {crumbly = 3, sand = 1, oddly_breakable_by_hand = 2},
    paramtype = "light",
})

core.register_node(MODNAME .. ":silver_sand", {
	description = "Silver Sand",
	tiles = {"silver_sand.png"},
	groups = {crumbly = 3, sand = 1, oddly_breakable_by_hand = 2},
    paramtype = "light",
})

core.register_node(MODNAME .. ":stone", {
	description = "Stone",
	tiles = {"stone.png"},
	groups = {cracky = 3, stone = 1, oddly_breakable_by_hand = 1},
    paramtype = "light",
})

core.register_node(MODNAME .. ":desert_stone", {
	description = "Desert Stone",
	tiles = {"desert_stone.png"},
	groups = {cracky = 3, stone = 1, oddly_breakable_by_hand = 1},
    paramtype = "light",
})

-----------------------------------------
-- Hand Capabilities (dig & place support)
-----------------------------------------
core.register_item(":", {
	type = "none",
	wield_image = "[fill:16x16:#E0AC69",
	wield_scale = {x = 1, y = 1, z = 2.5},
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {times = {[1] = 1.50, [2] = 0.80, [3] = 0.35}, uses = 0, maxlevel = 1},
			cracky = {times = {[1] = 2.40, [2] = 1.40, [3] = 0.85}, uses = 0, maxlevel = 1},
			oddly_breakable_by_hand = {times = {[1] = 1.20, [2] = 0.60, [3] = 0.30}, uses = 0},
			dig_immediate = {times = {[2] = 0.40, [3] = 0.00}, uses = 0},
		},
		damage_groups = {fleshy = 1},
	},
})

-----------------------------------------
-- Mapgen Aliases & Biomes
-----------------------------------------
local mg_name = core.get_mapgen_setting("mg_name")

if mg_name == "flat" then
	-- Flat mapgen: pure sand.png nodes everywhere
	core.register_alias("mapgen_stone", MODNAME .. ":sand")
	core.register_alias("mapgen_water_source", MODNAME .. ":sand")
	core.register_alias("mapgen_river_water_source", MODNAME .. ":sand")
	core.register_alias("mapgen_lava_source", MODNAME .. ":sand")
	core.register_alias("mapgen_cobble", MODNAME .. ":sand")

	core.register_biome({
		name = MODNAME .. ":flat_sand",
		node_top = MODNAME .. ":sand",
		depth_top = 1,
		node_filler = MODNAME .. ":sand",
		depth_filler = 1,
		node_stone = MODNAME .. ":sand",
		node_water_top = MODNAME .. ":sand",
		depth_water_top = 1,
		node_water = MODNAME .. ":sand",
		node_river_water = MODNAME .. ":sand",
		node_riverbed = MODNAME .. ":sand",
		depth_riverbed = 1,
		y_min = -31000,
		y_max = 31000,
		heat_point = 50,
		humidity_point = 50,
	})
else
	-- Standard mapgens (v5, v6, v7, carpathian, valleys, fractal)
	core.register_alias("mapgen_stone", MODNAME .. ":stone")
	core.register_alias("mapgen_water_source", "air")
	core.register_alias("mapgen_river_water_source", "air")
	core.register_alias("mapgen_lava_source", "air")
	core.register_alias("mapgen_cobble", MODNAME .. ":stone")

	-- Additional aliases used by Mapgen v6
	core.register_alias("mapgen_sand", MODNAME .. ":sand")
	core.register_alias("mapgen_dirt", MODNAME .. ":sand")
	core.register_alias("mapgen_dirt_with_grass", MODNAME .. ":sand")
	core.register_alias("mapgen_desert_stone", MODNAME .. ":desert_stone")
	core.register_alias("mapgen_desert_sand", MODNAME .. ":desert_sand")
	core.register_alias("mapgen_gravel", MODNAME .. ":silver_sand")
	core.register_alias("mapgen_dirt_with_snow", MODNAME .. ":silver_sand")
	core.register_alias("mapgen_snowblock", MODNAME .. ":silver_sand")
	core.register_alias("mapgen_tree", "air")
	core.register_alias("mapgen_leaves", "air")
	core.register_alias("mapgen_apple", "air")

	core.register_biome({
		name = MODNAME .. ":sand_dunes",
		node_top = MODNAME .. ":sand",
		depth_top = 2,
		node_filler = MODNAME .. ":sand",
		depth_filler = 4,
		node_stone = MODNAME .. ":stone",
		node_water_top = "air",
		depth_water_top = 1,
		node_water = "air",
		node_river_water = "air",
		node_riverbed = MODNAME .. ":sand",
		depth_riverbed = 2,
		y_min = -31000,
		y_max = 31000,
		heat_point = 50,
		humidity_point = 50,
	})

	core.register_biome({
		name = MODNAME .. ":desert_wasteland",
		node_top = MODNAME .. ":desert_sand",
		depth_top = 2,
		node_filler = MODNAME .. ":desert_sand",
		depth_filler = 4,
		node_stone = MODNAME .. ":desert_stone",
		node_water_top = "air",
		depth_water_top = 1,
		node_water = "air",
		node_river_water = "air",
		node_riverbed = MODNAME .. ":desert_sand",
		depth_riverbed = 2,
		y_min = -31000,
		y_max = 31000,
		heat_point = 85,
		humidity_point = 15,
	})

	core.register_biome({
		name = MODNAME .. ":silver_flats",
		node_top = MODNAME .. ":silver_sand",
		depth_top = 2,
		node_filler = MODNAME .. ":silver_sand",
		depth_filler = 3,
		node_stone = MODNAME .. ":stone",
		node_water_top = "air",
		depth_water_top = 1,
		node_water = "air",
		node_river_water = "air",
		node_riverbed = MODNAME .. ":silver_sand",
		depth_riverbed = 2,
		y_min = -31000,
		y_max = 31000,
		heat_point = 20,
		humidity_point = 80,
	})
end