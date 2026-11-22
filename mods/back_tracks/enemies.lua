-- local MODNAME = core.get_current_modname()

-- -----------------------------------------
-- -- Enemy Tuning Constants
-- -----------------------------------------
-- local TARGET_BIKES_PER_PLAYER = 4
-- local TARGET_FLYERS_IN_ZONE   = 3

-- local BIKE_GRAVITY       = 15.0
-- local BIKE_SPRING_K      = 14.0
-- local BIKE_SPRING_DAMP   = 4.5
-- local BIKE_SUSP_REST     = 1.05
-- local BIKE_BASE_SPEED    = 46.0
-- local BIKE_CATCHUP_SPEED = 70.0 -- Catches up over time when trailing behind
-- local BIKE_ACCEL         = 26.0
-- local BIKE_TURN_RATE     = 3.4
-- local BIKE_FIRE_INTERVAL = 2.0
-- local BIKE_DESPAWN_DIST  = 95.0

-- local FLYER_BASE_SPEED   = 44.0
-- local FLYER_FIRE_INTERVAL = 2.2
-- local FLYER_DESPAWN_DIST = 115.0

-- local ENEMY_BULLET_SPEED    = 72.0
-- local ENEMY_BULLET_MAX_DIST = 95.0
-- local ENEMY_BULLET_DAMAGE   = 12.0

-- local BIKE_TEX_BODY  = "[fill:16x16:#AA2222"
-- local BIKE_TEX_HEAD  = "[fill:16x16:#FFF099"
-- local FLYER_TEX_BODY = "[fill:16x16:#7722BB"
-- local FLYER_TEX_HEAD = "[fill:16x16:#88FFFF"
-- local E_BULLET_TEX   = "[fill:16x16:#FFAA00"

-- local next_enemy_id = 0
-- local function alloc_enemy_id()
-- 	next_enemy_id = next_enemy_id + 1
-- 	return next_enemy_id
-- end

-- -- Helper: check if position is in a Starfox Flyer zone
-- -- (Curvy Canyon, Ramps, Causeways, or Mountain Spiral)
-- local function is_in_flyer_zone(pos)
-- 	if pos.x <= 5 and pos.x >= -970 and math.abs(pos.z) <= 130 then
-- 		return true
-- 	end
-- 	local dx = pos.x - (-1145)
-- 	local dz = pos.z
-- 	local r2 = dx * dx + dz * dz
-- 	if r2 <= 210 * 210 and r2 >= 86 * 86 then
-- 		return true
-- 	end
-- 	return false
-- end

-- -- Find walkable surface Y near (x, z) starting from y_hint
-- local function find_surface_y_near(x, y_hint, z)
-- 	local ix = back_tracks.round_int(x)
-- 	local iz = back_tracks.round_int(z)
-- 	local top_y = back_tracks.round_int(y_hint + 18)
-- 	local bot_y = back_tracks.round_int(y_hint - 24)
-- 	for ny = top_y, bot_y, -1 do
-- 		local p = {x = ix, y = ny, z = iz}
-- 		if back_tracks.is_node_solid(p) then
-- 			if not back_tracks.is_node_solid({x = ix, y = ny + 1, z = iz})
-- 			and not back_tracks.is_node_solid({x = ix, y = ny + 2, z = iz}) then
-- 				return ny + 1.4
-- 			end
-- 		end
-- 	end
-- 	return nil
-- end

-- -----------------------------------------
-- -- Enemy Bullet Entity
-- -----------------------------------------
-- core.register_entity(MODNAME .. ":enemy_bullet", {
-- 	initial_properties = {
-- 		visual = "cube",
-- 		visual_size = {x = 0.24, y = 0.24, z = 0.65},
-- 		textures = {
-- 			E_BULLET_TEX, E_BULLET_TEX, E_BULLET_TEX,
-- 			E_BULLET_TEX, E_BULLET_TEX, E_BULLET_TEX,
-- 		},
-- 		glow = 14,
-- 		physical = false,
-- 		pointable = false,
-- 		collide_with_objects = false,
-- 		static_save = false,
-- 	},

-- 	on_activate = function(self)
-- 		self.dir = vector.new(0, 0, 1)
-- 		self.dist_traveled = 0
-- 	end,

-- 	on_step = function(self, dtime)
-- 		local dt = math.min(dtime, 0.1)
-- 		local pos = self.object:get_pos()
-- 		if not pos or not self.dir then
-- 			self.object:remove()
-- 			return
-- 		end

-- 		local step_dist = ENEMY_BULLET_SPEED * dt
-- 		local next_pos = vector.add(pos, vector.multiply(self.dir, step_dist))

-- 		-- Check hit against active player trucks
-- 		local seg = vector.subtract(next_pos, pos)
-- 		local seg_len2 = vector.dot(seg, seg)
-- 		if seg_len2 > 1e-6 then
-- 			for name, driver in pairs(back_tracks.active_drivers) do
-- 				local dp = driver.pos
-- 				local t = back_tracks.clamp(vector.dot(vector.subtract(dp, pos), seg) / seg_len2, 0, 1)
-- 				local closest = vector.add(pos, vector.multiply(seg, t))
-- 				local d2 = vector.dot(vector.subtract(dp, closest), vector.subtract(dp, closest))
-- 				if d2 <= 2.1 * 2.1 then
-- 					back_tracks.damage_player(name, ENEMY_BULLET_DAMAGE)
-- 					back_tracks.spawn_explosion(closest, 0.45)
-- 					self.object:remove()
-- 					return
-- 				end
-- 			end
-- 		end

-- 		if back_tracks.raycast_solid(pos, next_pos) then
-- 			self.object:remove()
-- 			return
-- 		end

-- 		self.dist_traveled = self.dist_traveled + step_dist
-- 		if self.dist_traveled >= ENEMY_BULLET_MAX_DIST then
-- 			self.object:remove()
-- 			return
-- 		end

-- 		self.object:set_pos(next_pos)
-- 	end,
-- })

-- local function fire_enemy_bullet(origin, target_pos, spread)
-- 	local to_target = vector.subtract(target_pos, origin)
-- 	local dist = vector.length(to_target)
-- 	if dist < 1.0 then return end
-- 	local dir = vector.divide(to_target, dist)
-- 	if spread and spread > 0 then
-- 		dir.x = dir.x + (math.random() - 0.5) * spread
-- 		dir.y = dir.y + (math.random() - 0.5) * spread * 0.5
-- 		dir.z = dir.z + (math.random() - 0.5) * spread
-- 		dir = vector.normalize(dir)
-- 	end
-- 	local b = core.add_entity(origin, MODNAME .. ":enemy_bullet")
-- 	if b then
-- 		local ent = b:get_luaentity()
-- 		ent.dir = dir
-- 		ent.dist_traveled = 0
-- 		b:set_rotation(vector.dir_to_rotation(dir))
-- 	end
-- end

-- -----------------------------------------
-- -- 1. Chasing Dirt Bike Entity
-- -----------------------------------------
-- core.register_entity(MODNAME .. ":dirt_bike", {
-- 	initial_properties = {
-- 		visual = "cube",
-- 		visual_size = {x = 0.85, y = 0.90, z = 2.0},
-- 		textures = {
-- 			BIKE_TEX_BODY, BIKE_TEX_BODY, BIKE_TEX_BODY,
-- 			BIKE_TEX_BODY, BIKE_TEX_BODY, BIKE_TEX_HEAD,
-- 		},
-- 		glow = 12,
-- 		physical = false,
-- 		pointable = false,
-- 		collide_with_objects = false,
-- 		static_save = false,
-- 	},

-- 	on_activate = function(self)
-- 		self.eid = alloc_enemy_id()
-- 		self.vel = vector.zero()
-- 		self.yaw = 0
-- 		self.pitch = 0
-- 		self.roll = 0
-- 		self.lane_offset = (math.random() - 0.5) * 10.0
-- 		self.fire_timer = 1.0 + math.random() * 1.5
-- 		self.light_timer = 0
-- 		self.light_nodes = {}
-- 		self.target_name = nil
-- 		self.dead = false

-- 		local ent_ref = {
-- 			obj = self.object,
-- 			kind = "bike",
-- 			hit_radius = 1.9,
-- 			pos = self.object:get_pos(),
-- 			dead = false,
-- 			kill = function(killer_name)
-- 				if self.dead then return end
-- 				self.dead = true
-- 				back_tracks.clear_light_list(self.light_nodes)
-- 				self.light_nodes = {}
-- 				back_tracks.spawn_explosion(self.object:get_pos() or vector.zero(), 1.1)
-- 				if killer_name then back_tracks.register_kill(killer_name) end
-- 				back_tracks.enemies[self.eid] = nil
-- 				self.object:remove()
-- 			end,
-- 		}
-- 		self.reg = ent_ref
-- 		back_tracks.enemies[self.eid] = ent_ref
-- 	end,

-- 	on_deactivate = function(self)
-- 		back_tracks.clear_light_list(self.light_nodes)
-- 		self.light_nodes = {}
-- 		if self.eid then
-- 			back_tracks.enemies[self.eid] = nil
-- 		end
-- 	end,

-- 	on_step = function(self, dtime)
-- 		if self.dead then return end
-- 		local dt = math.min(dtime, 0.1)
-- 		local pos = self.object:get_pos()
-- 		if not pos then return end

-- 		local driver = self.target_name and back_tracks.active_drivers[self.target_name]
-- 		if not driver then
-- 			back_tracks.clear_light_list(self.light_nodes)
-- 			back_tracks.enemies[self.eid] = nil
-- 			self.object:remove()
-- 			return
-- 		end

-- 		local dist_to_player = vector.distance(pos, driver.pos)
-- 		if dist_to_player > BIKE_DESPAWN_DIST or pos.y < -25 then
-- 			back_tracks.clear_light_list(self.light_nodes)
-- 			back_tracks.enemies[self.eid] = nil
-- 			self.object:remove()
-- 			return
-- 		end

-- 		-- Aim slightly offset beside the player so bikes fan out naturally
-- 		local _, _, p_fwd = back_tracks.compute_basis(driver.yaw, 0, 0)
-- 		local p_right = vector.new(p_fwd.z, 0, -p_fwd.x)
-- 		local chase_target = vector.add(
-- 			driver.pos,
-- 			vector.add(vector.multiply(p_right, self.lane_offset), vector.multiply(driver.vel, 0.25))
-- 		)

-- 		-- Rubberband target speed: catches up when far, paces aggressively when close
-- 		local target_speed = BIKE_BASE_SPEED
-- 		if dist_to_player > 24.0 then
-- 			local t = back_tracks.clamp((dist_to_player - 24.0) / 35.0, 0, 1)
-- 			target_speed = BIKE_BASE_SPEED + (BIKE_CATCHUP_SPEED - BIKE_BASE_SPEED) * t
-- 		elseif dist_to_player < 10.0 then
-- 			target_speed = 38.0
-- 		end

-- 		-- Sub-stepped terrain physics (mirrors player truck physics!)
-- 		local sub_steps = 3
-- 		local sdt = dt / sub_steps
-- 		for _ = 1, sub_steps do
-- 			local right, up, forward = back_tracks.compute_basis(self.yaw, self.pitch, self.roll)

-- 			-- Steer toward chase target
-- 			local to_t = vector.subtract(chase_target, pos)
-- 			local desired_yaw = math.atan2(-to_t.x, to_t.z)
-- 			local yaw_err = (desired_yaw - self.yaw + math.pi) % (2 * math.pi) - math.pi
-- 			local max_turn = BIKE_TURN_RATE * sdt
-- 			self.yaw = self.yaw + back_tracks.clamp(yaw_err, -max_turn, max_turn)

-- 			-- Smooth ground sampling at front & rear wheel hubs
-- 			local climb_boost = math.max(0.0, self.pitch) * 2.5 + math.max(0.0, self.vel.y) * 0.15
-- 			local step_up = 1.6 + math.min(climb_boost, 2.8)
-- 			local hub_f = vector.add(pos, vector.multiply(forward,  1.0))
-- 			local hub_r = vector.add(pos, vector.multiply(forward, -1.0))
-- 			local gf = back_tracks.sample_smooth_ground_y(hub_f.x, pos.y - 0.3, hub_f.z, step_up)
-- 			local gr = back_tracks.sample_smooth_ground_y(hub_r.x, pos.y - 0.3, hub_r.z, step_up)

-- 			local grounded = false
-- 			local v_up = vector.dot(self.vel, up)
-- 			if gf or gr then
-- 				local g_mid = (gf and gr) and ((gf + gr) * 0.5) or (gf or gr)
-- 				local comp = BIKE_SUSP_REST - ((pos.y - 0.3) - g_mid)
-- 				if comp > 0 then
-- 					grounded = true
-- 					comp = math.min(comp, 1.6)
-- 					local f_susp = math.max(0.0, BIKE_SPRING_K * comp - BIKE_SPRING_DAMP * v_up)
-- 					self.vel = vector.add(self.vel, vector.multiply(up, f_susp * sdt))
-- 					if comp > 0.95 then
-- 						pos.y = pos.y + (comp - 0.95) * 0.45
-- 					end
-- 				end
-- 			end

-- 			self.vel.y = self.vel.y - BIKE_GRAVITY * sdt

-- 			if grounded then
-- 				-- Ramp launch deflection
-- 				if self.pitch > 0.06 and v_up < 0 then
-- 					local spd = vector.length(self.vel)
-- 					local tv = vector.multiply(forward, spd * 0.92)
-- 					if tv.y > self.vel.y then
-- 						self.vel = vector.add(self.vel, vector.multiply(vector.subtract(tv, self.vel), math.min(1, 18 * sdt)))
-- 					end
-- 				end
-- 				-- Drive forward + lateral grip
-- 				local v_fwd = vector.dot(self.vel, forward)
-- 				local accel = back_tracks.clamp((target_speed - v_fwd) * 3.0, -BIKE_ACCEL, BIKE_ACCEL)
-- 				self.vel = vector.add(self.vel, vector.multiply(forward, accel * sdt))

-- 				local v_lat = vector.dot(self.vel, right)
-- 				self.vel = vector.subtract(self.vel, vector.multiply(right, v_lat * math.min(1, 10.0 * sdt)))
-- 			end

-- 			-- Slope pitch & lean roll
-- 			local target_pitch = 0
-- 			if gf and gr then
-- 				target_pitch = back_tracks.clamp(math.atan2(gf - gr, 2.0), -0.75, 0.75)
-- 			end
-- 			self.pitch = self.pitch + (target_pitch - self.pitch) * math.min(1, (grounded and 16 or 1.5) * sdt)
-- 			local target_roll = back_tracks.clamp(-yaw_err * 0.65, -0.5, 0.5)
-- 			self.roll = self.roll + (target_roll - self.roll) * math.min(1, 10 * sdt)

-- 			pos = vector.add(pos, vector.multiply(self.vel, sdt))
-- 			back_tracks.resolve_wall_collisions(pos, self.vel, forward, climb_boost)
-- 		end

-- 		self.object:set_pos(pos)
-- 		local _, up, forward = back_tracks.compute_basis(self.yaw, self.pitch, self.roll)
-- 		self.object:set_rotation(vector.dir_to_rotation(forward, up))
-- 		self.reg.pos = pos

-- 		-- Headlight beam ahead of bike
-- 		self.light_timer = self.light_timer + dt
-- 		if self.light_timer >= 0.10 then
-- 			self.light_timer = 0
-- 			local beam = {
-- 				vector.add(pos, vector.add(vector.multiply(forward, 5.0), vector.new(0, 0.8, 0))),
-- 			}
-- 			self.light_nodes = back_tracks.update_headlights(self.light_nodes, beam)
-- 		end

-- 		-- Fire bullets at player
-- 		self.fire_timer = self.fire_timer - dt
-- 		if self.fire_timer <= 0 and dist_to_player < 68.0 then
-- 			self.fire_timer = BIKE_FIRE_INTERVAL + math.random() * 1.0
-- 			local muzzle = vector.add(pos, vector.new(0, 0.7, 0))
-- 			if not back_tracks.raycast_solid(muzzle, driver.pos) then
-- 				local lead_pos = vector.add(driver.pos, vector.multiply(driver.vel, dist_to_player / ENEMY_BULLET_SPEED * 0.5))
-- 				fire_enemy_bullet(muzzle, lead_pos, 0.08)
-- 			end
-- 		end
-- 	end,
-- })

-- -----------------------------------------
-- -- 2. Starfox-Style Strafing Flyer Entity
-- -----------------------------------------
-- core.register_entity(MODNAME .. ":flyer", {
-- 	initial_properties = {
-- 		visual = "cube",
-- 		visual_size = {x = 2.4, y = 0.45, z = 1.6},
-- 		textures = {
-- 			FLYER_TEX_BODY, FLYER_TEX_BODY, FLYER_TEX_BODY,
-- 			FLYER_TEX_BODY, FLYER_TEX_BODY, FLYER_TEX_HEAD,
-- 		},
-- 		glow = 14,
-- 		physical = false,
-- 		pointable = false,
-- 		collide_with_objects = false,
-- 		static_save = false,
-- 	},

-- 	on_activate = function(self)
-- 		self.eid = alloc_enemy_id()
-- 		self.phase = math.random() * math.pi * 2
-- 		self.strafe_dir = (math.random() < 0.5) and 1 or -1
-- 		self.fire_timer = 0.8 + math.random() * 1.0
-- 		self.burst_left = 0
-- 		self.light_timer = 0
-- 		self.light_nodes = {}
-- 		self.target_name = nil
-- 		self.dead = false

-- 		local ent_ref = {
-- 			obj = self.object,
-- 			kind = "flyer",
-- 			hit_radius = 2.2,
-- 			pos = self.object:get_pos(),
-- 			dead = false,
-- 			kill = function(killer_name)
-- 				if self.dead then return end
-- 				self.dead = true
-- 				back_tracks.clear_light_list(self.light_nodes)
-- 				self.light_nodes = {}
-- 				back_tracks.spawn_explosion(self.object:get_pos() or vector.zero(), 1.25)
-- 				if killer_name then back_tracks.register_kill(killer_name) end
-- 				back_tracks.enemies[self.eid] = nil
-- 				self.object:remove()
-- 			end,
-- 		}
-- 		self.reg = ent_ref
-- 		back_tracks.enemies[self.eid] = ent_ref
-- 	end,

-- 	on_deactivate = function(self)
-- 		back_tracks.clear_light_list(self.light_nodes)
-- 		self.light_nodes = {}
-- 		if self.eid then
-- 			back_tracks.enemies[self.eid] = nil
-- 		end
-- 	end,

-- 	on_step = function(self, dtime)
-- 		if self.dead then return end
-- 		local dt = math.min(dtime, 0.1)
-- 		local pos = self.object:get_pos()
-- 		if not pos then return end

-- 		local driver = self.target_name and back_tracks.active_drivers[self.target_name]
-- 		if not driver then
-- 			back_tracks.clear_light_list(self.light_nodes)
-- 			back_tracks.enemies[self.eid] = nil
-- 			self.object:remove()
-- 			return
-- 		end

-- 		local dist = vector.distance(pos, driver.pos)
-- 		if dist > FLYER_DESPAWN_DIST then
-- 			back_tracks.clear_light_list(self.light_nodes)
-- 			back_tracks.enemies[self.eid] = nil
-- 			self.object:remove()
-- 			return
-- 		end

-- 		self.phase = self.phase + dt * 2.1

-- 		-- Starfox-style sweeping strafe target ahead of player
-- 		local _, _, p_fwd = back_tracks.compute_basis(driver.yaw, 0, 0)
-- 		local p_right = vector.new(p_fwd.z, 0, -p_fwd.x)
-- 		local lat_wave = math.sin(self.phase * self.strafe_dir) * 20.0
-- 		local vert_wave = math.cos(self.phase * 1.35) * 4.5

-- 		local anchor = vector.add(driver.pos, vector.multiply(p_fwd, 30.0))
-- 		local desired_pos = vector.add(anchor, vector.add(
-- 			vector.multiply(p_right, lat_wave),
-- 			vector.new(0, 11.0 + vert_wave, 0)
-- 		))

-- 		-- Terrain clearance safety so flyers pull up over canyon walls / ramps
-- 		local ground_below = back_tracks.sample_smooth_ground_y(pos.x, pos.y - 2, pos.z, 6.0)
-- 		if ground_below and desired_pos.y < ground_below + 7.0 then
-- 			desired_pos.y = ground_below + 7.0
-- 		end

-- 		local to_desired = vector.subtract(desired_pos, pos)
-- 		local d_len = vector.length(to_desired)
-- 		local move_dir = (d_len > 0.5) and vector.divide(to_desired, d_len) or p_fwd
-- 		local speed = math.min(FLYER_BASE_SPEED + math.max(0, d_len - 10) * 1.4, 78.0)

-- 		local next_pos = vector.add(pos, vector.multiply(move_dir, speed * dt))
-- 		if not back_tracks.is_node_solid(next_pos) then
-- 			pos = next_pos
-- 		else
-- 			pos.y = pos.y + 8.0 * dt
-- 		end
-- 		self.object:set_pos(pos)

-- 		-- Bank dramatically into the strafe while facing toward player/flight path
-- 		local look_dir = vector.normalize(vector.subtract(driver.pos, pos))
-- 		local roll = back_tracks.clamp(-math.cos(self.phase) * 0.65 * self.strafe_dir, -0.7, 0.7)
-- 		local r_vec = vector.cross(vector.new(0, 1, 0), look_dir)
-- 		if vector.length(r_vec) > 0.01 then
-- 			r_vec = vector.normalize(r_vec)
-- 			local u_vec = vector.normalize(vector.cross(look_dir, r_vec))
-- 			local banked_up = vector.add(
-- 				vector.multiply(u_vec, math.cos(roll)),
-- 				vector.multiply(r_vec, math.sin(roll))
-- 			)
-- 			self.object:set_rotation(vector.dir_to_rotation(look_dir, banked_up))
-- 		end
-- 		self.reg.pos = pos

-- 		-- Searchlight headlight projecting toward player/ground
-- 		self.light_timer = self.light_timer + dt
-- 		if self.light_timer >= 0.12 then
-- 			self.light_timer = 0
-- 			local spot = vector.add(pos, vector.multiply(look_dir, 6.0))
-- 			spot.y = spot.y - 2.0
-- 			self.light_nodes = back_tracks.update_headlights(self.light_nodes, {spot})
-- 		end

-- 		-- Burst plasma fire during strafe pass
-- 		self.fire_timer = self.fire_timer - dt
-- 		if self.fire_timer <= 0 and dist < 80.0 then
-- 			if self.burst_left <= 0 then
-- 				self.burst_left = 2
-- 			end
-- 			local muzzle = vector.add(pos, vector.multiply(look_dir, 1.8))
-- 			if not back_tracks.raycast_solid(muzzle, driver.pos) then
-- 				local lead = vector.add(driver.pos, vector.multiply(driver.vel, dist / ENEMY_BULLET_SPEED * 0.35))
-- 				fire_enemy_bullet(muzzle, lead, 0.06)
-- 			end
-- 			self.burst_left = self.burst_left - 1
-- 			if self.burst_left > 0 then
-- 				self.fire_timer = 0.22
-- 			else
-- 				self.fire_timer = FLYER_FIRE_INTERVAL + math.random() * 1.0
-- 			end
-- 		end
-- 	end,
-- })

-- -----------------------------------------
-- -- Enemy Wave Spawner Loop
-- -----------------------------------------
-- local spawn_timer = 0

-- local function count_player_enemies(name)
-- 	local bikes, flyers = 0, 0
-- 	for _, e in pairs(back_tracks.enemies) do
-- 		if not e.dead and e.obj and e.obj:is_valid() then
-- 			local lua = e.obj:get_luaentity()
-- 			if lua and lua.target_name == name then
-- 				if e.kind == "bike" then
-- 					bikes = bikes + 1
-- 				elseif e.kind == "flyer" then
-- 					flyers = flyers + 1
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return bikes, flyers
-- end

-- local function try_spawn_bike(name, driver)
-- 	local _, _, p_fwd = back_tracks.compute_basis(driver.yaw, 0, 0)
-- 	local p_right = vector.new(p_fwd.z, 0, -p_fwd.x)

-- 	-- Spawn behind the player along the track so they ride up & chase
-- 	for _ = 1, 5 do
-- 		local back_dist = 24 + math.random() * 20
-- 		local side_off = (math.random() - 0.5) * 14
-- 		local cand_x = driver.pos.x - p_fwd.x * back_dist + p_right.x * side_off
-- 		local cand_z = driver.pos.z - p_fwd.z * back_dist + p_right.z * side_off
-- 		local sy = find_surface_y_near(cand_x, driver.pos.y, cand_z)
-- 		if sy then
-- 			local bike = core.add_entity({x = cand_x, y = sy, z = cand_z}, MODNAME .. ":dirt_bike")
-- 			if bike then
-- 				local ent = bike:get_luaentity()
-- 				ent.target_name = name
-- 				ent.yaw = driver.yaw
-- 				ent.vel = vector.multiply(p_fwd, 35.0)
-- 				return true
-- 			end
-- 		end
-- 	end
-- 	return false
-- end

-- local function try_spawn_flyer(name, driver)
-- 	local _, _, p_fwd = back_tracks.compute_basis(driver.yaw, 0, 0)
-- 	local p_right = vector.new(p_fwd.z, 0, -p_fwd.x)
-- 	local ahead = 42 + math.random() * 20
-- 	local side = (math.random() - 0.5) * 32
-- 	local sp = {
-- 		x = driver.pos.x + p_fwd.x * ahead + p_right.x * side,
-- 		y = driver.pos.y + 12 + math.random() * 8,
-- 		z = driver.pos.z + p_fwd.z * ahead + p_right.z * side,
-- 	}
-- 	if not back_tracks.is_node_solid(sp) then
-- 		local flyer = core.add_entity(sp, MODNAME .. ":flyer")
-- 		if flyer then
-- 			flyer:get_luaentity().target_name = name
-- 			return true
-- 		end
-- 	end
-- 	return false
-- end

-- core.register_globalstep(function(dtime)
-- 	spawn_timer = spawn_timer + math.min(dtime, 0.1)
-- 	if spawn_timer < 1.5 then return end
-- 	spawn_timer = 0

-- 	for name, driver in pairs(back_tracks.active_drivers) do
-- 		if driver.ground_ready then
-- 			local bikes, flyers = count_player_enemies(name)
-- 			if bikes < TARGET_BIKES_PER_PLAYER then
-- 				try_spawn_bike(name, driver)
-- 			end
-- 			local flyer_cap = is_in_flyer_zone(driver.pos) and TARGET_FLYERS_IN_ZONE or 1
-- 			if flyers < flyer_cap then
-- 				try_spawn_flyer(name, driver)
-- 			end
-- 		end
-- 	end
-- end)