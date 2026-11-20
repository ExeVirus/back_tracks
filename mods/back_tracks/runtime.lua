local MODNAME = core.get_current_modname()

-----------------------------------------
-- Configuration & Tuning Constants
-----------------------------------------
local SHOW_PLACEHOLDER_MODEL = true -- Set false to make the truck & turret invisible

-- Wheelbase & Visual Offsets
local WHEEL_HALF_X = 1.5         -- Half-width of wheelbase in nodes (total width = 2 * this)
local WHEEL_HALF_Z = 1.5         -- Half-length of wheelbase in nodes (total length = 2 * this)
local WHEEL_HUB_Y = -0.35        -- Vertical offset of wheel hubs relative to truck center
local TURRET_HEIGHT_OFFSET = 0.72 -- Height of turret above truck center along truck 'up'
local CAMERA_EYE_OFFSET = {x = 0, y = 3.2, z = -5} -- 3rd-person camera offset (clamped by Luanti)

local WHEEL_OFFSETS = {
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front-Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front-Right
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear-Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear-Right
}

-- Suspension, Gravity & Terrain Centroid Smoothing
local SUSPENSION_REST = 1.20     -- Max distance from wheel hub to ground before wheel leaves terrain
local NOMINAL_COMP = 0.30        -- Spring compression that equals 1.0 wheel pressure (~resting height)
local MAX_COMP = 1.75            -- Maximum allowed spring compression before clamp
local SPRING_K = 12.0            -- Spring stiffness per wheel (4 * SPRING_K * comp_rest = GRAVITY)
local SPRING_DAMP = 4.2          -- Vertical suspension shock absorber damping (along truck 'up')
local GRAVITY = 15.0             -- World gravity (lower = floatier THPS / Rocket League hangtime)
local TERRAIN_SIGMA = 0.72       -- Gaussian smoothing radius over nearby filled node centroids
local TERRAIN_SEARCH_DOWN = 4    -- Max nodes below wheel hub to search for solid ground
local TRACTION_DIVISOR = 3.0     -- Total wheel pressure needed for 100% drive/steer traction (max 4 wheels * 1.5 = 6.0)
local BOTTOM_OUT_COMP = 1.05     -- Compression threshold where chassis bump-stop engages
local BOTTOM_OUT_PUSH = 0.45     -- Fraction of bottom-out penetration pushed up per sub-step
local BOTTOM_OUT_VEL_KEEP = 0.50 -- Fraction of downward normal velocity cancelled on bottom-out

local PROGRESSIVE_COMP_START = 0.55 -- Compression where progressive spring stiffening kicks in
local PROGRESSIVE_SPRING_MULT = 2.5 -- Quadratic stiffness boost on hard bumps/landings

local RAMP_MIN_PITCH = 0.06      -- Min nose-up pitch (rad) to convert forward speed into Y lift
local RAMP_REDIRECT_RATE = 24.0  -- How fast horizontal momentum deflects up a ramp/bump
local RAMP_SPEED_RETENTION = 0.92 -- Fraction of speed kept when launching up a ramp

-- Climbing & Wall Collisions
local FLAT_STEP_UP = 1.55        -- Max height above hub treated as driveable step/slope when flat
local CLIMB_PITCH_THRESHOLD = 0.05 -- Min nose-up pitch (rad) to unlock extra ledge-climb reach
local CLIMB_VEL_Y_THRESHOLD = 1.0  -- Min upward speed (nodes/s) to unlock extra ledge-climb reach
local CLIMB_PITCH_GAIN = 3.0     -- Extra climb height (nodes) gained per radian of nose-up pitch
local CLIMB_VEL_Y_GAIN = 0.18    -- Extra climb height (nodes) gained per node/s of upward speed
local CLIMB_MAX_BOOST = 3.2      -- Hard cap on bonus climb height above FLAT_STEP_UP

local WALL_BODY_RADIUS = 1.05    -- Horizontal collision radius of front/mid/rear chassis anchors
local WALL_ANCHOR_OFFSET = 0.80  -- Distance forward/backward from truck center for bumper anchors
local WALL_CHECK_Y_MIN = 0.95    -- Lowest height above truck center checked as a solid wall when flat
local WALL_CHECK_Y_MAX = 1.85    -- Highest height above truck center checked as a solid wall
local WALL_CLIMB_Y_SHIFT = 0.55  -- How much WALL_CHECK_Y_MIN raises per unit of climb_boost
local WALL_CLIMB_SPEED_BLEED = 0.78 -- Horizontal speed multiplier when scraping/climbing a ledge

-- Orientation Inertia, Ground Conforming & Air Attitude
local PITCH_INERTIA = 2.2        -- Pitch rotational inertia (lower = snappier front/back tilt)
local ROLL_INERTIA = 2.2         -- Roll rotational inertia (lower = snappier side-to-side tilt)
local GROUND_ALIGN_K = 34.0      -- How strongly truck snaps to terrain slope when >=1 wheel touches
local GROUND_ROT_DAMP = 10.5     -- Pitch/roll damping on ground (higher = less landing wobble)
local AIR_ALIGN_K = 0.6          -- Gentle mid-air leveling pull (lower = preserves jump launch angle)
local AIR_ROT_DAMP = 1.8         -- Pitch/roll damping while airborne
local AIR_YAW_DAMP = 1.5         -- Yaw spin decay while airborne
local SLOPE_TARGET_MAX = 0.80    -- Max terrain slope angle (rad) the chassis will try to match (~46 deg)
local MAX_TILT_RAD = 0.85        -- Hard clamp on pitch and roll angles in radians (~49 deg)

-- Driving, Arcade Steering, Speed & Nitro
local MAX_DISP_PER_STEP = 0.35   -- Max nodes moved per physics sub-step (prevents wall tunneling)
local MAX_SUB_STEPS = 14         -- Upper limit on physics sub-steps per globalstep
local WORLD_TOP_SPEED = 60.0     -- Actual world speed (nodes/s) corresponding to 60 on speedometer
local DISPLAY_TOP_SPEED = 60     -- Max normal speed shown on HUD
local NITRO_TOP_SPEED = 90.0     -- Actual world speed (nodes/s) during Nitro (displays as 90)
local NITRO_DURATION = 3.0       -- Seconds per Nitro charge
local NITRO_MAX_CHARGES = 3      -- Starting Nitro charges

local ENGINE_ACCEL = 20.0        -- Forward acceleration (nodes/s^2)
local REVERSE_ACCEL = 10.0       -- Reverse acceleration (nodes/s^2)
local BRAKE_ACCEL = 30.0         -- Braking deceleration when pressing S while moving forward
local NITRO_ACCEL = 45.0         -- Forward acceleration during Nitro

local TARGET_TURN_RATE = 3.0     -- Max yaw turn rate (rad/s) at full traction
local STEER_RESPONSE = 18.0      -- How quickly yaw rate snaps on A/D press and release
local TURN_CARVE = 0.70          -- Fraction of velocity rotated with heading while turning (0=drift, 1=rails)
local LATERAL_GRIP = 12.0        -- Sideways tire friction (higher = tighter grip, lower = driftier)
local ROLLING_DRAG = 0.15        -- Linear rolling resistance when coasting
local OVERSPEED_DRAG = 1.4       -- Extra drag when exceeding WORLD_TOP_SPEED without Nitro

-- Weapons
local BULLET_SPEED = 120.0
local BULLET_MAX_DIST = 100.0
local BULLET_COOLDOWN = 0.12
local MUZZLE_HEIGHT_OFFSET = 1.35
local MUZZLE_FORWARD_OFFSET = 1.8
local BULLET_TEX = "[fill:16x16:#FFFFFF^[colorize:#FF2200:255"

-- Active driver state keyed by player name
local active_drivers = {}

-----------------------------------------
-- Math & World Helpers
-----------------------------------------
local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function round_int(v)
	return math.floor(v + 0.5)
end

local function is_node_solid(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "air" or node.name == "ignore" then
		return false
	end
	local def = core.registered_nodes[node.name]
	return def ~= nil and def.walkable == true
end

-- Smooth ground height around a wheel using Gaussian-weighted distance
-- from nearby filled node centroids (air is ignored).
-- Surfaces taller than (wy + max_step_up) are treated as walls, not climbable ground.
local function sample_smooth_ground_y(wx, wy, wz, max_step_up)
	local cx = round_int(wx)
	local cz = round_int(wz)
	local max_surface_y = wy + max_step_up
	local top_scan = round_int(max_surface_y)
	local bot_scan = round_int(wy) - TERRAIN_SEARCH_DOWN
	local two_sigma2 = 2.0 * TERRAIN_SIGMA * TERRAIN_SIGMA

	local weight_sum = 0.0
	local height_sum = 0.0
	local p = {x = 0, y = 0, z = 0}

	for dx = -1, 1 do
		p.x = cx + dx
		for dz = -1, 1 do
			p.z = cz + dz
			local found_y = nil

			-- Check if column is blocked by a solid wall above max_step_up
			p.y = top_scan + 1
			local blocked_above = is_node_solid(p)

			if not blocked_above then
				for ny = top_scan, bot_scan, -1 do
					p.y = ny
					if is_node_solid(p) then
						local top_y = ny + 0.5
						if top_y <= max_surface_y then
							found_y = top_y
						end
						break
					end
				end
			end

			if found_y then
				local rx = wx - p.x
				local rz = wz - p.z
				local d2 = rx * rx + rz * rz
				local w = math.exp(-d2 / two_sigma2)
				weight_sum = weight_sum + w
				height_sum = height_sum + w * found_y
			end
		end
	end

	if weight_sum <= 0.0001 then
		return nil
	end
	return height_sum / weight_sum
end

-- Build orthonormal (right, up, forward) vectors from yaw, pitch, roll
local function compute_basis(yaw, pitch, roll)
	local sin_y, cos_y = math.sin(yaw), math.cos(yaw)
	local sin_p, cos_p = math.sin(pitch), math.cos(pitch)
	local sin_r, cos_r = math.sin(roll), math.cos(roll)

	local fwd_flat = vector.new(-sin_y, 0, cos_y)
	local right_flat = vector.new(cos_y, 0, sin_y)
	local up_world = vector.new(0, 1, 0)

	local forward = vector.add(
		vector.multiply(fwd_flat, cos_p),
		vector.multiply(up_world, sin_p)
	)
	local up_pitched = vector.subtract(
		vector.multiply(up_world, cos_p),
		vector.multiply(fwd_flat, sin_p)
	)
	local right = vector.subtract(
		vector.multiply(right_flat, cos_r),
		vector.multiply(up_pitched, sin_r)
	)
	local up = vector.add(
		vector.multiply(up_pitched, cos_r),
		vector.multiply(right_flat, sin_r)
	)

	return right, up, forward
end

-- Resolve AABB-vs-circle collisions in XZ against solid walls above step height.
-- Coming in flat stops you against 2+ high walls; arriving pitched up with upward
-- momentum raises clearance and lets you clamber over ledges at the cost of speed.
local function resolve_wall_collisions(pos, vel, forward, climb_boost)
	local body_r = WALL_BODY_RADIUS
	local y_min = round_int(pos.y + WALL_CHECK_Y_MIN + climb_boost * WALL_CLIMB_Y_SHIFT)
	local y_max = round_int(pos.y + WALL_CHECK_Y_MAX)
	if y_min > y_max then y_min = y_max end

	local anchors = {
		vector.add(pos, vector.multiply(forward,  WALL_ANCHOR_OFFSET)), -- Front bumper
		pos,                                                            -- Center
		vector.add(pos, vector.multiply(forward, -WALL_ANCHOR_OFFSET)), -- Rear bumper
	}

	local p = {x = 0, y = 0, z = 0}
	local hit_wall = false

	for a = 1, 3 do
		local ap = anchors[a]
		local cx = round_int(ap.x)
		local cz = round_int(ap.z)

		for dx = -2, 2 do
			p.x = cx + dx
			for dz = -2, 2 do
				p.z = cz + dz
				local solid_col = false
				for ny = y_min, y_max do
					p.y = ny
					if is_node_solid(p) then
						solid_col = true
						break
					end
				end

				if solid_col then
					local closest_x = clamp(ap.x, p.x - 0.5, p.x + 0.5)
					local closest_z = clamp(ap.z, p.z - 0.5, p.z + 0.5)
					local rx = ap.x - closest_x
					local rz = ap.z - closest_z
					local d2 = rx * rx + rz * rz

					if d2 < body_r * body_r then
						local nx, nz, pen
						if d2 > 0.00001 then
							local d = math.sqrt(d2)
							nx = rx / d
							nz = rz / d
							pen = body_r - d
						else
							-- Center inside block: push back opposite forward
							local hx, hz = -forward.x, -forward.z
							local hl = math.sqrt(hx * hx + hz * hz)
							if hl < 0.01 then hx, hz, hl = 0, 1, 1 end
							nx, nz = hx / hl, hz / hl
							pen = body_r
						end

						pos.x = pos.x + nx * pen
						pos.z = pos.z + nz * pen
						ap.x = ap.x + nx * pen
						ap.z = ap.z + nz * pen

						local vn = vel.x * nx + vel.z * nz
						if vn < 0 then
							vel.x = vel.x - nx * vn
							vel.z = vel.z - nz * vn
							hit_wall = true
						end
					end
				end
			end
		end
	end

	if hit_wall and climb_boost > 0.25 then
		vel.x = vel.x * WALL_CLIMB_SPEED_BLEED
		vel.z = vel.z * WALL_CLIMB_SPEED_BLEED
	end
end

local function format_nitros(count)
	if count <= 0 then
		return "--"
	end
	local parts = {}
	for i = 1, count do
		parts[i] = "N"
	end
	return table.concat(parts, " ")
end

-----------------------------------------
-- Bullet Entity
-----------------------------------------
core.register_entity(MODNAME .. ":bullet", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.18, y = 0.18, z = 0.50},
		textures = {
			BULLET_TEX, BULLET_TEX, BULLET_TEX,
			BULLET_TEX, BULLET_TEX, BULLET_TEX,
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
	end,

	on_step = function(self, dtime)
		local dt = math.min(dtime, 0.1)
		local pos = self.object:get_pos()
		if not pos or not self.dir then
			self.object:remove()
			return
		end

		local step_dist = BULLET_SPEED * dt
		local next_pos = vector.add(pos, vector.multiply(self.dir, step_dist))

		local ray = core.raycast(pos, next_pos, false, false)
		local hit = ray:next()
		if hit and hit.type == "node" then
			self.object:remove()
			return
		end

		self.dist_traveled = self.dist_traveled + step_dist
		if self.dist_traveled >= BULLET_MAX_DIST then
			self.object:remove()
			return
		end

		self.object:set_pos(next_pos)
	end,
})

local function fire_bullet(player, truck_pos, truck_up)
	local look_dir = vector.normalize(player:get_look_dir())
	local eye_pos = vector.add(truck_pos, vector.multiply(truck_up, MUZZLE_HEIGHT_OFFSET))
	local muzzle_pos = vector.add(eye_pos, vector.multiply(look_dir, MUZZLE_FORWARD_OFFSET))

	local aim_target = vector.add(eye_pos, vector.multiply(look_dir, BULLET_MAX_DIST))
	local ray = core.raycast(eye_pos, aim_target, false, false)
	local hit = ray:next()
	if hit and hit.intersection_point then
		aim_target = hit.intersection_point
	end

	local bullet_dir = vector.subtract(aim_target, muzzle_pos)
	if vector.length(bullet_dir) < 0.1 then
		bullet_dir = look_dir
	else
		bullet_dir = vector.normalize(bullet_dir)
	end

	local bullet = core.add_entity(muzzle_pos, MODNAME .. ":bullet")
	if bullet then
		local ent = bullet:get_luaentity()
		ent.dir = bullet_dir
		ent.dist_traveled = 0
		bullet:set_rotation(vector.dir_to_rotation(bullet_dir))
	end
end

-----------------------------------------
-- Monster Truck & Turret Entities
-----------------------------------------
core.register_entity(MODNAME .. ":turret", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.80, y = 0.45, z = 1.50},
		textures = {
			"desert_stone.png", "desert_stone.png", "desert_stone.png",
			"desert_stone.png", "desert_stone.png", "desert_stone.png",
		},
		is_visible = SHOW_PLACEHOLDER_MODEL,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_step = function(self)
		if not self.owner_name or not active_drivers[self.owner_name] then
			self.object:remove()
		end
	end,
})

core.register_entity(MODNAME .. ":truck", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 2.4, y = 0.85, z = 2.8},
		textures = {
			"stone.png", "stone.png", "stone.png",
			"stone.png", "stone.png", "stone.png",
		},
		is_visible = SHOW_PLACEHOLDER_MODEL,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_step = function(self)
		if not self.owner_name or not active_drivers[self.owner_name] then
			self.object:remove()
		end
	end,
})

-----------------------------------------
-- Physics Tick
-----------------------------------------
local function step_vehicle_physics(state, controls, dt)
	local pos = state.pos
	local vel = state.vel

	-- Nitro timer update
	if state.nitro_timer > 0 then
		state.nitro_timer = math.max(0, state.nitro_timer - dt)
	end

	local jump_pressed = controls.jump == true
	if jump_pressed and not state.prev_jump then
		if state.nitros > 0 and state.nitro_timer <= 0 then
			state.nitros = state.nitros - 1
			state.nitro_timer = NITRO_DURATION
		end
	end
	state.prev_jump = jump_pressed

	local throttle = 0
	if controls.up then throttle = throttle + 1 end
	if controls.down then throttle = throttle - 1 end

	local steer = 0
	if controls.left then steer = steer + 1 end
	if controls.right then steer = steer - 1 end

	local right, up, forward = compute_basis(state.yaw, state.pitch, state.roll)

	-- Dynamic climb allowance: flat driving only clears FLAT_STEP_UP;
	-- pitched-up orientation or upward momentum lets you climb taller ledges.
	local climb_boost = 0.0
	if state.pitch > CLIMB_PITCH_THRESHOLD or vel.y > CLIMB_VEL_Y_THRESHOLD then
		climb_boost = clamp(
			math.max(0.0, state.pitch) * CLIMB_PITCH_GAIN + math.max(0.0, vel.y) * CLIMB_VEL_Y_GAIN,
			0.0,
			CLIMB_MAX_BOOST
		)
	end
	local max_step_up = FLAT_STEP_UP + climb_boost

	-- 1. Evaluate 4-wheel suspension & dynamic centroid pressure
	local total_spring_force = 0.0
	local total_pressure = 0.0
	local tau_pitch = 0.0
	local tau_roll = 0.0
	local deepest_floor_push = 0.0
	local wheels_touching = 0
	local wheel_ground_y = {}

	-- Suspension velocity along chassis 'up' so driving up ramps doesn't damp out lift
	local v_up = vector.dot(vel, up)

	for i = 1, 4 do
		local off = WHEEL_OFFSETS[i]
		local hub = vector.add(pos, vector.add(
			vector.multiply(right, off.x),
			vector.add(vector.multiply(up, off.y), vector.multiply(forward, off.z))
		))

		local ground_y = sample_smooth_ground_y(hub.x, hub.y, hub.z, max_step_up)
		wheel_ground_y[i] = ground_y
		if ground_y then
			local dist = hub.y - ground_y
			local comp = SUSPENSION_REST - dist
			if comp > 0 then
				wheels_touching = wheels_touching + 1
				comp = math.min(comp, MAX_COMP)
				local v_wheel_susp = v_up + state.pitch_rate * off.z - state.roll_rate * off.x
                local eff_comp = comp
				if comp > PROGRESSIVE_COMP_START then
					local extra = comp - PROGRESSIVE_COMP_START
					eff_comp = comp + extra * extra * PROGRESSIVE_SPRING_MULT
				end
				local f_spring = math.max(0.0, SPRING_K * eff_comp - SPRING_DAMP * v_wheel_susp)
				local pressure = clamp(comp / NOMINAL_COMP, 0.0, 1.5)

				total_spring_force = total_spring_force + f_spring
				total_pressure = total_pressure + pressure
				tau_pitch = tau_pitch + f_spring * off.z
				tau_roll = tau_roll - f_spring * off.x

				if comp > BOTTOM_OUT_COMP then
					deepest_floor_push = math.max(deepest_floor_push, comp - BOTTOM_OUT_COMP)
				end
			end
		end
	end

	-- Traction scales with how many and how hard the 4 wheels are pressed
	local traction = clamp(total_pressure / TRACTION_DIVISOR, 0.0, 1.0)

	-- 2. Apply gravity and normal suspension force along truck 'up'
	vel.y = vel.y - GRAVITY * dt
	if total_spring_force > 0 then
		vel = vector.add(vel, vector.multiply(up, total_spring_force * dt))
	end

	if deepest_floor_push > 0 then
		pos.y = pos.y + deepest_floor_push * BOTTOM_OUT_PUSH
		local vn_up = vector.dot(vel, up)
		if vn_up < 0 then
			vel = vector.subtract(vel, vector.multiply(up, vn_up * BOTTOM_OUT_VEL_KEEP))
		end
	end

	-- 3. Arcade Steering, Carve & Throttle (only effective when wheels have ground pressure)
	local v_fwd = vector.dot(vel, forward)
	local v_lat

    -- Deflect forward speed into upward Y momentum when hitting a bump/ramp at speed
	if wheels_touching > 0 and state.pitch > RAMP_MIN_PITCH and v_fwd > 4.0 and v_up < 0.0 then
		local speed_mag = vector.length(vel)
		local redirect = math.min(1.0, RAMP_REDIRECT_RATE * math.max(traction, 0.25) * dt)
		local target_vel = vector.multiply(forward, speed_mag * RAMP_SPEED_RETENTION)
		if target_vel.y > vel.y then
			vel = vector.add(vel, vector.multiply(vector.subtract(target_vel, vel), redirect))
			v_fwd = vector.dot(vel, forward)
		end
	end

	if traction > 0.0 then
		local steer_dir = (v_fwd >= -0.5) and 1.0 or -1.0
		local target_yaw_rate = steer * steer_dir * TARGET_TURN_RATE * traction
		local blend = math.min(1.0, STEER_RESPONSE * dt)
		state.yaw_rate = state.yaw_rate + (target_yaw_rate - state.yaw_rate) * blend

		-- Carve velocity into the new heading as the truck turns
		local delta_yaw = state.yaw_rate * dt
		if math.abs(delta_yaw) > 0.00001 then
			local carve_angle = delta_yaw * TURN_CARVE * traction
			local sc, cc = math.sin(carve_angle), math.cos(carve_angle)
			local vx, vz = vel.x, vel.z
			vel.x = vx * cc - vz * sc
			vel.z = vx * sc + vz * cc
		end

		-- Damp remaining lateral slip
		v_lat = vector.dot(vel, right)
		local lat_damp = math.min(1.0, LATERAL_GRIP * traction * dt)
		vel = vector.subtract(vel, vector.multiply(right, v_lat * lat_damp))

		-- Engine, Braking & Nitro thrust
		local boosting = state.nitro_timer > 0
		local target_max = boosting and NITRO_TOP_SPEED or WORLD_TOP_SPEED
		local drive_accel = 0.0

		if boosting then
			local boost_factor = (throttle >= 0) and 1.0 or 0.4
			drive_accel = NITRO_ACCEL * boost_factor * traction
		elseif throttle > 0 then
			drive_accel = ENGINE_ACCEL * throttle * traction
		elseif throttle < 0 then
			local accel_mag = (v_fwd > 2.0) and BRAKE_ACCEL or REVERSE_ACCEL
			drive_accel = accel_mag * throttle * traction
		end

		vel = vector.add(vel, vector.multiply(forward, drive_accel * dt))

		-- Drag tuned so flat max speed hits WORLD_TOP_SPEED (or NITRO_TOP_SPEED on Nitro)
		local new_v_fwd = vector.dot(vel, forward)
		local drag_k = (boosting and NITRO_ACCEL or ENGINE_ACCEL) / (target_max * target_max)
		local drag_decel = (ROLLING_DRAG * new_v_fwd + drag_k * new_v_fwd * math.abs(new_v_fwd)) * dt
		if math.abs(new_v_fwd) > target_max and not boosting then
			drag_decel = drag_decel + (new_v_fwd - clamp(new_v_fwd, -target_max * 0.6, target_max)) * OVERSPEED_DRAG * dt
		end
		vel = vector.subtract(vel, vector.multiply(forward, drag_decel))
	else
		-- Airborne: no acceleration or turning control, light yaw damping
		state.yaw_rate = state.yaw_rate * math.max(0.0, 1.0 - AIR_YAW_DAMP * dt)
	end

	-- 4. Integrate orientation (yaw, pitch, roll)
	state.yaw = state.yaw + state.yaw_rate * dt

	state.pitch_rate = state.pitch_rate + (tau_pitch / PITCH_INERTIA) * dt
	state.roll_rate = state.roll_rate + (tau_roll / ROLL_INERTIA) * dt

	local target_pitch = 0.0
	local target_roll = 0.0
	if wheels_touching > 0 and wheel_ground_y[1] and wheel_ground_y[2] and wheel_ground_y[3] and wheel_ground_y[4] then
		local g_front = (wheel_ground_y[1] + wheel_ground_y[2]) * 0.5
		local g_rear  = (wheel_ground_y[3] + wheel_ground_y[4]) * 0.5
		local g_left  = (wheel_ground_y[1] + wheel_ground_y[3]) * 0.5
		local g_right = (wheel_ground_y[2] + wheel_ground_y[4]) * 0.5
		target_pitch = clamp(math.atan2(g_front - g_rear, 2.0 * WHEEL_HALF_Z), -SLOPE_TARGET_MAX, SLOPE_TARGET_MAX)
		target_roll  = clamp(math.atan2(g_left - g_right, 2.0 * WHEEL_HALF_X), -SLOPE_TARGET_MAX, SLOPE_TARGET_MAX)
	end

	-- On impact/ground: conform fast to terrain slope; in mid-air: keep floaty launch angle
	local align_k = (wheels_touching > 0) and GROUND_ALIGN_K or AIR_ALIGN_K
	local rot_damp = (wheels_touching > 0) and GROUND_ROT_DAMP or AIR_ROT_DAMP

	state.pitch_rate = state.pitch_rate + (target_pitch - state.pitch) * align_k * dt
	state.roll_rate  = state.roll_rate  + (target_roll - state.roll) * align_k * dt
	state.pitch_rate = state.pitch_rate * math.max(0.0, 1.0 - rot_damp * dt)
	state.roll_rate  = state.roll_rate  * math.max(0.0, 1.0 - rot_damp * dt)

	state.pitch = clamp(state.pitch + state.pitch_rate * dt, -MAX_TILT_RAD, MAX_TILT_RAD)
	state.roll  = clamp(state.roll  + state.roll_rate  * dt, -MAX_TILT_RAD, MAX_TILT_RAD)

	-- 5. Integrate position & resolve wall collisions
	pos = vector.add(pos, vector.multiply(vel, dt))
	resolve_wall_collisions(pos, vel, forward, climb_boost)

	state.pos = pos
	state.vel = vel
end

-----------------------------------------
-- Enter / Exit Vehicle Mode
-----------------------------------------
local function enter_truck_mode(player)
	local name = player:get_player_name()
	if active_drivers[name] then return end

	local ppos = player:get_pos()
	local spawn_pos = vector.offset(ppos, 0, 1.2, 0)
	local start_yaw = player:get_look_horizontal()

	local truck = core.add_entity(spawn_pos, MODNAME .. ":truck")
	if not truck then
		core.chat_send_player(name, "Failed to spawn Monster Truck entity.")
		return
	end

	local turret = core.add_entity(vector.offset(spawn_pos, 0, TURRET_HEIGHT_OFFSET, 0), MODNAME .. ":turret")
	if not turret then
		truck:remove()
		core.chat_send_player(name, "Failed to spawn Turret entity.")
		return
	end

	truck:get_luaentity().owner_name = name
	turret:get_luaentity().owner_name = name

	local old_props = player:get_properties()
	local privs = core.get_player_privs(name)
	local had_interact = privs.interact == true
	if had_interact then
		privs.interact = nil
		core.set_player_privs(name, privs)
	end

	local old_hud_flags = player:hud_get_flags()
	player:hud_set_flags({hotbar = false, wielditem = false})

	player:set_properties({visual_size = {x = 0, y = 0, z = 0}})
	player:set_attach(truck, "", {x = 0, y = 10, z = 0}, {x = 0, y = 0, z = 0}, false)
	player:set_camera({mode = "third"})
	player:set_eye_offset({x = 0, y = 0, z = 0}, CAMERA_EYE_OFFSET, CAMERA_EYE_OFFSET)

	local speed_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.88},
		offset = {x = 0, y = -18},
		text = "0/" .. DISPLAY_TOP_SPEED,
		alignment = {x = 0, y = 0},
		number = 0xFFFFFF,
		size = {x = 2, y = 2},
	})

	local nitro_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.88},
		offset = {x = 0, y = 18},
		text = format_nitros(NITRO_MAX_CHARGES),
		alignment = {x = 0, y = 0},
		number = 0x00E5FF,
		size = {x = 2, y = 2},
	})

	active_drivers[name] = {
		truck = truck,
		turret = turret,
		pos = spawn_pos,
		vel = vector.zero(),
		yaw = start_yaw,
		yaw_rate = 0,
		pitch = 0,
		pitch_rate = 0,
		roll = 0,
		roll_rate = 0,
		nitros = NITRO_MAX_CHARGES,
		nitro_timer = 0,
		prev_jump = false,
		fire_cooldown = 0,
		speed_hud = speed_hud,
		nitro_hud = nitro_hud,
		last_speed_text = "",
		last_speed_color = 0xFFFFFF,
		last_nitro_text = "",
		saved_visual_size = old_props.visual_size,
		saved_hud_flags = old_hud_flags,
		had_interact = had_interact,
	}

	core.chat_send_player(name, "Monster Truck mode ON (WASD drive, Space Nitro, LMB Fire, /toggle to exit).")
end

local function exit_truck_mode(player, silent)
	local name = player:get_player_name()
	local state = active_drivers[name]
	if not state then return end

	active_drivers[name] = nil

	local exit_pos = state.pos and vector.offset(state.pos, 0, 1.5, 0) or player:get_pos()

	player:set_detach()
	player:set_pos(exit_pos)
	player:set_camera({mode = "any"})
	player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})

	if state.saved_visual_size then
		player:set_properties({visual_size = state.saved_visual_size})
	end
	if state.saved_hud_flags then
		player:hud_set_flags({
			hotbar = state.saved_hud_flags.hotbar,
			wielditem = state.saved_hud_flags.wielditem,
		})
	end
	if state.had_interact then
		local privs = core.get_player_privs(name)
		privs.interact = true
		core.set_player_privs(name, privs)
	end

	if state.speed_hud then player:hud_remove(state.speed_hud) end
	if state.nitro_hud then player:hud_remove(state.nitro_hud) end
	if state.turret and state.turret:is_valid() then state.turret:remove() end
	if state.truck and state.truck:is_valid() then state.truck:remove() end

	if not silent then
		core.chat_send_player(name, "Normal mode ON (Walk / Fly / Dig).")
	end
end

-----------------------------------------
-- Chat Command: /toggle
-----------------------------------------
core.register_chatcommand("toggle", {
	description = "Toggle between normal walk/fly/dig mode and Monster Truck mode",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		if active_drivers[name] then
			exit_truck_mode(player, false)
		else
			enter_truck_mode(player)
		end
		return true
	end,
})

-----------------------------------------
-- Globalstep: Input, Physics, Turret, Weapons & HUD
-----------------------------------------
core.register_globalstep(function(dtime)
	local clamped_dt = math.min(dtime, 0.1)

	for name, state in pairs(active_drivers) do
		local player = core.get_player_by_name(name)
		if not player or not state.truck or not state.truck:is_valid() then
			if player then
				exit_truck_mode(player, true)
			else
				if state.turret and state.turret:is_valid() then state.turret:remove() end
				if state.truck and state.truck:is_valid() then state.truck:remove() end
				active_drivers[name] = nil
			end
		else
			local controls = player:get_player_control()

			-- Adaptive sub-stepping so high speeds (60-90 n/s) never tunnel through 1-node walls
			local speed_est = vector.length(state.vel) + 15.0
			local n_steps = clamp(math.ceil((speed_est * clamped_dt) / MAX_DISP_PER_STEP), 2, MAX_SUB_STEPS)
			local step_dt = clamped_dt / n_steps
			for _ = 1, n_steps do
				step_vehicle_physics(state, controls, step_dt)
			end

			-- Apply truck position and 3D orientation
			local _, up, forward = compute_basis(state.yaw, state.pitch, state.roll)
			local truck_rot = vector.dir_to_rotation(forward, up)
			state.truck:set_pos(state.pos)
			state.truck:set_rotation(truck_rot)

			-- Update turret position & aim along player's look direction
			if state.turret and state.turret:is_valid() then
				local look_dir = vector.normalize(player:get_look_dir())
				local turret_pos = vector.add(state.pos, vector.multiply(up, TURRET_HEIGHT_OFFSET))
				state.turret:set_pos(turret_pos)

				local t_right = vector.cross(up, look_dir)
				if vector.length(t_right) > 0.01 then
					local ortho_up = vector.normalize(vector.cross(look_dir, t_right))
					state.turret:set_rotation(vector.dir_to_rotation(look_dir, ortho_up))
				else
					state.turret:set_rotation(vector.dir_to_rotation(look_dir))
				end
			end

			-- Weapons: LMB = Bullets, RMB = Bomb/Missile (unimplemented)
			if state.fire_cooldown > 0 then
				state.fire_cooldown = math.max(0, state.fire_cooldown - clamped_dt)
			end
			if controls.LMB and state.fire_cooldown <= 0 then
				fire_bullet(player, state.pos, up)
				state.fire_cooldown = BULLET_COOLDOWN
			end
			-- if controls.RMB then -- Bomb/Missile: unimplemented for now end

			-- Update HUD (only when values change)
			local speed_world = vector.length(vector.new(state.vel.x, 0, state.vel.z))
			local speed_disp = math.floor(speed_world * (DISPLAY_TOP_SPEED / WORLD_TOP_SPEED) + 0.5)
			local speed_text = string.format("%d/%d", speed_disp, DISPLAY_TOP_SPEED)
			local speed_color = (state.nitro_timer > 0) and 0xFFAA00 or 0xFFFFFF

			if speed_text ~= state.last_speed_text then
				player:hud_change(state.speed_hud, "text", speed_text)
				state.last_speed_text = speed_text
			end
			if speed_color ~= state.last_speed_color then
				player:hud_change(state.speed_hud, "number", speed_color)
				state.last_speed_color = speed_color
			end

			local nitro_text = format_nitros(state.nitros)
			if nitro_text ~= state.last_nitro_text then
				player:hud_change(state.nitro_hud, "text", nitro_text)
				state.last_nitro_text = nitro_text
			end
		end
	end
end)

-----------------------------------------
-- Cleanup on Disconnect / Shutdown
-----------------------------------------
core.register_on_leaveplayer(function(player)
	exit_truck_mode(player, true)
end)

core.register_on_shutdown(function()
	for name, _ in pairs(active_drivers) do
		local player = core.get_player_by_name(name)
		if player then
			exit_truck_mode(player, true)
		end
	end
end)