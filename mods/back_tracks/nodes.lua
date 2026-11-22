local MODNAME = core.get_current_modname()

-----------------------------------------
-- Terrain & Structure Nodes (CC0 default_* textures)
-----------------------------------------
core.register_node(MODNAME .. ":sand", {
	description = "Sand",
	tiles = {"default_sand.png"},
	groups = {crumbly = 3, sand = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":desert_sand", {
	description = "Desert Sand",
	tiles = {"default_desert_sand.png"},
	groups = {crumbly = 3, sand = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":silver_sand", {
	description = "Silver Sand",
	tiles = {"default_silver_sand.png"},
	groups = {crumbly = 3, sand = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":stone", {
	description = "Stone",
	tiles = {"default_stone.png"},
	groups = {cracky = 3, stone = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":desert_stone", {
	description = "Desert Stone",
	tiles = {"default_desert_stone.png"},
	groups = {cracky = 3, stone = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":sandstone", {
	description = "Sandstone",
	tiles = {"default_sandstone.png"},
	groups = {crumbly = 1, cracky = 3},
	paramtype = "light",
})

core.register_node(MODNAME .. ":sandstone_brick", {
	description = "Sandstone Brick",
	tiles = {"default_sandstone_brick.png"},
	groups = {cracky = 2},
	paramtype = "light",
})

core.register_node(MODNAME .. ":obsidian", {
	description = "Obsidian",
	tiles = {"default_obsidian.png"},
	groups = {cracky = 1},
	paramtype = "light",
})

core.register_node(MODNAME .. ":meselamp", {
	description = "Tunnel Lamp",
	tiles = {"default_meselamp.png"},
	paramtype = "light",
	light_source = 14,
	groups = {cracky = 3},
})

-----------------------------------------
-- Lava (glowing, non-walkable)
-----------------------------------------
core.register_node(MODNAME .. ":lava_source", {
	description = "Lava Source",
	drawtype = "liquid",
	tiles = {"default_lava.png"},
	paramtype = "light",
	light_source = 13,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	drowning = 0,
	liquidtype = "source",
	liquid_alternative_flowing = MODNAME .. ":lava_flowing",
	liquid_alternative_source = MODNAME .. ":lava_source",
	liquid_viscosity = 7,
	liquid_renewable = false,
	liquid_range = 2,
	post_effect_color = {a = 191, r = 255, g = 64, b = 0},
	groups = {lava = 3, liquid = 2},
})

core.register_node(MODNAME .. ":lava_flowing", {
	description = "Flowing Lava",
	drawtype = "flowingliquid",
	tiles = {"default_lava.png"},
	special_tiles = {
		{name = "default_lava.png", backface_culling = false},
		{name = "default_lava.png", backface_culling = true},
	},
	paramtype = "light",
	paramtype2 = "flowingliquid",
	light_source = 13,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	drowning = 0,
	liquidtype = "flowing",
	liquid_alternative_flowing = MODNAME .. ":lava_flowing",
	liquid_alternative_source = MODNAME .. ":lava_source",
	liquid_viscosity = 7,
	liquid_renewable = false,
	liquid_range = 2,
	post_effect_color = {a = 191, r = 255, g = 64, b = 0},
	groups = {lava = 3, liquid = 2, not_in_creative_inventory = 1},
})

-----------------------------------------
-- Desert Flora
-----------------------------------------
core.register_node(MODNAME .. ":cactus", {
	description = "Cactus",
	tiles = {"default_cactus_top.png", "default_cactus_top.png", "default_cactus_side.png"},
	groups = {choppy = 3},
	paramtype = "light",
})

local function register_plant(name, desc, tex)
	core.register_node(MODNAME .. ":" .. name, {
		description = desc,
		drawtype = "plantlike",
		waving = 1,
		tiles = {tex},
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		groups = {snappy = 3, flammable = 3},
	})
end

register_plant("dry_shrub", "Dry Shrub", "default_dry_shrub.png")
register_plant("dry_grass_1", "Dry Grass", "default_dry_grass_1.png")
register_plant("dry_grass_3", "Dry Grass", "default_dry_grass_3.png")
register_plant("dry_grass_5", "Dry Grass", "default_dry_grass_5.png")

-----------------------------------------
-- Invisible Dynamic Headlight Node
-----------------------------------------
core.register_node(MODNAME .. ":headlight_air", {
	description = "Headlight Air",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	light_source = 14,
	groups = {not_in_creative_inventory = 1},
})

-----------------------------------------
-- No Digging Hand (Turret & Shoot Only)
-----------------------------------------
core.register_item(":", {
	type = "none",
	wield_image = "blank.png",
	wield_scale = {x = 0.01, y = 0.01, z = 0.01},
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {},
		damage_groups = {},
	},
})

-----------------------------------------
-- Minimal Engine Aliases (avoids startup warnings)
-----------------------------------------
core.register_alias("mapgen_stone", MODNAME .. ":stone")
core.register_alias("mapgen_water_source", "air")
core.register_alias("mapgen_river_water_source", "air")