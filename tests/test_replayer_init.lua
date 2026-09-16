-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_init.lua
-- Loads the real wiring with stubs: buttons, config rows, log loading by
-- picker and by drop, and hooks that keep the game's return values.
local JSON = dofile('json.lua')
local writes = {}
love = {timer = {getTime = function() return 0 end}, thread = {getChannel = function() return {push = function() end} end},
    system = {getOS = function() return 'Windows' end},
    filesystem = {createDirectory = function() return true end, write = function(p, t) writes[p] = t; return true end}}
G = {STAGE = 1, STAGES = {MAIN_MENU = 1, RUN = 2}, STATES = {}, FUNCS = {}, UIT = {ROOT = 'ROOT', R = 'R', C = 'C', T = 'T'}, C = {WHITE = {}, BLUE = {}, CLEAR = {}}, SETTINGS = {}}
Game = {update = function() return nil, 42 end, start_run = function() return 7 end, main_menu = function() return 'menu' end}
local manifest = {seed = 'TEST', deck = 'b_red', ruleset = 'r', gamemode = 'g', stake = 1}
package.loaded.json = {decode = function() return manifest end, encode = function() return '{}' end}
local chosen = 'picked.log'
SMODS = {load_file = function(path, id)
    assert(id == 'BalatroReplayer')
    if path == 'replayer/file-picker.lua' then return function() return function() return chosen end end end
    return loadfile(path)
end}
local text = ':: MULTIPLAYER :: MP_RLOG: MANIFEST {}\n:: MULTIPLAYER :: MP_RLOG: 1 reroll\n:: MULTIPLAYER :: Client sent message: action:rerollShop,cost:5\n'
NFS = {getInfo = function() return {type = 'file', size = #text} end, read = function(path) assert(path == 'picked.log'); return text end}
local mod = {id = 'BalatroReplayer'}
local session = dofile('replayer/init.lua')(mod, JSON)
assert(BalatroReplayer == session and session.phase == 'idle')

-- The mod's config tab: four status lines and four buttons.
local tab = mod.config_tab()
assert(tab.n == G.UIT.ROOT and #tab.nodes == 10)
for i, line in ipairs({'line1', 'line2', 'line3', 'line4'}) do
    assert(tab.nodes[i].nodes[1].config.ref_table == session and tab.nodes[i].nodes[1].config.ref_value == line)
end
assert(session.line1:find('Load Log'), 'the first status is already on the lines')
local buttons = {}
for _, node in ipairs(tab.nodes[5].nodes) do buttons[#buttons + 1] = node.config.button end
assert(table.concat(buttons, ',') == 'brpl_load,brpl_next,brpl_start,brpl_stop')
for _, name in ipairs(buttons) do assert(type(G.FUNCS[name]) == 'function') end

assert(tab.nodes[6].nodes[1].config.ref_value == 'mod_summary')
assert(tab.nodes[10].nodes[1].config.button == 'brpl_mod_prev')
assert(tab.nodes[10].nodes[3].config.button == 'brpl_mod_next')
G.FUNCS.brpl_mod_prev(); G.FUNCS.brpl_mod_next()
assert(session.mod_summary == 'Mods: load a log to compare')

-- Loading through the picker, cancelling, and dropping a file.
G.FUNCS.brpl_load()
assert(session.runs and #session.runs == 1 and session.runs[1].actions == 1, session.text)
chosen = nil
local loaded = session.runs
G.FUNCS.brpl_load()
assert(session.runs == loaded)
local dropped = {getFilename = function() return 'C:/x/lovely-2.LOG' end, getSize = function() return #text end,
    open = function() end, read = function() return text .. ':: MULTIPLAYER :: MP_RLOG: 2 reroll\n' end, close = function() end}
love.filedropped(dropped)
assert(session.runs ~= loaded and session.runs[1].actions == 2, session.text)
-- The filtered actions are written out for the player to read.
assert(writes['balatro_replayer/actions.txt'] == 'MANIFEST {}\nOP_NUM: 1 || OP: reroll ||\nOP_NUM: 2 || OP: reroll ||\n', writes['balatro_replayer/actions.txt'])
assert(session.text:find('2 actions') and session.text:find('actions.txt') and not session.text:find('OLD REPLAY'), session.text)
local other = {getFilename = function() return 'notes.txt' end}
love.filedropped(other)
assert(session.runs[1].actions == 2, 'other files are not logs')

-- A failing start is reported in the status, not raised at the button.
G.FUNCS.brpl_start()
assert(session.phase == 'idle' and session.text:find('Multiplayer is required'), session.text)
G.FUNCS.brpl_next()
assert(session.index == 1, 'a single run has nothing to cycle')

-- Hooks preserve the game's return values.
local function pack(...) return {n = select('#', ...), ...} end
local result = pack(Game:update(0.1))
assert(result.n == 2 and result[2] == 42)
assert(Game:start_run({}) == 7 and Game:main_menu('game') == 'menu')
assert(writes['balatro_replayer/status.json']:find('"phase":"idle"'))
print('PASS: config rows and buttons, picker and drop loading, guarded start, and hook return values')
