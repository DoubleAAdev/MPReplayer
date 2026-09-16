-- MP Replayer: replays a Multiplayer game from its Lovely log, action by
-- action. If Balatro Observer's Action Recorder is installed, it records the replay.
local mod = SMODS.current_mod
local function load(name) return assert(SMODS.load_file(name, mod.id))() end
load('replayer/init.lua')(mod, load('json.lua'))
