local MODNAME = core.get_current_modname()

local clamp = back_tracks.clamp

-----------------------------------------
-- Mesa & Boss Tuning Constants
-----------------------------------------
local MX, MZ = -1145, 0
local MESA_Y = 180.0

local BOSS_MAX_HP = 6
local BOSS_PHASE2_HP = 3

local MOUTH_POS = vector.new(MX, 178.3, MZ)
local MOUTH_SIZE = {x = 15.6, y = 3.12, z = 13.2}
local MOUTH_HIT_RADIUS = 8.64
local MOUTH_EAT_RX = 7.44
local MOUTH_EAT_RZ = 6.24
local SWALLOW_DURATION = 1.85

local NUM_INNER_TENTACLES = 12
local NUM_OUTER_TENTACLES = 4
local NUM_SEGMENTS = 5

local INNER_BASE_R = 10.2
local OUTER_BASE_R = 52.0

local INNER_SEG_LEN = {8.88, 8.16, 7.44, 6.72, 6.00} -- 37.2 total reach (+20%)
local OUTER_SEG_LEN = {7.80, 7.20, 6.60, 6.00, 5.40} -- 33.0 total reach (+20%)
local SEG_WIDTH     = {2.3, 1.9, 1.55, 1.2, 0.85}
local SEG_HIT_R     = {3.5, 3.3, 3.0, 2.8, 2.5}
local SEG_TOUCH_R   = {1.2, 1.05, 0.9, 0.75, 0.6}

local TENTACLE_MAX_HP = 95          -- ~58% more HP than 60
local GRAB_ESCAPE_DMG = 30          -- 3 shots while grabbed to break free & throw outward
local INNER_SUBDUE_TIME = 30.0
local OUTER_SUBDUE_TIME = 20.0

local GRAB_PULL_SPEED = 4.9
local DOUBLE_GRAB_WINDOW = 22.0     -- Must be grabbed twice within this span to die from grasp damage
local GRAB_FIRST_FLOOR_HP = 24.0
local GRAB_FIRST_DPS = 13.0
local GRAB_SECOND_DPS = 24.0
local GRAB_RELEASE_IMMUNITY = 2.4

local TIP_PUSH_IMPULSE = 22.0
local TIP_PUSH_COOLDOWN = 0.75

local WRITHE_TIME_NORMAL = 3.0
local WRITHE_TIME_PHASE2 = 4.2
local DEATH_EXPLODE_TIME = 1.6

local REQUIRED_INNER_SUBDUED = 3
local REQUIRED_OUTER_SUBDUED = 0

-- Spiky Rock Throw Tuning
local ROCK_THROW_INTERVAL_P1 = 0.45
local ROCK_THROW_INTERVAL_P2 = 0.22
local ROCK_WINDUP_TIME = 0.55
local ROCK_FOLLOW_TIME = 0.20
local ROCK_GRAVITY = 15.0
local ROCK_RADIUS = 0.75
local ROCK_HIT_RADIUS = 2.25
local ROCK_DAMAGE = 28.0
local ROCK_ROLL_MIN_TIME = 1.3
local ROCK_ROLL_MAX_TIME = 2.0

-----------------------------------------
-- Placeholder Colors / Textures
-----------------------------------------
local MOUTH_TEX_TOP  = "[fill:16x16:#1A55FF"
local MOUTH_TEX_SIDE = "[fill:16x16:#0E36B8"
local MOUTH_VIOLET_MOD = "^[colorize:#9922FF:155"
local WINDUP_MOD = "^[colorize:#FF9922:110"

local ROCK_TEX       = "[fill:16x16:#E89238"
local ROCK_SPIKE_TEX = "[fill:16x16:#FFBB55"

local SEG_TEX = {
	"[fill:16x16:#683619",
	"[fill:16x16:#7E431F",
	"[fill:16x16:#975224",
	"[fill:16x16:#B56329",
	"[fill:16x16:#D6762F",
}

-----------------------------------------
-- Math & Geometry Helpers
-----------------------------------------
local function safe_normalize(v, fallback)
	local len = vector.length(v)
	if len < 1e-5 then
		return fallback or vector.new(0, 1, 0)
	end
	return vector.multiply(v, 1.0 / len)
end

local function closest_point_on_seg(p, a, b)
	local ab = vector.subtract(b, a)
	local len2 = vector.dot(ab, ab)
	if len2 < 1e-6 then
		return a, 0.0
	end
	local t = clamp(vector.dot(vector.subtract(p, a), ab) / len2, 0.0, 1.0)
	return vector.add(a, vector.multiply(ab, t)), t
end

local function angle_diff(a, b)
	local d = (a - b + math.pi) % (2.0 * math.pi) - math.pi
	return d
end

local function is_driver_in_boss_arena(dstate)
	if not dstate or not dstate.pos then return false end
	if dstate.pos.y < 165.0 then
		dstate.boss_arena_entered = nil
		return false
	end

	local dx = dstate.pos.x - MX
	local dz = dstate.pos.z - MZ
	local d2 = dx * dx + dz * dz
	local num_cp = back_tracks.CHECKPOINTS and #back_tracks.CHECKPOINTS or 6

	if (dstate.checkpoint_idx or 0) >= num_cp then
		if d2 <= 96.0 * 96.0 then
			dstate.boss_arena_entered = true
			return true
		end
		return false
	end

	if dstate.boss_arena_entered then
		if d2 <= 96.0 * 96.0 then
			return true
		end
		dstate.boss_arena_entered = nil
		return false
	end

	-- Fallback if teleported directly into the Mesa arena without checkpoints (inside r=84 rim wall)
	if d2 <= 80.0 * 80.0 and dstate.pos.y >= 175.0 then
		dstate.boss_arena_entered = true
		return true
	end
	return false
end

-----------------------------------------
-- Boss State & Enemy UID Counter
-----------------------------------------
local next_boss_uid = 100000
local boss_time = 0.0
local boss_generation = 1

local boss = {
	spawned = false,
	hp = BOSS_MAX_HP,
	phase = 1,
	state = "active", -- "active" | "writhing" | "dying" | "dead"
	writhe_timer = 0.0,
	writhe_is_phase2 = false,
	death_timer = 0.0,
	rock_timer = 0.8,
	throwing_tent_id = nil,
	last_throwing_tent_id = nil,
	throw_windup_timer = 0.0,
	throw_follow_timer = 0.0,
	throw_target_name = nil,
	held_rock_obj = nil,
	mouth_obj = nil,
	mouth_reg = nil,
	inner = {},
	outer = {},
	outer_sprouted = false,
}

local boss_huds = {}
local shield_alerts = {} -- [player_name] = {msg = str, timer = num}

local function set_player_alert(name, msg, duration)
	if not name then return end
	shield_alerts[name] = {msg = msg, timer = duration or 2.0}
end

local function find_tentacle_by_id(id)
	if not id then return nil end
	for i = 1, #boss.inner do
		if boss.inner[i].id == id then return boss.inner[i] end
	end
	for i = 1, #boss.outer do
		if boss.outer[i].id == id then return boss.outer[i] end
	end
	return nil
end

-----------------------------------------
-- Entities (Mouth, Tentacles, Spiky Rock)
-----------------------------------------
core.register_entity(MODNAME .. ":boss_mouth", {
	initial_properties = {
		visual = "cube",
		visual_size = MOUTH_SIZE,
		textures = {
			MOUTH_TEX_TOP, MOUTH_TEX_SIDE, MOUTH_TEX_SIDE,
			MOUTH_TEX_SIDE, MOUTH_TEX_SIDE, MOUTH_TEX_SIDE,
		},
		glow = 6,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_deactivate = function(self)
		if self.uid then
			back_tracks.enemies[self.uid] = nil
		end
		if boss.mouth_obj == self.object then
			boss.mouth_obj = nil
			boss.mouth_reg = nil
		end
	end,
})

core.register_entity(MODNAME .. ":boss_tentacle_seg", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 1.5, y = 1.5, z = 6.0},
		textures = {
			SEG_TEX[3], SEG_TEX[3], SEG_TEX[3],
			SEG_TEX[3], SEG_TEX[3], SEG_TEX[3],
		},
		glow = 3,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_deactivate = function(self)
		if self.uid then
			back_tracks.enemies[self.uid] = nil
		end
	end,
})

core.register_entity(MODNAME .. ":boss_rock_spike", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.41, y = 1.74, z = 0.41},
		textures = {
			ROCK_SPIKE_TEX, ROCK_SPIKE_TEX, ROCK_SPIKE_TEX,
			ROCK_SPIKE_TEX, ROCK_SPIKE_TEX, ROCK_SPIKE_TEX,
		},
		glow = 10,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_step = function(self)
		if not self.parent_obj or not self.parent_obj:is_valid() or self.gen ~= boss_generation then
			self.object:remove()
		end
	end,
})

local function spawn_rock_debris(pos, count)
	core.add_particlespawner({
		amount = count or 12,
		time = 0.06,
		minpos = vector.subtract(pos, vector.new(0.45, 0.35, 0.45)),
		maxpos = vector.add(pos, vector.new(0.45, 0.45, 0.45)),
		minvel = vector.new(-5, 2, -5),
		maxvel = vector.new( 5, 7,  5),
		minacc = vector.new(0, -15, 0),
		maxacc = vector.new(0, -12, 0),
		minexptime = 0.20,
		maxexptime = 0.45,
		minsize = 2.2,
		maxsize = 4.2,
		glow = 9,
		texture = ROCK_SPIKE_TEX,
	})
end

local ROCK_SPIKE_ROTS = {
	{x =  45, y = 0, z =  45},
	{x = -45, y = 0, z =  45},
	{x =  45, y = 0, z = -45},
	{x = -45, y = 0, z = -45},
}

core.register_entity(MODNAME .. ":boss_rock", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 1.02, y = 1.02, z = 1.02},
		textures = {
			ROCK_TEX, ROCK_TEX, ROCK_TEX,
			ROCK_TEX, ROCK_TEX, ROCK_TEX,
		},
		glow = 11,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_activate = function(self)
		self.vel = vector.zero()
		self.rot = vector.new(math.random() * 6, math.random() * 6, math.random() * 6)
		self.spin_vel = vector.new(
			(math.random() - 0.5) * 8.0,
			(math.random() - 0.5) * 8.0,
			(math.random() - 0.5) * 8.0
		)
		self.held = false
		self.grounded = false
		self.roll_timer = 0.0
		self.air_age = 0.0
		self.gen = boss_generation
		self.spikes = {}

		for i = 1, #ROCK_SPIKE_ROTS do
			local sp = core.add_entity(self.object:get_pos() or MOUTH_POS, MODNAME .. ":boss_rock_spike")
			if sp then
				local sent = sp:get_luaentity()
				sent.parent_obj = self.object
				sent.gen = self.gen
				sp:set_attach(self.object, "", {x = 0, y = 0, z = 0}, ROCK_SPIKE_ROTS[i], true)
				self.spikes[#self.spikes + 1] = sp
			end
		end
	end,

	on_deactivate = function(self)
		if boss.held_rock_obj == self.object then
			boss.held_rock_obj = nil
		end
		if self.spikes then
			for i = 1, #self.spikes do
				local sp = self.spikes[i]
				if sp and sp:is_valid() then
					sp:remove()
				end
			end
			self.spikes = nil
		end
	end,

	on_step = function(self, dtime)
		local dt = math.min(dtime, 0.1)
		if self.gen ~= boss_generation or not boss.spawned or boss.state == "dead" or boss.state == "dying" then
			self.object:remove()
			return
		end

		if self.held then
			self.rot = vector.add(self.rot, vector.multiply(self.spin_vel, dt * 1.4))
			self.object:set_rotation(self.rot)
			return
		end

		local pos = self.object:get_pos()
		if not pos then
			self.object:remove()
			return
		end

		self.air_age = self.air_age + dt
		if self.air_age > 10.0 or pos.y < 140.0 then
			self.object:remove()
			return
		end

		-- Check collision against active drivers (spin + damage)
		for name, dstate in pairs(back_tracks.active_drivers) do
			if dstate and dstate.hp > 0 and dstate.pos and not dstate.boss_swallow_lock and not dstate.boss_grabbed then
				local diff = vector.subtract(dstate.pos, pos)
				if vector.dot(diff, diff) <= ROCK_HIT_RADIUS * ROCK_HIT_RADIUS then
					back_tracks.damage_player(name, ROCK_DAMAGE)

					local push = safe_normalize(vector.new(
						diff.x * 0.6 + self.vel.x * 0.4,
						0.0,
						diff.z * 0.6 + self.vel.z * 0.4
					), vector.new(1, 0, 0))

					-- Pop briefly off suspension so tire steering damping doesn't instantly eat the spin
					dstate.pos.y = dstate.pos.y + 0.35
					dstate.vel = vector.new(
						dstate.vel.x * 0.65 + push.x * 19.0,
						math.max(dstate.vel.y, 7.5),
						dstate.vel.z * 0.65 + push.z * 19.0
					)

					local side = vector.dot(vector.subtract(pos, dstate.pos), dstate.right)
					local spin_sign = (side >= 0) and 1.0 or -1.0
					local spin_impulse = vector.add(
						vector.multiply(dstate.up, spin_sign * 7.2),
						vector.add(
							vector.multiply(dstate.forward, spin_sign * 2.4),
							vector.multiply(dstate.right, 1.5)
						)
					)
					dstate.ang_vel = vector.add(dstate.ang_vel, spin_impulse)

					back_tracks.spawn_explosion(pos, 0.95)
					spawn_rock_debris(pos, 16)
					self.object:remove()
					return
				end
			end
		end

		if not self.grounded then
			self.vel.y = self.vel.y - ROCK_GRAVITY * dt
			local next_pos = vector.add(pos, vector.multiply(self.vel, dt))
			local move_dir = safe_normalize(self.vel, vector.new(0, -1, 0))

			local hit = back_tracks.raycast_solid(pos, vector.add(next_pos, vector.multiply(move_dir, ROCK_RADIUS * 0.65)))
			if not hit then
				hit = back_tracks.raycast_solid(pos, vector.add(next_pos, vector.new(0, -ROCK_RADIUS, 0)))
			end

			if hit and hit.intersection_point and hit.intersection_normal then
				local n = hit.intersection_normal
				if n.y >= 0.5 then
					self.grounded = true
					self.roll_timer = ROCK_ROLL_MIN_TIME + math.random() * (ROCK_ROLL_MAX_TIME - ROCK_ROLL_MIN_TIME)
					next_pos = vector.add(hit.intersection_point, vector.new(0, ROCK_RADIUS, 0))
					self.vel.y = (self.vel.y < -6.0) and (-self.vel.y * 0.28) or 0.0
					spawn_rock_debris(hit.intersection_point, 8)
				else
					local vn = vector.dot(self.vel, n)
					if vn < 0 then
						self.vel = vector.subtract(self.vel, vector.multiply(n, 1.45 * vn))
					end
					next_pos = vector.add(hit.intersection_point, vector.multiply(n, ROCK_RADIUS + 0.1))
				end
			end

			self.rot = vector.add(self.rot, vector.multiply(self.spin_vel, dt))
			self.object:set_pos(next_pos)
			self.object:set_rotation(self.rot)
		else
			self.roll_timer = self.roll_timer - dt
			if self.roll_timer <= 0.0 then
				spawn_rock_debris(pos, 10)
				self.object:remove()
				return
			end

			local drag = math.max(0.0, 1.0 - 0.75 * dt)
			self.vel.x = self.vel.x * drag
			self.vel.z = self.vel.z * drag
			self.vel.y = self.vel.y - ROCK_GRAVITY * dt

			local next_pos = vector.add(pos, vector.multiply(self.vel, dt))

			local h_spd = math.sqrt(self.vel.x * self.vel.x + self.vel.z * self.vel.z)
			if h_spd > 0.2 then
				local h_dir = vector.new(self.vel.x / h_spd, 0, self.vel.z / h_spd)
				local wall_hit = back_tracks.raycast_solid(pos, vector.add(next_pos, vector.multiply(h_dir, ROCK_RADIUS + 0.1)))
				if wall_hit and wall_hit.intersection_normal and wall_hit.intersection_normal.y < 0.5 then
					local n = wall_hit.intersection_normal
					local vn = vector.dot(self.vel, n)
					if vn < 0 then
						self.vel = vector.subtract(self.vel, vector.multiply(n, 1.45 * vn))
					end
					next_pos = vector.add(wall_hit.intersection_point, vector.multiply(n, ROCK_RADIUS + 0.1))
				end
			end

			local gy = back_tracks.sample_smooth_ground_y(next_pos.x, next_pos.y, next_pos.z, 2.0)
			if gy and (next_pos.y - ROCK_RADIUS) <= gy + 0.20 and self.vel.y <= 0.0 then
				next_pos.y = gy + ROCK_RADIUS
				self.vel.y = 0.0
			end

			local roll_rate = h_spd / ROCK_RADIUS
			self.rot.x = self.rot.x + (self.vel.z / math.max(h_spd, 0.1)) * roll_rate * dt
			self.rot.z = self.rot.z - (self.vel.x / math.max(h_spd, 0.1)) * roll_rate * dt
			self.object:set_pos(next_pos)
			self.object:set_rotation(self.rot)
		end
	end,
})

local function compute_rock_launch_vel(origin, target_pos, target_vel)
	local dx = target_pos.x - origin.x
	local dz = target_pos.z - origin.z
	local horiz_dist = math.sqrt(dx * dx + dz * dz)
	local flight_t = clamp(horiz_dist / 36.0, 0.75, 2.35)

	local speed_h = target_vel and math.sqrt(target_vel.x * target_vel.x + target_vel.z * target_vel.z) or 0.0
	local lead_mult = 0.85
	local rand_ang = math.random() * 2.0 * math.pi
	local rand_dist = (speed_h > 5.0) and (2.0 + math.random() * 2.0) or (math.random() * 2.0)

	local pred_x = target_pos.x + (target_vel and target_vel.x or 0) * (flight_t * lead_mult) + math.cos(rand_ang) * rand_dist
	local pred_z = target_pos.z + (target_vel and target_vel.z or 0) * (flight_t * lead_mult) + math.sin(rand_ang) * rand_dist

	-- Keep target inside the Mesa rim wall
	local pdx, pdz = pred_x - MX, pred_z - MZ
	local pr = math.sqrt(pdx * pdx + pdz * pdz)
	if pr > 82.0 then
		pred_x = MX + (pdx / pr) * 82.0
		pred_z = MZ + (pdz / pr) * 82.0
	end

	local vx = (pred_x - origin.x) / flight_t
	local vz = (pred_z - origin.z) / flight_t
	local vy = ((target_pos.y + 0.5) - origin.y + 0.5 * ROCK_GRAVITY * flight_t * flight_t) / flight_t
	return vector.new(vx, vy, vz)
end

local function clear_active_throw(remove_held)
	if remove_held and boss.held_rock_obj and boss.held_rock_obj:is_valid() then
		boss.held_rock_obj:remove()
	end
	boss.held_rock_obj = nil
	boss.throwing_tent_id = nil
	boss.throw_windup_timer = 0.0
	boss.throw_follow_timer = 0.0
	boss.throw_target_name = nil
end

-----------------------------------------
-- Boss Cleanup & Reset
-----------------------------------------
local function remove_tentacle_list(list)
	for i = 1, #list do
		local tent = list[i]
		for k = 1, NUM_SEGMENTS do
			local seg = tent.segs[k]
			if seg then
				if seg.uid then
					back_tracks.enemies[seg.uid] = nil
				end
				if seg.obj and seg.obj:is_valid() then
					seg.obj:remove()
				end
			end
		end
	end
end

local function despawn_boss_entities()
	boss_generation = boss_generation + 1
	clear_active_throw(true)
	boss.last_throwing_tent_id = nil
	remove_tentacle_list(boss.inner)
	remove_tentacle_list(boss.outer)
	boss.inner = {}
	boss.outer = {}

	if boss.mouth_reg and boss.mouth_reg.uid then
		back_tracks.enemies[boss.mouth_reg.uid] = nil
	end
	if boss.mouth_obj and boss.mouth_obj:is_valid() then
		boss.mouth_obj:remove()
	end
	boss.mouth_obj = nil
	boss.mouth_reg = nil
	boss.spawned = false
end

local function clear_player_boss_hud(name)
	local h = boss_huds[name]
	if not h then return end
	local player = core.get_player_by_name(name)
	if player and player:is_player() then
		if h.title then player:hud_remove(h.title) end
		if h.bg then player:hud_remove(h.bg) end
		if h.bar then player:hud_remove(h.bar) end
		if h.status then player:hud_remove(h.status) end
	end
	boss_huds[name] = nil
end

function back_tracks.reset_boss()
	for name, dstate in pairs(back_tracks.active_drivers) do
		if dstate then
			dstate.boss_grabbed = nil
			dstate.boss_swallow_lock = false
			dstate.boss_last_grab_time = -100
			dstate.boss_second_grab = false
			dstate.boss_arena_entered = nil
		end
		shield_alerts[name] = nil
	end
	despawn_boss_entities()
	boss.hp = BOSS_MAX_HP
	boss.phase = 1
	boss.state = "active"
	boss.writhe_timer = 0.0
	boss.writhe_is_phase2 = false
	boss.death_timer = 0.0
	boss.rock_timer = 0.8
	boss.outer_sprouted = false
end

-----------------------------------------
-- Victory Formspec
-----------------------------------------
local function show_victory_formspec(player, kills)
	local fs = table.concat({
		"formspec_version[6]",
		"size[10.5,6.8]",
		"bgcolor[#0E0A16EE;both]",
		"box[0.4,0.4;9.7,6.0;#1B1428CC]",
		"hypertext[0.6,0.7;9.3,1.4;win_title;<center><bigger><style color=#FFDD44><b>YOU WIN!</b></style></bigger></center>]",
		"hypertext[0.8,2.1;8.9,1.8;win_body;<center><style color=#FFFFFF size=18>The Mesa Sarlacc has been defeated!</style>\n\n<style color=#88EEFF size=15>Enemies & Tentacles Subdued: " .. tostring(kills or 0) .. "</style></center>]",
		"button_exit[1.4,4.7;3.4,1.1;play_again;Play Again]",
		"button_exit[5.7,4.7;3.4,1.1;continue;Keep Driving]",
	})
	core.show_formspec(player:get_player_name(), MODNAME .. ":victory", fs)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= MODNAME .. ":victory" then return end
	if fields.play_again then
		local name = player:get_player_name()
		local dstate = back_tracks.active_drivers[name]
		if dstate then
			dstate.checkpoint_idx = 0
			dstate.kills = 0
		end
		player:set_hp(0)
		back_tracks.reset_boss()
		if back_tracks.respawn_all_turrets then
			back_tracks.respawn_all_turrets()
		end
	end
	return true
end)

-----------------------------------------
-- Tentacle Subdue, Grab Release & Damage
-----------------------------------------
local function count_subdued(list)
	local n = 0
	for i = 1, #list do
		if list[i].mode == "subdued" then
			n = n + 1
		end
	end
	return n
end

local function release_grab(tent, throw_outward)
	local target_name = tent.grab_target
	tent.grab_target = nil
	tent.grab_dmg_accum = 0
	if not target_name then return end

	local dstate = back_tracks.active_drivers[target_name]
	if not dstate then return end
	if dstate.boss_grabbed == tent.id then
		dstate.boss_grabbed = nil
		dstate.boss_grab_release_time = boss_time
	end

	if throw_outward and dstate.hp > 0 and not dstate.boss_swallow_lock then
		local out = vector.new(dstate.pos.x - MX, 0, dstate.pos.z - MZ)
		if vector.length(out) < 0.5 then
			out = vector.new(math.cos(tent.base_angle), 0, math.sin(tent.base_angle))
		else
			out = vector.normalize(out)
		end
		dstate.vel = vector.new(out.x * 25.0, 5.0, out.z * 25.0)
		back_tracks.spawn_explosion(dstate.pos, 1.1)
	end
end

local function set_tentacle_texture_mod(tent, mod_str)
	for k = 1, NUM_SEGMENTS do
		local seg = tent.segs[k]
		if seg and seg.obj and seg.obj:is_valid() then
			seg.obj:set_texture_mod(mod_str)
		end
	end
end

local function subdue_tentacle(tent, killer_name, throw_if_grabbed)
	if tent.mode == "subdued" then return end
	if tent.mode == "grab" then
		release_grab(tent, throw_if_grabbed)
	end
	if boss.throwing_tent_id == tent.id then
		clear_active_throw(true)
		boss.rock_timer = 0.45
	end

	tent.mode = "subdued"
	tent.subdue_timer = tent.is_outer and OUTER_SUBDUE_TIME or INNER_SUBDUE_TIME
	tent.hp = 0
	tent.flash_timer = 0
	tent.recoil_timer = 0
	set_tentacle_texture_mod(tent, "^[multiply:#886655")

	for k = 1, NUM_SEGMENTS do
		local seg = tent.segs[k]
		if seg and seg.reg then
			seg.reg.dead = true
		end
	end

	local mid_pos = tent.joints[3] or tent.base_pos
	back_tracks.spawn_explosion(mid_pos, 1.2)
	if killer_name then
		back_tracks.register_kill(killer_name)
	end
end

local function revive_tentacle(tent, tex_mod)
	tent.mode = "wave"
	tent.hp = TENTACLE_MAX_HP
	tent.subdue_timer = 0
	tent.flash_timer = 0
	tent.recoil_timer = 0
	tent.grab_dmg_accum = 0
	set_tentacle_texture_mod(tent, tex_mod or "")
	for k = 1, NUM_SEGMENTS do
		local seg = tent.segs[k]
		if seg and seg.reg then
			seg.reg.dead = false
		end
	end
end

-----------------------------------------
-- Tentacle & Mouth Spawning
-----------------------------------------
local function create_tentacle(id, is_outer, angle)
	local base_r = is_outer and OUTER_BASE_R or INNER_BASE_R
	local seg_lens = is_outer and OUTER_SEG_LEN or INNER_SEG_LEN
	local base_y = is_outer and 179.6 or 179.2
	local base_pos = vector.new(MX + math.cos(angle) * base_r, base_y, MZ + math.sin(angle) * base_r)

	local tent = {
		id = id,
		is_outer = is_outer,
		base_angle = angle,
		base_pos = base_pos,
		seg_lens = seg_lens,
		mode = is_outer and "sprout" or "wave",
		sprout_timer = is_outer and 0.7 or 0.0,
		hp = TENTACLE_MAX_HP,
		subdue_timer = 0.0,
		flash_timer = 0.0,
		recoil_timer = 0.0,
		grab_target = nil,
		grab_dmg_accum = 0,
		tip_push_cd = {},
		seed = id * 1.73,
		dirs = {},
		joints = {},
		segs = {},
	}

	local init_dir = safe_normalize(vector.new(math.cos(angle), 0.7, math.sin(angle)))
	tent.joints[0] = vector.copy(base_pos)
	for k = 1, NUM_SEGMENTS do
		tent.dirs[k] = vector.copy(init_dir)
		tent.joints[k] = vector.add(tent.joints[k - 1], vector.multiply(init_dir, seg_lens[k]))
	end

	for k = 1, NUM_SEGMENTS do
		local p_mid = vector.multiply(vector.add(tent.joints[k - 1], tent.joints[k]), 0.5)
		local obj = core.add_entity(p_mid, MODNAME .. ":boss_tentacle_seg")
		if obj then
			local uid = next_boss_uid
			next_boss_uid = next_boss_uid + 1
			local ent = obj:get_luaentity()
			ent.uid = uid

			local w = SEG_WIDTH[k]
			local tex = SEG_TEX[k]
			obj:set_properties({
				visual_size = {x = w, y = w, z = seg_lens[k] + 0.30},
				textures = {tex, tex, tex, tex, tex, tex},
			})
			obj:set_rotation(vector.dir_to_rotation(tent.dirs[k]))

			local reg = {
				uid = uid,
				obj = obj,
				pos = p_mid,
				dead = false,
				hit_radius = SEG_HIT_R[k],
				damage = function(amount, killer_name)
					if tent.mode == "subdued" or boss.state == "dead" or boss.state == "dying" then
						return
					end
					tent.hp = tent.hp - amount
					tent.flash_timer = 0.10
					tent.recoil_timer = 0.55
					set_tentacle_texture_mod(tent, "^[brighten")

					if tent.mode == "grab" then
						tent.grab_dmg_accum = tent.grab_dmg_accum + amount
						if tent.grab_dmg_accum >= GRAB_ESCAPE_DMG or tent.hp <= 0 then
							subdue_tentacle(tent, killer_name, true)
						end
					elseif tent.hp <= 0 then
						subdue_tentacle(tent, killer_name, false)
					end
				end,
			}
			back_tracks.enemies[uid] = reg
			tent.segs[k] = {obj = obj, uid = uid, reg = reg}
		end
	end

	return tent
end

local function trigger_mouth_hit()
	local m_obj = boss.mouth_obj
	boss.hp = math.max(0, boss.hp - 1)
	boss.state = "writhing"
	if boss.mouth_reg then
		boss.mouth_reg.dead = true
	end
	clear_active_throw(true)

	local is_p2_transition = (boss.hp <= BOSS_PHASE2_HP and boss.phase == 1)
	local writhe_mod = is_p2_transition and MOUTH_VIOLET_MOD or ""

	-- Release any grabbing tentacle and instantly recover ALL tentacles so they all writhe
	for i = 1, #boss.inner do
		local t = boss.inner[i]
		if t.mode == "grab" then
			release_grab(t, true)
		end
		revive_tentacle(t, writhe_mod)
	end
	for i = 1, #boss.outer do
		local t = boss.outer[i]
		if t.mode == "grab" then
			release_grab(t, true)
		end
		revive_tentacle(t, writhe_mod)
	end

	if is_p2_transition then
		boss.phase = 2
		boss.writhe_is_phase2 = true
		boss.writhe_timer = WRITHE_TIME_PHASE2
		if m_obj and m_obj:is_valid() then
			m_obj:set_texture_mod(MOUTH_VIOLET_MOD)
		end
		back_tracks.spawn_explosion(vector.new(MX, 182, MZ), 2.2)

		-- Sprout 4 outer tentacles in between the 4 cardinal ramps
		if not boss.outer_sprouted then
			boss.outer_sprouted = true
			for i = 0, NUM_OUTER_TENTACLES - 1 do
				local ang = (i + 0.5) * (math.pi * 0.5)
				boss.outer[i + 1] = create_tentacle(100 + i + 1, true, ang)
				back_tracks.spawn_explosion(boss.outer[i + 1].base_pos, 1.5)
			end
		end
	else
		boss.writhe_is_phase2 = false
		boss.writhe_timer = WRITHE_TIME_NORMAL
		if m_obj and m_obj:is_valid() then
			m_obj:set_texture_mod("^[brighten")
		end
		back_tracks.spawn_explosion(vector.new(MX, 181, MZ), 1.6)
	end
end

function back_tracks.is_bomb_hit_mouth(pos)
	if not boss.spawned or boss.state ~= "active" or not pos then
		return false
	end
	return math.abs(pos.x - MX) <= (MOUTH_EAT_RX + 1.5)
		and math.abs(pos.z - MZ) <= (MOUTH_EAT_RZ + 1.5)
		and pos.y <= 181.8
		and pos.y >= 176.0
end

function back_tracks.on_bomb_explode(pos, owner_name)
	if not boss.spawned or boss.state ~= "active" or not pos then
		return
	end

	local dx = math.abs(pos.x - MX)
	local dz = math.abs(pos.z - MZ)
	local hit_mouth = (dx <= MOUTH_EAT_RX + 3.0 and dz <= MOUTH_EAT_RZ + 3.0 and pos.y <= 186.0)
		or (vector.distance(pos, MOUTH_POS) <= MOUTH_HIT_RADIUS + 2.5)

	if hit_mouth then
		local inner_sub = count_subdued(boss.inner)
		if inner_sub < REQUIRED_INNER_SUBDUED then
			set_player_alert(owner_name, "SHIELDED! SUBDUE MORE TENTACLES!", 2.2)
			back_tracks.spawn_explosion(vector.new(MX, 184, MZ), 0.7)
		else
			trigger_mouth_hit()
			return
		end
	end

	-- Splash damage (at most once per tentacle) for nearby tentacles
	local splash_r2 = 5.5 * 5.5
	local function splash_list(list)
		for i = 1, #list do
			local tent = list[i]
			if tent.mode ~= "subdued" and tent.mode ~= "sprout" then
				for k = 1, NUM_SEGMENTS do
					local seg = tent.segs[k]
					if seg and seg.reg and not seg.reg.dead and seg.reg.pos then
						local diff = vector.subtract(seg.reg.pos, pos)
						if vector.dot(diff, diff) <= splash_r2 then
							seg.reg.damage(35, owner_name)
							break
						end
					end
				end
			end
		end
	end
	splash_list(boss.inner)
	splash_list(boss.outer)
end

local function spawn_boss()
	if boss.spawned then return end
	local ground_node = core.get_node_or_nil({x = MX, y = 179, z = MZ})
	if not ground_node or ground_node.name == "ignore" then
		return
	end

	boss.spawned = true
	boss.hp = BOSS_MAX_HP
	boss.phase = 1
	boss.state = "active"
	boss.writhe_timer = 0.0
	boss.writhe_is_phase2 = false
	boss.death_timer = 0.0
	boss.rock_timer = 0.8
	boss.last_throwing_tent_id = nil
	clear_active_throw(true)
	boss.outer_sprouted = false

	local m_obj = core.add_entity(MOUTH_POS, MODNAME .. ":boss_mouth")
	if m_obj then
		local uid = next_boss_uid
		next_boss_uid = next_boss_uid + 1
		m_obj:get_luaentity().uid = uid

		local reg = {
			uid = uid,
			obj = m_obj,
			pos = vector.copy(MOUTH_POS),
			dead = false,
			hit_radius = MOUTH_HIT_RADIUS,
			damage = function(_amount, killer_name)
				if boss.state ~= "active" then return end

				if count_subdued(boss.inner) < REQUIRED_INNER_SUBDUED then
					set_player_alert(killer_name, "SHIELDED! SUBDUE MORE TENTACLES!", 2.2)
					back_tracks.spawn_explosion(vector.new(MX, 184, MZ), 0.5)
				else
					set_player_alert(killer_name, "DROP A BOMB ON THE MOUTH (RIGHT-CLICK)!", 2.2)
				end
			end,
		}
		back_tracks.enemies[uid] = reg
		boss.mouth_obj = m_obj
		boss.mouth_reg = reg
	end

	for i = 0, NUM_INNER_TENTACLES - 1 do
		local ang = i * (2.0 * math.pi / NUM_INNER_TENTACLES)
		boss.inner[i + 1] = create_tentacle(i + 1, false, ang)
	end
end

-----------------------------------------
-- Tentacle Target Pose & Physics Tick
-----------------------------------------
local function compute_target_dirs(tent, any_airborne, lunge_target_pos)
	local dirs = {}
	local t = boss_time
	local s = tent.seed
	local ang = tent.base_angle
	local rad_x, rad_z = math.cos(ang), math.sin(ang)
	local tan_x, tan_z = -rad_z, rad_x

	if tent.mode == "subdued" then
		for k = 1, NUM_SEGMENTS do
			local droop = (k == 1) and 0.04 or -0.02
			local wiggle = 0.06 * math.sin(s * 3.1 + k)
			dirs[k] = safe_normalize(vector.new(rad_x + tan_x * wiggle, droop, rad_z + tan_z * wiggle))
		end
		return dirs
	end

	if tent.mode == "sprout" then
		for k = 1, NUM_SEGMENTS do
			dirs[k] = safe_normalize(vector.new(rad_x * 0.3, 1.0, rad_z * 0.3))
		end
		return dirs
	end

	if boss.state == "writhing" or boss.state == "dying" then
		local whip_speed = boss.writhe_is_phase2 and 16.5 or 13.0
		for k = 1, NUM_SEGMENTS do
			local phase = t * whip_speed + s * 2.1 - k * 1.15
			local sweep_amp = 0.95 + k * 0.22
			local thrash_a = ang + sweep_amp * math.sin(phase)
				+ 0.45 * math.cos(t * (whip_speed * 0.63) - s + k * 0.8)
			local thrash_y = 0.45 + 1.05 * math.sin(t * (whip_speed * 0.85) + s * 1.7 - k * 0.95)
			local radial_push = 0.85 + 0.45 * math.cos(t * (whip_speed * 0.52) + s - k * 0.7)
			dirs[k] = safe_normalize(vector.new(
				math.cos(thrash_a) * radial_push,
				thrash_y,
				math.sin(thrash_a) * radial_push
			))
		end
		return dirs
	end

	if tent.mode == "grab" and tent.grab_target then
		local gstate = back_tracks.active_drivers[tent.grab_target]
		if gstate and gstate.pos then
			local tp = gstate.pos
			local cur = vector.copy(tent.base_pos)
			for k = 1, NUM_SEGMENTS do
				local dist_to_truck = vector.distance(cur, tp)
				local d
				if k <= 2 or dist_to_truck > 4.2 then
					local to_t = vector.subtract(vector.new(tp.x, tp.y + 0.6, tp.z), cur)
					d = safe_normalize(to_t)
				else
					local wrap_ang = (k - 2) * 1.65 + t * 2.2
					local coil_pt = vector.new(
						tp.x + math.cos(wrap_ang) * 2.1,
						tp.y + 0.5 + 0.4 * math.sin(k + t * 4.0),
						tp.z + math.sin(wrap_ang) * 2.1
					)
					d = safe_normalize(vector.subtract(coil_pt, cur))
				end
				dirs[k] = d
				cur = vector.add(cur, vector.multiply(d, tent.seg_lens[k]))
			end
			return dirs
		end
	end

	-- Rock-Throw Windup & Follow-Through (mutually exclusive with lunging/pointing)
	if boss.throwing_tent_id == tent.id then
		local tstate = boss.throw_target_name and back_tracks.active_drivers[boss.throw_target_name]
		local aim_horiz
		if tstate and tstate.pos then
			aim_horiz = safe_normalize(vector.new(tstate.pos.x - tent.base_pos.x, 0.0, tstate.pos.z - tent.base_pos.z), vector.new(rad_x, 0.0, rad_z))
		else
			aim_horiz = vector.new(rad_x, 0.0, rad_z)
		end

		if boss.throw_windup_timer > 0.0 then
			tent.mode = "windup"
			local u = clamp(1.0 - (boss.throw_windup_timer / ROCK_WINDUP_TIME), 0.0, 1.0)
			local back_pull = 0.45 + 0.95 * u
			for k = 1, NUM_SEGMENTS do
				local lift_y = 1.20 - (k - 1) * 0.14
				local back_scale = (k <= 2) and (back_pull * 0.55) or back_pull
				dirs[k] = safe_normalize(vector.new(
					-aim_horiz.x * back_scale + tan_x * (0.12 * math.sin(t * 12.0 + k)),
					lift_y,
					-aim_horiz.z * back_scale + tan_z * (0.12 * math.sin(t * 12.0 + k))
				))
			end
			return dirs
		elseif boss.throw_follow_timer > 0.0 then
			tent.mode = "throw_follow"
			for k = 1, NUM_SEGMENTS do
				dirs[k] = safe_normalize(vector.new(
					aim_horiz.x * 1.15,
					0.55 - (k - 1) * 0.14,
					aim_horiz.z * 1.15
				))
			end
			return dirs
		end
	end

	-- Airborne Defense: rise up to cover the mouth & lunge at flying truck
	if any_airborne then
		tent.mode = "wave"
		local truck_ang = math.atan2(any_airborne.z - MZ, any_airborne.x - MX)
		local near_flyer = math.abs(angle_diff(ang, truck_ang)) < 0.85
		local cur = vector.copy(tent.base_pos)
		local target_pt = near_flyer and any_airborne or vector.new(MX, 193.5, MZ)

		for k = 1, NUM_SEGMENTS do
			local d
			if near_flyer and k >= 2 then
				d = safe_normalize(vector.subtract(target_pt, cur))
			else
				local dome_pt = vector.new(
					MX + rad_x * (10.0 - k * 1.6),
					183.0 + k * 3.8 + 1.2 * math.sin(t * 4.5 + s + k),
					MZ + rad_z * (10.0 - k * 1.6)
				)
				d = safe_normalize(vector.subtract(dome_pt, cur))
			end
			dirs[k] = d
			cur = vector.add(cur, vector.multiply(d, tent.seg_lens[k]))
		end
		return dirs
	end

	-- Single closest tentacle lunges / points at truck
	if lunge_target_pos then
		tent.mode = "lunge"
		local cur = vector.copy(tent.base_pos)
		for k = 1, NUM_SEGMENTS do
			local aim_pt = vector.new(
				lunge_target_pos.x,
				lunge_target_pos.y + ((k == 1) and 3.8 or 0.4),
				lunge_target_pos.z
			)
			local d = safe_normalize(vector.subtract(aim_pt, cur))
			dirs[k] = d
			cur = vector.add(cur, vector.multiply(d, tent.seg_lens[k]))
		end
		return dirs
	end

	-- Default: agile waving & evasive weaving (speeds up when hurt or recoiling from shots)
	tent.mode = "wave"
	local hurt_ratio = 1.0 - clamp(tent.hp / TENTACLE_MAX_HP, 0.0, 1.0)
	local recoil_boost = (tent.recoil_timer > 0.0) and 1.65 or 0.0
	local sway_speed = 1.0 + hurt_ratio * 0.85 + recoil_boost
	local sway_amp = 1.0 + hurt_ratio * 0.45 + recoil_boost * 0.35

	for k = 1, NUM_SEGMENTS do
		local yaw_wobble = (0.68 * sway_amp) * math.sin(t * 2.1 * sway_speed + s * 1.7 - k * 0.75)
			+ (0.32 * sway_amp) * math.cos(t * 3.6 * sway_speed - s + k * 0.9)
		local cur_ang = ang + yaw_wobble
		local pitch_y = 0.62 - (k - 1) * 0.18
			+ (0.48 * sway_amp) * math.sin(t * 2.6 * sway_speed + s * 2.3 - k * 0.85)
		local outward = tent.is_outer and (math.sin(t * 0.9 + s) * 0.90) or 1.0
		dirs[k] = safe_normalize(vector.new(
			math.cos(cur_ang) * outward,
			pitch_y,
			math.sin(cur_ang) * outward
		))
	end
	return dirs
end

local function step_tentacle(tent, dt, any_airborne, lunge_target_pos)
	if tent.recoil_timer > 0 then
		tent.recoil_timer = math.max(0.0, tent.recoil_timer - dt)
	end

	if tent.flash_timer > 0 then
		tent.flash_timer = tent.flash_timer - dt
		if tent.flash_timer <= 0 then
			tent.flash_timer = 0
			if tent.mode == "subdued" then
				set_tentacle_texture_mod(tent, "^[multiply:#886655")
			elseif boss.throwing_tent_id == tent.id and boss.throw_windup_timer > 0 then
				set_tentacle_texture_mod(tent, WINDUP_MOD)
			elseif boss.state == "writhing" and boss.writhe_is_phase2 then
				set_tentacle_texture_mod(tent, MOUTH_VIOLET_MOD)
			else
				set_tentacle_texture_mod(tent, "")
			end
		end
	elseif boss.throwing_tent_id == tent.id and boss.throw_windup_timer > 0 and tent.mode ~= "subdued" then
		set_tentacle_texture_mod(tent, WINDUP_MOD)
	end

	if tent.mode == "sprout" then
		tent.sprout_timer = tent.sprout_timer - dt
		if tent.sprout_timer <= 0 then
			tent.mode = "wave"
		end
	elseif tent.mode == "subdued" then
		tent.subdue_timer = tent.subdue_timer - dt
		if tent.subdue_timer <= 0 then
			revive_tentacle(tent)
		end
	end

	local target_dirs = compute_target_dirs(tent, any_airborne, lunge_target_pos)
	local blend_rate
	if boss.state == "writhing" or boss.state == "dying" then
		blend_rate = 18.0
	elseif tent.mode == "throw_follow" then
		blend_rate = 22.0
	elseif tent.mode == "windup" then
		blend_rate = 14.0
	elseif tent.mode == "grab" then
		blend_rate = 14.0
	elseif tent.mode == "lunge" or any_airborne then
		blend_rate = 9.0
	elseif tent.recoil_timer > 0 then
		blend_rate = 10.5
	else
		blend_rate = 5.4
	end
	local alpha = 1.0 - math.exp(-blend_rate * dt)

	local cur_pos = vector.copy(tent.base_pos)
	if tent.mode == "sprout" then
		cur_pos.y = tent.base_pos.y - (tent.sprout_timer / 0.7) * 8.0
	end
	tent.joints[0] = cur_pos

	for k = 1, NUM_SEGMENTS do
		local blended = vector.add(
			vector.multiply(tent.dirs[k], 1.0 - alpha),
			vector.multiply(target_dirs[k], alpha)
		)
		tent.dirs[k] = safe_normalize(blended, target_dirs[k])
		tent.joints[k] = vector.add(tent.joints[k - 1], vector.multiply(tent.dirs[k], tent.seg_lens[k]))

		local seg = tent.segs[k]
		if seg and seg.obj and seg.obj:is_valid() then
			local p_mid = vector.multiply(vector.add(tent.joints[k - 1], tent.joints[k]), 0.5)
			seg.obj:set_pos(p_mid)
			seg.obj:set_rotation(vector.dir_to_rotation(tent.dirs[k]))
			if seg.reg then
				seg.reg.pos = p_mid
			end
		end
	end

	-- Active Grab pull & grasp damage
	if tent.mode == "grab" and tent.grab_target then
		local dstate = back_tracks.active_drivers[tent.grab_target]
		if not dstate or dstate.hp <= 0 or dstate.boss_swallow_lock or boss.state ~= "active" then
			release_grab(tent, false)
			if tent.mode == "grab" then tent.mode = "wave" end
		else
			local to_mouth = vector.new(MX - dstate.pos.x, 0, MZ - dstate.pos.z)
			local h_dist = vector.length(to_mouth)
			local pull_dir = (h_dist > 0.1) and vector.multiply(to_mouth, 1.0 / h_dist) or vector.zero()

			dstate.vel = vector.multiply(dstate.vel, math.max(0.0, 1.0 - 9.0 * dt))
			dstate.pos = vector.add(dstate.pos, vector.multiply(pull_dir, GRAB_PULL_SPEED * dt))
			if dstate.pos.y < 180.5 then
				dstate.pos.y = 180.5
			elseif dstate.pos.y > 183.0 then
				dstate.pos.y = dstate.pos.y - 3.5 * dt
			end

			dstate.hp_delay = 2.5
			if dstate.boss_second_grab then
				dstate.hp = math.max(0.0, dstate.hp - GRAB_SECOND_DPS * dt)
			elseif dstate.hp > GRAB_FIRST_FLOOR_HP then
				dstate.hp = math.max(GRAB_FIRST_FLOOR_HP, dstate.hp - GRAB_FIRST_DPS * dt)
			end
		end
		return
	end

	-- Check collisions between moving tentacle segments and ungrabbed trucks
	if boss.state ~= "active" or tent.mode == "subdued" or tent.mode == "sprout" then
		return
	end

	for name, dstate in pairs(back_tracks.active_drivers) do
		if dstate and dstate.hp > 0 and dstate.pos and not dstate.boss_swallow_lock and not dstate.boss_grabbed then
			local tp = dstate.pos
			local can_grab = (boss_time - (dstate.boss_grab_release_time or -100)) > GRAB_RELEASE_IMMUNITY

			local grabbed_now = false
			if can_grab then
				for k = 2, 4 do
					local cp = closest_point_on_seg(tp, tent.joints[k - 1], tent.joints[k])
					local diff = vector.subtract(tp, cp)
					local hit_dist = SEG_TOUCH_R[k] + 1.55
					if vector.dot(diff, diff) <= hit_dist * hit_dist then
						if boss.throwing_tent_id == tent.id then
							clear_active_throw(true)
							boss.rock_timer = 0.45
						end
						tent.mode = "grab"
						tent.grab_target = name
						tent.grab_dmg_accum = 0
						dstate.boss_grabbed = tent.id
						if (boss_time - (dstate.boss_last_grab_time or -100)) <= DOUBLE_GRAB_WINDOW then
							dstate.boss_second_grab = true
						else
							dstate.boss_second_grab = false
						end
						dstate.boss_last_grab_time = boss_time
						grabbed_now = true
						break
					end
				end
			end

			if not grabbed_now and (boss_time - (tent.tip_push_cd[name] or -100)) > TIP_PUSH_COOLDOWN then
				local cp = closest_point_on_seg(tp, tent.joints[4], tent.joints[5])
				local diff = vector.subtract(tp, cp)
				local hit_dist = SEG_TOUCH_R[5] + 1.70
				if vector.dot(diff, diff) <= hit_dist * hit_dist then
					tent.tip_push_cd[name] = boss_time
					local push_dir = safe_normalize(vector.new(diff.x, 0.35, diff.z), vector.new(math.cos(tent.base_angle), 0.35, math.sin(tent.base_angle)))
					dstate.vel = vector.add(dstate.vel, vector.multiply(push_dir, TIP_PUSH_IMPULSE))
					if dstate.hp > 18.0 then
						dstate.hp = math.max(18.0, dstate.hp - 5.0)
						dstate.hp_delay = 2.0
					end
				end
			end
		end
	end
end

-----------------------------------------
-- Boss HUD Update
-----------------------------------------
local function update_boss_hud(name, player, dstate, dt)
	local show_hud = is_driver_in_boss_arena(dstate) and (boss.state ~= "dead")

	if not show_hud then
		clear_player_boss_hud(name)
		return
	end

	local h = boss_huds[name]
	if not h then
		local title = player:hud_add({
			type = "text",
			position = {x = 0.5, y = 0.05},
			offset = {x = 0, y = 0},
			text = "MESA SARLACC",
			alignment = {x = 0, y = 0},
			number = 0xFF7744,
			size = {x = 1.5, y = 1.5},
		})
		local bg = player:hud_add({
			type = "image",
			position = {x = 0.5, y = 0.085},
			offset = {x = 0, y = 0},
			text = "[fill:16x16:#221122",
			scale = {x = 240 / 16, y = 14 / 16},
			alignment = {x = 0, y = 0},
		})
		local bar = player:hud_add({
			type = "image",
			position = {x = 0.5, y = 0.085},
			offset = {x = -120, y = 0},
			text = "[fill:16x16:#FF3344",
			scale = {x = 240 / 16, y = 14 / 16},
			alignment = {x = 1, y = 0},
		})
		local status = player:hud_add({
			type = "text",
			position = {x = 0.5, y = 0.125},
			offset = {x = 0, y = 0},
			text = "",
			alignment = {x = 0, y = 0},
			number = 0xFFDD44,
			size = {x = 1.2, y = 1.2},
		})
		h = {
			title = title,
			bg = bg,
			bar = bar,
			status = status,
			last_hp = -1,
			last_phase = -1,
			last_status = "",
			last_color = 0xFFDD44,
		}
		boss_huds[name] = h
	end

	if h.last_hp ~= boss.hp then
		local px = math.max(1, math.floor((boss.hp / BOSS_MAX_HP) * 240 + 0.5))
		player:hud_change(h.bar, "scale", {x = px / 16, y = 14 / 16})
		h.last_hp = boss.hp
	end
	if h.last_phase ~= boss.phase then
		local bar_tex = (boss.phase == 2) and "[fill:16x16:#BB33FF" or "[fill:16x16:#FF3344"
		player:hud_change(h.bar, "text", bar_tex)
		h.last_phase = boss.phase
	end

	local alert = shield_alerts[name]
	if alert then
		alert.timer = alert.timer - dt
		if alert.timer <= 0 then
			shield_alerts[name] = nil
			alert = nil
		end
	end

	local status_txt = ""
	local status_col = 0xFFCC44
	if dstate.boss_swallow_lock then
		status_txt = "BEING SWALLOWED!"
		status_col = 0xFF2222
	elseif dstate.boss_grabbed then
		status_txt = "GRABBED! SHOOT THE TENTACLE TO BREAK FREE!"
		status_col = 0xFF4422
	elseif boss.state == "writhing" then
		status_txt = boss.writhe_is_phase2 and "PHASE 2! OUTER TENTACLES EMERGING!" or "BEAST WRITHING!"
		status_col = boss.writhe_is_phase2 and 0xCC66FF or 0xFFDD44
	elseif alert then
		status_txt = alert.msg
		status_col = 0xFFAA33
	else
		local in_sub = count_subdued(boss.inner)
		if in_sub >= REQUIRED_INNER_SUBDUED then
			status_txt = "MOUTH EXPOSED! RAMP JUMP & DROP A BOMB (RMB)!"
			status_col = 0x44FF88
		else
			status_txt = string.format("SUBDUE TENTACLES: %d/%d", in_sub, REQUIRED_INNER_SUBDUED)
			status_col = (boss.phase == 2) and 0xCC88FF or 0xFFCC66
		end
	end

	if status_txt ~= h.last_status then
		player:hud_change(h.status, "text", status_txt)
		h.last_status = status_txt
	end
	if status_col ~= h.last_color then
		player:hud_change(h.status, "number", status_col)
		h.last_color = status_col
	end
end

-----------------------------------------
-- Single-Tentacle Selection (Lunge vs Throw Windup)
-----------------------------------------
local function select_lunge_targets()
	local lunge_targets = {}
	if boss.state ~= "active" then
		return lunge_targets
	end

	for _, dstate in pairs(back_tracks.active_drivers) do
		if is_driver_in_boss_arena(dstate) and dstate.hp > 0 and not dstate.boss_swallow_lock and not dstate.boss_grabbed then
			local best_tent = nil
			local best_d2 = 50.0 * 50.0

			local function check_list(list)
				for i = 1, #list do
					local tent = list[i]
					if tent.mode ~= "subdued" and tent.mode ~= "sprout" and tent.mode ~= "grab"
						and tent.hp > 0
						and tent.id ~= boss.throwing_tent_id
						and not lunge_targets[tent.id] then
						local diff = vector.subtract(dstate.pos, tent.base_pos)
						local d2 = vector.dot(diff, diff)
						if d2 <= best_d2 then
							best_d2 = d2
							best_tent = tent
						end
					end
				end
			end

			check_list(boss.inner)
			check_list(boss.outer)
			if best_tent then
				lunge_targets[best_tent.id] = vector.copy(dstate.pos)
			end
		end
	end

	return lunge_targets
end

local function step_rock_throws(dt, lunge_targets)
	if boss.state ~= "active" then
		if boss.throwing_tent_id then
			clear_active_throw(true)
		end
		return
	end

	-- Advance active windup or throw follow-through (only one working arm throws at a time)
	if boss.throwing_tent_id then
		local throwing_tent = find_tentacle_by_id(boss.throwing_tent_id)
		if not throwing_tent
			or throwing_tent.mode == "subdued"
			or throwing_tent.mode == "grab"
			or throwing_tent.mode == "sprout"
			or throwing_tent.hp <= 0 then
			clear_active_throw(true)
			boss.rock_timer = 0.35
			return
		end

		local tip_pos = throwing_tent.joints[NUM_SEGMENTS] or throwing_tent.base_pos

		if boss.throw_windup_timer > 0.0 then
			boss.throw_windup_timer = boss.throw_windup_timer - dt
			if boss.held_rock_obj and boss.held_rock_obj:is_valid() then
				boss.held_rock_obj:set_pos(tip_pos)
			end

			if boss.throw_windup_timer <= 0.0 then
				boss.throw_windup_timer = 0.0
				boss.throw_follow_timer = ROCK_FOLLOW_TIME
				set_tentacle_texture_mod(throwing_tent, "")

				local tstate = boss.throw_target_name and back_tracks.active_drivers[boss.throw_target_name]
				if not tstate or not is_driver_in_boss_arena(tstate) or tstate.hp <= 0 then
					tstate = nil
					for _, ds in pairs(back_tracks.active_drivers) do
						if is_driver_in_boss_arena(ds) and ds.hp > 0 and not ds.boss_swallow_lock then
							tstate = ds
							break
						end
					end
				end

				if boss.held_rock_obj and boss.held_rock_obj:is_valid() and tstate then
					local ent = boss.held_rock_obj:get_luaentity()
					boss.held_rock_obj:set_pos(tip_pos)
					ent.vel = compute_rock_launch_vel(tip_pos, tstate.pos, tstate.vel)
					ent.held = false
					ent.air_age = 0.0
					boss.held_rock_obj = nil
				else
					if boss.held_rock_obj and boss.held_rock_obj:is_valid() then
						boss.held_rock_obj:remove()
					end
					boss.held_rock_obj = nil
				end
			end
			return
		end

		if boss.throw_follow_timer > 0.0 then
			boss.throw_follow_timer = boss.throw_follow_timer - dt
			if boss.throw_follow_timer <= 0.0 then
				clear_active_throw(true)
				boss.rock_timer = (boss.phase == 2) and ROCK_THROW_INTERVAL_P2 or ROCK_THROW_INTERVAL_P1
			end
			return
		end

		clear_active_throw(true)
		return
	end

	-- Pick a valid driver anywhere inside the arena to target
	local target_name = nil
	local target_state = nil
	local best_d2 = 1e9
	local any_slow_camper = false
	for name, dstate in pairs(back_tracks.active_drivers) do
		if is_driver_in_boss_arena(dstate) and dstate.hp > 0 and not dstate.boss_swallow_lock and not dstate.boss_grabbed then
			local dx = dstate.pos.x - MX
			local dz = dstate.pos.z - MZ
			local d2 = dx * dx + dz * dz
			if d2 < best_d2 then
				best_d2 = d2
				target_name = name
				target_state = dstate
			end
			if vector.length(dstate.vel) < 12.0 then
				any_slow_camper = true
			end
		end
	end

	if not target_state then return end

	local tick_mult = any_slow_camper and 1.35 or 1.0
	boss.rock_timer = boss.rock_timer - dt * tick_mult
	if boss.rock_timer > 0.0 then return end

	-- Collect working (healthy/waving, non-pointing) arms facing toward the target
	local target_ang = math.atan2(target_state.pos.z - MZ, target_state.pos.x - MX)
	local candidates = {}

	local function collect_working(list)
		for i = 1, #list do
			local tent = list[i]
			if tent.mode == "wave" and tent.hp > 0 and not lunge_targets[tent.id] then
				local ad = math.abs(angle_diff(tent.base_angle, target_ang))
				candidates[#candidates + 1] = {tent = tent, ad = ad}
			end
		end
	end

	collect_working(boss.inner)
	if boss.phase == 2 then
		collect_working(boss.outer)
	end

	if #candidates == 0 then
		boss.rock_timer = 0.25
		return
	end

	table.sort(candidates, function(a, b) return a.ad < b.ad end)
	local pool_n = math.min(3, #candidates)
	local best_tent = nil
	if pool_n > 1 then
		local non_repeat = {}
		for i = 1, pool_n do
			if candidates[i].tent.id ~= boss.last_throwing_tent_id then
				non_repeat[#non_repeat + 1] = candidates[i].tent
			end
		end
		if #non_repeat > 0 then
			best_tent = non_repeat[math.random(1, #non_repeat)]
		end
	end
	if not best_tent then
		best_tent = candidates[1].tent
	end

	local tip_pos = best_tent.joints[NUM_SEGMENTS] or best_tent.base_pos
	local rock = core.add_entity(tip_pos, MODNAME .. ":boss_rock")
	if rock then
		local ent = rock:get_luaentity()
		ent.held = true
		ent.gen = boss_generation
		boss.held_rock_obj = rock
		boss.throwing_tent_id = best_tent.id
		boss.last_throwing_tent_id = best_tent.id
		boss.throw_windup_timer = ROCK_WINDUP_TIME
		boss.throw_follow_timer = 0.0
		boss.throw_target_name = target_name
		best_tent.mode = "windup"
		set_tentacle_texture_mod(best_tent, WINDUP_MOD)
	else
		boss.rock_timer = 0.25
	end
end

-----------------------------------------
-- Globalstep: Boss Lifecycle, Swallow & Tentacles
-----------------------------------------
core.register_globalstep(function(dtime)
	local dt = math.min(dtime, 0.1)
	boss_time = boss_time + dt

	if not next(back_tracks.active_drivers) then
		return
	end

	local any_in_arena = false
	local any_airborne = nil
	for name, dstate in pairs(back_tracks.active_drivers) do
		local player = core.get_player_by_name(name)
		if player and player:is_player() and dstate and dstate.pos then
			update_boss_hud(name, player, dstate, dt)

			if is_driver_in_boss_arena(dstate) then
				any_in_arena = true
				local dx = dstate.pos.x - MX
				local dz = dstate.pos.z - MZ
				local d2 = dx * dx + dz * dz
				if d2 <= 72.0 * 72.0 and dstate.pos.y >= 184.0 and dstate.hp > 0 and not dstate.boss_swallow_lock then
					any_airborne = dstate.pos
				end
			end
		end
	end

	if boss.state == "dead" then
		return
	end

	if not boss.spawned then
		if any_in_arena then
			spawn_boss()
		end
		return
	end

	-- Handle writhing & dying states
	if boss.state == "writhing" then
		boss.writhe_timer = boss.writhe_timer - dt
		if boss.mouth_obj and boss.mouth_obj:is_valid() then
			local shake_x = math.sin(boss_time * 32.0) * 0.45
			local shake_z = math.cos(boss_time * 28.0) * 0.45
			boss.mouth_obj:set_pos(vector.new(MX + shake_x, MOUTH_POS.y + math.sin(boss_time * 20.0) * 0.25, MZ + shake_z))
			if boss.writhe_is_phase2 then
				boss.mouth_obj:set_texture_mod(MOUTH_VIOLET_MOD)
			end
		end
		if boss.writhe_is_phase2 and math.random() < 0.45 then
			back_tracks.spawn_explosion(vector.new(
				MX + (math.random() - 0.5) * 10,
				181.0 + math.random() * 4,
				MZ + (math.random() - 0.5) * 10
			), 0.7)
		end

		if boss.writhe_timer <= 0 then
			if boss.mouth_obj and boss.mouth_obj:is_valid() then
				boss.mouth_obj:set_pos(MOUTH_POS)
				boss.mouth_obj:set_texture_mod("")
			end
			if boss.hp <= 0 then
				boss.state = "dying"
				boss.death_timer = DEATH_EXPLODE_TIME
				back_tracks.spawn_explosion(vector.new(MX, 181, MZ), 2.8)
			else
				boss.state = "active"
				boss.writhe_is_phase2 = false
				boss.rock_timer = 0.6
				if boss.mouth_reg then
					boss.mouth_reg.dead = false
				end
				for i = 1, #boss.inner do
					set_tentacle_texture_mod(boss.inner[i], "")
				end
				for i = 1, #boss.outer do
					set_tentacle_texture_mod(boss.outer[i], "")
				end
			end
		end
	elseif boss.state == "dying" then
		boss.death_timer = boss.death_timer - dt
		if math.random() < 0.5 then
			back_tracks.spawn_explosion(vector.new(
				MX + (math.random() - 0.5) * 12,
				180.5 + math.random() * 5,
				MZ + (math.random() - 0.5) * 12
			), 1.4)
		end
		if boss.death_timer <= 0 then
			boss.state = "dead"
			despawn_boss_entities()
			for name, dstate in pairs(back_tracks.active_drivers) do
				clear_player_boss_hud(name)
				local player = core.get_player_by_name(name)
				if player and player:is_player() then
					back_tracks.register_kill(name)
					show_victory_formspec(player, dstate.kills)
				end
			end
			return
		end
	end

	-- Central Mouth Swallow Logic
	for _, dstate in pairs(back_tracks.active_drivers) do
		if dstate and dstate.hp > 0 and dstate.pos then
			if not dstate.boss_swallow_lock and boss.state ~= "dying" then
				local dx = math.abs(dstate.pos.x - MX)
				local dz = math.abs(dstate.pos.z - MZ)
				if dx <= MOUTH_EAT_RX and dz <= MOUTH_EAT_RZ and dstate.pos.y <= 181.6 then
					for i = 1, #boss.inner do
						if boss.inner[i].mode == "grab" then
							release_grab(boss.inner[i], false)
							boss.inner[i].mode = "wave"
						end
					end
					for i = 1, #boss.outer do
						if boss.outer[i].mode == "grab" then
							release_grab(boss.outer[i], false)
							boss.outer[i].mode = "wave"
						end
					end
					dstate.boss_swallow_lock = true
					dstate.swallow_timer = 0.0
					dstate.swallow_start_pos = vector.copy(dstate.pos)
					dstate.vel = vector.zero()
					dstate.ang_vel = vector.zero()
				end
			elseif dstate.boss_swallow_lock then
				dstate.swallow_timer = dstate.swallow_timer + dt
				local t = clamp(dstate.swallow_timer / SWALLOW_DURATION, 0.0, 1.0)
				local sp = dstate.swallow_start_pos

				local sink_y
				if t < 0.35 then
					local u = t / 0.35
					sink_y = sp.y + (179.0 - sp.y) * (u * u)
				else
					local u = (t - 0.35) / 0.65
					sink_y = 179.0 - 5.2 * u
				end

				local pull_t = math.min(1.0, t * 1.6)
				dstate.pos = vector.new(
					sp.x + (MX - sp.x) * pull_t,
					sink_y,
					sp.z + (MZ - sp.z) * pull_t
				)
				dstate.vel = vector.zero()
				dstate.ang_vel = vector.zero()

				local tilt_fwd = safe_normalize(vector.new(
					math.cos(t * 2.5) * 0.65,
					-0.75,
					math.sin(t * 2.5) * 0.65
				))
				local right_s = safe_normalize(vector.cross(vector.new(0, 1, 0), tilt_fwd))
				local up_s = safe_normalize(vector.cross(tilt_fwd, right_s))
				dstate.forward = tilt_fwd
				dstate.right = right_s
				dstate.up = up_s

				if math.random() < 0.35 then
					back_tracks.spawn_explosion(vector.new(dstate.pos.x, 179.8, dstate.pos.z), 0.5)
				end

				if t >= 1.0 then
					dstate.hp = 0
				end
			end
		end
	end

	-- Choose at most one pointing/lunging tentacle per driver, then step rock thrower & tentacles
	local lunge_targets = select_lunge_targets()
	step_rock_throws(dt, lunge_targets)

	for i = 1, #boss.inner do
		step_tentacle(boss.inner[i], dt, any_airborne, lunge_targets[boss.inner[i].id])
	end
	for i = 1, #boss.outer do
		step_tentacle(boss.outer[i], dt, any_airborne, lunge_targets[boss.outer[i].id])
	end
end)

core.register_on_leaveplayer(function(player)
	clear_player_boss_hud(player:get_player_name())
end)

core.register_on_shutdown(function()
	despawn_boss_entities()
	boss_huds = {}
	shield_alerts = {}
end)