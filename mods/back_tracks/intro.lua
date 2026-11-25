local MODNAME = core.get_current_modname()

local clamp = back_tracks.clamp

-----------------------------------------
-- State & Tuning
-----------------------------------------
local intro_players = {}
back_tracks.intro_view_positions = back_tracks.intro_view_positions or {}

local TEXT_COLOR_R = 0xD9
local TEXT_COLOR_G = 0xB3
local TEXT_COLOR_B = 0x82
local TEXT_COLOR_HEX = 0xD9B382
local BOX_MAX_OPACITY = 200
local CHARS_PER_SEC = 26.0
local WRAP_WIDTH = 56

local START_POS = {x = 26, y = 12.0, z = 0}
local START_YAW = math.pi / 2
local TRUCK_MODEL_Y_OFFSET = -1.25

-- Loaded on demand as each scene begins (never blocks playback)
local EMERGE_BOXES = {
	{min = {x = -1470, y = -5,  z = -85},  max = {x = -1350, y = 55,  z = 65}},  -- 1. Desert behind mountain
	{min = {x = -155,  y = 0,   z = -95},  max = {x = 65,    y = 75,  z = 60}},  -- 2. Start pad & canyon
	{min = {x = -615,  y = 0,   z = -95},  max = {x = -320,  y = 75,  z = 55}},  -- 3. Ramps
	{min = {x = -945,  y = -15, z = -95},  max = {x = -655,  y = 85,  z = 75}},  -- 4. Causeways & lava
	{min = {x = -1255, y = 0,   z = -100}, max = {x = -900,  y = 255, z = 110}}, -- 5. Mountain, tunnel, mesa
	{min = {x = -5,    y = 0,   z = -35},  max = {x = 55,    y = 35,  z = 35}},  -- 6. Start pad & truck showcase
}

local SCENES = {
	-- 1. Desert behind the mountain
	{
		duration = 9,
		cut = true,
		fade_in = 0.5,
		fade_out = 0.5,
		pos_a  = {x = -1380, y = 34, z = -35},
		pos_b  = {x = -1415, y = 36, z = 25},
		look_a = {x = -1450, y = 8,  z = -20},
		look_b = {x = -1485, y = 8,  z = 25},
		text = "I'm a bounty hunter, here on this god-forsaken desert to capture a Great Mesa Beast. "
			.. "But it won't be easy - it's protected by devout fanatics... the Mesen.",
	},
	-- 2. Start square -> smooth move right into canyon & turrets
	{
		duration = 9,
		cut = true,
		fade_in = 0.5,
		fade_out = 0.5,
		pos_a  = {x = 54,  y = 48, z = 16},
		pos_b  = {x = -85, y = 58, z = -48},
		look_a = {x = 14,  y = 11, z = 0},
		look_b = {x = -135, y = 22, z = 0},
		text = "I'll start from a nearby canyon, where defenses in the canyon are weak. "
			.. "...Just a few scattered turrets watching the ridges.",
	},
	-- 3. Ramps (side-scroll)
	{
		duration = 8,
		cut = true,
		fade_in = 0.5,
		fade_out = 0.5,
		pos_a  = {x = -350, y = 66, z = -48},
		pos_b  = {x = -565, y = 66, z = -48},
		look_a = {x = -375, y = 16, z = 4},
		look_b = {x = -585, y = 16, z = 4},
		text = "Beyond the canyon lies foothills, be careful with the hidden traps.",
	},
	-- 4. Causeways (side-scroll)
	{
		duration = 8,
		cut = true,
		fade_in = 0.5,
		fade_out = 0.5,
		pos_a  = {x = -680, y = 74, z = -62},
		pos_b  = {x = -900, y = 74, z = -62},
		look_a = {x = -700, y = 14, z = 6},
		look_b = {x = -920, y = 14, z = 6},
		text = "Then come the lava causeways. Find the right path, keep your speed and wits.",
	},
	-- 5. Mountain base -> pan up past tunnel -> mesa & arena at top
	{
		duration = 12,
		cut = true,
		fade_in = 0.5,
		fade_out = 0.5,
		pos_a  = {x = -925, y = 20,  z = 65},
		pos_b  = {x = -995, y = 242, z = 42},
		look_a = {x = -1110, y = 58,  z = 12},
		look_b = {x = -1145, y = 180, z = 0},
		text = "And the grand mesa...       Towering hundreds of feet high, pierced by "
			.. "tunnels and a spiraling road all the way up to the Beast's Lair at the top.",
	},
	-- 6. 45-degree look down at waiting truck -> slide into starting gameplay camera offset
	{
		duration = 2.6,
		cut = true,
		fade_in = 0.5,
		show_truck = true,
		pos_a  = {x = 42.0, y = 28.0,  z = 0},
		pos_b  = {x = 28.3, y = 13.2, z = 0},
		look_a = {x = 26.0, y = 12.0,  z = 0},
		look_b = {x = 10.0, y = 13.2, z = 0},
		text = "",
	},
    {
		duration = 20,
		cut = false,
		show_truck = true,
		pos_a  = {x = 28.3, y = 13.2, z = 0},
		pos_b  = {x = 28.3, y = 13.2, z = 0},
		look_a = {x = 10.0, y = 13.2, z = 0},
		look_b = {x = 10.0, y = 13.2, z = 0},
		text = "[WASD] to Drive. [Left Click] to Shoot. Space Bar [Jump] for Boost. E [AUX] to toggle View. Press Space Bar [Jump] to Begin.",
	},
}

-----------------------------------------
-- Helpers
-----------------------------------------
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp_vec(a, b, t)
	return {
		x = lerp(a.x, b.x, t),
		y = lerp(a.y, b.y, t),
		z = lerp(a.z, b.z, t),
	}
end

local function smoothstep(t)
	local c = clamp(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
end

-- Word-wrap upfront so typewriter reveal never jumps words between lines
local function wrap_text(str, max_len)
	local lines = {}
	local cur = ""
	for word in str:gmatch("%S+") do
		if cur == "" then
			cur = word
		elseif #cur + 1 + #word <= max_len then
			cur = cur .. " " .. word
		else
			lines[#lines + 1] = cur
			cur = word
		end
	end
	if cur ~= "" then
		lines[#lines + 1] = cur
	end
	return table.concat(lines, "\n")
end

for i = 1, #SCENES do
	SCENES[i].wrapped_text = wrap_text(SCENES[i].text, WRAP_WIDTH)
end

local function quantize_opacity(alpha01, max_op)
	max_op = max_op or 255
	local c = clamp(alpha01, 0.0, 1.0)
	if c >= 0.98 then return max_op end
	if c <= 0.02 then return 0 end
	local q = math.floor((c * max_op) / 10.0 + 0.5) * 10
	return math.min(max_op, math.max(0, q))
end

local function set_camera_look(player, cam_pos, look_target)
	local dx = look_target.x - cam_pos.x
	local dy = look_target.y - cam_pos.y
	local dz = look_target.z - cam_pos.z
	local horiz = math.sqrt(dx * dx + dz * dz)
	local yaw = math.atan2(-dx, dz)
	local pitch = -math.atan2(dy, math.max(horiz, 0.001))
	player:set_look_horizontal(yaw)
	player:set_look_vertical(pitch)
end

local function emerge_for_idx(idx)
	local box = EMERGE_BOXES[idx]
	if box then
		core.emerge_area(box.min, box.max)
	end
end

-----------------------------------------
-- Invisible Intro Camera & Preview Truck Entities
-----------------------------------------
core.register_entity(MODNAME .. ":intro_cam", {
	initial_properties = {
		visual = "cube",
		textures = {
			"[fill:1x1:#00000000", "[fill:1x1:#00000000", "[fill:1x1:#00000000",
			"[fill:1x1:#00000000", "[fill:1x1:#00000000", "[fill:1x1:#00000000",
		},
		use_texture_alpha = true,
		visual_size = {x = 0.001, y = 0.001, z = 0.001},
		is_visible = false,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_step = function(self)
		if not self.owner_name or not intro_players[self.owner_name] then
			self.object:remove()
		end
	end,
})

core.register_entity(MODNAME .. ":intro_truck", {
	initial_properties = {
		visual = "mesh",
		mesh = "monster_truck.gltf",
		textures = { "monster_truck.png" },
		visual_size = {x = 1, y = 1, z = 1},
		backface_culling = false,
		is_visible = true,
		glow = 2,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_step = function(self)
		if not self.owner_name or not intro_players[self.owner_name] then
			self.object:remove()
		end
	end,
})

-----------------------------------------
-- Safe Camera & Preview Truck Sync
-----------------------------------------
local function detach_cam_ent(player, st)
	if player and player:is_player() then
		player:set_detach()
		player:set_camera({mode = "first"})
		player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	end
	if st.cam_ent and st.cam_ent:is_valid() then
		st.cam_ent:remove()
	end
	st.cam_ent = nil
end

local function ensure_preview_truck(name, st)
	if st.preview_truck and st.preview_truck:is_valid() then
		return
	end
	st.preview_truck = nil

	local vis_pos = vector.new(START_POS.x, START_POS.y + TRUCK_MODEL_Y_OFFSET, START_POS.z)
	if core.get_node_or_nil(vis_pos) == nil then
		return
	end

	local truck = core.add_entity(vis_pos, MODNAME .. ":intro_truck")
	if truck then
		local fwd = vector.new(-math.sin(START_YAW), 0, math.cos(START_YAW))
		local up = vector.new(0, 1, 0)
		truck:set_rotation(vector.dir_to_rotation(fwd, up))
		truck:get_luaentity().owner_name = name
		if truck.play_animation then
			truck:play_animation("idle", {speed = 1.0, loop = true, blend = 0.20})
		else
			truck:set_animation({x = 0.0, y = 1.2}, 1.0, 0.2, true)
		end
		st.preview_truck = truck
	end
end

local function sync_camera(name, player, st, cam_pos, look_pt, dt, force_cut)
	if force_cut then
		detach_cam_ent(player, st)
		st.cam_retry_timer = 0.25
		player:set_pos(cam_pos)
	elseif st.cam_ent and st.cam_ent:is_valid() then
		st.cam_ent:set_pos(cam_pos)
	else
		st.cam_ent = nil
		player:set_pos(cam_pos)

		st.cam_retry_timer = st.cam_retry_timer - dt
		if st.cam_retry_timer <= 0.0 then
			st.cam_retry_timer = 0.25
			if core.get_node_or_nil(cam_pos) ~= nil then
				local cam_ent = core.add_entity(cam_pos, MODNAME .. ":intro_cam")
				if cam_ent then
					cam_ent:get_luaentity().owner_name = name
					st.cam_ent = cam_ent
					player:set_attach(cam_ent, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, false)
					player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
					player:set_camera({mode = "first"})
				end
			end
		end
	end

	back_tracks.intro_view_positions[name] = cam_pos
	set_camera_look(player, cam_pos, look_pt)
end

-----------------------------------------
-- Cleanup & Transition to Mission
-----------------------------------------
local function cleanup_intro(name, player, restore_player)
	local st = intro_players[name]
	if not st then return end
	intro_players[name] = nil
	back_tracks.intro_view_positions[name] = nil

	if st.preview_truck and st.preview_truck:is_valid() then
		st.preview_truck:remove()
	end
	st.preview_truck = nil

	if st.cam_ent and st.cam_ent:is_valid() then
		st.cam_ent:remove()
	end
	st.cam_ent = nil

	if player and player:is_player() then
		for i = 1, #st.hud_ids do
			player:hud_remove(st.hud_ids[i])
		end

		if restore_player then
			player:set_detach()
			player:set_camera({mode = "any"})
			player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
			player:set_physics_override({speed = 1, jump = 1, gravity = 1})
			player:set_properties({
				visual_size = st.saved_visual_size or {x = 1, y = 1, z = 1},
				eye_height = st.saved_eye_height or 1.625,
			})
			player:set_pos(START_POS)
			player:set_look_horizontal(START_YAW)
			player:set_look_vertical(0)
		end
	end
end

local function finish_intro_and_start_mission(name, player, st, seamless)
	if st.finishing then return end
	st.finishing = true

	if seamless then
		-- Already at START_POS camera offset spot: seamlessly swap to the live Monster Truck
		cleanup_intro(name, player, true)
		if player and player:is_player() and back_tracks.enter_truck_mode then
			back_tracks.enter_truck_mode(player)
		end
		return
	end

	-- Early skip: keep black curtain up briefly while relocating to START_POS
	player:hud_change(st.box_hud, "text", "[fill:16x16:#140D08^[opacity:0")
	player:hud_change(st.text_hud, "text", "")
	player:hud_change(st.skip_hud, "text", "")
	player:hud_change(st.fade_hud, "text", "[fill:16x16:#000000^[opacity:255")

	detach_cam_ent(player, st)
	player:set_pos(START_POS)
	player:set_look_horizontal(START_YAW)
	player:set_look_vertical(0)
	emerge_for_idx(#EMERGE_BOXES)

	core.after(0.15, function()
		local p = core.get_player_by_name(name)
		cleanup_intro(name, p, p ~= nil)
		if p and p:is_player() and back_tracks.enter_truck_mode then
			back_tracks.enter_truck_mode(p)
		end
	end)
end

-----------------------------------------
-- Public Entry Point
-----------------------------------------
function back_tracks.start_intro(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()
	if intro_players[name] or back_tracks.active_drivers[name] then return end

	-- Only queue the first area on start (no waiting for completion)
	emerge_for_idx(1)

	local old_props = player:get_properties()
	player:set_properties({
		visual_size = {x = 0, y = 0, z = 0},
		eye_height = 0,
	})
	player:set_physics_override({speed = 0, jump = 0, gravity = 0})
	player:hud_set_flags({
		hotbar = false,
		wielditem = false,
		healthbar = false,
		breathbar = false,
		minimap = false,
		crosshair = false,
	})

	local s1 = SCENES[1]
	player:set_pos(s1.pos_a)
	player:set_camera({mode = "first"})
	player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	set_camera_look(player, s1.pos_a, s1.look_a)

	-- Fullscreen fade-to-black curtain
	local fade_hud = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.5},
		offset = {x = 0, y = 0},
		text = "[fill:16x16:#000000^[opacity:255",
		scale = {x = -100, y = -100},
		alignment = {x = 0, y = 0},
		z_index = 900,
	})

	-- Dark translucent narrative panel
	local box_hud = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.84},
		offset = {x = 0, y = 0},
		text = "[fill:16x16:#140D08^[opacity:0",
		scale = {x = -62, y = -16},
		alignment = {x = 0, y = 0},
		z_index = 950,
	})

	-- Light brown scrolling text
	local text_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.84},
		offset = {x = 0, y = 0},
		text = "",
		alignment = {x = 0, y = 0},
		number = TEXT_COLOR_HEX,
		size = {x = 1.45, y = 1.45},
		z_index = 951,
	})

	-- Subtle skip prompt
	local skip_hud = player:hud_add({
		type = "text",
		position = {x = 0.96, y = 0.95},
		offset = {x = 0, y = 0},
		text = "[SPACE] Skip",
		alignment = {x = -1, y = 0},
		number = 0x997B5E,
		size = {x = 1.0, y = 1.0},
		z_index = 952,
	})

	back_tracks.intro_view_positions[name] = vector.copy(s1.pos_a)

	intro_players[name] = {
		cam_ent = nil,
		preview_truck = nil,
		cam_retry_timer = 0.25,
		saved_visual_size = old_props.visual_size,
		saved_eye_height = old_props.eye_height,
		hud_ids = {fade_hud, box_hud, text_hud, skip_hud},
		fade_hud = fade_hud,
		box_hud = box_hud,
		text_hud = text_hud,
		skip_hud = skip_hud,

		finishing = false,
		queued_emerge = 1,
		total_time = 0.0,
		scene_idx = 1,
		scene_time = 0.0,
		skipping = false,
		skip_hidden = false,
		skip_timer = 0.0,

		last_fade_op = 255,
		last_box_op = 0,
		last_text = "",
		last_text_col = TEXT_COLOR_HEX,
	}
end

-----------------------------------------
-- HUD Update Helpers
-----------------------------------------
local function set_fade_opacity(player, st, alpha01)
	local q = quantize_opacity(alpha01, 255)
	if q ~= st.last_fade_op then
		player:hud_change(st.fade_hud, "text", "[fill:16x16:#000000^[opacity:" .. q)
		st.last_fade_op = q
	end
end

local function set_box_opacity(player, st, alpha01)
	local q = quantize_opacity(alpha01, BOX_MAX_OPACITY)
	if q ~= st.last_box_op then
		player:hud_change(st.box_hud, "text", "[fill:16x16:#140D08^[opacity:" .. q)
		st.last_box_op = q
	end
end

-----------------------------------------
-- Globalstep: Intro Sequencer
-----------------------------------------
core.register_globalstep(function(dtime)
	local dt = math.min(dtime, 0.1)

	for name, st in pairs(intro_players) do
		local player = core.get_player_by_name(name)
		if not player or not player:is_player() then
			cleanup_intro(name, player, false)
		elseif not st.finishing then
			st.total_time = st.total_time + dt
			local controls = player:get_player_control()

			-- Allow skipping after 0.75s with Jump (Space) or Aux1 (E)
			if not st.skipping and st.total_time >= 0.75 and (controls.jump or controls.aux1) then
				st.skipping = true
				st.skip_timer = 0.0
				st.skip_start_fade = st.last_fade_op / 255.0
				if not st.skip_hidden then
					player:hud_change(st.skip_hud, "text", "")
					st.skip_hidden = true
				end
				if st.queued_emerge < #EMERGE_BOXES then
					emerge_for_idx(#EMERGE_BOXES)
					st.queued_emerge = #EMERGE_BOXES
				end
			end

			if st.skipping then
				st.skip_timer = st.skip_timer + dt
				local u = clamp(st.skip_timer / 0.35, 0.0, 1.0)
				set_fade_opacity(player, st, lerp(st.skip_start_fade, 1.0, u))
				set_box_opacity(player, st, 1.0 - u)
				local dim = 1.0 - u
				local col = (math.floor(TEXT_COLOR_R * dim) * 0x10000)
					+ (math.floor(TEXT_COLOR_G * dim) * 0x100)
					+ math.floor(TEXT_COLOR_B * dim)
				if col ~= st.last_text_col then
					player:hud_change(st.text_hud, "number", col)
					st.last_text_col = col
				end
				if u >= 1.0 then
					finish_intro_and_start_mission(name, player, st, false)
				end
			else
				local prev_idx = st.scene_idx
				local scene = SCENES[st.scene_idx]
				if not scene then
					finish_intro_and_start_mission(name, player, st, true)
				else
					st.scene_time = st.scene_time + dt
					while scene and st.scene_time >= scene.duration do
						st.scene_time = st.scene_time - scene.duration
						st.scene_idx = st.scene_idx + 1
						scene = SCENES[st.scene_idx]
					end

					if not scene then
						finish_intro_and_start_mission(name, player, st, true)
					else
						local cut_now = (st.scene_idx ~= prev_idx) and scene.cut

						-- On-demand preloading:
						-- While Scene 1 plays -> emerge Scene 2
						-- Upon cutting to Scene N -> emerge Scene N+1
						if st.scene_idx == 1 then
							if st.queued_emerge < 2 and st.scene_time >= 0.15 then
								emerge_for_idx(2)
								st.queued_emerge = 2
							end
						elseif st.queued_emerge < st.scene_idx + 1 then
							local next_box = st.scene_idx + 1
							if next_box <= #EMERGE_BOXES then
								emerge_for_idx(next_box)
							end
							st.queued_emerge = next_box
						end

						local t = clamp(st.scene_time / scene.duration, 0.0, 1.0)
						local u = scene.cut and smoothstep(t) or t

						local cam_pos = lerp_vec(scene.pos_a, scene.pos_b, u)
						local look_pt = lerp_vec(scene.look_a, scene.look_b, u)

						sync_camera(name, player, st, cam_pos, look_pt, dt, cut_now)

						if scene.show_truck then
							ensure_preview_truck(name, st)
						end

						-- 0.5s fade-in and 0.5s fade-out around teleport cuts
						local fade_alpha = 0.0
						if scene.fade_in and st.scene_time < scene.fade_in then
							fade_alpha = 1.0 - (st.scene_time / scene.fade_in)
						elseif scene.fade_out and st.scene_time >= (scene.duration - scene.fade_out) then
							fade_alpha = clamp(
								(st.scene_time - (scene.duration - scene.fade_out)) / scene.fade_out,
								0.0, 1.0
							)
						end
						set_fade_opacity(player, st, fade_alpha)

						-- Narrative box & typewriter text (hidden on textless Scene 6)
						local has_text = (scene.wrapped_text ~= "")
						local box_vis = has_text and 1.0 or 0.0
						local text_vis = has_text and 1.0 or 0.0

						if has_text then
							if st.scene_idx == 1 and st.scene_time < 0.4 then
								box_vis = clamp(st.scene_time / 0.4, 0.0, 1.0)
							end
							if scene.fade_out and st.scene_time >= (scene.duration - 0.35) then
								text_vis = clamp((scene.duration - st.scene_time) / 0.35, 0.0, 1.0)
								if st.scene_idx == 5 then
									box_vis = text_vis
								end
							end
						elseif not st.skip_hidden then
							player:hud_change(st.skip_hud, "text", "")
							st.skip_hidden = true
						end

						set_box_opacity(player, st, box_vis)

						local reveal_chars = math.floor(st.scene_time * CHARS_PER_SEC)
						local shown = has_text and string.sub(scene.wrapped_text, 1, reveal_chars) or ""

						local col = (math.floor(TEXT_COLOR_R * text_vis) * 0x10000)
							+ (math.floor(TEXT_COLOR_G * text_vis) * 0x100)
							+ math.floor(TEXT_COLOR_B * text_vis)
						if col ~= st.last_text_col then
							player:hud_change(st.text_hud, "number", col)
							st.last_text_col = col
						end

						if text_vis <= 0.02 then
							shown = ""
						end
						if shown ~= st.last_text then
							player:hud_change(st.text_hud, "text", shown)
							st.last_text = shown
						end
					end
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	cleanup_intro(player:get_player_name(), player, false)
end)

core.register_on_shutdown(function()
	for name, _ in pairs(intro_players) do
		local player = core.get_player_by_name(name)
		cleanup_intro(name, player, false)
	end
end)