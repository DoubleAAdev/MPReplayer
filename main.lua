-- MP Replayer: replays a Multiplayer game from its Lovely log, action by
-- action. If Balatro Observer's Action Recorder is installed, it records the replay.
local mod = SMODS.current_mod
local function load(name) return assert(SMODS.load_file(name, mod.id))() end
-- Pause and play icons for the speed control; the game has none.
SMODS.Atlas{key = 'mprpl_controls', path = 'controls.png', px = 10, py = 10}
load('replayer/init.lua')(mod, load('json.lua'))
