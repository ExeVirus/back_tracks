-- Live Mapgen Editor (runs on async mapgen threads)
-- Pure-function deterministic desert course + 4-piece non-colliding mountain spiral + sealed Mesa turn-in.

local atan2 = math.atan2 or math.atan
local sqrt  = math.sqrt
local sin   = math.sin
local cos   = math.cos
local floor = math.floor
local abs   = math.abs
local min   = math.min
local max   = math.max
local pi    = math.pi

-- Safe content ID resolver with fallbacks
local function resolve_cid(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if core.registered_nodes[name] then
			return core.get_content_id(name)
		end
	end
	return core.CONTENT_AIR
end

local function resolve_optional_cid(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if core.registered_nodes[name] then
			return core.get_content_id(name)
		end
	end
	return nil
end

local c_air             = core.CONTENT_AIR
local c_desert_sand     = resolve_cid("back_tracks:desert_sand", "default:desert_sand", "back_tracks:sand")
local c_sandstone       = resolve_cid("back_tracks:sandstone", "default:sandstone", "back_tracks:stone")
local c_sandstone_brick = resolve_cid("back_tracks:sandstone_brick", "default:sandstone_brick", "back_tracks:sandstone")
local c_desert_stone    = resolve_cid("back_tracks:desert_stone", "default:desert_stone", "back_tracks:stone")
local c_obsidian        = resolve_cid("back_tracks:obsidian", "default:obsidian", "back_tracks:desert_stone")
local c_lava            = resolve_cid("back_tracks:lava_source", "default:lava_source")
local c_light           = resolve_cid("back_tracks:meselamp", "default:meselamp", "back_tracks:lava_source")

-- Optional desert flora
local c_cactus          = resolve_optional_cid("back_tracks:cactus", "default:cactus")
local c_dry_shrub       = resolve_optional_cid("back_tracks:dry_shrub", "default:dry_shrub")
local c_dry_grass_1     = resolve_optional_cid("back_tracks:dry_grass_1", "default:dry_grass_1", "back_tracks:dry_shrub")
local c_dry_grass_3     = resolve_optional_cid("back_tracks:dry_grass_3", "default:dry_grass_3", "back_tracks:dry_shrub")
local c_dry_grass_5     = resolve_optional_cid("back_tracks:dry_grass_5", "default:dry_grass_5", "back_tracks:dry_shrub")

local is_singlenode = (core.get_mapgen_setting("mg_name") == "singlenode")
local data_buf = {}

--------------------------------------------------------------------------------
-- Pure Deterministic Math & Noise Helpers
--------------------------------------------------------------------------------
local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function smoothstep(edge0, edge1, x)
	local t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function hash2(ix, iz)
	local n = (ix * 374761393 + iz * 668265263) % 2147483647
	local v = sin(n * 0.000173 + ix * 12.9898 + iz * 78.233) * 43758.5453
	return (v - floor(v)) * 2 - 1
end

local function hash01(ix, iz)
	return hash2(ix, iz) * 0.5 + 0.5
end

local function noise2(x, z)
	local ix = floor(x)
	local iz = floor(z)
	local fx = x - ix
	local fz = z - iz
	local ux = fx * fx * (3 - 2 * fx)
	local uz = fz * fz * (3 - 2 * fz)
	local a = hash2(ix, iz)
	local b = hash2(ix + 1, iz)
	local c = hash2(ix, iz + 1)
	local d = hash2(ix + 1, iz + 1)
	return lerp(lerp(a, b, ux), lerp(c, d, ux), uz)
end

--------------------------------------------------------------------------------
-- Spline Sampling & 2D Spatial Grid Indexer (Initialized Once Per Thread)
--------------------------------------------------------------------------------
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

local function sample_spline_segments(ctrl_pts, steps_per_seg, path_id, segs_out)
	local n = #ctrl_pts
	local s_accum = 0
	local prev_x, prev_y, prev_z = ctrl_pts[1][1], ctrl_pts[1][2], ctrl_pts[1][3]

	for i = 1, n - 1 do
		local p0 = ctrl_pts[max(1, i - 1)]
		local p1 = ctrl_pts[i]
		local p2 = ctrl_pts[i + 1]
		local p3 = ctrl_pts[min(n, i + 2)]

		for step = 1, steps_per_seg do
			local t = step / steps_per_seg
			local x = catmull_rom_val(p0[1], p1[1], p2[1], p3[1], t)
			local y = catmull_rom_val(p0[2], p1[2], p2[2], p3[2], t)
			local z = catmull_rom_val(p0[3], p1[3], p2[3], p3[3], t)

			local dx = x - prev_x
			local dy = y - prev_y
			local dz = z - prev_z
			local len3 = sqrt(dx * dx + dy * dy + dz * dz)
			local len2_sq = dx * dx + dz * dz
			if len2_sq < 1e-6 then len2_sq = 1e-6 end

			segs_out[#segs_out + 1] = {
				ax = prev_x, ay = prev_y, az = prev_z,
				bx = x,      by = y,      bz = z,
				dx = dx,     dy = dy,     dz = dz,
				len2_sq = len2_sq,
				s0 = s_accum,
				s1 = s_accum + len3,
				id = path_id,
			}

			s_accum = s_accum + len3
			prev_x, prev_y, prev_z = x, y, z
		end
	end
end

local function build_spatial_grid(segs, cell_size, pad)
	local grid = { cell_size = cell_size, cells = {} }
	for idx = 1, #segs do
		local s = segs[idx]
		local min_cx = floor((min(s.ax, s.bx) - pad) / cell_size)
		local max_cx = floor((max(s.ax, s.bx) + pad) / cell_size)
		local min_cz = floor((min(s.az, s.bz) - pad) / cell_size)
		local max_cz = floor((max(s.az, s.bz) + pad) / cell_size)

		for cx = min_cx, max_cx do
			local col = grid.cells[cx]
			if not col then
				col = {}
				grid.cells[cx] = col
			end
			for cz = min_cz, max_cz do
				local bucket = col[cz]
				if not bucket then
					bucket = {}
					col[cz] = bucket
				end
				bucket[#bucket + 1] = idx
			end
		end
	end
	return grid
end

local function get_grid_bucket(grid, x, z)
	local cx = floor(x / grid.cell_size)
	local col = grid.cells[cx]
	if not col then return nil end
	local cz = floor(z / grid.cell_size)
	return col[cz]
end

--------------------------------------------------------------------------------
-- World Layout Constants & Precomputed Splines
--------------------------------------------------------------------------------
local MX, MZ      = -1145, 0
local R_BASE      = 185   -- Diameter 370 nodes
local R_MESA      = 90    -- Diameter 180 nodes
local H_MESA      = 180
local MTN_EXP     = 1.55
local INV_MTN_EXP = 1 / MTN_EXP

local function mtn_radius_at_height(y)
	if y <= 0 then return R_BASE end
	if y >= H_MESA then return R_MESA end
	local u = (y / H_MESA) ^ INV_MTN_EXP
	return R_BASE - u * (R_BASE - R_MESA)
end

-- 1) Region 1: Tight, Bumpy & Vertically Rolling Curvy Halfpipes (x = 0 .. -300)
local curvy_segs = {}
sample_spline_segments({
	{   14, 10,   0 },
	{   -8, 10,   0 },
	{  -26, 14,  46 },
	{  -50, 18,  52 },
	{  -66, 12, -44 },
	{  -92,  8, -56 },
	{ -112, 15,  46 },
	{ -138, 20,  58 },
	{ -158, 13, -48 },
	{ -184,  8, -56 },
	{ -204, 15,  50 },
	{ -230, 19,  54 },
	{ -252, 13, -42 },
	{ -274, 10, -34 },
	{ -292, 10,   0 },
	{ -314, 10,   0 },
}, 10, 1, curvy_segs)
local curvy_grid = build_spatial_grid(curvy_segs, 20, 22)

-- 2) Region 3: Thin (1-2 node thick) Lava Causeways with Organic Web Splits/Merges & Clean Start Entry
local causeway_segs = {}
local causeway_paths = {
	-- All start paths stay within |z| <= 12 until x < -652 so they NEVER cut through the bridgehead side walls!
	-- Continuous Low Tier (1..7, y = 3..12)
	{ {-640, 12,  0}, {-660, 10,   0}, {-695,  6,  -8}, {-745,  4,  14}, {-805,  4, -12}, {-865,  6,  10}, {-915,  9,  0}, {-946, 12,  0} },
	{ {-640, 12,  4}, {-658, 10,  10}, {-695,  5,  42}, {-745,  3,  68}, {-805,  3,  70}, {-868,  5,  50}, {-915,  9, 22}, {-946, 12,  0} },
	{ {-640, 12, -4}, {-658, 10, -10}, {-695,  5, -42}, {-745,  3, -68}, {-805,  3, -70}, {-868,  5, -50}, {-915,  9,-22}, {-946, 12,  0} },

	-- Low Braided Cross Links
	{ {-695,  5,  42}, {-720,  4,   2}, {-745,  3, -68} },
	{ {-695,  5, -42}, {-720,  4,  -2}, {-745,  3,  68} },
	{ {-745,  3,  68}, {-775,  4,  28}, {-805,  4, -12} },
	{ {-745,  3, -68}, {-775,  4, -28}, {-805,  4,  14} },
	{ {-805,  3,  70}, {-835,  5,  32}, {-865,  6,  10} },
	{ {-805,  3, -70}, {-835,  5, -32}, {-868,  5, -50} },
	{ {-868,  5,  50}, {-892,  7,  14}, {-915,  9, -22} },

	-- High Sky-Overpass Web (11..16, y = 21..44): Branch cleanly after x=-656, drop 13-16 nodes above low hubs!
	-- 11: North Skyway -> splits high and drops onto (-915, 9, 22)
	{ {-656, 10,  10}, {-682, 22,  26}, {-735, 36,  34}, {-800, 44,  16}, {-865, 34,  38}, {-912, 23,  22} },
	-- 12: South Skyway -> splits high and drops onto (-915, 9, -22)
	{ {-656, 10, -10}, {-682, 22, -26}, {-735, 36, -34}, {-800, 44, -16}, {-865, 34, -38}, {-912, 23, -22} },
	-- 13: High Cross N->S -> drops onto (-805, 3, -70)
	{ {-735, 36,  34}, {-775, 30,   0}, {-805, 20, -68} },
	-- 14: High Cross S->N -> drops onto (-805, 3, 70)
	{ {-735, 36, -34}, {-775, 30,   0}, {-805, 20,  68} },
	-- 15: Skyway Center Drop -> drops onto (-865, 6, 10)
	{ {-800, 44,  16}, {-838, 32,  -8}, {-864, 21,  10} },
	-- 16: Late Mid-Overpass -> climbs from (-745, 4, 14) to drop onto (-915, 9, 0)
	{ {-745,  4,  14}, {-795, 20, -28}, {-855, 27,  -6}, {-908, 22,   0} },
}
for id = 1, #causeway_paths do
	sample_spline_segments(causeway_paths[id], 10, id, causeway_segs)
end
local causeway_grid = build_spatial_grid(causeway_segs, 16, 10)
local NUM_CAUSEWAYS = #causeway_paths

-- 3) Mountain Spiral Parameters, 4 Non-Colliding Pieces, & Multi-Path Tunnels
local LOWER_JOIN_PHI  = 0.24
local LOWER_END_PHI   = 2.0 * pi
local LOWER_Y_START   = 12
local LOWER_Y_END     = 90

local UPPER_THETA_0   = pi
local UPPER_SPLIT_PHI = 0.90 * pi   -- Splits Upper Spiral into Piece C (<0.9pi) and Piece D (>=0.9pi) so they NEVER collide!
local UPPER_END_PHI   = 2.00 * pi   -- Ends cleanly back at theta = pi (r = 91, y = 180)
local UPPER_Y_START   = 96
local UPPER_Y_END     = H_MESA

local function eval_lower_spiral_y(phi)
	if phi <= LOWER_JOIN_PHI then return LOWER_Y_START end
	local t = clamp((phi - LOWER_JOIN_PHI) / (LOWER_END_PHI - LOWER_JOIN_PHI), 0, 1)
	return LOWER_Y_START
		+ (LOWER_Y_END - LOWER_Y_START) * t
		- 7.5 * sin(t * 4 * pi)
		+ 4.0 * sin(t * 6 * pi)
end

local function eval_upper_spiral_y(phi_u)
	if phi_u <= 0.12 then return UPPER_Y_START end
	local t = clamp((phi_u - 0.12) / (UPPER_END_PHI - 0.12), 0, 1)
	return UPPER_Y_START
		+ (UPPER_Y_END - UPPER_Y_START) * t
		- 8.0 * sin(t * 4 * pi)
		+ 4.5 * sin(t * 6 * pi)
end

local r_join_cw = mtn_radius_at_height(LOWER_Y_START) + 3
local x_join_cw = MX + r_join_cw * cos(LOWER_JOIN_PHI)
local z_join_cw = MZ + r_join_cw * sin(LOWER_JOIN_PHI)

local r_in  = mtn_radius_at_height(LOWER_Y_END) + 3
local r_out = mtn_radius_at_height(UPPER_Y_START) + 3

-- Banked Halfpipe Transition Chutes:
--   1: Causeway->Spiral (Piece A), 2: LowerSpiral->Tunnel (Piece B), 3: ExitTunnel->UpperSpiral (Piece C), 4: UpperSpiral->Mesa Top (Piece D)
local trans_segs = {}
local trans_paths = {
	-- 1: Causeway Exit -> sweeping halfpipe turn onto Lower Spiral
	{
		{ -938, 12,  0 },
		{ -950, 12,  0 },
		{ -964, 12, 14 },
		{ x_join_cw, 12, z_join_cw },
		{ x_join_cw - 12 * sin(LOWER_JOIN_PHI), 12, z_join_cw + 12 * cos(LOWER_JOIN_PHI) },
	},
-- 2: Aggressive curved halfpipe turn from Lower Spiral End into East Tunnel mouth
	{
		{ MX + r_in,      LOWER_Y_END, -14 },
		{ MX + r_in,      LOWER_Y_END,   0 },
		{ MX + r_in -  6, LOWER_Y_END,  18 },
		{ MX + r_in - 18, LOWER_Y_END,  28 },
		{ MX + r_in - 26, LOWER_Y_END,  30 },
	},
	-- 3: Aggressive curved halfpipe turn from West Tunnel mouth onto Upper Spiral Start
	{
		{ MX - r_out + 18, UPPER_Y_START,  28 },
		{ MX - r_out +  6, UPPER_Y_START,  18 },
		{ MX - r_out,      UPPER_Y_START,   0 },
		{ MX - r_out,      UPPER_Y_START, -16 },
	},
	-- 4: Top of Upper Spiral (theta=pi, r=91, moving -Z) -> tight sealed banked turn LEFT (+X) into Mesa floor!
	{
		{ MX - 91, H_MESA,  12 },
		{ MX - 91, H_MESA,   0 },
		{ MX - 84, H_MESA, -18 },
		{ MX - 72, H_MESA, -29 },
		{ MX - 56, H_MESA, -33 },
	},
}
for id = 1, #trans_paths do
	sample_spline_segments(trans_paths[id], 12, id, trans_segs)
end
local trans_grid = build_spatial_grid(trans_segs, 16, 20)

-- Multi-Path Tunnels connecting East Halfpipe Turn -> West Halfpipe Turn
local hubA_x, hubA_y, hubA_z = MX + r_in - 26, LOWER_Y_END, 30
local hubB_x, hubB_y, hubB_z = MX - r_out + 26, UPPER_Y_START, 30

local abx, abz = hubB_x - hubA_x, hubB_z - hubA_z
local ab_len = sqrt(abx * abx + abz * abz)
local px_u, pz_u = -abz / ab_len, abx / ab_len

local tunnel_segs = {}
local tunnel_paths = {
	{
		{ MX + r_in - 14, LOWER_Y_END, 26 },
		{ hubA_x, hubA_y, hubA_z },
		{ hubA_x - 14, 90, 24 },
	},
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.22) - px_u * 28, 86, lerp(hubA_z, hubB_z, 0.22) - pz_u * 28 },
		{ lerp(hubA_x, hubB_x, 0.52) - px_u * 46, 76, lerp(hubA_z, hubB_z, 0.52) - pz_u * 46 },
		{ lerp(hubA_x, hubB_x, 0.80) - px_u * 24, 88, lerp(hubA_z, hubB_z, 0.80) - pz_u * 24 },
		{ hubB_x + 14, UPPER_Y_START, 24 },
	},
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.30) + px_u * 2,  87, lerp(hubA_z, hubB_z, 0.30) + pz_u * 2 },
		{ lerp(hubA_x, hubB_x, 0.56) - px_u * 6,  93, lerp(hubA_z, hubB_z, 0.56) - pz_u * 6 },
		{ lerp(hubA_x, hubB_x, 0.82) + px_u * 2,  95, lerp(hubA_z, hubB_z, 0.82) + pz_u * 2 },
		{ hubB_x + 14, UPPER_Y_START, 24 },
	},
	{
		{ hubA_x - 14, 90, 24 },
		{ lerp(hubA_x, hubB_x, 0.20) + px_u * 30,  93, lerp(hubA_z, hubB_z, 0.20) + pz_u * 30 },
		{ lerp(hubA_x, hubB_x, 0.46) + px_u * 44, 108, lerp(hubA_z, hubB_z, 0.46) + pz_u * 44 },
		{ lerp(hubA_x, hubB_x, 0.70) + px_u * 36, 118, lerp(hubA_z, hubB_z, 0.70) + pz_u * 36 },
		{ lerp(hubA_x, hubB_x, 0.88) + px_u * 14, 110, lerp(hubA_z, hubB_z, 0.88) + pz_u * 14 },
		{ hubB_x + 18, UPPER_Y_START + 11, 24 },
	},
	{
		{ hubB_x + 22, UPPER_Y_START, 22 },
		{ hubB_x + 12, UPPER_Y_START, 25 },
		{ hubB_x,      UPPER_Y_START, 30 },
		{ MX - r_out + 14, UPPER_Y_START, 26 },
	},
}
for id = 1, #tunnel_paths do
	sample_spline_segments(tunnel_paths[id], 12, id, tunnel_segs)
end
local tunnel_grid = build_spatial_grid(tunnel_segs, 16, 11)
local NUM_TUNNELS = #tunnel_paths

--------------------------------------------------------------------------------
-- Pure Column Evaluators
--------------------------------------------------------------------------------
local function eval_desert_base(x, z)
	local d1 = 4.5 * noise2(x * 0.015, z * 0.015)
	local d2 = 2.0 * sin(x * 0.032 + z * 0.018) * cos(z * 0.025)
	local plateau = 6.5 * max(0, noise2(x * 0.007 + 4.1, z * 0.007 - 2.3) - 0.35)
	local h = floor(3 + d1 + d2 + plateau)
	local surf = (plateau > 1.2) and c_sandstone or c_desert_sand
	return h, surf, c_sandstone
end

local function eval_curvy(x, z)
	local canyon_y = floor(38 + 3.0 * noise2(x * 0.035, z * 0.035))
	local bucket = get_grid_bucket(curvy_grid, x, z)
	if not bucket then
		return canyon_y, c_desert_stone, c_desert_stone
	end

	local best_d2 = 1e9
	local best_s = 0
	local best_y = 10
	for i = 1, #bucket do
		local s = curvy_segs[bucket[i]]
		local t = clamp(((x - s.ax) * s.dx + (z - s.az) * s.dz) / s.len2_sq, 0, 1)
		local px = s.ax + t * s.dx
		local pz = s.az + t * s.dz
		local d2 = (x - px) * (x - px) + (z - pz) * (z - pz)
		if d2 < best_d2 then
			best_d2 = d2
			best_s = s.s0 + t * (s.s1 - s.s0)
			best_y = s.ay + t * s.dy
		end
	end

	local d = sqrt(best_d2)
	local hw = 13.5
	if x > -16 then
		hw = lerp(13.5, 16.0, smoothstep(-16, 0, x))
	elseif x < -282 then
		hw = lerp(13.5, 24.0, smoothstep(-282, -302, x))
	end

	if d <= hw then
		local u = d / hw
		local bump_fade = smoothstep(-5, -24, x) * smoothstep(-302, -280, x)
		local bumps = bump_fade * (
			1.25 * sin(best_s * 0.27) * cos(u * 2.1)
			+ 0.80 * sin(best_s * 0.62 + u * 3.2)
			+ 0.50 * noise2(x * 0.16, z * 0.16)
		)
		local h = floor(best_y + 22 * (u ^ 2.35) + bumps)
		local surf = (u < 0.68) and c_sandstone or c_desert_sand
		return h, surf, c_desert_stone
	elseif d <= hw + 6 then
		local w = smoothstep(hw, hw + 6, d)
		local h = floor(lerp(best_y + 22, canyon_y, w))
		return h, c_desert_sand, c_desert_stone
	end
	return canyon_y, c_desert_stone, c_desert_stone
end

local function lane_jump(s, s0, s_peak, s_drop, s_end, h_base, h_peak)
	if s <= s0 or s >= s_end then return h_base end
	if s <= s_peak then
		local t = (s - s0) / (s_peak - s0)
		return h_base + (h_peak - h_base) * (t ^ 1.65)
	elseif s <= s_drop then
		local t = (s - s_peak) / (s_drop - s_peak)
		return lerp(h_peak, h_base, t)
	else
		return h_base
	end
end

local function eval_ramps(x, z)
	local s = -300 - x
	local z_track = 14 * sin(s * pi / 170) * smoothstep(0, 30, s) * smoothstep(340, 305, s)
	local dz = z - z_track
	local d = abs(dz)
	local canyon_y = floor(42 + 3 * noise2(x * 0.03, z * 0.03))

	local y_left, y_center, y_right = 10, 10, 10
	if s < 115 then
		y_left   = lane_jump(s, 24, 52, 58, 92, 10, 21)
		y_right  = lane_jump(s, 28, 56, 62, 96, 10, 22)
		y_center = lane_jump(s, 54, 82, 88, 114, 10, 21)
	elseif s < 210 then
		y_center = lane_jump(s, 118, 152, 160, 206, 10, 25)
		y_left   = lane_jump(s, 134, 162, 168, 206, 10, 20)
		y_right  = lane_jump(s, 120, 144, 150, 176, 10, 18)
		if s > 176 then
			y_right = lane_jump(s, 176, 194, 198, 210, 10, 17)
		end
	else
		y_left   = lane_jump(s, 212, 238, 244, 276, 10, 22)
		y_center = lane_jump(s, 228, 256, 262, 294, 10, 23)
		y_right  = lane_jump(s, 214, 240, 246, 278, 10, 21)
		if s > 276 then
			local finale = lane_jump(s, 278, 304, 310, 340, 12, 24)
			local blend = smoothstep(276, 286, s)
			y_left   = lerp(y_left, finale, blend)
			y_center = lerp(y_center, finale, blend)
			y_right  = lerp(y_right, finale, blend)
		end
	end

	local y_base
	if dz <= -9.5 then
		y_base = y_left
	elseif dz < -6.5 then
		y_base = lerp(y_left, y_center, smoothstep(-9.5, -6.5, dz))
	elseif dz <= 6.5 then
		y_base = y_center
	elseif dz < 9.5 then
		y_base = lerp(y_center, y_right, smoothstep(6.5, 9.5, dz))
	else
		y_base = y_right
	end

	local hw = 24
	if d <= hw then
		local u = d / hw
		local is_lane_line = (abs(abs(dz) - 8) < 0.7) and s > 15 and s < 318
		local h = floor(y_base + 2.5 * (u ^ 4))
		local surf = is_lane_line and c_sandstone_brick or ((u < 0.85) and c_sandstone or c_desert_sand)
		return h, surf, c_desert_stone
	elseif d <= hw + 9 then
		local w = smoothstep(hw, hw + 9, d)
		local wall_h = max(canyon_y, y_base + 24)
		local h = floor(lerp(y_base + 2.5, wall_h, w ^ 0.8))
		return h, (w > 0.5) and c_desert_stone or c_desert_sand, c_desert_stone
	end
	return canyon_y, c_desert_stone, c_desert_stone
end

-- Scratch arrays for thin causeway bridge intervals per column
local br_yb = {}
local br_yt = {}
local br_id_d2 = {}
local br_id_yc = {}

local function eval_causeways(x, z)
	local count = 0
	local bucket = get_grid_bucket(causeway_grid, x, z)
	if not bucket then return 0 end

	for id = 1, NUM_CAUSEWAYS do
		br_id_d2[id] = 1e9
	end

	for i = 1, #bucket do
		local s = causeway_segs[bucket[i]]
		local t = clamp(((x - s.ax) * s.dx + (z - s.az) * s.dz) / s.len2_sq, 0, 1)
		local px = s.ax + t * s.dx
		local pz = s.az + t * s.dz
		local d2 = (x - px) * (x - px) + (z - pz) * (z - pz)
		local id = s.id
		if d2 < br_id_d2[id] then
			br_id_d2[id] = d2
			br_id_yc[id] = s.ay + t * s.dy
		end
	end

	local hw = 4.2 -- ~8.4 nodes wide, ultra-thin 1-2 node slab!
	local hw2 = hw * hw
	for id = 1, NUM_CAUSEWAYS do
		local d2 = br_id_d2[id]
		if d2 <= hw2 then
			local d = sqrt(d2)
			local u = d / hw
			local yc = br_id_yc[id]
			local yt = floor(yc + 0.2)
			local yb = (u < 0.65) and (yt - 1) or yt
			count = count + 1
			br_yb[count] = yb
			br_yt[count] = yt
		end
	end
	return count
end

local function mtn_surface_height(r, theta, x, z)
	if r <= R_MESA then
		return H_MESA
	elseif r >= R_BASE then
		return 0
	end
	local u = (R_BASE - r) / (R_BASE - R_MESA)
	local h = H_MESA * (u ^ MTN_EXP)
	local ridge = 5.0 * sin(theta * 7 + u * 3.0) * u * (1 - u)
		+ 3.5 * noise2(x * 0.025, z * 0.025) * (1 - u * 0.75)
	return max(0, h + ridge)
end

-- Scratch arrays for up to 4 non-colliding spiral/chute pieces per column (sorted bottom-to-top!)
local sp_ok   = {false, false, false, false}
local sp_y    = {0, 0, 0, 0}
local sp_ctop = {0, 0, 0, 0}
local sp_sbot = {0, 0, 0, 0}
local sp_rock = {false, false, false, false}
local sp_carve_air = {false, false, false, false}

local function write_halfpipe_slot(slot, abs_dr, dr, y_c, phi, bump_scale, wall_in, wall_out, hw, x, z)
	if abs_dr > hw + 3.5 then
		sp_ok[slot] = false
		return
	end
	local v = clamp(dr / hw, -1, 1)
	local wall_h = (v < 0) and wall_in or wall_out
	local bank = wall_h * (v * v)
	local bumps = bump_scale * (
		1.35 * sin(phi * 14) * cos(v * 2.3)
		+ 0.85 * sin(phi * 31 + v * 4.0)
		+ 0.55 * noise2(x * 0.15, z * 0.15)
	)
	local rock_bump = (bump_scale > 0.3 and abs(v) > 0.45 and noise2(x * 0.25, z * 0.25) > 0.35)

	if abs_dr <= hw then
		sp_ok[slot] = true
		sp_carve_air[slot] = true
		sp_y[slot] = floor(y_c + bank + bumps)
		sp_ctop[slot] = floor(y_c + bank + 21)
		sp_sbot[slot] = floor(y_c - 16)
		sp_rock[slot] = rock_bump
	elseif (dr > 0 and wall_out > 2.0) or (dr < 0 and wall_in > 2.0) then
		-- Thick 3.5-node outer wall buttress: NEVER carves down below lip_top!
		local wh = (dr > 0) and wall_out or wall_in
		local w = smoothstep(hw, hw + 3.5, abs_dr)
		sp_ok[slot] = true
		sp_carve_air[slot] = false
		sp_y[slot] = floor(lerp(y_c + wh + 2, y_c + wh - 2, w))
		sp_ctop[slot] = sp_y[slot]
		sp_sbot[slot] = floor(y_c - 15)
		sp_rock[slot] = true
	else
		sp_ok[slot] = false
	end
end

-- Evaluate 4 height-ordered, <200-deg spiral pieces so NO turn can ever erase or thin another turn!
--   Slot 1: Lower Spiral (y=12..90) + Trans 1 (Causeway->Spiral)
--   Slot 2: Trans 2 (LowerSpiral->East Tunnel, y=90)
--   Slot 3: Trans 3 (West Tunnel->UpperSpiral) + Upper Spiral 1st half (phi_u in [0, 0.92*pi], y=96..134)
--   Slot 4: Upper Spiral 2nd half (phi_u in [0.88*pi, 2.0*pi], y=134..180) + Trans 4 (Sealed Mesa Turn-In)
local function eval_spiral_pieces(r, theta, x, z)
	local theta_pos = theta % (2 * pi)
	local hw = 11.5

	-- Best candidate params per slot
	local b_abs  = {1e9, 1e9, 1e9, 1e9}
	local b_dr   = {0, 0, 0, 0}
	local b_y    = {0, 0, 0, 0}
	local b_phi  = {0, 0, 0, 0}
	local b_bump = {0, 0, 0, 0}
	local b_win  = {18, 17, 18, 18}
	local b_wout = {17, 17, 17, 18}

	-- Slot 1: Lower Spiral (1.0 turn, phi in [LOWER_JOIN_PHI, LOWER_END_PHI])
	do
		local phi = theta_pos
		if phi >= LOWER_JOIN_PHI - 0.05 and phi <= LOWER_END_PHI then
			local y_c = eval_lower_spiral_y(phi)
			local r_c = mtn_radius_at_height(y_c) + 2
			local dr = r - r_c
			b_abs[1] = abs(dr)
			b_dr[1]  = dr
			b_y[1]   = y_c
			b_phi[1] = phi
			b_bump[1] = smoothstep(LOWER_JOIN_PHI, LOWER_JOIN_PHI + 0.20, phi)
				* smoothstep(LOWER_END_PHI, LOWER_END_PHI - 0.16, phi)
			b_win[1], b_wout[1] = 18.0, 17.0
		end
		-- Also check k=1 at phi = 2*pi (theta_pos ~ 0) for Lower Spiral End
		if theta_pos < 0.06 then
			local phi_end = theta_pos + 2 * pi
			if phi_end <= LOWER_END_PHI + 0.04 then
				local y_c = eval_lower_spiral_y(phi_end)
				local r_c = mtn_radius_at_height(y_c) + 2
				local dr = r - r_c
				if abs(dr) < b_abs[1] then
					b_abs[1] = abs(dr)
					b_dr[1]  = dr
					b_y[1]   = y_c
					b_phi[1] = phi_end
					b_bump[1] = 0.0
					b_win[1], b_wout[1] = 18.0, 17.0
				end
			end
		end
	end

	-- Slot 3 & Slot 4: Upper Spiral split into non-overlapping halves (<200 deg each!)
	local rel_theta = (theta_pos - UPPER_THETA_0) % (2 * pi)
	-- Slot 3: phi_u in [0, 0.92*pi]
	if rel_theta <= 0.92 * pi then
		local y_c = eval_upper_spiral_y(rel_theta)
		local r_c = mtn_radius_at_height(y_c) + 2
		local dr = r - r_c
		b_abs[3]  = abs(dr)
		b_dr[3]   = dr
		b_y[3]    = y_c
		b_phi[3]  = rel_theta + 12.0
		b_bump[3] = smoothstep(0.05, 0.25, rel_theta)
		b_win[3], b_wout[3] = 18.0, 17.0
	end
	-- Slot 4: phi_u in [0.88*pi, 2.0*pi]
	local phi4 = rel_theta
	if phi4 < 0.10 then phi4 = phi4 + 2 * pi end
	if phi4 >= 0.88 * pi and phi4 <= UPPER_END_PHI + 0.04 then
		local y_c = eval_upper_spiral_y(phi4)
		local r_c = mtn_radius_at_height(y_c) + 1
		local dr = r - r_c
		b_abs[4]  = abs(dr)
		b_dr[4]   = dr
		b_y[4]    = y_c
		b_phi[4]  = phi4 + 12.0
		b_bump[4] = smoothstep(UPPER_END_PHI, UPPER_END_PHI - 0.18, phi4)
		b_win[4], b_wout[4] = 18.0, 18.0
	end

	-- Transition Splines mapped strictly to their matching slots (1->Slot1, 2->Slot2, 3->Slot3, 4->Slot4)
	local bucket = get_grid_bucket(trans_grid, x, z)
	if bucket then
		for id = 1, 4 do
			local d2_min = 1e9
			local yc_min = 0
			local s_min  = 0
			local sign_side = 1
			for i = 1, #bucket do
				local s = trans_segs[bucket[i]]
				if s.id == id then
					local t = clamp(((x - s.ax) * s.dx + (z - s.az) * s.dz) / s.len2_sq, 0, 1)
					local px = s.ax + t * s.dx
					local pz = s.az + t * s.dz
					local vx, vz = x - px, z - pz
					local d2 = vx * vx + vz * vz
					if d2 < d2_min then
						d2_min = d2
						yc_min = s.ay + t * s.dy
						s_min  = s.s0 + t * (s.s1 - s.s0)
						local cross = s.dx * vz - s.dz * vx
						sign_side = (cross >= 0) and 1 or -1
					end
				end
			end
			local d = sqrt(d2_min)
			local d = sqrt(d2_min)
			local slot = (id == 2) and 1 or id
			if d < b_abs[slot] then
				b_abs[slot]  = d
				b_dr[slot]   = d * sign_side
				b_y[slot]    = yc_min
				b_phi[slot]  = s_min * 0.05
				b_bump[slot] = 0.0
				if id == 1 then
					local mouth_open = smoothstep(4, 20, s_min)
					b_win[1]  = lerp(0.0, 17.0, mouth_open)
					b_wout[1] = lerp(0.0, 17.0, mouth_open)
				elseif id == 4 then
					local cliff_keep = (r >= 76) and 1.0 or smoothstep(66, 76, r)
					local inner_fade = 1.0 - smoothstep(26, 42, s_min)
					b_win[4]  = 18.0 * cliff_keep
					b_wout[4] = 17.0 * inner_fade
				else
					b_win[slot], b_wout[slot] = 17.0, 17.0
				end
			end
		end
	end

	for slot = 1, 4 do
		write_halfpipe_slot(slot, b_abs[slot], b_dr[slot], b_y[slot], b_phi[slot], b_bump[slot], b_win[slot], b_wout[slot], hw, x, z)
	end
end

-- Scratch arrays for tunnel intervals per column
local tn_yb = {}
local tn_yt = {}
local tn_light = {}
local tn_id_d2 = {}
local tn_id_yc = {}
local tn_id_s  = {}

local function eval_tunnels(x, z)
	local bucket = get_grid_bucket(tunnel_grid, x, z)
	if not bucket then return 0 end

	for id = 1, NUM_TUNNELS do
		tn_id_d2[id] = 1e9
	end

	for i = 1, #bucket do
		local s = tunnel_segs[bucket[i]]
		local t = clamp(((x - s.ax) * s.dx + (z - s.az) * s.dz) / s.len2_sq, 0, 1)
		local px = s.ax + t * s.dx
		local pz = s.az + t * s.dz
		local d2 = (x - px) * (x - px) + (z - pz) * (z - pz)
		local id = s.id
		if d2 < tn_id_d2[id] then
			tn_id_d2[id] = d2
			tn_id_yc[id] = s.ay + t * s.dy
			tn_id_s[id]  = s.s0 + t * (s.s1 - s.s0)
		end
	end

	local count = 0
	local r_tun = 7.5
	local r_tun2 = r_tun * r_tun
	for id = 1, NUM_TUNNELS do
		local d2 = tn_id_d2[id]
		if d2 < r_tun2 then
			local u = d2 / r_tun2
			local yc = tn_id_yc[id]
			local s_arc = tn_id_s[id]
			local rough_scale = (id == 1 or id == 5) and 0.0 or 1.0
			local floor_bumps = rough_scale * (0.8 * sin(s_arc * 0.32) + 0.6 * noise2(x * 0.22, z * 0.22))
			local ceil_rough  = 2.2 * noise2(x * 0.16, z * 0.16) + 1.0 * sin(s_arc * 0.42 + d2 * 0.3)

			local yb = floor(yc + floor_bumps)
			local arch_h = (id == 5) and 17.0 or 9.5
			local yt = floor(yc + arch_h * sqrt(max(0, 1 - u)) + ceil_rough)
			if yt >= yb + 3 then
				count = count + 1
				tn_yb[count] = yb
				tn_yt[count] = yt
				local s_mod = s_arc % 13
				tn_light[count] = (d2 <= 2.4 and s_mod < 1.5)
			end
		end
	end
	return count
end

local function eval_mesa(dx, dz, r, theta)
	local h = H_MESA
	local surf = c_sandstone

	-- Center Boss Stage (r <= 36)
	if r <= 36 then
		local center_bumps = 2.2 * noise2(dx * 0.13, dz * 0.13)
			+ 1.1 * sin(r * 0.42) * cos(theta * 3)
			+ 0.8 * noise2(dx * 0.28, dz * 0.28)
		h = floor(H_MESA - 1 + center_bumps)
		surf = (r > 33.5) and c_obsidian or ((center_bumps > 1.3) and c_desert_stone or c_sandstone)
	else
		-- Outer arena (36 < r < 84): gentler jagged sand-colored terrain with 24 nodes turning room behind ramps
		local outer_rough = 1.25 * noise2(dx * 0.14, dz * 0.14) + 0.65 * noise2(dx * 0.30, dz * 0.30)
		local gateway_ang = abs((theta - 1.12 * pi + pi) % (2 * pi) - pi)
		local gate_fade = smoothstep(0.15, 0.35, gateway_ang)
		h = floor(H_MESA + outer_rough * gate_fade)
		local sand_pick = noise2(dx * 0.19 + 3.7, dz * 0.19 - 1.9)
		surf = (sand_pick > 0.35) and c_sandstone or c_desert_sand
		if r <= 38.5 then
			surf = c_sandstone_brick
		end
	end

	-- Four cardinal launch ramps: directly abutting black center ring (r = 36 .. 60), +15 tall (y=195), 24 nodes turning room behind!
	local t_ramp = -1
	local perp = 99
	if dx >= 36 and dx <= 60 and abs(dz) <= 10 then
		t_ramp = (60 - dx) / 24
		perp = abs(dz)
	elseif dx <= -36 and dx >= -60 and abs(dz) <= 10 then
		t_ramp = (60 + dx) / 24
		perp = abs(dz)
	elseif dz >= 36 and dz <= 60 and abs(dx) <= 10 then
		t_ramp = (60 - dz) / 24
		perp = abs(dx)
	elseif dz <= -36 and dz >= -60 and abs(dx) <= 10 then
		t_ramp = (60 + dz) / 24
		perp = abs(dx)
	end

	if t_ramp >= 0 then
		h = floor(H_MESA + 15 * (t_ramp ^ 1.5))
		surf = (perp >= 8.2) and c_sandstone_brick or c_sandstone
		return h, surf, c_sandstone_brick
	end

	-- Big Arena Walls (r = 84 .. 90, 16 nodes high)
	if r >= 84 and r <= 90 then
		local rim_u = smoothstep(84, 88, r)
		h = floor(H_MESA + 16 * rim_u)
		surf = c_desert_stone
	end

	return h, surf, c_desert_stone
end

--------------------------------------------------------------------------------
-- Deterministic Desert Flora & Shrubbery Selector
--------------------------------------------------------------------------------
local function eval_decor(x, z, surf_mat, allow_decor)
	if not allow_decor then return 0, 0, c_air end
	if surf_mat ~= c_desert_sand and surf_mat ~= c_sandstone then
		return 0, 0, c_air
	end

	local h1 = hash01(x, z)
	if c_cactus and surf_mat == c_desert_sand and h1 > 0.992 then
		local ch = 2 + floor(hash01(x * 3 + 7, z * 5 - 11) * 3)
		return 1, ch, c_cactus
	end

	if h1 > 0.962 and h1 <= 0.992 then
		local pick = hash01(x + 19, z - 23)
		if pick < 0.45 and c_dry_shrub then
			return 2, 1, c_dry_shrub
		elseif pick < 0.65 and c_dry_grass_1 then
			return 2, 1, c_dry_grass_1
		elseif pick < 0.85 and c_dry_grass_3 then
			return 2, 1, c_dry_grass_3
		elseif c_dry_grass_5 then
			return 2, 1, c_dry_grass_5
		end
	end

	if h1 < 0.008 and surf_mat == c_sandstone then
		local bh = (h1 < 0.003) and 2 or 1
		return 3, bh, c_desert_stone
	end

	return 0, 0, c_air
end

--------------------------------------------------------------------------------
-- Master Pure Column Function
--------------------------------------------------------------------------------
local function eval_column(x, z, check_tunnels)
	local surf_y, surf_mat, sub_mat = eval_desert_base(x, z)
	local lava_top = nil
	local bridge_count = 0
	local tunnel_count = 0
	local allow_decor = true

	for s = 1, 4 do sp_ok[s] = false end

	-- Start Pad (x in [-4, 52], z in [-34, 34])
	if x >= -4 and x <= 52 and abs(z) <= 34 then
		allow_decor = false
		local half_open = lerp(16, 24, smoothstep(0, 18, x))
		local rim = max(abs(z) - half_open, x - 44)
		local sy = (rim > 0) and floor(10 + rim * 1.4) or 10
		local sm = (rim > 0) and c_desert_sand or c_sandstone
		if x < 6 then
			local cy, cm, csub = eval_curvy(x, z)
			local w = smoothstep(-4, 6, x)
			surf_y = floor(lerp(cy, sy, w))
			surf_mat = (w > 0.5) and sm or cm
			sub_mat = csub
		else
			surf_y, surf_mat, sub_mat = sy, sm, c_sandstone
		end
		return surf_y, surf_mat, sub_mat, lava_top, 0, 0, 0, 0, c_air
	end

	-- Region 1: Tight, Vertically Rolling Curvy Halfpipes (x in [-304, 0], z in [-105, 105])
	if x >= -304 and x <= 0 and abs(z) <= 105 then
		local cy, cm, csub = eval_curvy(x, z)
		if cm == c_sandstone then allow_decor = false end
		if abs(z) > 88 then
			local w = smoothstep(88, 105, abs(z))
			surf_y = floor(lerp(cy, surf_y, w))
			surf_mat = (w > 0.6) and surf_mat or cm
			sub_mat = csub
		else
			surf_y, surf_mat, sub_mat = cy, cm, csub
		end
	end

	-- Region 2: Multi-Lane Podracer Ramps + Flat Landings (x in [-642, -296], z in [-100, 100])
	if x >= -642 and x <= -296 and abs(z) <= 100 then
		local ry, rm, rsub = eval_ramps(x, z)
		if abs(z) <= 28 then allow_decor = false end
		if x > -304 then
			local w = smoothstep(-304, -296, x)
			surf_y = floor(lerp(ry, surf_y, w))
		elseif abs(z) > 84 then
			local w = smoothstep(84, 100, abs(z))
			surf_y = floor(lerp(ry, surf_y, w))
		else
			surf_y, surf_mat, sub_mat = ry, rm, rsub
		end
	end

	-- Open Bridgehead Deck at Ramps <-> Causeways (-650 .. -636, |z| <= 24)
	if x >= -650 and x <= -636 and abs(z) <= 24 then
		allow_decor = false
		if abs(z) <= 16 then
			surf_y = 12
			surf_mat = c_sandstone
			sub_mat = c_desert_stone
		else
			local w = smoothstep(16, 24, abs(z))
			surf_y = floor(lerp(12, 54, w))
			surf_mat = c_desert_stone
			sub_mat = c_desert_stone
		end
	end

	-- Region 3: Lava & Thin Braided High-Verticality Causeways (x in [-968, -640], z in [-125, 125])
	if x >= -968 and x <= -640 and abs(z) <= 125 then
		allow_decor = false
		local az = abs(z)
		local in_entry_deck = (x >= -650 and az <= 16)

		if not in_entry_deck then
			if az <= 94 and x <= -650 and x >= -960 then
				surf_y = floor(-9 + 1.5 * noise2(x * 0.08, z * 0.08))
				surf_mat = c_obsidian
				sub_mat = c_desert_stone
				lava_top = 0
			elseif az <= 122 then
				local wall_t = smoothstep(94, 122, az)
				surf_y = floor(lerp(0, 56 + 4 * noise2(x * 0.03, z * 0.03), wall_t))
				surf_mat = (wall_t > 0.72) and c_desert_sand or c_desert_stone
				sub_mat = c_desert_stone
				if wall_t > 0.75 then allow_decor = true end
			end
		end
		bridge_count = eval_causeways(x, z)
	end

	-- Mountain, 4-Piece Non-Colliding Spiral, Tunnels, & Boss Mesa
	local dx = x - MX
	local dz = z - MZ
	local r2 = dx * dx + dz * dz
	local r_max = R_BASE + 30
	if r2 <= r_max * r_max then
		local r = sqrt(r2)
		local theta = atan2(dz, dx)

		if r <= R_MESA + 1 then
			allow_decor = false
			local my, mm, msub = eval_mesa(dx, dz, r, theta)
			surf_y, surf_mat, sub_mat = my, mm, msub
		else
			local mtn_y = mtn_surface_height(r, theta, x, z)
			local skirt_w = (r > R_BASE - 10) and smoothstep(R_BASE + 20, R_BASE - 10, r) or 1
			local base_y = floor(lerp(surf_y, mtn_y, skirt_w))
			local m_surf = (mtn_y > 22) and ((noise2(x * 0.05, z * 0.05) > 0.25) and c_sandstone or c_desert_stone) or c_desert_sand
			surf_y = max(surf_y, base_y)
			if skirt_w > 0.3 then
				surf_mat = m_surf
				sub_mat = c_desert_stone
			end
			if mtn_y > 35 then allow_decor = false end
		end

		eval_spiral_pieces(r, theta, x, z)
		for s = 1, 4 do
			if sp_ok[s] then
				allow_decor = false
				break
			end
		end

		if check_tunnels and r < 145 then
			tunnel_count = eval_tunnels(x, z)
		end
	end

	local decor_type, decor_h, decor_cid = eval_decor(x, z, surf_mat, allow_decor)
	return surf_y, surf_mat, sub_mat, lava_top,
		bridge_count, tunnel_count,
		decor_type, decor_h, decor_cid
end

--------------------------------------------------------------------------------
-- Async Mapgen Callback
--------------------------------------------------------------------------------
core.register_on_generated(function(vm, minp, maxp, blockseed)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data(data_buf)
	local ystride = area.ystride or (emax.x - emin.x + 1)

	local check_tunnels = (maxp.y >= 66 and minp.y <= 138)
		and (maxp.x >= MX - 150 and minp.x <= MX + 150)
		and (maxp.z >= MZ - 150 and minp.z <= MZ + 150)

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local surf_y, surf_mat, sub_mat, lava_top,
				bridge_count, tunnel_count,
				decor_type, decor_h, decor_cid = eval_column(x, z, check_tunnels)

			local col_max_y = surf_y + decor_h
			if lava_top and lava_top > col_max_y then col_max_y = lava_top end
			for s = 1, 4 do
				if sp_ok[s] and sp_y[s] > col_max_y then col_max_y = sp_y[s] end
			end
			for b = 1, bridge_count do
				if br_yt[b] > col_max_y then col_max_y = br_yt[b] end
			end

			local y0 = minp.y
			local y1 = is_singlenode and min(maxp.y, col_max_y) or maxp.y

			if y0 <= y1 then
				local vi = area:index(x, y0, z)
				for y = y0, y1 do
					local cid = c_air

					-- 1. Base terrain / mountain / mesa solid
					if y <= surf_y then
						if y == surf_y then
							cid = surf_mat
						elseif y >= surf_y - 3 then
							cid = sub_mat
						else
							cid = c_desert_stone
						end
					elseif lava_top and y <= lava_top then
						cid = c_lava
					elseif decor_type > 0 and y > surf_y and y <= surf_y + decor_h then
						cid = decor_cid
					end

					-- 2. Four height-ordered non-colliding Spiral & Turn Halfpipe Pieces
					for s = 1, 4 do
						if sp_ok[s] then
							local sy = sp_y[s]
							if sp_carve_air[s] and y > sy and y <= sp_ctop[s] then
								cid = c_air
							elseif y == sy then
								-- Never overwrite a taller existing Mesa rim wall with a lower buttress!
								if sp_carve_air[s] or cid == c_air then
									cid = sp_rock[s] and c_desert_stone or c_sandstone
								end
							elseif y < sy and y >= sp_sbot[s] then
								if cid == c_air or cid == c_lava then
									cid = c_desert_stone
								end
							end
						end
					end

					-- 3. Lava region ultra-thin 3D causeway overpasses
					for b = 1, bridge_count do
						local yb = br_yb[b]
						local yt = br_yt[b]
						if y >= yb and y <= yt then
							cid = (y == yt) and c_sandstone or c_desert_stone
						end
					end

					-- 4. Multi-path mountain tunnels (2-pass: floors/lights first, air carving second)
					if tunnel_count > 0 then
						for t = 1, tunnel_count do
							if y == tn_yb[t] - 1 then
								cid = c_sandstone
							elseif tn_light[t] and y == tn_yt[t] + 1 then
								cid = c_light
							end
						end
						for t = 1, tunnel_count do
							if y >= tn_yb[t] and y <= tn_yt[t] then
								cid = c_air
								break
							end
						end
					end

					if cid ~= c_air or data[vi] ~= c_air then
						data[vi] = cid
					end
					vi = vi + ystride
				end
			end
		end
	end

	vm:set_data(data)
	if vm.calc_lighting then vm:calc_lighting() end
	if vm.update_liquids then vm:update_liquids() end
end)