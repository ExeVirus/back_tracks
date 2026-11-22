local MODNAME = core.get_current_modname()

-----------------------------------------
-- Configuration & Tuning Constants
-----------------------------------------
local SHOW_PLACEHOLDER_MODEL = true

local START_POS = {x = 26, y = 12.0, z = 0}
local START_YAW = math.pi / 2 -- Faces -X down the Start Pad

-- Wheelbase & Visual Offsets
local WHEEL_HALF_X = 1.5
local WHEEL_HALF_Z = 1.5
local WHEEL_HUB_Y = -0.35
local TURRET_HEIGHT_OFFSET = 0.72
local CAMERA_EYE_OFFSET = {x = 0, y = 3.2, z = -5}

local WHEEL_OFFSETS = {
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z =  WHEEL_HALF_Z}, -- Front Right
	{x = -WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear Left
	{x =  WHEEL_HALF_X, y = WHEEL_HUB_Y, z = -WHEEL_HALF_Z}, -- Rear Right
}

-- 3D Chassis Collision Hull (tucked inside tire envelope so tires climb first)
local CHASSIS_SPHERES = {
	-- Lower skid-plate / chassis corners (reaches x=±1.07, z=±1.37, bottom=-0.07)
	{x = -0.65, y = 0.35, z =  0.95, r = 0.42},
	{x =  0.65, y = 0.35, z =  0.95, r = 0.42},
	{x = -0.65, y = 0.35, z = -0.95, r = 0.42},
	{x =  0.65, y = 0.35, z = -0.95, r = 0.42},
	-- Upper cab / roof / turret guard corners (top=+1.02)
	{x = -0.72, y = 0.62, z =  0.85, r = 0.40},
	{x =  0.72, y = 0.62, z =  0.85, r = 0.40},
	{x = -0.72, y = 0.62, z = -0.85, r = 0.40},
	{x =  0.72, y = 0.62, z = -0.85, r = 0.40},
}

-- 3D Suspension, Gravity & Surface Smoothing
local SUSPENSION_REST = 1.20
local MAX_COMP = 1.35
local SPRING_K = 15.5
local SPRING_DAMP = 5.2
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

-- Rigid-Body Inertia & Chassis Collision Response
local I_PITCH = 2.25
local I_YAW   = 2.65
local I_ROLL  = 2.35

local AIR_LIN_DRAG = 0.04
local AIR_ANG_DAMP = 0.35
local GROUND_ANG_DAMP = 1.65

local WALL_BOUNCE_THRESHOLD = -8.0 -- Only bounce on real impacts, not curved-wall scrapes
local WALL_RESTITUTION = 0.24
local WALL_FRICTION_SIDE = 0.04
local SKID_PLATE_FRICTION = 0.02
local ROOF_FRICTION_FLIP = 0.52

-- Driving, Weighty Steering, Compressible Grip & Nitro
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

local WHEELBASE_STEER = 3.5
local MAX_STEER_ANGLE = 0.42
local STEER_INPUT_SPEED = 3.2
local STEER_YAW_RESPONSE = 9.5
local LATERAL_GRIP = 10.5
local TIRE_MAX_LAT_ACCEL = 26.0
local TIRE_ROLL_ARM = 0.11
local ROLLING_DRAG = 0.14
local OVERSPEED_DRAG = 1.4

-- Self-Righting Recovery (when flipped upside-down)
local FLIP_COOLDOWN = 0.75
local ROCK_TORQUE_RATE = 3.6

-- Health & Damage
local HEALTH_MAX = 100.0
local HEALTH_RECHARGE_RATE = 4.5
local HEALTH_RECHARGE_DELAY = 2.5
local LAVA_DPS = 30.0

-- Weapons
local BULLET_SPEED = 120.0
local BULLET_MAX_DIST = 100.0
local BULLET_COOLDOWN = 0.12
local MUZZLE_HEIGHT_OFFSET = 1.35
local MUZZLE_FORWARD_OFFSET = 1.8
local BULLET_TEX = "[fill:16x16:#FFFFFF^[colorize:#FF2200:255"

-- HUD Bar Config
local HUD_BAR_W = 140
local HUD_BAR_H = 12

-- Shared Global State
local active_drivers = {}
back_tracks.active_drivers = active_drivers
back_tracks.enemies = back_tracks.enemies or {}

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
-- Player Bullet Entity
-----------------------------------------
core.register_entity(MODNAME .. ":bullet", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.18, y = 0.18, z = 0.55},
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
							if enemy.kill then
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

local function fire_bullet(player, truck_pos, truck_up)
	local look_dir = vector.normalize(player:get_look_dir())
	local eye_pos = vector.add(truck_pos, vector.multiply(truck_up, MUZZLE_HEIGHT_OFFSET))
	local muzzle_pos = vector.add(eye_pos, vector.multiply(look_dir, MUZZLE_FORWARD_OFFSET))

	local aim_target = vector.add(eye_pos, vector.multiply(look_dir, BULLET_MAX_DIST))
	local hit = raycast_solid(eye_pos, aim_target)
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
		ent.owner_name = player:get_player_name()
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
			"default_desert_stone.png", "default_desert_stone.png", "default_desert_stone.png",
			"default_desert_stone.png", "default_desert_stone.png", "default_desert_stone.png",
		},
		is_visible = SHOW_PLACEHOLDER_MODEL,
		glow = 4,
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
			"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "[fill:16x16:#FFEE99",
		},
		is_visible = SHOW_PLACEHOLDER_MODEL,
		glow = 5,
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
-- 3D Rigid-Body & Suspension Physics Tick
-----------------------------------------
local function step_vehicle_physics(state, controls, dt)
	local pos = state.pos
	local vel = state.vel
	local ang_vel = state.ang_vel

	if not state.ground_ready then
		if is_node_solid({x = round_int(pos.x), y = round_int(pos.y - 2), z = round_int(pos.z)}) then
			state.ground_ready = true
		else
			return
		end
	end

	-- Recharging Nitro Meter
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

	-- Smooth steering wheel lock
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
		drive_traction = clamp(total_normal / (GRAVITY * 0.45), 0.35, 1.45)
	end

	-- 3. Tire Friction, Weighty Steering & Throttle
	if wheels_touching > 0 and (grip_load > 0.02 or drive_traction > 0.0) then
		local v_fwd = vector.dot(vel, forward)
		local v_lat = vector.dot(vel, right)
		local abs_fwd = math.abs(v_fwd)
		local eff_grip = math.max(grip_load, 0.35)

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

		-- Compressible Lateral Tire Grip + Mild Cornering Body Roll
		local req_lat_accel = -v_lat * LATERAL_GRIP * eff_grip
		local max_lat = TIRE_MAX_LAT_ACCEL * eff_grip
		local lat_accel = clamp(req_lat_accel, -max_lat, max_lat)
		vel = vector.add(vel, vector.multiply(right, lat_accel * dt))

		local roll_tau = vector.multiply(forward, lat_accel * TIRE_ROLL_ARM * dt)
		ang_vel = apply_ang_impulse(ang_vel, roll_tau, right, up, forward)

		-- Forward Drive / Braking / Nitro / Drag
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
		if math.abs(new_v_fwd) > target_max and not boosting then
			drag_decel = drag_decel + (new_v_fwd - clamp(new_v_fwd, -target_max * 0.6, target_max)) * OVERSPEED_DRAG * dt
		end
		vel = vector.subtract(vel, vector.multiply(forward, drag_decel))

		-- Damping on pitch/roll keeps chassis composed over bumps & halfpipe transitions
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

	-- 5. Resolve 3D Seam-Free Chassis Collisions
	resolve_chassis_collisions(state)
end

-----------------------------------------
-- Enter / Exit Vehicle Mode
-----------------------------------------
local function init_basis_from_yaw(yaw)
	local fwd = vector.new(-math.sin(yaw), 0, math.cos(yaw))
	return orthonormalize_basis(fwd, vector.new(0, 1, 0))
end

local function reset_driver_to_start(player, state)
	local right, up, forward = init_basis_from_yaw(START_YAW)
	state.pos = vector.new(START_POS.x, START_POS.y, START_POS.z)
	state.vel = vector.zero()
	state.ang_vel = vector.zero()
	state.right = right
	state.up = up
	state.forward = forward
	state.steer_angle = 0
	state.hp = HEALTH_MAX
	state.hp_delay = 0
	state.nitro = NITRO_MAX
	state.nitro_delay = 0
	state.boosting = false
	state.flip_cooldown = 0
	state.ground_ready = false
	if state.truck and state.truck:is_valid() then
		state.truck:set_pos(state.pos)
		state.truck:set_rotation(safe_dir_to_rotation(forward, up))
	end
	player:set_look_horizontal(START_YAW)
end

local function enter_truck_mode(player)
	local name = player:get_player_name()
	if active_drivers[name] then return end

	local spawn_pos = vector.new(START_POS.x, START_POS.y, START_POS.z)
	player:set_pos(spawn_pos)
	player:set_look_horizontal(START_YAW)

	core.emerge_area(
		{x = START_POS.x - 16, y = 0, z = START_POS.z - 16},
		{x = START_POS.x + 16, y = 24, z = START_POS.z + 16}
	)

	local truck = core.add_entity(spawn_pos, MODNAME .. ":truck")
	if not truck then return end

	local turret = core.add_entity(vector.offset(spawn_pos, 0, TURRET_HEIGHT_OFFSET, 0), MODNAME .. ":turret")
	if not turret then
		truck:remove()
		return
	end

	truck:get_luaentity().owner_name = name
	turret:get_luaentity().owner_name = name

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
	})

	local old_props = player:get_properties()
	player:set_properties({visual_size = {x = 0, y = 0, z = 0}})
	player:set_attach(truck, "", {x = 0, y = 10, z = 0}, {x = 0, y = 0, z = 0}, false)
	player:set_camera({mode = "third"})
	player:set_eye_offset({x = 0, y = 0, z = 0}, CAMERA_EYE_OFFSET, CAMERA_EYE_OFFSET)

	local hud_ids = {}

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

	local kills_hud = player:hud_add({
		type = "text",
		position = {x = 0.96, y = 0.06},
		offset = {x = 0, y = 0},
		text = "KILLS: 0",
		alignment = {x = -1, y = 0},
		number = 0xFFCC44,
		size = {x = 1.5, y = 1.5},
	})
	hud_ids[#hud_ids + 1] = kills_hud

	local right, up, forward = init_basis_from_yaw(START_YAW)

	active_drivers[name] = {
		truck = truck,
		turret = turret,
		pos = spawn_pos,
		vel = vector.zero(),
		ang_vel = vector.zero(),
		right = right,
		up = up,
		forward = forward,
		steer_angle = 0,
		ground_ready = false,

		nitro = NITRO_MAX,
		nitro_delay = 0,
		boosting = false,
		flip_cooldown = 0,

		hp = HEALTH_MAX,
		hp_delay = 0,
		lava_tick = 0,
		kills = 0,

		fire_cooldown = 0,
		light_nodes = {},
		light_timer = 0,

		hud_ids = hud_ids,
		speed_hud = speed_hud,
		flip_hud = flip_hud,
		hp_label = hp_label,
		hp_bar = hp_bar,
		nitro_bar = nitro_bar,
		kills_hud = kills_hud,

		last_speed_text = "",
		last_speed_color = 0xFFFFFF,
		last_flipped = false,
		last_hp_px = -1,
		last_nitro_px = -1,
		last_kills = -1,

		saved_visual_size = old_props.visual_size,
		had_interact = had_interact,
	}
end

local function exit_truck_mode(player, _silent)
	local name = player:get_player_name()
	local state = active_drivers[name]
	if not state then return end

	active_drivers[name] = nil
	clear_light_list(state.light_nodes)

	if state.hud_ids then
		for i = 1, #state.hud_ids do
			player:hud_remove(state.hud_ids[i])
		end
	end

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

	if state.turret and state.turret:is_valid() then state.turret:remove() end
	if state.truck and state.truck:is_valid() then state.truck:remove() end
end

-----------------------------------------
-- Join / Respawn / Night-Dusk Atmosphere
-----------------------------------------
local function apply_dusk_atmosphere(player)
	player:override_day_night_ratio(0.22)
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
		clouds = true,
	})
end

core.register_on_joinplayer(function(player)
	core.set_timeofday(0.83)
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
		reset_driver_to_start(player, active_drivers[name])
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
-- Globalstep: Time Lock, Physics, Headlights, Health & HUD
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
				if state.turret and state.turret:is_valid() then state.turret:remove() end
				if state.truck and state.truck:is_valid() then state.truck:remove() end
				active_drivers[name] = nil
			end
		else
			local controls = player:get_player_control()

			local speed_est = vector.length(state.vel) + 15.0
			local n_steps = clamp(math.ceil((speed_est * clamped_dt) / MAX_DISP_PER_STEP), 2, MAX_SUB_STEPS)
			local step_dt = clamped_dt / n_steps
			for _ = 1, n_steps do
				step_vehicle_physics(state, controls, step_dt)
			end

			local up, forward = state.up, state.forward
			local truck_rot = safe_dir_to_rotation(forward, up)
			state.truck:set_pos(state.pos)
			state.truck:set_rotation(truck_rot)

			-- Turret aim
			if state.turret and state.turret:is_valid() then
				local look_dir = vector.normalize(player:get_look_dir())
				local turret_pos = vector.add(state.pos, vector.multiply(up, TURRET_HEIGHT_OFFSET))
				state.turret:set_pos(turret_pos)

				local t_right = vector.cross(up, look_dir)
				if vector.length(t_right) > 0.01 then
					local ortho_up = vector.normalize(vector.cross(look_dir, t_right))
					state.turret:set_rotation(safe_dir_to_rotation(look_dir, ortho_up))
				else
					state.turret:set_rotation(vector.dir_to_rotation(look_dir))
				end
			end

			-- Shooting (LMB)
			if state.fire_cooldown > 0 then
				state.fire_cooldown = math.max(0, state.fire_cooldown - clamped_dt)
			end
			if controls.LMB and state.fire_cooldown <= 0 then
				fire_bullet(player, state.pos, up)
				state.fire_cooldown = BULLET_COOLDOWN
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

			-- Lava damage + Void safety
			local node_here = core.get_node_or_nil(state.pos)
			if node_here and (node_here.name == MODNAME .. ":lava_source" or node_here.name == MODNAME .. ":lava_flowing") then
				back_tracks.damage_player(name, LAVA_DPS * clamped_dt)
			elseif state.pos.y < -30 then
				state.hp = 0
			end

			-- Health recharge or Respawn at track start
			if state.hp <= 0 then
				back_tracks.spawn_explosion(state.pos, 1.6)
				reset_driver_to_start(player, state)
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