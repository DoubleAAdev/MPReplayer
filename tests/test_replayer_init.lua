-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_init.lua
-- Loads the real wiring with stubs: buttons, config rows, log loading by
-- picker and by drop, and hooks that keep the game's return values.
local JSON = dofile('json.lua')
local writes = {}
love = {timer = {getTime = function() return 0 end}, thread = {getChannel = function() return {push = function() end} end},
    system = {getOS = function() return 'Windows' end},
    filesystem = {createDirectory = function() return true end, write = function(p, t) writes[p] = t; return true end}}
G = {STAGE = 1, STAGES = {MAIN_MENU = 1, RUN = 2}, STATES = {}, FUNCS = {}, UIT = {ROOT = 'ROOT', R = 'R', C = 'C', T = 'T'}, C = {WHITE = {}, BLUE = {}, RED = {}, CLEAR = {}}, SETTINGS = {}}
Game = {update = function() return nil, 42 end, start_run = function() return 7 end, main_menu = function() return 'menu' end}
local manifest = {seed = 'TEST', deck = 'b_red', ruleset = 'r', gamemode = 'g', stake = 1}
package.loaded.json = {decode = function() return manifest end, encode = function() return '{}' end}
local chosen = 'picked.log'
SMODS = {load_file = function(path, id)
    assert(id == 'MPReplayer')
    if path == 'replayer/file-picker.lua' then return function() return function() return chosen end end end
    return loadfile(path)
end}
local text = ':: MULTIPLAYER :: MP_RLOG: MANIFEST {}\n:: MULTIPLAYER :: MP_RLOG: 1 reroll\n:: MULTIPLAYER :: Client sent message: action:rerollShop,cost:5\n'
NFS = {getInfo = function() return {type = 'file', size = #text} end, read = function(path) assert(path == 'picked.log'); return text end}
function UIBox_button(args)
    return {n = G.UIT.C, config = {button = args.button, minw = args.minw, minh = args.minh, colour = args.colour}, nodes = {
        {n = G.UIT.T, config = {text = args.label[1], scale = args.scale}}}}
end
function create_UIBox_generic_options(args) return args end
G.FUNCS.overlay_menu = function(args) G.OVERLAY_MENU = args.definition end
local mod = {id = 'MPReplayer'}
local session = dofile('replayer/init.lua')(mod, JSON)
assert(MPReplayer == session and session.phase == 'idle')

-- One Replays tab replaces Config, with the two primary controls above the list.
assert(type(mod.config_tab) == 'function', 'native mod-list gear requires a config callback')
local menu_calls = 0
function create_UIBox_mods()
    menu_calls = menu_calls + 1
    if G.ACTIVE_MOD_UI == mod then
        assert(mod.config_tab == nil, 'the actual menu must not contain Config')
        assert(SMODS.LAST_SELECTED_MOD_TAB == 'MPReplayer_1')
    end
    return 'native_menu'
end
function getModtagInfo(info) return 'original', {x = 1, y = 1}, 'message', {} end
Game:update(0)
local atlas, pos, message = getModtagInfo({id = mod.id, can_load = true})
assert(atlas == 'tags' and pos.x == 0 and pos.y == 2 and message == 'message')
assert(getModtagInfo({id = 'OtherMod', can_load = true}) == 'original')
assert(getModtagInfo({id = mod.id, can_load = false}) == 'original')
G.ACTIVE_MOD_UI = mod
SMODS.LAST_SELECTED_MOD_TAB = 'config'
assert(create_UIBox_mods() == 'native_menu')
assert(type(mod.config_tab) == 'function', 'gear eligibility is restored after menu creation')
G.ACTIVE_MOD_UI = {}
assert(create_UIBox_mods() == 'native_menu')
G.ACTIVE_MOD_UI = nil
assert(menu_calls == 2)
local tab = mod.extra_tabs()[1].tab_definition_function()
assert(mod.extra_tabs()[1].label == 'Replays')
assert(tab.nodes[1].nodes[1].config.button == 'mprpl_load')
assert(tab.nodes[1].nodes[3].config.button == 'mprpl_details')
assert(tab.nodes[1].nodes[3].nodes[1].config.text == 'Compare Mods')
assert(tab.nodes[1].nodes[1].config.minw == tab.nodes[1].nodes[3].config.minw)
local opened = 0
G.FUNCS.openModUI_MPReplayer = function()
    opened = opened + 1
    assert(SMODS.LAST_SELECTED_MOD_TAB == 'MPReplayer_1')
    G.OVERLAY_MENU = mod.extra_tabs()[1].tab_definition_function()
end
G.FUNCS.mprpl_details()
assert(G.OVERLAY_MENU.back_func == 'mprpl_details_back')
assert(#G.OVERLAY_MENU.contents == 2, 'no-data comparison should only show title and a short message')
assert(G.OVERLAY_MENU.contents[2].nodes[1].config.ref_value == 'mod_overview')
G.FUNCS.mprpl_details_back()
assert(opened == 1)
G.OVERLAY_MENU = nil

-- Loading through the picker, cancelling, and dropping a file.
G.FUNCS.mprpl_load()
assert(opened == 2, 'loading a log rebuilds the Replays list immediately')
assert(session.runs and #session.runs == 1 and session.runs[1].actions == 1, session.text)
chosen = nil
local loaded = session.runs
G.FUNCS.mprpl_load()
assert(session.runs == loaded)
local dropped = {getFilename = function() return 'C:/x/lovely-2.LOG' end, getSize = function() return #text end,
    open = function() end, read = function() return text .. ':: MULTIPLAYER :: MP_RLOG: 2 reroll\n' end, close = function() end}
love.filedropped(dropped)
assert(session.runs ~= loaded and #session.runs == 1 and session.runs[1].actions == 2, session.text)
-- The filtered actions are written out for the player to read.
assert(writes['mp_replayer/actions.txt'] == 'MANIFEST {}\nOP_NUM: 1 || OP: reroll ||\nOP_NUM: 2 || OP: reroll ||\n', writes['mp_replayer/actions.txt'])
assert(session.text:find('2 actions') and not session.text:find('actions.txt') and not session.text:find('OLD REPLAY'), session.text)
local other = {getFilename = function() return 'notes.txt' end}
love.filedropped(other)
assert(session.runs[1].actions == 2, 'other files are not logs')

-- A failing start is reported in the status, not raised at the button.
G.FUNCS.mprpl_start()
assert(session.phase == 'idle' and session.text:find('Multiplayer is required'), session.text)
G.FUNCS.mprpl_next()
assert(session.index == 1, 'a single run has nothing to cycle')

-- Isolate removal fixtures from the already tested replacement workflow.
session.runs, session.log_runs, session.log_imports = nil, nil, nil
-- Stable replay numbering survives removals and the final removal clears selection.
session.load(text .. text)
assert(#session.runs == 2 and session.runs[2].label_number == 2)
G.FUNCS.mprpl_remove()
assert(#session.runs == 1 and session.runs[1].label_number == 2 and session.replay_title:find('Replay 2'))
assert(session.confirmed == nil and session.replay_seed:find('TEST'))
G.FUNCS.mprpl_remove()
assert(session.runs == nil and session.replay_title == 'No replay selected')
assert(writes['mp_replayer/actions.txt'] == '')
G.FUNCS.mprpl_next(); G.FUNCS.mprpl_remove()
assert(not pcall(session.start), 'empty selection cannot start')
session.runs, session.log_runs, session.log_imports = nil, nil, nil
session.load(text)
assert(session.runs[1].label_number == 1)
local old_stop = session.stop
local removed_active = false
session.stop = function() removed_active = true; session.phase = 'idle' end
session.phase = 'running'
G.FUNCS.mprpl_remove()
assert(removed_active and session.runs == nil)
session.stop = old_stop

-- A native third tab describes the source log, including removed entries.
local tabs = mod.extra_tabs()
assert(#tabs == 1 and tabs[1].label == 'Replays')
assert(tabs[1].tab_definition_function().n == G.UIT.ROOT)
session.runs, session.log_runs, session.log_imports = nil, nil, nil
session.load(text .. text .. text .. text, 'C:/logs/match.log')
assert(session.log_filename == 'match.log' and session.log_count == '4 replays loaded')
assert(session.log_game1:find('1%. ') and session.log_setup1 == 'Deck: Red Deck | White Stake')
G.FUNCS.mprpl_log_next()
assert(session.log_game1:find('4%. ') and session.log_game2 == '')
G.FUNCS.mprpl_log_prev()
assert(session.log_game1:find('1%. '))
session.remove_run()
assert(#session.log_runs == 4 and #session.runs == 3, 'source log info survives list removal')
assert(not session.replay_setup:find('b_red'))
assert(not session.text:find('mp_replayer'))

-- Badges require recorded evidence, not merely a Multiplayer-format log.
assert(session.game_type({lobby_code = 'ABC'}) == 'Multiplayer')
assert(session.game_type({practice = true, lobby_code = 'ABC'}) == 'Practice (solo)')
assert(session.game_type({multiplayer = false}) == 'Single-player')
assert(session.game_type({gamemode = 'gamemode_mp_attrition'}) == 'Game type unknown')
G.ASSET_ATLAS = {centers = {}, chips = {}, mp_modicon = {}}
G.P_CENTERS = {b_red = {set = 'Back', pos = {x = 0, y = 0}}}
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
assert(#list.nodes[4].nodes[3].nodes == 2, 'name and stake occupy two aligned rows')
assert(list.nodes[4].config.minw == 8.2, 'games have distinct list rows')

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
    if session.confirmed == selected then
        session.phase = 'joining'
    else
        session.confirmed, session.confirmed_mods = selected, 'test-mods'
    end
end
G.FUNCS.mprpl_start_listed({config = {ref_table = selected}})
assert(session.phase == 'idle' and G.OVERLAY_MENU.no_back)
local controls = G.OVERLAY_MENU.contents[4]
assert(controls.nodes[1].config.button == 'mprpl_cancel_replay')
assert(controls.nodes[1].config.colour == G.C.RED)
assert(controls.nodes[3].config.button == 'mprpl_continue_replay')
G.FUNCS.mprpl_cancel_replay()
assert(session.phase == 'idle' and not session.confirmed)
G.FUNCS.mprpl_continue_replay()
assert(starts == 1, 'cancelled confirmation cannot start')
G.FUNCS.mprpl_start_listed({config = {ref_table = selected}})
G.FUNCS.mprpl_continue_replay()
assert(starts == 3 and session.phase == 'joining')
session.phase = 'idle'
session.remove_run()
G.FUNCS.mprpl_start_listed({config = {ref_table = selected}})
assert(session.runs[session.index] == selected)
session.phase = 'running'
assert(not pcall(session.start_listed, selected))
session.phase = 'idle'
assert(not pcall(session.start_listed, {}))
session.start = original_start

-- Name-based manifests resolve the same sprite as center keys.
G.P_CENTERS.b_ghost = {key = 'b_ghost', set = 'Back', name = 'Ghost Deck', pos = {x = 2, y = 2}}
assert(session.deck_center('Ghost Deck') == G.P_CENTERS.b_ghost)
assert(session.deck_center('b_ghost') == G.P_CENTERS.b_ghost)
assert(session.deck_name({deck = 'Ghost Deck'}) == 'Ghost Deck')
local preserved = session.log_runs[1]
local old_count = #session.log_runs
session.load(text, 'second.log')
assert(#session.log_runs == 1 and session.log_runs[1] ~= preserved)
assert(session.log_source == 'second.log' and session.index == 1 and session.log_page_index == 1)
assert(not pcall(session.start_listed, preserved), 'old-log rows cannot start after replacement')
assert(session.runs[session.index] == session.log_runs[#session.log_runs])
assert(session.log_runs[#session.log_runs].source_name == 'second.log')
assert(not pcall(session.load, 'invalid log'))
assert(#session.log_runs == 1, 'invalid imports preserve existing games')
session.status('Ready.')
local compact = mod.extra_tabs()[1].tab_definition_function()
local status_rows = 0
for _, node in ipairs(compact.nodes) do
    local config = node.nodes and node.nodes[1] and node.nodes[1].config or {}
    if config.ref_value and config.ref_value:match('^line%d$') then status_rows = status_rows + 1 end
end
assert(status_rows == 1, 'unused status lines must not consume vertical space')

-- Hooks preserve the game's return values.
local function pack(...) return {n = select('#', ...), ...} end
local result = pack(Game:update(0.1))
assert(result.n == 2 and result[2] == 42)
assert(Game:start_run({}) == 7 and Game:main_menu('game') == 'menu')
assert(writes['mp_replayer/status.json']:find('"phase":"idle"'))
local stop_calls = 0
local actual_stop = session.stop
session.stop = function()
    assert(not G.OVERLAY_MENU, 'End Replay closes the overlay before cleanup')
    stop_calls = stop_calls + 1
    session.phase = 'idle'
end
G.FUNCS.exit_overlay_menu = function() G.OVERLAY_MENU = nil end
session.phase = 'running'; G.OVERLAY_MENU = {}
G.FUNCS.mprpl_end()
assert(stop_calls == 1 and session.phase == 'idle')
G.FUNCS.mprpl_end()
assert(stop_calls == 1, 'End Replay is harmless outside replays')
session.stop = actual_stop
print('PASS: config rows and buttons, picker and drop loading, guarded start, and hook return values')
