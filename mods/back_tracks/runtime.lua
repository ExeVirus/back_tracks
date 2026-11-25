local MODNAME = core.get_current_modname()

-----------------------------------------
-- Configuration & Tuning Constants
-----------------------------------------
local TRUCK_MESH = "monster_truck.gltf"
local TRUCK_TEXTURE = "monster_truck.png"
local TRUCK_MODEL_Y_OFFSET = -1.25 -- Offsets tire bottom (Y=0) down to ground below chassis center
local TRUCK_MODEL_FLIP_FWD = false -- Set true if the model faces backwards when driving

local START_POS = {x = 26, y = 12.0, z = 0}
local START_YAW = math.pi / 2 -- Faces -X down the Start Pad

-- Wheelbase & Visual Offsets
local WHEEL_HALF_X = 1.05
local WHEEL_HALF_Z = 1.25
local WHEEL_HUB_Y = -0.35
local CAMERA_ATTACH_OFFSET = {x = 0, y = 26, z = -18}     -- 10x model units: 2.6 up, 1.8 back
local CAMERA_EYE_OFFSET = {x = 0, y = 7.0, z = -5.0}        -- Engine clamps thirdperson_back z to [-5, 5], y to [-10, 15]
local NOSE_CAMERA_ATTACH_OFFSET = {x = 0, y = 2, z = 23}  -- 10x model units: 0.2 up (+1.625 eye_height), 2.3 forward

-- Front Bumper Aim & Slewing Reticle Tuning
local BUMPER_FWD_OFFSET = 1.95
local BUMPER_UP_OFFSET = 0.45
local AIM_SLEW_RATE = math.rad(360) -- 180 degrees in 0.5 seconds
local AIM_MAX_PITCH = math.rad(80)  -- +/- 80 degrees vertical aim cap (360 azimuth)
local CAMERA_FOV_DEG = 72.0         -- Matches Luanti default vertical FOV for screen projection

-- Checkpoints (Edit pos / yaw / boundary plane_normal here)
-- Triggers when dot(player_pos - cp.pos, cp.plane_normal) >= 0 within max_dist & [y_min, y_max]
local CHECKPOINTS = {
	{
		name = "Ramps",
		pos = {x = -300, y = 12.0, z = 0},
		yaw = math.pi / 2,
		plane_normal = {x = -1, y = 0, z = 0},
		max_dist = 85,
		y_min = -5, y_max = 60,
	},
	{
		name = "Causeway",
		pos = {x = -642, y = 13.5, z = 0},
		yaw = math.pi / 2,
		plane_normal = {x = -1, y = 0, z = 0},
		max_dist = 75,
		y_min = -5, y_max = 65,
	},
	{
		name = "Mountain",
		pos = {x = -946, y = 13.5, z = 0},
		yaw = math.pi / 2,
		plane_normal = {x = -1, y = 0, z = 0},
		max_dist = 95,
		y_min = -5, y_max = 75,
	},
	{
		name = "Tunnel",
		pos = {x = -1034, y = 91.5, z = 27},
		yaw = math.atan2(10, 3),
		plane_normal = {x = -0.97, y = 0, z = 0.24},
		max_dist = 26,
		y_min = 74, y_max = 115,
	},
	{
		name = "Exit",
		pos = {x = -1258, y = 97.5, z = 25},
		yaw = math.atan2(11.7, -25),
		plane_normal = {x = -0.80, y = 0, z = -0.60},
		max_dist = 26,
		y_min = 82, y_max = 125,
	},
	{
		name = "Mesa",
		pos = {x = -1217, y = 182.0, z = -29},
		yaw = math.atan2(-72, 29),
		plane_normal = {x = 0.88, y = 0, z = -0.47},
		max_dist = 26,
		y_min = 172, y_max = 215,
	},
}

local MESA_CHECKPOINT_IDX = #CHECKPOINTS
for i = 1, #CHECKPOINTS do
	if CHECKPOINTS[i].name == "Mesa" then
		MESA_CHECKPOINT_IDX = i
		break
	end
end
local MESA_CENTER_X = -1145.0
local MESA_CENTER_Z = 0.0
local MESA_SPIRAL_OUTER_RADIUS = 130.0 -- Adjust to match your mapgen's upper spiral outer edge

-- Truck Animation Tuning
local WHEEL_BONES = { "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr" }
local IDLE_SPEED_THRESHOLD = 0.45     -- World units/sec below which truck counts as stopped
local DRIVE_ANIM_SPEED_SCALE = 0.19   -- Scales drive animation speed to world speed (1:1 tire roll)
local DRIVE_ANIM_MAX_SPEED = 9.0      -- Caps animation multiplier at top/nitro speed
local DRIVE_STALL_SPIN_SPEED = 0.75   -- Wheel spin speed if holding throttle while blocked at 0 speed
local AIR_WHEEL_SPIN_SPEED = 14.0     -- Wheel spin rate (rad/s) when holding W/S in mid-air
local AIR_ANIM_GRACE = 0.12           -- Seconds airborne before switching to air wheel-spin mode

local WHEEL_OFFSETS = {
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front Right
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear Right
}

-- 3D Chassis Collision Hull (tucked inside tire envelope, roof spheres reach cab top)
local CHASSIS_SPHERES = {
	-- Lower skid-plate / chassis corners
	{x = -0.52, y = 0.35, z =  0.85, r = 0.40},
	{x =  0.52, y = 0.35, z =  0.85, r = 0.40},
	{x = -0.52, y = 0.35, z = -0.85, r = 0.40},
	{x =  0.52, y = 0.35, z = -0.85, r = 0.40},
	-- Upper cab roof corners (reaches y = +1.67 above chassis center, matching ~2.94 truck height)
	{x = -0.42, y = 1.25, z =  0.38, r = 0.42},
	{x =  0.42, y = 1.25, z =  0.38, r = 0.42},
	{x = -0.42, y = 1.25, z = -0.38, r = 0.42},
	{x =  0.42, y = 1.25, z = -0.38, r = 0.42},
}

-- 3D Suspension, Gravity & Surface Smoothing
local SUSPENSION_REST = 1.20
local MAX_COMP = 1.35
local SPRING_K = 15.5
local SPRING_DAMP = 6.8
local GRAVITY = 15.0

local PROGRESSIVE_COMP_START = 0.48
local PROGRESSIVE_SPRING_MULT = 12.0
local PROGRESSIVE_DAMP_MULT = 2.6
local BOTTOM_OUT_COMP = 1.12
local BOTTOM_OUT_PUSH = 0.40

local WHEEL_PROBE_UP = 1.55
local WHEEL_PROBE_STEP_UP = 2.45
local WHEEL_PROBE_DOWN = 1.35
local WHEEL_SMOOTH_SPAN = 0.72
local WHEEL_SMOOTH_WEIGHT = 0.55

-- Rigid-Body Inertia & Chassis Collision Response (decreased inertia for faster pitch/turn response)
local I_PITCH = 1.40
local I_YAW   = 1.60
local I_ROLL  = 1.40

local AIR_LIN_DRAG = 0.04
local AIR_ANG_DAMP = 0.35
local GROUND_ANG_DAMP = 2.40

local WALL_BOUNCE_THRESHOLD = -8.0 -- Only bounce on real impacts, not curved-wall scrapes
local WALL_RESTITUTION = 0.24
local WALL_FRICTION_SIDE = 0.06
local SKID_PLATE_FRICTION = 0.03
local ROOF_FRICTION_FLIP = 0.65

-- Driving, Weighty Steering, Top-Heavy Grip & Nitro
local MAX_DISP_PER_STEP = 0.28
local MAX_SUB_STEPS = 24
local WORLD_TOP_SPEED = 50.0
local DISPLAY_TOP_SPEED = 50
local NITRO_TOP_SPEED = 70.0

local NITRO_MAX = 100.0
local NITRO_BURN_RATE = 34.0
local NITRO_RECHARGE_RATE = 11.0
local NITRO_RECHARGE_DELAY = 0.65
local NITRO_MIN_START = 8.0

local ENGINE_ACCEL = 13.0
local REVERSE_ACCEL = 7.0
local BRAKE_ACCEL = 25.0
local NITRO_ACCEL = 25.0

local WHEELBASE_STEER = 3.2
local MAX_STEER_ANGLE = 0.42
local STEER_INPUT_SPEED = 4.2
local STEER_YAW_RESPONSE = 13.0
local LATERAL_GRIP = 14.5
local TIRE_MAX_LAT_ACCEL = 25.0
local TIRE_ROLL_ARM = 0.42         -- Balanced for higher lateral accel + lower roll inertia
local ROLLING_DRAG = 0.28          -- Viscous rolling resistance
local COAST_ROLL_FRICTION = 1.45   -- Constant rolling/engine drag when off-throttle (stops halfpipe wobble)
local OVERSPEED_DRAG = 1.4

-- Self-Righting Recovery (when flipped upside-down)
local FLIP_COOLDOWN = 0.75
local ROCK_TORQUE_RATE = 3.8

-- Health & Damage
local HEALTH_MAX = 100.0
local HEALTH_RECHARGE_RATE = 4.5
local HEALTH_RECHARGE_DELAY = 2.5
local LAVA_DPS = 30.0

-- Weapons
local BULLET_SPEED = 150.0
local BULLET_MAX_DIST = 220.0
local BULLET_COOLDOWN = 0.12
local BULLET_DAMAGE = 10
local BULLET_TEX = "[fill:16x16:#FFFFFF^[colorize:#FF2200:255"

local BOMB_COOLDOWN = 6.0
local BOMB_GRAVITY = 18.0
local BOMB_HOMING_RANGE = 58.0
local BOMB_HOMING_RATE = 5.5
local BOMB_HOMING_MAX_SPEED = 45.0
local BOMB_SIZE = {x = 0.62, y = 0.62, z = 0.62} -- ~60% of boss rock size
local BOMB_TEX = "[fill:16x16:#22EE44"
local BOMB_PARTICLE_1 = "[fill:16x16:#44FF66"
local BOMB_PARTICLE_2 = "[fill:16x16:#AAFF33"

-- HUD Bar Config
local HUD_BAR_W = 140
local HUD_BAR_H = 12

-- Shared Global State
local active_drivers = {}
back_tracks.active_drivers = active_drivers
back_tracks.enemies = back_tracks.enemies or {}
back_tracks.CHECKPOINTS = CHECKPOINTS

-----------------------------------------
-- Procedurally Built Reticle Texture
-----------------------------------------
local function build_reticle_texture()
	if not (core.encode_png and core.encode_base64) then
		return "[fill:16x16:#00FF88"
	end
	local size = 25
	local mid = 13
	local data = {}
	local idx = 1
	for y = 1, size do
		for x = 1, size do
			local dx = x - mid
			local dy = y - mid
			local adx = math.abs(dx)
			local ady = math.abs(dy)
			local r2 = dx * dx + dy * dy
			local col = "#00000000"

			if adx <= 1 and ady <= 1 then
				col = (adx == 0 and ady == 0) and "#FFFFFFFF" or "#002211CC"
			elseif (adx == 0 and ady >= 4 and ady <= 10) or (ady == 0 and adx >= 4 and adx <= 10) then
				col = "#00FF88FF"
			elseif (adx == 1 and ady >= 4 and ady <= 10) or (ady == 1 and adx >= 4 and adx <= 10) then
				col = "#002211AA"
			elseif r2 >= 72 and r2 <= 96 and (adx >= 4 and ady >= 4) then
				col = "#00FF88AA"
			end
			data[idx] = col
			idx = idx + 1
		end
	end
	return "[png:" .. core.encode_base64(core.encode_png(size, size, data))
end

local RETICLE_TEX = build_reticle_texture()

-----------------------------------------
-- Math & World Helpers
-----------------------------------------
local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
back_tracks.clamp = clamp

local function round_int(v)
	return math.floor(v + 0.5)
end
back_tracks.round_int = round_int

local function format_time(t)
	local total_cs = math.floor(math.max(0, t or 0) * 100 + 0.5)
	local cs = total_cs % 100
	local total_sec = math.floor(total_cs / 100)
	local sec = total_sec % 60
	local min = math.floor(total_sec / 60)
	return string.format("%02d:%02d.%02d", min, sec, cs)
end
back_tracks.format_time = format_time


local function is_node_solid(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "air" or node.name == "ignore" then
		return false
	end
	local def = core.registered_nodes[node.name]
	return def ~= nil and def.walkable == true
end
back_tracks.is_node_solid = is_node_solid

local function raycast_solid(p1, p2)
	local ray = core.raycast(p1, p2, false, false)
	for hit in ray do
		if hit.type == "node" and hit.under and is_node_solid(hit.under) then
			return hit
		end
	end
	return nil
end
back_tracks.raycast_solid = raycast_solid

local function sample_smooth_ground_y(wx, wy, wz, max_step_up)
	local cx = round_int(wx)
	local cz = round_int(wz)
	local max_surface_y = wy + max_step_up
	local top_scan = round_int(max_surface_y)
	local bot_scan = round_int(wy) - 4
	local two_sigma2 = 2.0 * 0.72 * 0.72

	local weight_sum = 0.0
	local height_sum = 0.0
	local p = {x = 0, y = 0, z = 0}

	for dx = -1, 1 do
		p.x = cx + dx
		for dz = -1, 1 do
			p.z = cz + dz
			local found_y = nil

			p.y = top_scan + 1
			if not is_node_solid(p) then
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
				local w = math.exp(-(rx * rx + rz * rz) / two_sigma2)
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
back_tracks.sample_smooth_ground_y = sample_smooth_ground_y

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
back_tracks.compute_basis = compute_basis

local function rotate_vec_axis_angle(v, axis, angle)
	local c = math.cos(angle)
	local s = math.sin(angle)
	local k_dot_v = vector.dot(axis, v)
	local k_cross_v = vector.cross(axis, v)
	return vector.add(
		vector.multiply(v, c),
		vector.add(
			vector.multiply(k_cross_v, s),
			vector.multiply(axis, k_dot_v * (1.0 - c))
		)
	)
end

local function orthonormalize_basis(forward, up)
	local f_len = vector.length(forward)
	if f_len < 1e-6 then
		forward = vector.new(0, 0, 1)
	else
		forward = vector.multiply(forward, 1.0 / f_len)
	end

	local right = vector.cross(up, forward)
	local r_len = vector.length(right)
	if r_len < 1e-5 then
		local ref = (math.abs(forward.y) < 0.9) and vector.new(0, 1, 0) or vector.new(1, 0, 0)
		right = vector.normalize(vector.cross(ref, forward))
	else
		right = vector.multiply(right, 1.0 / r_len)
	end

	up = vector.normalize(vector.cross(forward, right))
	return right, up, forward
end

local function safe_dir_to_rotation(forward, up)
	local f = forward
	local u = up
	if math.abs(f.y) > 0.9994 then
		f = vector.normalize(vector.add(f, vector.multiply(u, 0.002)))
		local r = vector.normalize(vector.cross(u, f))
		u = vector.normalize(vector.cross(f, r))
	end
	local rot = vector.dir_to_rotation(f, u)
	if rot.x ~= rot.x or rot.y ~= rot.y or rot.z ~= rot.z then
		return vector.zero()
	end
	return rot
end

local function apply_ang_impulse(ang_vel, ang_imp, right, up, forward)
	local dp = vector.dot(ang_imp, right)   / I_PITCH
	local dy = vector.dot(ang_imp, up)      / I_YAW
	local dr = vector.dot(ang_imp, forward) / I_ROLL
	return vector.add(ang_vel, vector.add(
		vector.multiply(right, dp),
		vector.add(vector.multiply(up, dy), vector.multiply(forward, dr))
	))
end

local function impulse_denom(r, n, right, up, forward)
	local rcn = vector.cross(r, n)
	local invI_rcn = vector.add(
		vector.multiply(right,   vector.dot(rcn, right)   / I_PITCH),
		vector.add(
			vector.multiply(up,      vector.dot(rcn, up)      / I_YAW),
			vector.multiply(forward, vector.dot(rcn, forward) / I_ROLL)
		)
	)
	return 1.0 + vector.dot(rcn, invI_rcn)
end

-----------------------------------------
-- 3D Local-Up Wheel Surface Sampler & Chassis Collider
-----------------------------------------
local WHEEL_SAMPLE_OFFSETS = {
	{u =  0.0,               v =  0.0,               w = 1.0},
	{u =  WHEEL_SMOOTH_SPAN, v =  0.0,               w = WHEEL_SMOOTH_WEIGHT},
	{u = -WHEEL_SMOOTH_SPAN, v =  0.0,               w = WHEEL_SMOOTH_WEIGHT},
	{u =  0.0,               v =  WHEEL_SMOOTH_SPAN, w = WHEEL_SMOOTH_WEIGHT},
	{u =  0.0,               v = -WHEEL_SMOOTH_SPAN, w = WHEEL_SMOOTH_WEIGHT},
}

local function sample_wheel_surface(hub, right, up, forward)
	local dist_sum = 0.0
	local w_sum = 0.0

	for i = 1, 5 do
		local off = WHEEL_SAMPLE_OFFSETS[i]
		local s_hub = vector.add(hub, vector.add(
			vector.multiply(right, off.u),
			vector.multiply(forward, off.v)
		))

		local ray_start = nil
		local p_top = vector.add(s_hub, vector.multiply(up, WHEEL_PROBE_UP))
		if not is_node_solid(vector.round(p_top)) then
			ray_start = p_top
		elseif is_node_solid(vector.round(s_hub)) then
			-- Steep rising ramp/halfpipe wall passes through wheel height; check if open air sits just above it
			local p_top2 = vector.add(s_hub, vector.multiply(up, WHEEL_PROBE_STEP_UP))
			if not is_node_solid(vector.round(p_top2)) then
				ray_start = p_top2
			end
		end

		if ray_start then
			local p_bot = vector.subtract(s_hub, vector.multiply(up, WHEEL_PROBE_DOWN))
			local hit = raycast_solid(ray_start, p_bot)
			if hit and hit.intersection_point and hit.intersection_normal then
				local n = hit.intersection_normal
				local n_len = vector.length(n)
				if n_len > 0.5 and vector.dot(n, up) > 0.05 then
					local d = vector.dot(vector.subtract(s_hub, hit.intersection_point), up)
					dist_sum = dist_sum + d * off.w
					w_sum = w_sum + off.w
				end
			end
		end
	end

	if w_sum <= 0.001 then
		return nil
	end
	return dist_sum / w_sum
end

-- Seam-free sphere vs solid voxel AABB test; also reports whether the hit voxel is a drivable step
local function resolve_sphere_voxels(ws_center, radius, up)
	local min_x = round_int(ws_center.x - radius)
	local max_x = round_int(ws_center.x + radius)
	local min_y = round_int(ws_center.y - radius)
	local max_y = round_int(ws_center.y + radius)
	local min_z = round_int(ws_center.z - radius)
	local max_z = round_int(ws_center.z + radius)

	local best_pen = 0.0
	local best_nx, best_ny, best_nz = 0.0, 0.0, 0.0
	local best_vx, best_vy, best_vz = 0, 0, 0
	local p = {x = 0, y = 0, z = 0}
	local nb = {x = 0, y = 0, z = 0}
	local r2 = radius * radius

	for vx = min_x, max_x do
		p.x = vx
		for vy = min_y, max_y do
			p.y = vy
			for vz = min_z, max_z do
				p.z = vz
				if is_node_solid(p) then
					local cx = clamp(ws_center.x, vx - 0.5, vx + 0.5)
					local cy = clamp(ws_center.y, vy - 0.5, vy + 0.5)
					local cz = clamp(ws_center.z, vz - 0.5, vz + 0.5)

					local dx = ws_center.x - cx
					local dy = ws_center.y - cy
					local dz = ws_center.z - cz

					if dx > 0.0001 then
						nb.x, nb.y, nb.z = vx + 1, vy, vz
						if is_node_solid(nb) then dx = 0.0 end
					elseif dx < -0.0001 then
						nb.x, nb.y, nb.z = vx - 1, vy, vz
						if is_node_solid(nb) then dx = 0.0 end
					end
					if dy > 0.0001 then
						nb.x, nb.y, nb.z = vx, vy + 1, vz
						if is_node_solid(nb) then dy = 0.0 end
					elseif dy < -0.0001 then
						nb.x, nb.y, nb.z = vx, vy - 1, vz
						if is_node_solid(nb) then dy = 0.0 end
					end
					if dz > 0.0001 then
						nb.x, nb.y, nb.z = vx, vy, vz + 1
						if is_node_solid(nb) then dz = 0.0 end
					elseif dz < -0.0001 then
						nb.x, nb.y, nb.z = vx, vy, vz - 1
						if is_node_solid(nb) then dz = 0.0 end
					end

					local d2 = dx * dx + dy * dy + dz * dz
					if d2 > 1e-8 and d2 < r2 then
						local d = math.sqrt(d2)
						local pen = radius - d
						if pen > best_pen then
							best_pen = pen
							best_nx, best_ny, best_nz = dx / d, dy / d, dz / d
							best_vx, best_vy, best_vz = vx, vy, vz
						end
					elseif d2 <= 1e-8 and ws_center.x >= vx - 0.5 and ws_center.x <= vx + 0.5
						and ws_center.y >= vy - 0.5 and ws_center.y <= vy + 0.5
						and ws_center.z >= vz - 0.5 and ws_center.z <= vz + 0.5 then
						local candidates = {
							{dist = (vx + 0.5) - ws_center.x, nx =  1, ny =  0, nz =  0, ox =  1, oy =  0, oz =  0},
							{dist = ws_center.x - (vx - 0.5), nx = -1, ny =  0, nz =  0, ox = -1, oy =  0, oz =  0},
							{dist = (vy + 0.5) - ws_center.y, nx =  0, ny =  1, nz =  0, ox =  0, oy =  1, oz =  0},
							{dist = ws_center.y - (vy - 0.5), nx =  0, ny = -1, nz =  0, ox =  0, oy = -1, oz =  0},
							{dist = (vz + 0.5) - ws_center.z, nx =  0, ny =  0, nz =  1, ox =  0, oy =  0, oz =  1},
							{dist = ws_center.z - (vz - 0.5), nx =  0, ny =  0, nz = -1, ox =  0, oy =  0, oz = -1},
						}
						local min_face = 999
						for c_i = 1, 6 do
							local cand = candidates[c_i]
							nb.x, nb.y, nb.z = vx + cand.ox, vy + cand.oy, vz + cand.oz
							if not is_node_solid(nb) and cand.dist < min_face then
								min_face = cand.dist
								local pen = radius + cand.dist
								if pen > best_pen then
									best_pen = pen
									best_nx, best_ny, best_nz = cand.nx, cand.ny, cand.nz
									best_vx, best_vy, best_vz = vx, vy, vz
								end
							end
						end
					end
				end
			end
		end
	end

	if best_pen > 0.0 then
		local n = vector.new(best_nx, best_ny, best_nz)
		local is_step = false
		if up then
			local up_cell = {
				x = round_int(best_vx + up.x),
				y = round_int(best_vy + up.y),
				z = round_int(best_vz + up.z),
			}
			is_step = not is_node_solid(up_cell)
		end
		return best_pen, n, is_step
	end
	return 0.0, nil, false
end

local function resolve_chassis_collisions(state)
	local pos = state.pos
	local vel = state.vel
	local ang_vel = state.ang_vel
	local right, up, forward = state.right, state.up, state.forward
	local flipped = (up.y < 0.25)

	local contacts = {}

	for i = 1, #CHASSIS_SPHERES do
		local s = CHASSIS_SPHERES[i]
		local r_local = vector.add(
			vector.multiply(right, s.x),
			vector.add(vector.multiply(up, s.y), vector.multiply(forward, s.z))
		)
		local ws_center = vector.add(pos, r_local)
		local pen, n, is_step = resolve_sphere_voxels(ws_center, s.r, up)
		if pen > 0.004 and n then
			local is_roof = (i > 4)
			local is_skid_step = (not is_roof) and (not flipped) and is_step and (vector.dot(n, up) > -0.25)

			-- If the lower belly clips a stair/halfpipe edge, slide up/over it instead of braking backward
			if is_skid_step then
				local n_skid = vector.normalize(vector.add(n, vector.multiply(up, 1.35)))
				local fwd_comp = vector.dot(n_skid, forward)
				if fwd_comp < 0.0 and vector.dot(vel, forward) > 2.0 then
					n_skid = vector.normalize(vector.subtract(n_skid, vector.multiply(forward, fwd_comp)))
				end
				n = n_skid
			end

			contacts[#contacts + 1] = {
				r = r_local,
				n = n,
				pen = pen,
				is_roof = is_roof,
				is_skid_step = is_skid_step,
			}
			pos = vector.add(pos, vector.multiply(n, (pen - 0.002) * 0.65))
		end
	end

	if #contacts > 0 then
		state.chassis_touching = true
		for pass = 1, 2 do
			for k = 1, #contacts do
				local c = contacts[k]
				local r = c.r
				local n = c.n
				local v_contact = vector.add(vel, vector.cross(ang_vel, r))
				local vn = vector.dot(v_contact, n)

				if vn < 0.0 then
					local denom = impulse_denom(r, n, right, up, forward)
					local e = 0.0
					if pass == 1 and (not c.is_skid_step) and vn < WALL_BOUNCE_THRESHOLD then
						e = WALL_RESTITUTION
					end
					local j_n = -(1.0 + e) * vn / denom
					local imp_n = vector.multiply(n, j_n)

					vel = vector.add(vel, imp_n)
					ang_vel = apply_ang_impulse(ang_vel, vector.cross(r, imp_n), right, up, forward)

					-- Tangential scraping friction
					local v_after = vector.add(vel, vector.cross(ang_vel, r))
					local v_tan = vector.subtract(v_after, vector.multiply(n, vector.dot(v_after, n)))
					local vt_len = vector.length(v_tan)
					if vt_len > 0.01 then
						local t_dir = vector.multiply(v_tan, 1.0 / vt_len)
						local mu = WALL_FRICTION_SIDE
						if flipped or c.is_roof then
							mu = ROOF_FRICTION_FLIP
						elseif c.is_skid_step then
							mu = SKID_PLATE_FRICTION
						end
						local denom_t = impulse_denom(r, t_dir, right, up, forward)
						local j_t = math.min(vt_len / denom_t, mu * j_n)
						local imp_t = vector.multiply(t_dir, -j_t)

						vel = vector.add(vel, imp_t)
						ang_vel = apply_ang_impulse(ang_vel, vector.cross(r, imp_t), right, up, forward)
					end
				end
			end
		end
	end

	state.pos = pos
	state.vel = vel
	state.ang_vel = ang_vel
end

local function resolve_wall_collisions(pos, vel, forward, _climb_boost)
	local right, up, fwd = orthonormalize_basis(forward, vector.new(0, 1, 0))
	local tmp = {
		pos = pos,
		vel = vel,
		ang_vel = vector.zero(),
		right = right,
		up = up,
		forward = fwd,
	}
	resolve_chassis_collisions(tmp)
	pos.x, pos.y, pos.z = tmp.pos.x, tmp.pos.y, tmp.pos.z
	vel.x, vel.y, vel.z = tmp.vel.x, tmp.vel.y, tmp.vel.z
end
back_tracks.resolve_wall_collisions = resolve_wall_collisions

-----------------------------------------
-- Ref-Counted Dynamic Headlight System
-----------------------------------------
local HEADLIGHT_NODE = MODNAME .. ":headlight_air"
local light_refs = {}

local function add_light_at(p, list_out)
	local rp = {x = round_int(p.x), y = round_int(p.y), z = round_int(p.z)}
	local h = core.hash_node_position(rp)
	local cur = light_refs[h]
	if cur then
		light_refs[h] = cur + 1
		list_out[#list_out + 1] = rp
		return
	end
	local node = core.get_node_or_nil(rp)
	if node and node.name == "air" then
		core.set_node(rp, {name = HEADLIGHT_NODE})
		light_refs[h] = 1
		list_out[#list_out + 1] = rp
	end
end

local function clear_light_list(list)
	if not list then return end
	for i = 1, #list do
		local rp = list[i]
		local h = core.hash_node_position(rp)
		local cur = light_refs[h]
		if cur then
			if cur <= 1 then
				light_refs[h] = nil
				local node = core.get_node_or_nil(rp)
				if node and node.name == HEADLIGHT_NODE then
					core.set_node(rp, {name = "air"})
				end
			else
				light_refs[h] = cur - 1
			end
		end
	end
end
back_tracks.clear_light_list = clear_light_list

local function update_headlights(old_list, beam_positions)
	clear_light_list(old_list)
	local new_list = {}
	for i = 1, #beam_positions do
		add_light_at(beam_positions[i], new_list)
	end
	return new_list
end
back_tracks.update_headlights = update_headlights

-----------------------------------------
-- Explosion & Combat Helpers
-----------------------------------------
function back_tracks.spawn_explosion(pos, scale)
	local s = scale or 1.0
	core.add_particlespawner({
		amount = math.floor(28 * s),
		time = 0.08,
		minpos = vector.subtract(pos, vector.new(0.4, 0.4, 0.4)),
		maxpos = vector.add(pos, vector.new(0.4, 0.4, 0.4)),
		minvel = vector.new(-9 * s, 2, -9 * s),
		maxvel = vector.new( 9 * s, 12 * s, 9 * s),
		minacc = vector.new(0, -14, 0),
		maxacc = vector.new(0, -10, 0),
		minexptime = 0.25,
		maxexptime = 0.65,
		minsize = 3.0 * s,
		maxsize = 6.5 * s,
		glow = 14,
		texture = "[fill:16x16:#FF7700",
	})
	core.add_particlespawner({
		amount = math.floor(14 * s),
		time = 0.08,
		minpos = vector.subtract(pos, vector.new(0.3, 0.3, 0.3)),
		maxpos = vector.add(pos, vector.new(0.3, 0.3, 0.3)),
		minvel = vector.new(-5 * s, 3, -5 * s),
		maxvel = vector.new( 5 * s, 9 * s, 5 * s),
		minexptime = 0.35,
		maxexptime = 0.85,
		minsize = 4.0 * s,
		maxsize = 8.0 * s,
		glow = 10,
		texture = "[fill:16x16:#FFEE44",
	})
	-- TODO: Play explosion sound effect here
end

function back_tracks.damage_player(name, amount)
	local state = active_drivers[name]
	if not state or state.hp <= 0 then return end
	state.hp = math.max(0.0, state.hp - amount)
	state.hp_delay = HEALTH_RECHARGE_DELAY
end

function back_tracks.register_kill(name)
	local state = active_drivers[name]
	if state then
		state.kills = state.kills + 1
	end
end

-----------------------------------------
-- Player Bullet Entity (Front Bumper)
-----------------------------------------
core.register_entity(MODNAME .. ":bullet", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.16, y = 0.16, z = 0.50},
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
		self.owner_name = nil
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

		local seg = vector.subtract(next_pos, pos)
		local seg_len2 = vector.dot(seg, seg)
		if seg_len2 > 1e-6 then
			for _, enemy in pairs(back_tracks.enemies) do
				if enemy.obj and enemy.obj:is_valid() and not enemy.dead then
					local ep = enemy.pos or enemy.obj:get_pos()
					if ep then
						local t = clamp(vector.dot(vector.subtract(ep, pos), seg) / seg_len2, 0, 1)
						local closest = vector.add(pos, vector.multiply(seg, t))
						local d2 = vector.dot(vector.subtract(ep, closest), vector.subtract(ep, closest))
						local hit_r = enemy.hit_radius or 2.0
						if d2 <= hit_r * hit_r then
							if enemy.damage then
								enemy.damage(BULLET_DAMAGE, self.owner_name)
							elseif enemy.kill then
								enemy.kill(self.owner_name)
							else
								enemy.dead = true
								back_tracks.spawn_explosion(ep, 1.0)
								enemy.obj:remove()
							end
							self.object:remove()
							return
						end
					end
				end
			end
		end

		if raycast_solid(pos, next_pos) then
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

local function fire_bullet(player, state)
	local aim_dir = state.aim_dir
	local bumper_pos = vector.add(state.pos, vector.add(
		vector.multiply(state.forward, BUMPER_FWD_OFFSET),
		vector.multiply(state.up, BUMPER_UP_OFFSET)
	))
	if is_node_solid(vector.round(bumper_pos)) then
		bumper_pos = vector.add(state.pos, vector.multiply(state.up, 0.85))
	end

	-- Converge from camera/roof aim ray onto solid node or enemy under reticle
	local aim_origin = vector.add(state.pos, vector.multiply(state.up, 2.5))
	local aim_target = vector.add(aim_origin, vector.multiply(aim_dir, BULLET_MAX_DIST))
	local best_dist2 = BULLET_MAX_DIST * BULLET_MAX_DIST

	local hit = raycast_solid(aim_origin, aim_target)
	if hit and hit.intersection_point then
		local d2 = vector.dot(
			vector.subtract(hit.intersection_point, bumper_pos),
			vector.subtract(hit.intersection_point, bumper_pos)
		)
		if d2 > 9.0 then
			aim_target = hit.intersection_point
			best_dist2 = vector.dot(
				vector.subtract(aim_target, aim_origin),
				vector.subtract(aim_target, aim_origin)
			)
		end
	end

	local aim_seg = vector.subtract(aim_target, aim_origin)
	local aim_len2 = vector.dot(aim_seg, aim_seg)
	if aim_len2 > 1e-4 then
		for _, enemy in pairs(back_tracks.enemies) do
			if enemy.obj and enemy.obj:is_valid() and not enemy.dead then
				local ep = enemy.pos or enemy.obj:get_pos()
				if ep then
					local t = clamp(vector.dot(vector.subtract(ep, aim_origin), aim_seg) / aim_len2, 0, 1)
					local closest = vector.add(aim_origin, vector.multiply(aim_seg, t))
					local r = (enemy.hit_radius or 2.0) + 0.4
					local perp2 = vector.dot(vector.subtract(ep, closest), vector.subtract(ep, closest))
					local along2 = t * t * aim_len2
					if perp2 <= r * r and along2 < best_dist2 and along2 > 9.0 then
						best_dist2 = along2
						aim_target = ep
					end
				end
			end
		end
	end

	local bullet_dir = vector.subtract(aim_target, bumper_pos)
	if vector.length(bullet_dir) < 0.1 then
		bullet_dir = aim_dir
	else
		bullet_dir = vector.normalize(bullet_dir)
		if vector.dot(bullet_dir, aim_dir) < 0.5 then
			bullet_dir = aim_dir
		end
	end

	local bullet = core.add_entity(bumper_pos, MODNAME .. ":bullet")
	if bullet then
		local ent = bullet:get_luaentity()
		ent.dir = bullet_dir
		ent.dist_traveled = 0
		ent.owner_name = player:get_player_name()
		bullet:set_rotation(vector.dir_to_rotation(bullet_dir))
	end
end

-----------------------------------------
-- Player Bomb Entity (Right-Click Drop) & Nitro Thrusters
-----------------------------------------
core.register_entity(MODNAME .. ":bomb", {
	initial_properties = {
		visual = "cube",
		visual_size = BOMB_SIZE,
		textures = {
			BOMB_TEX, BOMB_TEX, BOMB_TEX,
			BOMB_TEX, BOMB_TEX, BOMB_TEX,
		},
		glow = 12,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
	},

	on_activate = function(self)
		self.vel = vector.zero()
		self.rot = vector.zero()
		self.age = 0.0
		self.fx_timer = 0.0
		self.owner_name = nil
	end,

	on_step = function(self, dtime)
		local dt = math.min(dtime, 0.1)
		local pos = self.object:get_pos()
		if not pos or not self.vel then
			self.object:remove()
			return
		end

		self.age = self.age + dt
		if self.age > 8.0 or pos.y < -40.0 then
			self.object:remove()
			return
		end

		self.vel.y = self.vel.y - BOMB_GRAVITY * dt

		-- Home horizontally toward the active boss mouth when dropped above the Mesa
		local home_target = nil
		for _, enemy in pairs(back_tracks.enemies) do
			if enemy.obj and enemy.obj:is_valid() and not enemy.dead
				and enemy.uid and enemy.uid >= 100000
				and enemy.hit_radius and enemy.hit_radius >= 7.0 then
				home_target = enemy.pos or enemy.obj:get_pos()
				break
			end
		end

		local homed = false
		if home_target and pos.y >= home_target.y + 0.5 then
			local to_x = home_target.x - pos.x
			local to_z = home_target.z - pos.z
			local h_dist = math.sqrt(to_x * to_x + to_z * to_z)
			if h_dist <= BOMB_HOMING_RANGE then
				local dy = math.max(0.5, pos.y - home_target.y)
				local v_down = -self.vel.y
				local disc = v_down * v_down + 2.0 * BOMB_GRAVITY * dy
				local t_fall = math.max(0.18, (-v_down + math.sqrt(disc)) / BOMB_GRAVITY)

				local des_vx = to_x / t_fall
				local des_vz = to_z / t_fall
				local des_spd = math.sqrt(des_vx * des_vx + des_vz * des_vz)
				if des_spd > BOMB_HOMING_MAX_SPEED then
					local s = BOMB_HOMING_MAX_SPEED / des_spd
					des_vx = des_vx * s
					des_vz = des_vz * s
				end

				local alpha = 1.0 - math.exp(-BOMB_HOMING_RATE * dt)
				self.vel.x = self.vel.x + (des_vx - self.vel.x) * alpha
				self.vel.z = self.vel.z + (des_vz - self.vel.z) * alpha
				homed = true
			end
		end

		if not homed then
			local drag = math.max(0.0, 1.0 - 0.55 * dt)
			self.vel.x = self.vel.x * drag
			self.vel.z = self.vel.z * drag
		end

		local next_pos = vector.add(pos, vector.multiply(self.vel, dt))

		-- Green particles streaming off the falling bomb
		self.fx_timer = self.fx_timer - dt
		if self.fx_timer <= 0.0 then
			self.fx_timer = 0.025
			core.add_particlespawner({
				amount = 3,
				time = 0.03,
				minpos = vector.subtract(pos, vector.new(0.2, 0.2, 0.2)),
				maxpos = vector.add(pos, vector.new(0.2, 0.2, 0.2)),
				minvel = vector.new(-1.5, 1.5, -1.5),
				maxvel = vector.new( 1.5, 4.5,  1.5),
				minexptime = 0.20,
				maxexptime = 0.40,
				minsize = 1.8,
				maxsize = 3.2,
				glow = 12,
				texture = (math.random() < 0.5) and BOMB_PARTICLE_1 or BOMB_PARTICLE_2,
			})
		end

		local hit = raycast_solid(pos, vector.add(next_pos, vector.new(0, -0.35, 0)))
		local mouth_hit = back_tracks.is_bomb_hit_mouth and back_tracks.is_bomb_hit_mouth(next_pos)

		if hit or mouth_hit then
			local det_pos = (hit and hit.intersection_point) or next_pos
			back_tracks.spawn_explosion(det_pos, 1.7)
			core.add_particlespawner({
				amount = 24,
				time = 0.06,
				minpos = vector.subtract(det_pos, vector.new(0.5, 0.3, 0.5)),
				maxpos = vector.add(det_pos, vector.new(0.5, 0.5, 0.5)),
				minvel = vector.new(-10, 3, -10),
				maxvel = vector.new( 10, 14, 10),
				minacc = vector.new(0, -14, 0),
				maxacc = vector.new(0, -10, 0),
				minexptime = 0.25,
				maxexptime = 0.55,
				minsize = 2.8,
				maxsize = 5.5,
				glow = 14,
				texture = BOMB_PARTICLE_1,
			})

			if back_tracks.on_bomb_explode then
				back_tracks.on_bomb_explode(det_pos, self.owner_name)
			end

			-- Splash damage to nearby ground turrets (boss entities use uid >= 100000)
			for _, enemy in pairs(back_tracks.enemies) do
				if enemy.obj and enemy.obj:is_valid() and not enemy.dead
					and (not enemy.uid or enemy.uid < 100000) then
					local ep = enemy.pos or enemy.obj:get_pos()
					if ep and vector.distance(ep, det_pos) <= 6.5 then
						if enemy.kill then
							enemy.kill(self.owner_name)
						elseif enemy.damage then
							enemy.damage(40, self.owner_name)
						end
					end
				end
			end

			self.object:remove()
			return
		end

		self.rot.x = self.rot.x + 3.5 * dt
		self.rot.z = self.rot.z + 2.5 * dt
		self.object:set_pos(next_pos)
		self.object:set_rotation(self.rot)
	end,
})

local function drop_bomb(player, state)
	local spawn_pos = vector.add(state.pos, vector.multiply(state.up, -0.55))
	if is_node_solid(vector.round(spawn_pos)) then
		spawn_pos = vector.add(state.pos, vector.multiply(state.up, 0.35))
	end

	local bomb = core.add_entity(spawn_pos, MODNAME .. ":bomb")
	if bomb then
		local ent = bomb:get_luaentity()
		ent.vel = vector.new(
			state.vel.x * 0.48,
			math.min(state.vel.y * 0.25, 0.0) - 5.5,
			state.vel.z * 0.48
		)
		ent.owner_name = player:get_player_name()
		state.bomb_cooldown = BOMB_COOLDOWN
	end
end

local function spawn_nitro_thrusters(state)
	local rear_center = vector.add(
		vector.subtract(state.pos, vector.multiply(state.forward, 1.05)),
		vector.multiply(state.up, 0.20)
	)
	local base_vel = vector.add(
		vector.multiply(state.forward, -16.0),
		vector.multiply(state.vel, 0.35)
	)
	for side = -1, 1, 2 do
		local nozzle = vector.add(rear_center, vector.multiply(state.right, side * 0.52))
		core.add_particlespawner({
			amount = 4,
			time = 0.03,
			minpos = vector.subtract(nozzle, vector.new(0.0, 0.0, 0.0)),
			maxpos = vector.add(nozzle, vector.new(0.12, 0.12, 0.12)),
			minvel = vector.subtract(base_vel, vector.new(1.5, 1.5, 1.5)),
			maxvel = vector.add(base_vel, vector.new(1.5, 1.5, 1.5)),
			minexptime = 0.10,
			maxexptime = 0.24,
			minsize = 0.5,
			maxsize = 1.0,
			glow = 14,
			texture = "[fill:16x16:#FF6600",
		})
		core.add_particlespawner({
			amount = 2,
			time = 0.03,
			minpos = vector.subtract(nozzle, vector.new(0.08, 0.08, 0.08)),
			maxpos = vector.add(nozzle, vector.new(0.08, 0.08, 0.08)),
			minvel = vector.subtract(base_vel, vector.new(1.0, 1.0, 1.0)),
			maxvel = vector.add(base_vel, vector.new(1.0, 1.0, 1.0)),
			minexptime = 0.08,
			maxexptime = 0.16,
			minsize = 1.4,
			maxsize = 2.6,
			glow = 14,
			texture = (math.random() < 0.5) and "[fill:16x16:#FFEE33" or "[fill:16x16:#FF2200",
		})
	end
end

-----------------------------------------
-- Slewing Aim & Screen-Space Reticle
-----------------------------------------
local function clamp_pitch_dir(dir, max_pitch)
	local p = math.asin(clamp(dir.y, -1.0, 1.0))
	if math.abs(p) <= max_pitch then
		return dir
	end
	p = clamp(p, -max_pitch, max_pitch)
	local h2 = dir.x * dir.x + dir.z * dir.z
	if h2 < 1e-8 then
		return vector.new(0, math.sin(p), math.cos(p))
	end
	local h = math.sqrt(h2)
	local cp = math.cos(p)
	return vector.new((dir.x / h) * cp, math.sin(p), (dir.z / h) * cp)
end

local function step_aim_reticle(name, player, state, dt)
	local look_dir = vector.normalize(player:get_look_dir())
	local target_pitch = clamp(math.asin(clamp(look_dir.y, -1.0, 1.0)), -AIM_MAX_PITCH, AIM_MAX_PITCH)

	local hx, hz = look_dir.x, look_dir.z
	local h_len = math.sqrt(hx * hx + hz * hz)
	local target_dir
	if h_len > 1e-4 then
		local cp = math.cos(target_pitch)
		target_dir = vector.new((hx / h_len) * cp, math.sin(target_pitch), (hz / h_len) * cp)
	else
		local cur = state.aim_dir
		local ch = math.sqrt(cur.x * cur.x + cur.z * cur.z)
		local cx = (ch > 1e-4) and (cur.x / ch) or 0
		local cz = (ch > 1e-4) and (cur.z / ch) or 1
		local cp = math.cos(target_pitch)
		target_dir = vector.new(cx * cp, math.sin(target_pitch), cz * cp)
	end

	local aim_dir = state.aim_dir
	local ang = math.acos(clamp(vector.dot(aim_dir, target_dir), -1.0, 1.0))
	if ang > 1e-4 then
		local step_ang = math.min(ang, AIM_SLEW_RATE * dt)
		local axis = vector.cross(aim_dir, target_dir)
		local axis_len = vector.length(axis)
		if axis_len > 1e-5 then
			axis = vector.multiply(axis, 1.0 / axis_len)
		else
			axis = vector.new(-aim_dir.z, 0, aim_dir.x)
			if vector.length(axis) < 1e-4 then
				axis = vector.new(1, 0, 0)
			else
				axis = vector.normalize(axis)
			end
		end
		aim_dir = vector.normalize(rotate_vec_axis_angle(aim_dir, axis, step_ang))
		aim_dir = clamp_pitch_dir(aim_dir, AIM_MAX_PITCH)
		state.aim_dir = aim_dir
	end

	-- Project state.aim_dir into screen space for the HUD reticle
	local cam_fwd = look_dir
	local cam_right = vector.cross(vector.new(0, 1, 0), cam_fwd)
	if vector.length(cam_right) < 1e-4 then
		cam_right = vector.new(1, 0, 0)
	else
		cam_right = vector.normalize(cam_right)
	end
	local cam_up = vector.normalize(vector.cross(cam_fwd, cam_right))

	local dx = vector.dot(state.aim_dir, cam_right)
	local dy = vector.dot(state.aim_dir, cam_up)
	local dz = vector.dot(state.aim_dir, cam_fwd)

	local win = core.get_player_window_information and core.get_player_window_information(name)
	local aspect = (win and win.size and win.size.y > 0) and (win.size.x / win.size.y) or (16 / 9)
	local tan_half_fov = math.tan(math.rad(CAMERA_FOV_DEG) * 0.5)

	local rx, ry
	if dz > 0.05 then
		local ndc_x = (dx / dz) / (tan_half_fov * aspect)
		local ndc_y = (dy / dz) / tan_half_fov
		rx = clamp(0.5 + 0.5 * ndc_x, 0.04, 0.96)
		ry = clamp(0.5 - 0.5 * ndc_y, 0.04, 0.96)
	else
		local edge_len = math.sqrt(dx * dx + dy * dy)
		if edge_len > 1e-4 then
			rx = clamp(0.5 + 0.46 * (dx / edge_len), 0.04, 0.96)
			ry = clamp(0.5 - 0.46 * (dy / edge_len), 0.04, 0.96)
		else
			rx, ry = 0.5, 0.5
		end
	end

	if math.abs(rx - state.last_reticle_x) > 0.001 or math.abs(ry - state.last_reticle_y) > 0.001 then
		player:hud_change(state.reticle_hud, "position", {x = rx, y = ry})
		state.last_reticle_x = rx
		state.last_reticle_y = ry
	end
end

-----------------------------------------
-- Monster Truck, Checkpoint Marker & Camera Mount Entities
-----------------------------------------
core.register_entity(MODNAME .. ":checkpoint_marker", {
	initial_properties = {
		visual = "sprite",
		textures = {"[fill:1x1:#00000000"},
		visual_size = {x = 0.1, y = 0.1},
		is_visible = false,
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
		visual = "mesh",
		mesh = TRUCK_MESH,
		textures = { TRUCK_TEXTURE },
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
		if not self.owner_name or not active_drivers[self.owner_name] then
			self.object:remove()
		end
	end,
})

core.register_entity(MODNAME .. ":cam_mount", {
	initial_properties = {
		visual = "cube",
		textures = {
			"[fill:1x1:#00000000", "[fill:1x1:#00000000", "[fill:1x1:#00000000",
			"[fill:1x1:#00000000", "[fill:1x1:#00000000", "[fill:1x1:#00000000",
		},
		use_texture_alpha = true,
		visual_size = {x = 0.001, y = 0.001, z = 0.001},
		is_visible = true,
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
-- Checkpoints & Waypoint Management
-----------------------------------------
local function sync_next_checkpoint_marker(name, player, state)
	local next_cp = CHECKPOINTS[state.checkpoint_idx + 1]
	if not next_cp then
		if state.cp_entity and state.cp_entity:is_valid() then
			state.cp_entity:remove()
		end
		state.cp_entity = nil
		if state.waypoint_hud then
			player:hud_remove(state.waypoint_hud)
			state.waypoint_hud = nil
		end
		return
	end

	local wp_pos = vector.new(next_cp.pos.x, next_cp.pos.y + 3.0, next_cp.pos.z)
	if state.cp_entity and state.cp_entity:is_valid() then
		state.cp_entity:set_pos(wp_pos)
	else
		local marker = core.add_entity(wp_pos, MODNAME .. ":checkpoint_marker")
		if marker then
			marker:get_luaentity().owner_name = name
			if marker.set_observers then
				marker:set_observers({[name] = true})
			end
			state.cp_entity = marker
		end
	end

	if state.waypoint_hud then
		player:hud_change(state.waypoint_hud, "world_pos", wp_pos)
		player:hud_change(state.waypoint_hud, "name", next_cp.name)
	else
		local wp_id = player:hud_add({
			type = "waypoint",
			name = next_cp.name,
			text = "m",
			precision = 1,
			number = 0xFFCC33,
			world_pos = wp_pos,
			alignment = {x = 0, y = 0},
			offset = {x = 0, y = 0},
		})
		state.waypoint_hud = wp_id
	end
end

local function advance_checkpoint(name, player, state, new_idx)
	state.checkpoint_idx = new_idx
	local cp = CHECKPOINTS[new_idx]
	sync_next_checkpoint_marker(name, player, state)

	if cp and state.cp_flash_hud then
		player:hud_change(state.cp_flash_hud, "text", "CHECKPOINT: " .. string.upper(cp.name))
		state.cp_flash_timer = 2.6
	end
end

-----------------------------------------
-- Truck Animation Blending & Bone Spin
-----------------------------------------
local function clear_wheel_overrides(truck)
	for i = 1, 4 do
		truck:set_bone_override(WHEEL_BONES[i], nil)
	end
end

local function apply_wheel_spin_overrides(truck, spin_rad)
	local rot_vec = vector.new(spin_rad, 0, 0)
	for i = 1, 4 do
		truck:set_bone_override(WHEEL_BONES[i], {
			rotation = {vec = rot_vec, interpolation = 0.05, absolute = true},
		})
	end
end

local function update_truck_animation(state, controls, dt)
	local truck = state.truck
	if not truck or not truck:is_valid() then return end

	local throttle = 0
	if controls.up then throttle = throttle + 1 end
	if controls.down then throttle = throttle - 1 end

	local v_fwd = vector.dot(state.vel, state.forward)
	local abs_fwd = math.abs(v_fwd)

	if state.wheels_touching > 0 then
		state.air_time = 0.0
	else
		state.air_time = state.air_time + dt
	end
	local is_airborne = (state.air_time >= AIR_ANIM_GRACE)

	if not truck.play_animation then
		local desired = (not is_airborne and abs_fwd < IDLE_SPEED_THRESHOLD and throttle == 0) and "idle" or "drive"
		if state.anim_mode ~= desired then
			if desired == "idle" then
				truck:set_animation({x = 0.0, y = 1.2}, 1.0, 0.2, true)
			else
				truck:set_animation({x = 0.0, y = 0.8}, 1.0, 0.15, true)
			end
			state.anim_mode = desired
		end
		return
	end

	if is_airborne then
		if state.anim_mode ~= "air" then
			truck:stop_animation("drive")
			truck:play_animation("idle", {
				start_frame = 0.0,
				speed = 0.0,
				loop = false,
				blend = 0.15,
			})
			state.anim_mode = "air"
			state.last_anim_speed = 0.0
			apply_wheel_spin_overrides(truck, state.wheel_spin_rad)
			state.air_wheels_spinning = (throttle ~= 0)
		end

		if throttle ~= 0 then
			state.wheel_spin_rad = (state.wheel_spin_rad - throttle * AIR_WHEEL_SPIN_SPEED * dt) % (2.0 * math.pi)
			apply_wheel_spin_overrides(truck, state.wheel_spin_rad)
			state.air_wheels_spinning = true
		elseif state.air_wheels_spinning then
			apply_wheel_spin_overrides(truck, state.wheel_spin_rad)
			state.air_wheels_spinning = false
		end
		return
	end

	if state.anim_mode == "air" then
		clear_wheel_overrides(truck)
		state.air_wheels_spinning = false
	end

	if abs_fwd < IDLE_SPEED_THRESHOLD and throttle == 0 then
		if state.anim_mode ~= "idle" then
			truck:stop_animation("drive")
			truck:play_animation("idle", {
				speed = 1.0,
				loop = true,
				blend = 0.20,
			})
			state.anim_mode = "idle"
			state.last_anim_speed = 1.0
		end
		return
	end

	local target_speed
	if abs_fwd >= IDLE_SPEED_THRESHOLD then
		target_speed = clamp(v_fwd * DRIVE_ANIM_SPEED_SCALE, -DRIVE_ANIM_MAX_SPEED, DRIVE_ANIM_MAX_SPEED)
		if math.abs(target_speed) < 0.20 and throttle ~= 0 then
			target_speed = throttle * DRIVE_STALL_SPIN_SPEED
		end
	else
		target_speed = throttle * DRIVE_STALL_SPIN_SPEED
	end

	if state.anim_mode ~= "drive" then
		truck:stop_animation("idle")
		truck:play_animation("drive", {
			speed = target_speed,
			loop = true,
			blend = 0.15,
		})
		state.anim_mode = "drive"
		state.last_anim_speed = target_speed
	elseif math.abs(target_speed - state.last_anim_speed) >= 0.05 then
		truck:update_animation("drive", { speed = target_speed })
		state.last_anim_speed = target_speed
	end
end

-----------------------------------------
-- 3D Rigid-Body & Suspension Physics Tick
-----------------------------------------
local function step_vehicle_physics(state, controls, dt)
	local pos = state.pos
	local vel = state.vel
	local ang_vel = state.ang_vel

	if not state.ground_ready then
		local rx, rz = round_int(pos.x), round_int(pos.z)
		if is_node_solid({x = rx, y = round_int(pos.y - 1), z = rz})
			or is_node_solid({x = rx, y = round_int(pos.y - 2), z = rz})
			or is_node_solid({x = rx, y = round_int(pos.y - 3), z = rz}) then
			state.ground_ready = true
		else
			return
		end
	end

	if state.nitro_delay > 0 then
		state.nitro_delay = math.max(0.0, state.nitro_delay - dt)
	end

	local jump_pressed = controls.jump == true
	if jump_pressed then
		if state.boosting and state.nitro > 0.0 then
			state.nitro = math.max(0.0, state.nitro - NITRO_BURN_RATE * dt)
			state.nitro_delay = NITRO_RECHARGE_DELAY
			if state.nitro <= 0.0 then
				state.boosting = false
			end
		elseif not state.boosting and state.nitro >= NITRO_MIN_START then
			state.boosting = true
			state.nitro = math.max(0.0, state.nitro - NITRO_BURN_RATE * dt)
			state.nitro_delay = NITRO_RECHARGE_DELAY
		end
	else
		state.boosting = false
		if state.nitro_delay <= 0.0 and state.nitro < NITRO_MAX then
			state.nitro = math.min(NITRO_MAX, state.nitro + NITRO_RECHARGE_RATE * dt)
		end
	end

	if state.flip_cooldown > 0 then
		state.flip_cooldown = math.max(0.0, state.flip_cooldown - dt)
	end

	local throttle = 0
	if controls.up then throttle = throttle + 1 end
	if controls.down then throttle = throttle - 1 end

	local steer = 0
	if controls.left then steer = steer + 1 end
	if controls.right then steer = steer - 1 end

	local right, up, forward = orthonormalize_basis(state.forward, state.up)

	local target_steer = steer * MAX_STEER_ANGLE
	local steer_step = STEER_INPUT_SPEED * dt
	if state.steer_angle < target_steer then
		state.steer_angle = math.min(target_steer, state.steer_angle + steer_step)
	elseif state.steer_angle > target_steer then
		state.steer_angle = math.max(target_steer, state.steer_angle - steer_step)
	end

	-- 1. Evaluate 4-wheel suspension along local -up
	local total_spring_force = 0.0
	local tau_susp = vector.zero()
	local wheels_touching = 0
	local deepest_bottom_out = 0.0
	local bump_impulse_total = 0.0

	for i = 1, 4 do
		local off = WHEEL_OFFSETS[i]
		local r_hub = vector.add(
			vector.multiply(right, off.x),
			vector.add(vector.multiply(up, off.y), vector.multiply(forward, off.z))
		)
		local hub = vector.add(pos, r_hub)

		local dist = sample_wheel_surface(hub, right, up, forward)
		if dist then
			local comp = SUSPENSION_REST - dist
			if comp > 0.0 then
				wheels_touching = wheels_touching + 1
				local comp_c = math.min(comp, MAX_COMP)

				local v_hub = vector.add(vel, vector.cross(ang_vel, r_hub))
				local v_up_wheel = vector.dot(v_hub, up)

				local extra = math.max(0.0, comp_c - PROGRESSIVE_COMP_START)
				local eff_comp = comp_c + extra * extra * PROGRESSIVE_SPRING_MULT
				local eff_damp = SPRING_DAMP * (1.0 + extra * PROGRESSIVE_DAMP_MULT)

				local f_spring = math.max(0.0, SPRING_K * eff_comp - eff_damp * v_up_wheel)
				total_spring_force = total_spring_force + f_spring
				tau_susp = vector.add(tau_susp, vector.cross(r_hub, vector.multiply(up, f_spring)))

				if comp > BOTTOM_OUT_COMP then
					deepest_bottom_out = math.max(deepest_bottom_out, comp - BOTTOM_OUT_COMP)
					if v_up_wheel < 0.0 then
						local denom = impulse_denom(r_hub, up, right, up, forward)
						local j_bump = (-v_up_wheel / denom) * 0.72
						local imp = vector.multiply(up, j_bump)
						vel = vector.add(vel, imp)
						ang_vel = apply_ang_impulse(ang_vel, vector.cross(r_hub, imp), right, up, forward)
						bump_impulse_total = bump_impulse_total + j_bump
					end
				end
			end
		end
	end

	-- 2. Gravity & Suspension Forces
	vel.y = vel.y - GRAVITY * dt
	if total_spring_force > 0.0 then
		vel = vector.add(vel, vector.multiply(up, total_spring_force * dt))
		ang_vel = apply_ang_impulse(ang_vel, vector.multiply(tau_susp, dt), right, up, forward)
	end
	if deepest_bottom_out > 0.0 then
		pos = vector.add(pos, vector.multiply(up, math.min(deepest_bottom_out, 0.35) * BOTTOM_OUT_PUSH))
	end

	local total_normal = total_spring_force + (bump_impulse_total / math.max(dt, 0.001))
	local grip_load = clamp(total_normal / GRAVITY, 0.0, 2.5)
	local drive_traction = 0.0
	if wheels_touching > 0 then
		drive_traction = clamp(total_normal / (GRAVITY * 0.45), 0.15, 1.45)
	end

	-- 3. Tire Friction, Weighty Steering & Throttle
	if wheels_touching > 0 and (grip_load > 0.02 or drive_traction > 0.0) then
		local v_fwd = vector.dot(vel, forward)
		local v_lat = vector.dot(vel, right)
		local abs_fwd = math.abs(v_fwd)
		local eff_grip = math.max(grip_load, 0.05)

		local steer_sign = (v_fwd >= -0.6) and 1.0 or -1.0
		local eff_speed = abs_fwd
		if eff_speed < 5.0 and throttle ~= 0 then
			eff_speed = 5.0
		end
		local kinematic_yaw = (eff_speed / WHEELBASE_STEER) * math.tan(state.steer_angle) * steer_sign
		local max_grip_yaw = ((TIRE_MAX_LAT_ACCEL * eff_grip) / math.max(abs_fwd, 6.0)) * 1.15
		local target_yaw_mag = clamp(kinematic_yaw, -max_grip_yaw, max_grip_yaw)
		local target_w_yaw = -target_yaw_mag

		local cur_w_yaw = vector.dot(ang_vel, up)
		local yaw_blend = math.min(1.0, STEER_YAW_RESPONSE * math.min(eff_grip, 1.2) * dt)
		ang_vel = vector.add(ang_vel, vector.multiply(up, (target_w_yaw - cur_w_yaw) * yaw_blend))

		-- Compressible Lateral Tire Grip + Top-Heavy Roll Torque
		local req_lat_accel = -v_lat * LATERAL_GRIP * eff_grip
		local max_lat = TIRE_MAX_LAT_ACCEL * eff_grip
		local lat_accel = clamp(req_lat_accel, -max_lat, max_lat)
		vel = vector.add(vel, vector.multiply(right, lat_accel * dt))

		local roll_tau = vector.multiply(forward, lat_accel * TIRE_ROLL_ARM * dt)
		ang_vel = apply_ang_impulse(ang_vel, roll_tau, right, up, forward)

		-- Forward Drive / Braking / Nitro / Rolling Resistance
		local boosting = state.boosting
		local target_max = boosting and NITRO_TOP_SPEED or WORLD_TOP_SPEED
		local drive_accel = 0.0

		if boosting then
			local boost_factor = (throttle >= 0) and 1.0 or 0.4
			drive_accel = NITRO_ACCEL * boost_factor * drive_traction
		elseif throttle > 0 then
			drive_accel = ENGINE_ACCEL * throttle * drive_traction
		elseif throttle < 0 then
			local accel_mag = (v_fwd > 2.0) and BRAKE_ACCEL or REVERSE_ACCEL
			drive_accel = accel_mag * throttle * drive_traction
		end

		vel = vector.add(vel, vector.multiply(forward, drive_accel * dt))

		local new_v_fwd = vector.dot(vel, forward)
		local drag_k = (boosting and NITRO_ACCEL or ENGINE_ACCEL) / (target_max * target_max)
		local drag_decel = (ROLLING_DRAG * new_v_fwd + drag_k * new_v_fwd * math.abs(new_v_fwd)) * dt
		if throttle == 0 then
			local coast_stop = math.min(math.abs(new_v_fwd), COAST_ROLL_FRICTION * eff_grip * dt)
			if new_v_fwd > 0 then
				drag_decel = drag_decel + coast_stop
			elseif new_v_fwd < 0 then
				drag_decel = drag_decel - coast_stop
			end
		end
		if math.abs(new_v_fwd) > target_max and not boosting then
			drag_decel = drag_decel + (new_v_fwd - clamp(new_v_fwd, -target_max * 0.6, target_max)) * OVERSPEED_DRAG * dt
		end
		vel = vector.subtract(vel, vector.multiply(forward, drag_decel))

		-- Damping on pitch/roll settles halfpipe bounce without killing high-bank rollovers
		local w_yaw_vec = vector.multiply(up, vector.dot(ang_vel, up))
		local w_pr_vec = vector.subtract(ang_vel, w_yaw_vec)
		ang_vel = vector.add(w_yaw_vec, vector.multiply(w_pr_vec, math.max(0.0, 1.0 - GROUND_ANG_DAMP * dt)))
	else
		vel = vector.multiply(vel, math.max(0.0, 1.0 - AIR_LIN_DRAG * dt))
		ang_vel = vector.multiply(ang_vel, math.max(0.0, 1.0 - AIR_ANG_DAMP * dt))
	end

	-- Self-righting recovery when flipped upside down or stuck on side
	if up.y < 0.35 and wheels_touching <= 1 then
		if steer ~= 0 then
			ang_vel = vector.add(ang_vel, vector.multiply(forward, -steer * ROCK_TORQUE_RATE * dt))
		end
		if controls.sneak and state.flip_cooldown <= 0.0 then
			pos.y = pos.y + 0.85
			vel.y = math.max(vel.y, 4.5)
			local flat_fwd = vector.new(forward.x, 0.0, forward.z)
			if vector.length(flat_fwd) < 0.1 then
				flat_fwd = vector.new(0, 0, 1)
			end
			right, up, forward = orthonormalize_basis(flat_fwd, vector.new(0, 1, 0))
			ang_vel = vector.zero()
			state.flip_cooldown = FLIP_COOLDOWN
		end
	end

	-- 4. Integrate Position & 3D Orientation
	pos = vector.add(pos, vector.multiply(vel, dt))

	local ang_speed = vector.length(ang_vel)
	if ang_speed > 1e-5 then
		local axis = vector.multiply(ang_vel, 1.0 / ang_speed)
		local angle = ang_speed * dt
		forward = rotate_vec_axis_angle(forward, axis, angle)
		up = rotate_vec_axis_angle(up, axis, angle)
		right, up, forward = orthonormalize_basis(forward, up)
	end

	state.pos = pos
	state.vel = vel
	state.ang_vel = ang_vel
	state.right = right
	state.up = up
	state.forward = forward
	state.wheels_touching = wheels_touching
	if wheels_touching > 0 then
		state.ground_contact = true
	end

	-- 5. Resolve 3D Seam-Free Chassis Collisions
	resolve_chassis_collisions(state)
	if state.chassis_touching then
		state.ground_contact = true
	end
end

-----------------------------------------
-- Camera Mode Toggle & Checkpoint Reset
-----------------------------------------
local function set_truck_camera_mode(player, state, nose_on)
	if not player or not player:is_player() then return end
	if not state or not state.truck or not state.truck:is_valid() then return end

	state.nose_cam = nose_on == true
	if state.nose_cam and state.cam_mount and state.cam_mount:is_valid() then
		player:set_attach(state.cam_mount, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, false)
		player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		player:set_camera({mode = "first"})
	else
		player:set_attach(state.truck, "", CAMERA_ATTACH_OFFSET, {x = 0, y = 0, z = 0}, false)
		player:set_eye_offset({x = 0, y = 0, z = 0}, CAMERA_EYE_OFFSET, CAMERA_EYE_OFFSET)
		player:set_camera({mode = "third"})
	end
end

local function init_basis_from_yaw(yaw)
	local fwd = vector.new(-math.sin(yaw), 0, math.cos(yaw))
	return orthonormalize_basis(fwd, vector.new(0, 1, 0))
end

local function reset_driver_to_checkpoint(player, state)
	local cp = (state.checkpoint_idx and state.checkpoint_idx > 0) and CHECKPOINTS[state.checkpoint_idx] or nil
	local spawn = cp and cp.pos or START_POS
	local yaw = cp and cp.yaw or START_YAW

	core.emerge_area(
		{x = math.floor(spawn.x) - 16, y = math.floor(spawn.y) - 12, z = math.floor(spawn.z) - 16},
		{x = math.floor(spawn.x) + 16, y = math.floor(spawn.y) + 12, z = math.floor(spawn.z) + 16}
	)

	local right, up, forward = init_basis_from_yaw(yaw)
	state.pos = vector.new(spawn.x, spawn.y, spawn.z)
	state.vel = vector.zero()
	state.ang_vel = vector.zero()
	state.right = right
	state.up = up
	state.forward = forward
	state.aim_dir = vector.copy(forward)
	state.steer_angle = 0
	state.wheels_touching = 0
	state.chassis_touching = false
	state.ground_contact = false
	state.air_time = 0
	state.wheel_spin_rad = 0
	state.air_wheels_spinning = false
	state.anim_mode = nil
	state.last_anim_speed = 0
	state.hp = HEALTH_MAX
	state.hp_delay = 0
	state.nitro = NITRO_MAX
	state.nitro_delay = 0
	state.nitro_fx_timer = 0
	state.boosting = false
	state.bomb_cooldown = 0
	state.flip_cooldown = 0
	state.ground_ready = false
	state.boss_swallow_lock = false
	state.boss_grabbed = nil
	state.boss_last_grab_time = -100
	state.boss_second_grab = false
	state.boss_arena_entered = nil
	if back_tracks.respawn_all_turrets then
		back_tracks.respawn_all_turrets()
	end
	if back_tracks.reset_boss then
		back_tracks.reset_boss()
	end
	if state.truck and state.truck:is_valid() then
		local vis_fwd = TRUCK_MODEL_FLIP_FWD and vector.multiply(forward, -1) or forward
		state.truck:set_pos(vector.add(state.pos, vector.multiply(up, TRUCK_MODEL_Y_OFFSET)))
		state.truck:set_rotation(safe_dir_to_rotation(vis_fwd, up))
		clear_wheel_overrides(state.truck)
	end
	player:set_look_horizontal(yaw)
	player:set_look_vertical(0)
end

local function teleport_driver(player, target_pos, yaw)
	local name = player:get_player_name()
	local state = active_drivers[name]
	if not state then
		player:set_pos(target_pos)
		if yaw then
			player:set_look_horizontal(yaw)
			player:set_look_vertical(0)
		end
		return
	end

	clear_light_list(state.light_nodes)
	state.light_nodes = {}

	local right, up, forward
	if yaw then
		right, up, forward = init_basis_from_yaw(yaw)
		player:set_look_horizontal(yaw)
		player:set_look_vertical(0)
	else
		local flat_fwd = vector.new(state.forward.x, 0, state.forward.z)
		if vector.length(flat_fwd) < 0.01 then
			flat_fwd = vector.new(0, 0, 1)
		end
		right, up, forward = orthonormalize_basis(flat_fwd, vector.new(0, 1, 0))
	end

	state.pos = vector.new(target_pos.x, target_pos.y, target_pos.z)
	state.vel = vector.zero()
	state.ang_vel = vector.zero()
	state.right = right
	state.up = up
	state.forward = forward
	state.steer_angle = 0
	state.wheels_touching = 0
	state.chassis_touching = false
	state.ground_contact = false
	state.air_time = 0
	state.ground_ready = false
	state.boss_swallow_lock = false
	state.boss_grabbed = nil
	state.teleport_seq = (state.teleport_seq or 0) + 1
	local seq = state.teleport_seq

	if state.truck and state.truck:is_valid() then
		local vis_fwd = TRUCK_MODEL_FLIP_FWD and vector.multiply(forward, -1) or forward
		state.truck:set_pos(vector.add(state.pos, vector.multiply(up, TRUCK_MODEL_Y_OFFSET)))
		state.truck:set_rotation(safe_dir_to_rotation(vis_fwd, up))
		clear_wheel_overrides(state.truck)
	end

	local p = vector.round(state.pos)
	core.emerge_area(
		{x = p.x - 16, y = p.y - 12, z = p.z - 16},
		{x = p.x + 16, y = p.y + 12, z = p.z + 16},
		function(_, _, calls_remaining)
			if calls_remaining == 0 then
				local cur = active_drivers[name]
				if cur and cur.teleport_seq == seq then
					cur.ground_ready = true
				end
			end
		end
	)
end
back_tracks.teleport_driver = teleport_driver

core.register_chatcommand("tel", {
	params = "<X>,<Y>,<Z> | <to_name>",
	description = "Teleport truck (or player) to coordinates or another player",
	privs = {teleport = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local state = active_drivers[name]
		local relpos = state and state.pos or player:get_pos()

		local sx, sy, sz = param:match("^%s*([%d.~+-]+)[,%s]+([%d.~+-]+)[,%s]+([%d.~+-]+)%s*$")
		if sx and sy and sz then
			local x = core.parse_relative_number(sx, relpos.x)
			local y = core.parse_relative_number(sy, relpos.y)
			local z = core.parse_relative_number(sz, relpos.z)
			if x and y and z and math.isfinite(x) and math.isfinite(y) and math.isfinite(z) then
				local dest = vector.new(x, y, z)
				teleport_driver(player, dest)
				return true, "Teleporting to " .. core.pos_to_string(dest, 1)
			end
		end

		local target_name = param:match("^%s*([^%s]+)%s*$")
		if target_name then
			local target = core.get_player_by_name(target_name)
			if not target then
				return false, "Target player '" .. target_name .. "' not found."
			end
			local t_state = active_drivers[target_name]
			local dest = t_state and vector.copy(t_state.pos) or target:get_pos()
			teleport_driver(player, dest)
			return true, "Teleporting to " .. target_name .. " at " .. core.pos_to_string(dest, 1)
		end

		return false, "Invalid usage. Use: /tel <X>,<Y>,<Z> or /tel <player>"
	end,
})

-----------------------------------------
-- Enter / Exit Vehicle Mode
-----------------------------------------
local function enter_truck_mode(player)
	local name = player:get_player_name()
	if active_drivers[name] then return end

	local spawn_pos = vector.new(START_POS.x, START_POS.y, START_POS.z)
	player:set_pos(spawn_pos)
	player:set_look_horizontal(START_YAW)
	player:set_look_vertical(0)

	core.emerge_area(
		{x = START_POS.x - 16, y = 0, z = START_POS.z - 16},
		{x = START_POS.x + 16, y = 24, z = START_POS.z + 16}
	)

	local right, up, forward = init_basis_from_yaw(START_YAW)
	local vis_pos = vector.add(spawn_pos, vector.multiply(up, TRUCK_MODEL_Y_OFFSET))
	local vis_fwd = TRUCK_MODEL_FLIP_FWD and vector.multiply(forward, -1) or forward

	local truck = core.add_entity(vis_pos, MODNAME .. ":truck")
	if not truck then return end
	truck:set_rotation(safe_dir_to_rotation(vis_fwd, up))
	truck:get_luaentity().owner_name = name

	local cam_mount = core.add_entity(vis_pos, MODNAME .. ":cam_mount")
	if cam_mount then
		cam_mount:get_luaentity().owner_name = name
		cam_mount:set_attach(truck, "", NOSE_CAMERA_ATTACH_OFFSET, {x = 0, y = 0, z = 0}, true)
	end

	local inv = player:get_inventory()
	inv:set_list("main", {})
	inv:set_size("main", 0)

	local privs = core.get_player_privs(name)
	local had_interact = privs.interact == true
	if had_interact then
		privs.interact = nil
		core.set_player_privs(name, privs)
	end

	player:hud_set_flags({
		hotbar = false,
		wielditem = false,
		healthbar = false,
		breathbar = false,
		minimap = false,
		crosshair = false,
	})

	local old_props = player:get_properties()
	player:set_properties({visual_size = {x = 0, y = 0, z = 0}})

	local hud_ids = {}

	local reticle_hud = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.5},
		offset = {x = 0, y = 0},
		text = RETICLE_TEX,
		scale = {x = 1.4, y = 1.4},
		alignment = {x = 0, y = 0},
		z_index = 10,
	})
	hud_ids[#hud_ids + 1] = reticle_hud

	local cp_flash_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.22},
		offset = {x = 0, y = 0},
		text = "",
		alignment = {x = 0, y = 0},
		number = 0xFFDD44,
		size = {x = 1.8, y = 1.8},
	})
	hud_ids[#hud_ids + 1] = cp_flash_hud

	local speed_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.84},
		offset = {x = 0, y = 0},
		text = "0/" .. DISPLAY_TOP_SPEED,
		alignment = {x = 0, y = 0},
		number = 0xFFFFFF,
		size = {x = 2, y = 2},
	})
	hud_ids[#hud_ids + 1] = speed_hud

	local flip_hud = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.77},
		offset = {x = 0, y = 0},
		text = "",
		alignment = {x = 0, y = 0},
		number = 0xFFDD55,
		size = {x = 1.4, y = 1.4},
	})
	hud_ids[#hud_ids + 1] = flip_hud

	local hp_label = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.89},
		offset = {x = -95, y = 0},
		text = "HP",
		alignment = {x = -1, y = 0},
		number = 0x44FF77,
		size = {x = 1, y = 1},
	})
	local hp_bg = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.89},
		offset = {x = 0, y = 0},
		text = "[fill:16x16:#222222",
		scale = {x = HUD_BAR_W / 16, y = HUD_BAR_H / 16},
		alignment = {x = 0, y = 0},
	})
	local hp_bar = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.89},
		offset = {x = -HUD_BAR_W * 0.5, y = 0},
		text = "[fill:16x16:#33EE66",
		scale = {x = HUD_BAR_W / 16, y = HUD_BAR_H / 16},
		alignment = {x = 1, y = 0},
	})
	hud_ids[#hud_ids + 1] = hp_label
	hud_ids[#hud_ids + 1] = hp_bg
	hud_ids[#hud_ids + 1] = hp_bar

	local nitro_label = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.93},
		offset = {x = -95, y = 0},
		text = "NITRO",
		alignment = {x = -1, y = 0},
		number = 0x00E5FF,
		size = {x = 1, y = 1},
	})
	local nitro_bg = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.93},
		offset = {x = 0, y = 0},
		text = "[fill:16x16:#222222",
		scale = {x = HUD_BAR_W / 16, y = HUD_BAR_H / 16},
		alignment = {x = 0, y = 0},
	})
	local nitro_bar = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.93},
		offset = {x = -HUD_BAR_W * 0.5, y = 0},
		text = "[fill:16x16:#00E5FF",
		scale = {x = HUD_BAR_W / 16, y = HUD_BAR_H / 16},
		alignment = {x = 1, y = 0},
	})
	hud_ids[#hud_ids + 1] = nitro_label
	hud_ids[#hud_ids + 1] = nitro_bg
	hud_ids[#hud_ids + 1] = nitro_bar

	local bomb_label = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.968},
		offset = {x = -95, y = 0},
		text = "",
		alignment = {x = -1, y = 0},
		number = 0x55FF66,
		size = {x = 1, y = 1},
	})
	local bomb_bg = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.968},
		offset = {x = 0, y = 0},
		text = "[fill:16x16:#222222",
		scale = {x = 0, y = 0},
		alignment = {x = 0, y = 0},
	})
	local bomb_bar = player:hud_add({
		type = "image",
		position = {x = 0.5, y = 0.968},
		offset = {x = -HUD_BAR_W * 0.5, y = 0},
		text = "[fill:16x16:#33EE55",
		scale = {x = 0, y = 0},
		alignment = {x = 1, y = 0},
	})
	hud_ids[#hud_ids + 1] = bomb_label
	hud_ids[#hud_ids + 1] = bomb_bg
	hud_ids[#hud_ids + 1] = bomb_bar

	local timer_hud = player:hud_add({
		type = "text",
		position = {x = 0.96, y = 0.025},
		offset = {x = 0, y = 0},
		text = "TIME: 00:00.00",
		alignment = {x = -1, y = 0},
		number = 0xFFFFFF,
		size = {x = 1.4, y = 1.4},
	})
	hud_ids[#hud_ids + 1] = timer_hud

	local kills_hud = player:hud_add({
		type = "text",
		position = {x = 0.96, y = 0.065},
		offset = {x = 0, y = 0},
		text = "KILLS: 0",
		alignment = {x = -1, y = 0},
		number = 0xFFCC44,
		size = {x = 1.4, y = 1.4},
	})
	hud_ids[#hud_ids + 1] = kills_hud

	local state = {
		truck = truck,
		cam_mount = cam_mount,
		pos = spawn_pos,
		vel = vector.zero(),
		ang_vel = vector.zero(),
		right = right,
		up = up,
		forward = forward,
		aim_dir = vector.copy(forward),
		steer_angle = 0,
		ground_ready = false,

		boss_swallow_lock = false,
		boss_grabbed = nil,
		boss_last_grab_time = -100,
		boss_second_grab = false,
		boss_arena_entered = nil,

		wheels_touching = 0,
		chassis_touching = false,
		ground_contact = false,
		air_time = 0,
		wheel_spin_rad = 0,
		air_wheels_spinning = false,
		anim_mode = nil,
		last_anim_speed = 0,

		nitro = NITRO_MAX,
		nitro_delay = 0,
		nitro_fx_timer = 0,
		boosting = false,
		flip_cooldown = 0,

		nose_cam = false,
		prev_aux1 = false,

		hp = HEALTH_MAX,
		hp_delay = 0,
		kills = 0,

		checkpoint_idx = 0,
		cp_entity = nil,
		waypoint_hud = nil,
		cp_flash_hud = cp_flash_hud,
		cp_flash_timer = 0,

		fire_cooldown = 0,
		bomb_cooldown = 0,
		light_nodes = {},
		light_timer = 0,

		hud_ids = hud_ids,
		reticle_hud = reticle_hud,
		speed_hud = speed_hud,
		flip_hud = flip_hud,
		hp_label = hp_label,
		hp_bar = hp_bar,
		nitro_bar = nitro_bar,
		bomb_label = bomb_label,
		bomb_bg = bomb_bg,
		bomb_bar = bomb_bar,
		kills_hud = kills_hud,

		last_reticle_x = 0.5,
		last_reticle_y = 0.5,
		last_speed_text = "",
		last_speed_color = 0xFFFFFF,
		last_flipped = false,
		last_hp_px = -1,
		last_nitro_px = -1,
		last_bomb_px = -1,
		last_bomb_text = "",
		last_kills = -1,

		saved_visual_size = old_props.visual_size,
		had_interact = had_interact,

		-- Mission Run Timer
		run_timer = 0,
		timer_running = true,
		final_time = nil,
		timer_hud = timer_hud,
		last_timer_text = "",
		last_timer_color = 0xFFFFFF,
	}

	active_drivers[name] = state
	set_truck_camera_mode(player, state, false)
	sync_next_checkpoint_marker(name, player, state)
	update_truck_animation(state, {}, 0)
end

local function exit_truck_mode(player, _silent)
	local name = player:get_player_name()
	local state = active_drivers[name]
	if not state then return end

	active_drivers[name] = nil
	clear_light_list(state.light_nodes)

	if state.waypoint_hud then
		player:hud_remove(state.waypoint_hud)
		state.waypoint_hud = nil
	end
	if state.hud_ids then
		for i = 1, #state.hud_ids do
			player:hud_remove(state.hud_ids[i])
		end
	end

	player:hud_set_flags({crosshair = true})

	local exit_pos = state.pos and vector.offset(state.pos, 0, 1.5, 0) or player:get_pos()
	player:set_detach()
	player:set_pos(exit_pos)
	player:set_camera({mode = "any"})
	player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})

	if state.saved_visual_size then
		player:set_properties({visual_size = state.saved_visual_size})
	end
	if state.had_interact then
		local privs = core.get_player_privs(name)
		privs.interact = true
		core.set_player_privs(name, privs)
	end

	if state.cp_entity and state.cp_entity:is_valid() then state.cp_entity:remove() end
	if state.cam_mount and state.cam_mount:is_valid() then state.cam_mount:remove() end
	if state.truck and state.truck:is_valid() then state.truck:remove() end
end

-----------------------------------------
-- Join / Respawn / Night-Dusk Atmosphere
-----------------------------------------
local function apply_dusk_atmosphere(player)
	player:override_day_night_ratio(0.40)
	player:set_sky({
		type = "regular",
		sky_color = {
			day_sky = "#2A1B2E",
			day_horizon = "#663322",
			dawn_sky = "#241628",
			dawn_horizon = "#773822",
			night_sky = "#0C0914",
			night_horizon = "#2B1822",
			indoors = "#0C0914",
		},
		clouds = false,
	})
end

core.register_on_joinplayer(function(player)
	core.set_timeofday(0.60)
	apply_dusk_atmosphere(player)
	player:set_pos(START_POS)
	player:set_look_horizontal(START_YAW)

	core.after(0.05, function()
		if player and player:is_player() then
			enter_truck_mode(player)
		end
	end)
end)

core.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	if active_drivers[name] then
		reset_driver_to_checkpoint(player, active_drivers[name])
	else
		enter_truck_mode(player)
	end
	return true
end)

if back_tracks.buildMode then
	core.register_chatcommand("toggle", {
		description = "Debug toggle between Monster Truck mode and normal mode",
		func = function(name)
			local player = core.get_player_by_name(name)
			if not player then return false, "Player not found." end
			if active_drivers[name] then
				exit_truck_mode(player, false)
			else
				enter_truck_mode(player)
			end
			return true
		end,
	})
end

-----------------------------------------
-- Globalstep: Time Lock, Physics, Aim, Checkpoints, Headlights & HUD
-----------------------------------------
local tod_timer = 0

core.register_globalstep(function(dtime)
	local clamped_dt = math.min(dtime, 0.1)

	tod_timer = tod_timer + clamped_dt
	if tod_timer >= 4.0 then
		tod_timer = 0
		local tod = core.get_timeofday()
		if tod < 0.80 or tod > 0.92 then
			core.set_timeofday(0.83)
		end
	end

	for name, state in pairs(active_drivers) do
		local player = core.get_player_by_name(name)
		if not player or not state.truck or not state.truck:is_valid() then
			if player then
				exit_truck_mode(player, true)
			else
				clear_light_list(state.light_nodes)
				if state.cp_entity and state.cp_entity:is_valid() then state.cp_entity:remove() end
				if state.cam_mount and state.cam_mount:is_valid() then state.cam_mount:remove() end
				if state.truck and state.truck:is_valid() then state.truck:remove() end
				active_drivers[name] = nil
			end
		else
			local controls = player:get_player_control()

			-- Toggle between normal third-person view and nose view with Aux1 (E)
			local aux_pressed = controls.aux1 == true
			if aux_pressed and not state.prev_aux1 then
				set_truck_camera_mode(player, state, not state.nose_cam)
			end
			state.prev_aux1 = aux_pressed

			if not state.boss_swallow_lock then
				state.ground_contact = false
				local speed_est = vector.length(state.vel) + 15.0
				local n_steps = clamp(math.ceil((speed_est * clamped_dt) / MAX_DISP_PER_STEP), 2, MAX_SUB_STEPS)
				local step_dt = clamped_dt / n_steps
				for _ = 1, n_steps do
					state.chassis_touching = false
					step_vehicle_physics(state, controls, step_dt)
				end
			end

			local up, forward = state.up, state.forward
			local vis_fwd = TRUCK_MODEL_FLIP_FWD and vector.multiply(forward, -1) or forward
			local truck_rot = safe_dir_to_rotation(vis_fwd, up)
			state.truck:set_pos(vector.add(state.pos, vector.multiply(up, TRUCK_MODEL_Y_OFFSET)))
			state.truck:set_rotation(truck_rot)

			update_truck_animation(state, controls, clamped_dt)

			-- Update slewing aim direction & screen-space reticle
			step_aim_reticle(name, player, state, clamped_dt)

			-- Shooting from front bumper (LMB)
			if state.fire_cooldown > 0 then
				state.fire_cooldown = math.max(0, state.fire_cooldown - clamped_dt)
			end
			if controls.LMB and state.fire_cooldown <= 0 then
				fire_bullet(player, state)
				state.fire_cooldown = BULLET_COOLDOWN
			end

			-- Bomb drop (RMB) with 10s cooldown
			if state.bomb_cooldown > 0 then
				state.bomb_cooldown = math.max(0, state.bomb_cooldown - clamped_dt)
			end
			if (controls.RMB or controls.place) and state.bomb_cooldown <= 0 and not state.boss_swallow_lock then
				drop_bomb(player, state)
			end

			-- Nitro thruster flames out the rear exhaust
			if state.boosting then
				state.nitro_fx_timer = state.nitro_fx_timer - clamped_dt
				if state.nitro_fx_timer <= 0 then
					state.nitro_fx_timer = 0.025
					spawn_nitro_thrusters(state)
				end
			else
				state.nitro_fx_timer = 0
			end

			-- Checkpoint boundary crossing check
			if state.checkpoint_idx < #CHECKPOINTS then
				local next_idx = state.checkpoint_idx + 1
				local cp = CHECKPOINTS[next_idx]
				if cp then
					local rel = vector.subtract(state.pos, cp.pos)
					local side = vector.dot(rel, cp.plane_normal)
					local horiz_d2 = rel.x * rel.x + rel.z * rel.z
					local y_ok = (state.pos.y >= (cp.y_min or -1000)) and (state.pos.y <= (cp.y_max or 1000))
					if side >= 0.0 and horiz_d2 <= (cp.max_dist * cp.max_dist) and y_ok then
						advance_checkpoint(name, player, state, next_idx)
					end
				end
			end

			if state.cp_flash_timer > 0 then
				state.cp_flash_timer = state.cp_flash_timer - clamped_dt
				if state.cp_flash_timer <= 0 then
					state.cp_flash_timer = 0
					player:hud_change(state.cp_flash_hud, "text", "")
				end
			end

			-- Far-casting Forward Headlight Beam
			state.light_timer = state.light_timer + clamped_dt
			if state.light_timer >= 0.05 then
				state.light_timer = 0
				local beam_origin = vector.add(state.pos, vector.multiply(up, 1.3))
				local beam_dir = forward
				local beam = {}
				local distances = {16.0, 28.0, 40.0, 52.0}

				for i = 1, #distances do
					local target = vector.add(beam_origin, vector.multiply(beam_dir, distances[i]))
					local hit = raycast_solid(beam_origin, target)
					if hit then
						if hit.above then
							beam[#beam + 1] = hit.above
						end
						break
					else
						beam[#beam + 1] = target
					end
				end

				state.light_nodes = update_headlights(state.light_nodes, beam)
			end

			-- Lava damage + Void / Boss Abyss safety
			local node_here = core.get_node_or_nil(state.pos)
			local node_def = node_here and core.registered_nodes[node_here.name]
			if node_here and (node_here.name == MODNAME .. ":lava_source" or node_here.name == MODNAME .. ":lava_flowing") then
				back_tracks.damage_player(name, LAVA_DPS * clamped_dt)
			elseif state.pos.y < -30 then
				state.hp = 0
			end

			if state.hp > 0 and state.checkpoint_idx >= MESA_CHECKPOINT_IDX and not state.boss_swallow_lock then
				local dx = state.pos.x - MESA_CENTER_X
				local dz = state.pos.z - MESA_CENTER_Z
				if (dx * dx + dz * dz) > (MESA_SPIRAL_OUTER_RADIUS * MESA_SPIRAL_OUTER_RADIUS) then
					local landed_in_liquid = node_def and node_def.liquidtype and node_def.liquidtype ~= "none"
					if state.ground_contact or landed_in_liquid then
						state.hp = 0
					end
				end
			end

			-- Health recharge or Respawn at last reached checkpoint
			if state.hp <= 0 then
				back_tracks.spawn_explosion(state.pos, 1.6)
				reset_driver_to_checkpoint(player, state)
			else
				if state.hp_delay > 0 then
					state.hp_delay = math.max(0, state.hp_delay - clamped_dt)
				elseif state.hp < HEALTH_MAX then
					state.hp = math.min(HEALTH_MAX, state.hp + HEALTH_RECHARGE_RATE * clamped_dt)
				end
			end

			-- Update HUD
			local speed_world = vector.length(state.vel)
			local speed_disp = math.floor(speed_world * (DISPLAY_TOP_SPEED / WORLD_TOP_SPEED) + 0.5)
			local speed_text = string.format("%d/%d", speed_disp, DISPLAY_TOP_SPEED)
			local speed_color = state.boosting and 0xFFAA00 or 0xFFFFFF

			if speed_text ~= state.last_speed_text then
				player:hud_change(state.speed_hud, "text", speed_text)
				state.last_speed_text = speed_text
			end
			if speed_color ~= state.last_speed_color then
				player:hud_change(state.speed_hud, "number", speed_color)
				state.last_speed_color = speed_color
			end

			local is_flipped = (state.up.y < 0.25 and vector.length(state.vel) < 12.0)
			if is_flipped ~= state.last_flipped then
				player:hud_change(state.flip_hud, "text", is_flipped and "PRESS SHIFT TO FLIP" or "")
				state.last_flipped = is_flipped
			end

			local hp_px = math.max(1, math.floor((state.hp / HEALTH_MAX) * HUD_BAR_W + 0.5))
			if hp_px ~= state.last_hp_px then
				player:hud_change(state.hp_bar, "scale", {x = hp_px / 16, y = HUD_BAR_H / 16})
				state.last_hp_px = hp_px
			end

			local nitro_px = math.max(1, math.floor((state.nitro / NITRO_MAX) * HUD_BAR_W + 0.5))
			if nitro_px ~= state.last_nitro_px then
				player:hud_change(state.nitro_bar, "scale", {x = nitro_px / 16, y = HUD_BAR_H / 16})
				state.last_nitro_px = nitro_px
			end

			local bomb_px = (state.bomb_cooldown > 0)
				and math.max(1, math.floor((state.bomb_cooldown / BOMB_COOLDOWN) * HUD_BAR_W + 0.5))
				or 0
			local bomb_txt = (state.bomb_cooldown > 0)
				and string.format("BOMB %ds", math.ceil(state.bomb_cooldown))
				or ""

			if bomb_txt ~= state.last_bomb_text then
				player:hud_change(state.bomb_label, "text", bomb_txt)
				local bg_visible = (bomb_px > 0)
				player:hud_change(state.bomb_bg, "scale", bg_visible and {x = HUD_BAR_W / 16, y = HUD_BAR_H / 16} or {x = 0, y = 0})
				state.last_bomb_text = bomb_txt
			end
			if bomb_px ~= state.last_bomb_px then
				player:hud_change(state.bomb_bar, "scale", (bomb_px > 0) and {x = bomb_px / 16, y = HUD_BAR_H / 16} or {x = 0, y = 0})
				state.last_bomb_px = bomb_px
			end

			if state.kills ~= state.last_kills then
				player:hud_change(state.kills_hud, "text", "KILLS: " .. state.kills)
				state.last_kills = state.kills
			end
			
			-- Update Mission Timer
			if state.timer_running then
				state.run_timer = state.run_timer + clamped_dt
			end

			local time_str = "TIME: " .. format_time(state.run_timer)
			if time_str ~= state.last_timer_text then
				player:hud_change(state.timer_hud, "text", time_str)
				state.last_timer_text = time_str
			end

			local target_timer_col = state.timer_running and 0xFFFFFF or 0x44FF88
			if target_timer_col ~= state.last_timer_color then
				player:hud_change(state.timer_hud, "number", target_timer_col)
				state.last_timer_color = target_timer_col
			end

			if state.kills ~= state.last_kills then
				player:hud_change(state.kills_hud, "text", "KILLS: " .. state.kills)
				state.last_kills = state.kills
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
	for h, _ in pairs(light_refs) do
		local rp = core.get_position_from_hash(h)
		local node = core.get_node_or_nil(rp)
		if node and node.name == HEADLIGHT_NODE then
			core.set_node(rp, {name = "air"})
		end
	end
	light_refs = {}
end)