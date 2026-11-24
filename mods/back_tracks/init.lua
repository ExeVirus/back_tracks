--
-- █████▄  ▄▄▄   ▄▄▄▄ ▄▄ ▄▄   ██████ ▄▄▄▄   ▄▄▄   ▄▄▄▄ ▄▄ ▄▄  ▄▄▄▄
-- ██▄▄██ ██▀██ ██▀▀▀ ██▄█▀     ██   ██▄█▄ ██▀██ ██▀▀▀ ██▄█▀ ███▄▄
-- ██▄▄█▀ ██▀██ ▀████ ██ ██     ██   ██ ██ ██▀██ ▀████ ██ ██ ▄▄██▀
--
-- MIT License, See License.txt
--

back_tracks = {}
back_tracks.buildMode = false -- Set true only if you want /toggle debug access
back_tracks.mod_path = core.get_modpath(core.get_current_modname())
back_tracks.mod_storage = core.get_mod_storage()

-- Force singlenode engine mapgen so mapgen.lua has total control
core.set_mapgen_setting("mg_name", "singlenode", true)

table.merge = function(dest, src)
	local ret_val = table.copy(dest)
	for k, v in pairs(src) do ret_val[k] = v end
	return ret_val
end

dofile(back_tracks.mod_path .. "/nodes.lua")
core.register_mapgen_script(back_tracks.mod_path .. "/mapgen.lua")
dofile(back_tracks.mod_path .. "/runtime.lua")
dofile(back_tracks.mod_path .. "/enemies.lua")
dofile(back_tracks.mod_path .. "/boss.lua")