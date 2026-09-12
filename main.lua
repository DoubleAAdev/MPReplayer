-- Balatro Replayer: replays a Multiplayer game from its Lovely log so Balatro
-- Observer's Action Recorder records it again.
local mod = SMODS.current_mod
local function load(name) return assert(SMODS.load_file(name, mod.id))() end
load('replayer/init.lua')(mod, load('json.lua'))
