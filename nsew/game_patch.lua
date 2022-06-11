--- Game patches.
-- @module nsew.game_patch

local ffi = require("ffi")
local native_dll = require("nsew.native_dll")

local game_patch = {}

ffi.cdef([[

bool nsew_disable_game_pause();

]])

--- Keep the game running even when the user opens the escape menu.
-- @return bool true for success and false if the patching failed
function game_patch.disable_game_pause()
    return native_dll.lib.nsew_disable_game_pause()
end

return game_patch
