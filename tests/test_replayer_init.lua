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
function UIBox_button(args)
    return {n = G.UIT.C, config = {button = args.button, minw = args.minw, minh = args.minh}, nodes = {
        {n = G.UIT.T, config = {text = args.label[1], scale = args.scale}}}}
end
function create_UIBox_generic_options(args) return args end
G.FUNCS.overlay_menu = function(args) G.OVERLAY_MENU = args.definition end
local mod = {id = 'BalatroReplayer'}
local session = dofile('replayer/init.lua')(mod, JSON)
assert(BalatroReplayer == session and session.phase == 'idle')

-- Larger native controls, identity fields and separate mod details.
local tab = mod.config_tab()
assert(tab.n == G.UIT.ROOT and #tab.nodes == 12)
assert(tab.nodes[1].nodes[1].config.ref_value == 'replay_title')
assert(tab.nodes[1].nodes[1].config.scale >= 0.4)
local buttons = {}
local function scan(node)
    if node.config and node.config.button then
        buttons[node.config.button] = true
        assert(node.config.minh >= 0.65)
        assert(node.nodes[1].config.scale >= 0.4)
    end
    for _, child in ipairs(node.nodes or {}) do scan(child) end
end
scan(tab)
for _, name in ipairs({'brpl_load','brpl_next','brpl_start','brpl_remove','brpl_details'}) do assert(buttons[name] and G.FUNCS[name]) end
assert(not buttons.brpl_end and not buttons.brpl_mod_next)
G.FUNCS.brpl_details()
assert(G.OVERLAY_MENU.back_func == 'brpl_details_back')
G.FUNCS.brpl_details_back()
assert(G.OVERLAY_MENU.back_func == 'openModUI_BalatroReplayer')
G.OVERLAY_MENU = nil

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
assert(session.text:find('2 actions') and not session.text:find('actions.txt') and not session.text:find('OLD REPLAY'), session.text)
local other = {getFilename = function() return 'notes.txt' end}
love.filedropped(other)
assert(session.runs[1].actions == 2, 'other files are not logs')

-- A failing start is reported in the status, not raised at the button.
G.FUNCS.brpl_start()
assert(session.phase == 'idle' and session.text:find('Multiplayer is required'), session.text)
G.FUNCS.brpl_next()
assert(session.index == 1, 'a single run has nothing to cycle')

-- Stable replay numbering survives removals and the final removal clears selection.
session.load(text .. text)
assert(#session.runs == 2 and session.runs[2].label_number == 2)
G.FUNCS.brpl_remove()
assert(#session.runs == 1 and session.runs[1].label_number == 2 and session.replay_title:find('Replay 2'))
assert(session.confirmed == nil and session.replay_seed:find('TEST'))
G.FUNCS.brpl_remove()
assert(session.runs == nil and session.replay_title == 'No replay selected')
assert(writes['balatro_replayer/actions.txt'] == '')
G.FUNCS.brpl_next(); G.FUNCS.brpl_remove()
assert(not pcall(session.start), 'empty selection cannot start')
session.load(text)
assert(session.runs[1].label_number == 1)
local old_stop = session.stop
local removed_active = false
session.stop = function() removed_active = true; session.phase = 'idle' end
session.phase = 'running'
G.FUNCS.brpl_remove()
assert(removed_active and session.runs == nil)
session.stop = old_stop

-- A native third tab describes the source log, including removed entries.
local tabs = mod.extra_tabs()
assert(#tabs == 1 and tabs[1].label == 'Log Info')
assert(tabs[1].tab_definition_function().n == G.UIT.ROOT)
session.load(text .. text .. text .. text, 'C:/logs/match.log')
assert(session.log_filename == 'match.log' and session.log_count == '4 games in this log')
assert(session.log_game1:find('1%. ') and session.log_setup1 == 'Deck: Red Deck | White Stake')
G.FUNCS.brpl_log_next()
assert(session.log_game1:find('4%. ') and session.log_game2 == '')
G.FUNCS.brpl_log_prev()
assert(session.log_game1:find('1%. '))
session.remove_run()
assert(#session.log_runs == 4 and #session.runs == 3, 'source log info survives list removal')
assert(not session.replay_setup:find('b_red'))
assert(not session.text:find('balatro_replayer'))

-- Badges require recorded evidence, not merely a Multiplayer-format log.
assert(session.game_type({lobby_code = 'ABC'}) == 'Multiplayer')
assert(session.game_type({practice = true, lobby_code = 'ABC'}) == 'Practice (solo)')
assert(session.game_type({multiplayer = false}) == 'Single-player')
assert(session.game_type({gamemode = 'gamemode_mp_attrition'}) == 'Game type unknown')
G.ASSET_ATLAS = {centers = {}, chips = {}, mp_modicon = {}}
G.P_CENTERS = {b_red = {pos = {x = 0, y = 0}}}
G.P_CENTER_POOLS = {Stake = {{pos = {x = 0, y = 0}}}}
local sprites = 0
local sprite_atlases, sprite_sizes = {}, {}
function Sprite(x, y, w, h, atlas, pos)
    sprites = sprites + 1
    sprite_atlases[atlas] = true
    sprite_sizes[#sprite_sizes + 1] = {w, h}
    return {states = {drag = {}, collide = {}}}
end
session.log_runs[1].manifest.lobby_code = 'ABC'
local list = mod.extra_tabs()[1].tab_definition_function()
assert(sprites >= 2 and not sprite_atlases[G.ASSET_ATLAS.mp_modicon], 'only deck and stake icons are shown')
assert(sprite_sizes[1][1] == 0.78 and sprite_sizes[1][2] == 1.06)
assert(#list.nodes[3].nodes[3].nodes == 2, 'name and stake occupy two aligned rows')
assert(list.nodes[3].config.minw == 8.2, 'games have distinct list rows')

-- Direct starts select exact objects across pages/removals and retain confirmation.
assert(session.stake_name(1) == 'White Stake' and session.stake_name(8) == 'Gold Stake')
G.localization = {descriptions = {Stake = {stake_custom = {name = 'Custom Stake'}}}}
G.P_CENTER_POOLS.Stake[9] = {key = 'stake_custom'}
assert(session.stake_name(9) == 'Custom Stake')
local original_start = session.start
local selected = session.log_runs[4]
local starts = 0
session.start = function()
    assert(session.runs[session.index] == selected)
    starts = starts + 1
    if starts == 1 then session.confirmed = selected else assert(session.confirmed == selected) end
end
G.FUNCS.brpl_start_listed({config = {ref_table = selected}})
G.FUNCS.brpl_start_listed({config = {ref_table = selected}})
assert(starts == 2)
session.remove_run()
G.FUNCS.brpl_start_listed({config = {ref_table = selected}})
assert(session.runs[session.index] == selected)
session.phase = 'running'
assert(not pcall(session.start_listed, selected))
session.phase = 'idle'
assert(not pcall(session.start_listed, {}))
session.start = original_start

-- Hooks preserve the game's return values.
local function pack(...) return {n = select('#', ...), ...} end
local result = pack(Game:update(0.1))
assert(result.n == 2 and result[2] == 42)
assert(Game:start_run({}) == 7 and Game:main_menu('game') == 'menu')
assert(writes['balatro_replayer/status.json']:find('"phase":"idle"'))
local stop_calls = 0
local actual_stop = session.stop
session.stop = function()
    assert(not G.OVERLAY_MENU, 'End Replay closes the overlay before cleanup')
    stop_calls = stop_calls + 1
    session.phase = 'idle'
end
G.FUNCS.exit_overlay_menu = function() G.OVERLAY_MENU = nil end
session.phase = 'running'; G.OVERLAY_MENU = {}
G.FUNCS.brpl_end()
assert(stop_calls == 1 and session.phase == 'idle')
G.FUNCS.brpl_end()
assert(stop_calls == 1, 'End Replay is harmless outside replays')
session.stop = actual_stop
print('PASS: config rows and buttons, picker and drop loading, guarded start, and hook return values')
