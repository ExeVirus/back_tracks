--
-- █████▄  ▄▄▄   ▄▄▄▄ ▄▄ ▄▄   ██████ ▄▄▄▄   ▄▄▄   ▄▄▄▄ ▄▄ ▄▄  ▄▄▄▄
-- ██▄▄██ ██▀██ ██▀▀▀ ██▄█▀     ██   ██▄█▄ ██▀██ ██▀▀▀ ██▄█▀ ███▄▄
-- ██▄▄█▀ ██▀██ ▀████ ██ ██     ██   ██ ██ ██▀██ ▀████ ██ ██ ▄▄██▀
--
-- MIT License, See License.txt
-- Ascii art generated with https://patorjk.com/software/taag/

-----------------------------------------
-- Everything can be modified, public API
-----------------------------------------
back_tracks = {} -- global table for other dependent mod access
back_tracks.buildMode = true -- Control ax_core globally: `true` for making/building levels and testing the game, `false` for releases
back_tracks.mod_path = core.get_modpath(core.get_current_modname())
back_tracks.mod_storage = core.get_mod_storage()

------------------------------------------------------
-- This really should exist in core, builtin luanti
------------------------------------------------------
table.merge = function(dest, src)
    local ret_val = table.copy(dest)
    for k, v in pairs(src) do ret_val[k] = v end
    return ret_val
end

dofile(back_tracks.mod_path .. "/nodes.lua")
dofile(back_tracks.mod_path .. "/runtime.lua")