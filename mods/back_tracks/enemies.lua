local MODNAME = core.get_current_modname()

local clamp = back_tracks.clamp
local round_int = back_tracks.round_int
local is_node_solid = back_tracks.is_node_solid
local raycast_solid = back_tracks.raycast_solid

-----------------------------------------
-- Turret & Projectile Tuning
-----------------------------------------
local TURRET_MAX_RANGE = 135.0
local TURRET_SPAWN_RADIUS = 165.0
local TURRET_FIRE_INTERVAL = 1.35
local TURRET_LOS_CHECK_INTERVAL = 0.20
local TURRET_MAX_HP = 25
local TURRET_HIT_RADIUS = 1.75
local TURRET_HALF_H = 0.90
local TURRET_MUZZLE_Y = 0.75

local ENEMY_BULLET_SPEED = 90.0
local ENEMY_BULLET_MAX_DIST = 215.0
local ENEMY_BULLET_DAMAGE = 14.0
local ENEMY_BULLET_HIT_R = 1.80
local ENEMY_BULLET_SEEK_RATE = math.rad(65)  -- Max steering rate (rad/s) toward player
local ENEMY_BULLET_SEEK_MIN_DOT = 0.30       -- Stops seeking once bullet passes target

local TURRET_TEX = "[fill:16x16:#FF1A1A"
local TURRET_TOP_TEX = "[fill:16x16:#FF4422"
local ENEMY_BULLET_TEX = "[fill:16x16:#FF3300"

back_tracks.turret_generation = back_tracks.turret_generation or 1

-----------------------------------------
-- Course Geometry Helpers (mirrors mapgen.lua)
-----------------------------------------
local MX, MZ = -1145, 0
local R_BASE = 185
local R_MESA = 90
local H_MESA = 180
local INV_MTN_EXP = 1 / 1.55

local function smoothstep(edge0, edge1, x)
	local t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function steer_dir_toward(dir, target_dir, max_angle)
	local dot_v = clamp(vector.dot(dir, target_dir), -1.0, 1.0)
	local ang = math.acos(dot_v)
	if ang <= 1e-4 then
		return dir
	end
	local step = math.min(ang, max_angle)
	local axis = vector.cross(dir, target_dir)
	local alen = vector.length(axis)
	if alen < 1e-5 then
		return dir
	end
	axis = vector.multiply(axis, 1.0 / alen)
	local c = math.cos(step)
	local s = math.sin(step)
	local k_dot_v = vector.dot(axis, dir)
	local k_cross_v = vector.cross(axis, dir)
	return vector.normalize(vector.add(
		vector.multiply(dir, c),
		vector.add(
			vector.multiply(k_cross_v, s),
			vector.multiply(axis, k_dot_v * (1.0 - c))
		)
	))
end

local function mtn_radius_at_height(y)
	if y <= 0 then return R_BASE end
	if y >= H_MESA then return R_MESA end
	local u = (y / H_MESA) ^ INV_MTN_EXP
	return R_BASE - u * (R_BASE - R_MESA)
end

local function eval_lower_spiral_y(phi)
	local join_phi = 0.24
	local end_phi = 2.0 * math.pi
	if phi <= join_phi then return 12 end
	local t = clamp((phi - join_phi) / (end_phi - join_phi), 0, 1)
	return 12 + (90 - 12) * t - 7.5 * math.sin(t * 4 * math.pi) + 4.0 * math.sin(t * 6 * math.pi)
end

local function eval_upper_spiral_y(phi_u)
	local end_phi = 2.0 * math.pi
	if phi_u <= 0.12 then return 96 end
	local t = clamp((phi_u - 0.12) / (end_phi - 0.12), 0, 1)
	return 96 + (H_MESA - 96) * t - 8.0 * math.sin(t * 4 * math.pi) + 4.5 * math.sin(t * 6 * math.pi)
end

local function catmull_rom_val(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function eval_spline_at(ctrl_pts, seg_idx, t)
	local n = #ctrl_pts
	local p0 = ctrl_pts[math.max(1, seg_idx - 1)]
	local p1 = ctrl_pts[seg_idx]
	local p2 = ctrl_pts[seg_idx + 1]
	local p3 = ctrl_pts[math.min(n, seg_idx + 2)]
	local x = catmull_rom_val(p0[1], p1[1], p2[1], p3[1], t)
	local y = catmull_rom_val(p0[2], p1[2], p2[2], p3[2], t)
	local z = catmull_rom_val(p0[3], p1[3], p2[3], p3[3], t)

	local dt = 0.02
	local t2 = math.min(1.0, t + dt)
	local x2 = catmull_rom_val(p0[1], p1[1], p2[1], p3[1], t2)
	local z2 = catmull_rom_val(p0[3], p1[3], p2[3], p3[3], t2)
	local dx, dz = x2 - x, z2 - z
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-4 then dx, dz = -1, 0 else dx, dz = dx / len, dz / len end
	local px, pz = -dz, dx
	return x, y, z, px, pz
end

local function ramp_track_z(x)
	local s = -300 - x
	return 14 * math.sin(s * math.pi / 170) * smoothstep(0, 30, s) * smoothstep(340, 305, s)
end

-----------------------------------------
-- Deterministic Turret Spawn List (Mesa intentionally empty for boss)
-----------------------------------------
local TURRET_SPAWNS = {}

local function add_spawn(x, z, y_min, y_max, tag)
	TURRET_SPAWNS[#TURRET_SPAWNS + 1] = {
		id = #TURRET_SPAWNS + 1,
		x = round_int(x),
		z = round_int(z),
		y_min = math.floor(y_min),
		y_max = math.ceil(y_max),
		tag = tag,
		dead = false,
		obj = nil,
	}
end

-- 1. Outer Desert Ground Turrets (anti-cheese outside Canyon, Ramps, Causeways, Mountain Skirt)
for _, x in ipairs({-50, -110, -170, -230, -280}) do
	add_spawn(x,  122, -4, 24, "desert_canyon")
	add_spawn(x, -122, -4, 24, "desert_canyon")
end
for _, x in ipairs({-350, -430, -510, -590}) do
	add_spawn(x,  118, -4, 24, "desert_ramps")
	add_spawn(x, -118, -4, 24, "desert_ramps")
end
for _, x in ipairs({-700, -780, -860, -930}) do
	add_spawn(x,  144, -4, 24, "desert_causeway")
	add_spawn(x, -144, -4, 24, "desert_causeway")
end
for _, th in ipairs({0.7, 1.4, 2.2, 3.0, 3.8, 4.6, 5.4}) do
	local r_skirt = R_BASE + 16
	add_spawn(MX + r_skirt * math.cos(th), MZ + r_skirt * math.sin(th), -4, 24, "desert_mtn_skirt")
end

-- 2. Top of Canyon Walls (outer rim + inner peninsulas)
for _, x in ipairs({-40, -90, -140, -190, -240, -285}) do
	add_spawn(x,  76, 30, 50, "canyon_top")
	add_spawn(x, -76, 30, 50, "canyon_top")
end
for _, pt in ipairs({{-38, -10}, {-78, 12}, {-125, -10}, {-170, 12}, {-215, -10}, {-258, 12}}) do
	add_spawn(pt[1], pt[2], 30, 50, "canyon_peninsula")
end

-- 3. Top of Ramp Walls
for _, x in ipairs({-345, -400, -455, -510, -565, -620}) do
	local zc = ramp_track_z(x)
	add_spawn(x, zc + 78, 34, 58, "ramp_wall_top")
	add_spawn(x, zc - 78, 34, 58, "ramp_wall_top")
end

-- 4. Backsides of Ramps (hidden behind ramp crest until you fly over or pass)
for _, r in ipairs({
	{s = 63, dz = -15},
	{s = 166, dz = 0}, 
	{s = 268, dz = 0},
}) do
	local x = -300 - r.s
	local z = ramp_track_z(x) + r.dz
	add_spawn(x, z, 6, 20, "ramp_backside")
end

-- 6. Edges of Causeways (low paths & high skyways)
local causeway_paths = {
	{                 {-660, 10,   0}, {-695,  6,  -8},                                 {-865,  6,  10},                 {-946, 12,  0} },
	{ {-640, 12,  4},                                  {-745,  3,  68},                 {-868,  5,  50},                                },
	{                 {-658, 10, -10},                 {-745,  3, -68}, {-805,  3, -70},                 {-915,  9,-22}, {-946, 12,  0} },
	-- Skyways (index 4..5 here)
	{ {-656, 10,  10},                                 {-800, 44,  16}, {-865, 34,  38},                 },
	{                 {-682, 22, -26}, {-735, 36, -34},                                  {-912, 23, -22} },
}
for p_idx, path in ipairs(causeway_paths) do
	for seg = 2, #path - 2 do
		local x, y, z, px, pz = eval_spline_at(path, seg, 0.5)
		local side = (seg % 2 == 0) and 2.6 or -2.6
		add_spawn(x + px * side, z + pz * side, y - 3, y + 4, (p_idx >= 4) and "skyway_edge" or "causeway_edge")
	end
end

-- 7. Spiral Mountain Halfpipe: Outer Wall Rim (punishes jumping out) + Along the Spiral Climb
for i = 0, 9 do
	local phi = 0.65 + i * 0.57
	local yc = eval_lower_spiral_y(phi)
	local rc = mtn_radius_at_height(yc) + 2
	local r_wall = rc + 12.2 + 2
	add_spawn(MX + r_wall * math.cos(phi), MZ + r_wall * math.sin(phi), yc + 11, yc + 22, "lower_spiral_outer_wall")
	if i % 2 == 1 then
		local dr_climb = (i % 4 == 1) and 7.5 or -7.5
		local r_climb = rc + dr_climb
		add_spawn(MX + r_climb * math.cos(phi), MZ + r_climb * math.sin(phi), yc, yc + 14, "lower_spiral_climb")
	end
end

for i = 0, 9 do
	local phi_u = 0.30 + i * 0.60
	local theta = math.pi + phi_u
	local yc = eval_upper_spiral_y(phi_u)
	local rc = mtn_radius_at_height(yc) + ((phi_u < 0.92 * math.pi) and 2 or 1)
	local r_wall = rc + 12.0 + 3
	add_spawn(MX + r_wall * math.cos(theta), MZ + r_wall * math.sin(theta), yc + 11, yc + 22, "upper_spiral_outer_wall")
	if i % 2 == 0 then
		local dr_climb = (rc - 7.5 > R_MESA + 4 and i % 4 == 0) and -7.5 or 7.5
		local r_climb = rc + dr_climb
		add_spawn(MX + r_climb * math.cos(theta), MZ + r_climb * math.sin(theta), yc, yc + 14, "upper_spiral_climb")
	end
end

-- 8. Inside the Mountain Tunnels (branches 2, 3, 4)
local r_in = mtn_radius_at_height(90) + 3
local r_out = mtn_radius_at_height(96) + 3
local hubA_x, hubA_y, hubA_z = MX + r_in - 26, 90, 30
local hubB_x, hubB_y, hubB_z = MX - r_out + 26, 96, 30
local abx, abz = hubB_x - hubA_x, hubB_z - hubA_z
local ab_len = math.sqrt(abx * abx + abz * abz)
local px_u, pz_u = -abz / ab_len, abx / ab_len

local tunnel_branches = {
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.22) - px_u * 28, 86, lerp(hubA_z, hubB_z, 0.22) - pz_u * 28 },
		{ lerp(hubA_x, hubB_x, 0.52) - px_u * 46, 76, lerp(hubA_z, hubB_z, 0.52) - pz_u * 46 },
		{ lerp(hubA_x, hubB_x, 0.80) - px_u * 24, 88, lerp(hubA_z, hubB_z, 0.80) - pz_u * 24 },
		{ hubB_x + 14, 96, 24 },
	},
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.30) + px_u * 2,  87, lerp(hubA_z, hubB_z, 0.30) + pz_u * 2 },
		{ lerp(hubA_x, hubB_x, 0.56) - px_u * 6,  93, lerp(hubA_z, hubB_z, 0.56) - pz_u * 6 },
		{ lerp(hubA_x, hubB_x, 0.82) + px_u * 2,  95, lerp(hubA_z, hubB_z, 0.82) + pz_u * 2 },
		{ hubB_x + 14, 96, 24 },
	},
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.20) + px_u * 30,  93, lerp(hubA_z, hubB_z, 0.20) + pz_u * 30 },
		{ lerp(hubA_x, hubB_x, 0.46) + px_u * 44, 108, lerp(hubA_z, hubB_z, 0.46) + pz_u * 44 },
		{ lerp(hubA_x, hubB_x, 0.70) + px_u * 36, 118, lerp(hubA_z, hubB_z, 0.70) + pz_u * 36 },
		{ lerp(hubA_x, hubB_x, 0.88) + px_u * 14, 110, lerp(hubA_z, hubB_z, 0.88) + pz_u * 14 },
		{ hubB_x + 18, 96 + 11, 24 },
	},
}
for _, tpath in ipairs(tunnel_branches) do
	for _, seg in ipairs({2, 3}) do
		local x, y, z, px, pz = eval_spline_at(tpath, seg, 0.45)
		local side = (seg == 2) and 3.4 or -3.4
		add_spawn(x + px * side, z + pz * side, y - 3, y + 4, "tunnel")
	end
end

-----------------------------------------
-- Mildly Seeking Enemy Projectile Entity
-----------------------------------------
core.register_entity(MODNAME .. ":enemy_bullet", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.34, y = 0.34, z = 0.65},
		textures = {
			ENEMY_BULLET_TEX, ENEMY_BULLET_TEX, ENEMY_BULLET_TEX,
			ENEMY_BULLET_TEX, ENEMY_BULLET_TEX, ENEMY_BULLET_TEX,
		},
		glow = 14,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_activate = function(self)
		self.dir = vector.new(0, 0, 1)
		self.dist_traveled = 0
		self.spawn_gen = back_tracks.turret_generation
	end,

	on_step = function(self, dtime)
		local dt = math.min(dtime, 0.1)
		local pos = self.object:get_pos()
		if not pos or not self.dir or self.spawn_gen ~= back_tracks.turret_generation then
			self.object:remove()
			return
		end

		-- Mildly steer toward the nearest visible player in front of the bullet
		local best_d2 = TURRET_MAX_RANGE * TURRET_MAX_RANGE
		local seek_dir = nil
		for _, dstate in pairs(back_tracks.active_drivers) do
			if dstate and dstate.hp > 0 and dstate.pos then
				local tp = vector.new(dstate.pos.x, dstate.pos.y + 0.5, dstate.pos.z)
				local to_p = vector.subtract(tp, pos)
				local d2 = vector.dot(to_p, to_p)
				if d2 > 1.0 and d2 < best_d2 then
					local d = math.sqrt(d2)
					local cand_dir = vector.multiply(to_p, 1.0 / d)
					if vector.dot(cand_dir, self.dir) >= ENEMY_BULLET_SEEK_MIN_DOT and not raycast_solid(pos, tp) then
						best_d2 = d2
						seek_dir = cand_dir
					end
				end
			end
		end

		if seek_dir then
			self.dir = steer_dir_toward(self.dir, seek_dir, ENEMY_BULLET_SEEK_RATE * dt)
			self.object:set_rotation(vector.dir_to_rotation(self.dir))
		end

		local step_dist = ENEMY_BULLET_SPEED * dt
		local next_pos = vector.add(pos, vector.multiply(self.dir, step_dist))

		-- Cannot shoot through the ground or walls
		if raycast_solid(pos, next_pos) then
			self.object:remove()
			return
		end

		-- Check hit against active driver trucks
		local seg = vector.subtract(next_pos, pos)
		local seg_len2 = vector.dot(seg, seg)
		if seg_len2 > 1e-6 then
			for name, dstate in pairs(back_tracks.active_drivers) do
				if dstate and dstate.hp > 0 and dstate.pos then
					local tp = dstate.pos
					local t = clamp(vector.dot(vector.subtract(tp, pos), seg) / seg_len2, 0, 1)
					local closest = vector.add(pos, vector.multiply(seg, t))
					local d2 = vector.dot(vector.subtract(tp, closest), vector.subtract(tp, closest))
					if d2 <= ENEMY_BULLET_HIT_R * ENEMY_BULLET_HIT_R then
						back_tracks.damage_player(name, ENEMY_BULLET_DAMAGE)
						core.add_particlespawner({
							amount = 10,
							time = 0.05,
							minpos = vector.subtract(closest, vector.new(0.2, 0.2, 0.2)),
							maxpos = vector.add(closest, vector.new(0.2, 0.2, 0.2)),
							minvel = vector.new(-5, 1, -5),
							maxvel = vector.new( 5, 6,  5),
							minexptime = 0.15,
							maxexptime = 0.35,
							minsize = 2.0,
							maxsize = 3.5,
							glow = 14,
							texture = ENEMY_BULLET_TEX,
						})
						self.object:remove()
						return
					end
				end
			end
		end

		self.dist_traveled = self.dist_traveled + step_dist
		if self.dist_traveled >= ENEMY_BULLET_MAX_DIST then
			self.object:remove()
			return
		end

		self.object:set_pos(next_pos)
	end,
})

-----------------------------------------
-- Ground Turret Entity
-----------------------------------------
local next_enemy_uid = 1

core.register_entity(MODNAME .. ":ground_turret", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 1.4, y = 1.8, z = 1.4},
		textures = {
			TURRET_TOP_TEX, TURRET_TEX, TURRET_TEX,
			TURRET_TEX, TURRET_TEX, TURRET_TEX,
		},
		glow = 14,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_activate = function(self)
		self.uid = next_enemy_uid
		next_enemy_uid = next_enemy_uid + 1
		self.hp = TURRET_MAX_HP
		self.fire_timer = math.random() * TURRET_FIRE_INTERVAL
		self.los_timer = math.random() * TURRET_LOS_CHECK_INTERVAL
		self.flash_timer = 0
		self.cached_target = nil
	end,

	on_deactivate = function(self, _removal)
		if self.uid then
			back_tracks.enemies[self.uid] = nil
		end
		if self.spawn_entry and self.spawn_entry.obj == self.object then
			self.spawn_entry.obj = nil
		end
	end,

	on_step = function(self, dtime)
		local dt = math.min(dtime, 0.1)
		local entry = self.registry_entry
		if not entry or entry.dead then
			self.object:remove()
			return
		end

		if self.flash_timer > 0 then
			self.flash_timer = self.flash_timer - dt
			if self.flash_timer <= 0 then
				self.object:set_texture_mod("")
			end
		end

		local pos = self.object:get_pos()
		if not pos then return end
		entry.pos = pos

		local muzzle = vector.new(pos.x, pos.y + TURRET_MUZZLE_Y, pos.z)

		-- Rate-limit raycast line-of-sight checks
		self.los_timer = self.los_timer - dt
		if self.los_timer <= 0 then
			self.los_timer = TURRET_LOS_CHECK_INTERVAL
			local best_dist2 = TURRET_MAX_RANGE * TURRET_MAX_RANGE
			local best_target = nil

			for _, dstate in pairs(back_tracks.active_drivers) do
				if dstate and dstate.hp > 0 and dstate.pos then
					local tp = vector.new(dstate.pos.x, dstate.pos.y + 0.6, dstate.pos.z)
					local diff = vector.subtract(tp, muzzle)
					local d2 = vector.dot(diff, diff)
					if d2 <= best_dist2 and d2 > 1.0 then
						if not raycast_solid(muzzle, tp) then
							best_dist2 = d2
							best_target = tp
						end
					end
				end
			end
			self.cached_target = best_target
		end

		local target = self.cached_target
		if target then
			local dir = vector.direction(muzzle, target)
			self.object:set_yaw(math.atan2(-dir.x, dir.z))

			self.fire_timer = self.fire_timer - dt
			if self.fire_timer <= 0 then
				self.fire_timer = TURRET_FIRE_INTERVAL
				if not raycast_solid(muzzle, target) then
					local bullet_spawn = vector.add(muzzle, vector.multiply(dir, 1.1))
					local b = core.add_entity(bullet_spawn, MODNAME .. ":enemy_bullet")
					if b then
						local bent = b:get_luaentity()
						bent.dir = dir
						bent.dist_traveled = 0
						bent.spawn_gen = back_tracks.turret_generation
						b:set_rotation(vector.dir_to_rotation(dir))
					end
				end
			end
		else
			self.fire_timer = math.max(0.25, self.fire_timer - dt)
		end
	end,
})

-----------------------------------------
-- Surface Snapping & Dynamic Spawner
-----------------------------------------
local function find_surface_in_column(x, z, y_min, y_max)
	local top_node = core.get_node_or_nil({x = x, y = y_max + 2, z = z})
	local bot_node = core.get_node_or_nil({x = x, y = y_min, z = z})
	if not top_node or top_node.name == "ignore" or not bot_node or bot_node.name == "ignore" then
		return nil
	end

	local p = {x = x, y = 0, z = z}
	local above = {x = x, y = 0, z = z}
	for y = y_max, y_min, -1 do
		p.y = y
		above.y = y + 1
		if is_node_solid(p) and not is_node_solid(above) then
			above.y = y + 2
			if not is_node_solid(above) then
				return y + 0.5 + TURRET_HALF_H
			end
		end
	end
	return nil
end

local function spawn_turret(spawn)
	local sy = find_surface_in_column(spawn.x, spawn.z, spawn.y_min, spawn.y_max)
	if not sy then return false end

	local pos = vector.new(spawn.x, sy, spawn.z)
	local obj = core.add_entity(pos, MODNAME .. ":ground_turret")
	if not obj then return false end

	local ent = obj:get_luaentity()
	ent.spawn_entry = spawn
	spawn.obj = obj

	local reg = {
		obj = obj,
		pos = pos,
		dead = false,
		hit_radius = TURRET_HIT_RADIUS,
		damage = function(amount, killer_name)
			if ent.hp <= 0 then return end
			ent.hp = ent.hp - amount
			if ent.hp <= 0 then
				spawn.dead = true
				back_tracks.enemies[ent.uid].dead = true
				back_tracks.spawn_explosion(pos, 1.3)
				if killer_name then
					back_tracks.register_kill(killer_name)
				end
				obj:remove()
			else
				ent.flash_timer = 0.08
				obj:set_texture_mod("^[brighten")
			end
		end,
		kill = function(killer_name)
			spawn.dead = true
			back_tracks.enemies[ent.uid].dead = true
			back_tracks.spawn_explosion(pos, 1.3)
			if killer_name then
				back_tracks.register_kill(killer_name)
			end
			obj:remove()
		end,
	}
	ent.registry_entry = reg
	back_tracks.enemies[ent.uid] = reg
	return true
end

local spawn_scan_timer = 0
local SPAWN_SCAN_INTERVAL = 0.25
local SPAWN_RADIUS_2 = TURRET_SPAWN_RADIUS * TURRET_SPAWN_RADIUS

function back_tracks.respawn_all_turrets()
	back_tracks.turret_generation = back_tracks.turret_generation + 1
	for i = 1, #TURRET_SPAWNS do
		local s = TURRET_SPAWNS[i]
		s.dead = false
		if s.obj and s.obj:is_valid() then
			local ent = s.obj:get_luaentity()
			if ent then
				ent.hp = TURRET_MAX_HP
				ent.flash_timer = 0
				ent.fire_timer = 0.4 + math.random() * TURRET_FIRE_INTERVAL
				ent.cached_target = nil
				if ent.registry_entry then
					ent.registry_entry.dead = false
				end
			end
			s.obj:set_texture_mod("")
		end
	end
	spawn_scan_timer = SPAWN_SCAN_INTERVAL
end

core.register_globalstep(function(dtime)
	spawn_scan_timer = spawn_scan_timer + dtime
	if spawn_scan_timer < SPAWN_SCAN_INTERVAL then return end
	spawn_scan_timer = 0

	local has_drivers = next(back_tracks.active_drivers) ~= nil
	local has_intro = back_tracks.intro_view_positions and next(back_tracks.intro_view_positions) ~= nil
	if not has_drivers and not has_intro then return end

	for i = 1, #TURRET_SPAWNS do
		local s = TURRET_SPAWNS[i]
		if not s.dead and (not s.obj or not s.obj:is_valid()) then
			local spawned = false
			for _, dstate in pairs(back_tracks.active_drivers) do
				if dstate and dstate.pos then
					local dx = dstate.pos.x - s.x
					local dz = dstate.pos.z - s.z
					if dx * dx + dz * dz <= SPAWN_RADIUS_2 then
						spawn_turret(s)
						spawned = true
						break
					end
				end
			end
			if not spawned and has_intro then
				for _, ipos in pairs(back_tracks.intro_view_positions) do
					local dx = ipos.x - s.x
					local dz = ipos.z - s.z
					if dx * dx + dz * dz <= SPAWN_RADIUS_2 then
						spawn_turret(s)
						break
					end
				end
			end
		end
	end
end)