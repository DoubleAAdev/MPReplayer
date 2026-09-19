local colour = {1, 1, 1, 1}
G = {UIT = {R = 'R', C = 'C', T = 'T', O = 'O'}, C = {WHITE = colour, GOLD = colour,
    ORANGE = colour, BLACK = colour, GREEN = colour, RED = colour, BLUE = colour}, FUNCS = {},
    STAGE = 2, STAGES = {MAIN_MENU = 1, RUN = 2}, ASSET_ATLAS = {centers = {}, chips = {}},
    P_CENTER_POOLS = {Stake = {{pos = {x = 0, y = 0}}}}}
local sprites = 0
function Sprite(_, _, w, h)
    sprites = sprites + 1
    return {w = w, h = h, states = {drag = {}, collide = {}}}
end
function UIBox_button(args) return {config = {button = args.button}, nodes = {{config = {text = args.label[1]}}}} end
function create_UIBox_generic_options(args) return args end
G.FUNCS.exit_overlay_menu = function() G.OVERLAY_MENU = nil end
local overlays = 0
G.FUNCS.overlay_menu = function(args) overlays = overlays + 1; G.OVERLAY_MENU = args end
local run = {manifest = {player = 'Alice', opponent = 'Bob', deck = 'b_red', stake = 1, seed = 'SEED123'},
    actions = 12, result = 'win', complete = true}
local active, stopped, restarted, tabs, approvals = run, 0, 0, 0, 0
local session = {phase = 'running', deck_center = function() return {pos = {x = 0, y = 0}} end,
    deck_name = function() return 'Red Deck' end, stake_name = function() return 'White Stake' end,
    active_run = function() return active end,
}
session.end_screen_reached = function() session.phase = 'finished' end
session.stop = function()
    assert(not G.OVERLAY_MENU)
    stopped = stopped + 1; session.phase = 'stopped'
end
session.start_listed = function(selected)
    assert(selected == run and session.phase == 'idle' and G.STAGE == G.STAGES.MAIN_MENU)
    -- The player already approved the mod difference to start this run, so
    -- restarting it must not ask them the same question a second time.
    assert(session.confirmed == run and session.confirmed_mods == 'old',
        'the approval that started this run is handed on to the restart')
    restarted = restarted + 1; session.phase = 'joining'; active = selected
end
local native = 0
MP = {UI = {create_UIBox_mp_game_end = function(won) native = native + 1; return won, 'native' end}}
local screen = dofile('replayer/end-screen.lua')(session, function() tabs = tabs + 1 end, function() approvals = approvals + 1 end)
screen.install(); screen.install()
local function contents(def)
    local texts, buttons = {}, {}
    local function walk(node)
        local config = node.config or {}
        if config.text then texts[#texts + 1] = config.text end
        if config.button then buttons[config.button] = true end
        for _, child in pairs(node.nodes or node.contents or {}) do walk(child) end
    end
    walk(def)
    return table.concat(texts, '|'), buttons
end
local def = MP.UI.create_UIBox_mp_game_end(true)
local text, buttons = contents(def)
assert(session.phase == 'finished' and native == 0 and sprites == 2)
assert(text:find('Replay Ended', 1, true) and text:find('White Stake', 1, true) and text:find('SEED123', 1, true))
assert(text:find('WINNER|Alice', 1, true) and text:find('LOSER|Bob', 1, true))
assert(not text:find('recorded actions', 1, true), 'the end screen does not count actions')
assert(buttons.mprpl_restart and buttons.mprpl_replays and buttons.mprpl_main_menu)
run.result = 'loss'; text = contents(screen.definition(run))
assert(text:find('WINNER|Bob', 1, true) and text:find('LOSER|Alice', 1, true))
run.result, run.complete = nil, false; text = contents(screen.definition(run))
assert(text:find('Result not recorded', 1, true) and not text:find('WINNER', 1, true))
assert(text:find('End of the available recording', 1, true))
run.manifest.player, run.manifest.opponent, run.manifest.is_host = nil, nil, false
run.lobby = {host = 'Host~1', guest = 'Guest~2'}; run.result = 'win'
text = contents(screen.definition(run))
assert(text:find('WINNER|Guest', 1, true) and text:find('LOSER|Host', 1, true))
G.OVERLAY_MENU = {}; session.confirmed, session.confirmed_mods = run, 'old'
G.FUNCS.mprpl_restart(); G.FUNCS.mprpl_restart()
assert(stopped == 1)
screen.update(); assert(restarted == 0, 'must wait for cleanup')
active = nil; session.phase = 'idle'; G.STAGE = G.STAGES.MAIN_MENU
-- Multiplayer resets the lobby options as it leaves, so a restart waits for the
-- menu to hold still: no overlay, no screen wipe, and a stretch of quiet after.
screen.update(); assert(restarted == 0, 'the first quiet frame is not enough')
G.OVERLAY_MENU = {}
for _ = 1, 60 do screen.update() end
assert(restarted == 0, 'an open overlay is not a settled menu')
G.OVERLAY_MENU = nil
G.CONTROLLER = {locks = {wipe = true}}
for _ = 1, 60 do screen.update() end
assert(restarted == 0, 'nor is a screen wipe')
G.CONTROLLER = {locks = {}}
for _ = 1, 44 do screen.update() end
assert(restarted == 0, 'the wait starts again once it is quiet')
screen.update(); assert(restarted == 1 and approvals == 1)
session.phase = 'finished'; screen.update()
assert(overlays == 1 and G.OVERLAY_MENU.config.no_esc)
screen.update(); assert(overlays == 1, 'open the finished summary once')
G.FUNCS.mprpl_replays(); screen.update(); assert(tabs == 0)
active = nil; session.phase = 'idle'; screen.update(); assert(tabs == 1)
active = run; session.phase = 'finished'; G.STAGE = G.STAGES.RUN
G.FUNCS.mprpl_main_menu(); active = nil; session.phase = 'idle'; G.STAGE = G.STAGES.MAIN_MENU
screen.update(); assert(tabs == 1 and restarted == 1 and stopped == 3)
local won, marker = MP.UI.create_UIBox_mp_game_end(false)
assert(won == false and marker == 'native' and native == 1, 'ordinary games keep their result screen')
G.FUNCS.mprpl_restart(); assert(stopped == 3, 'stale buttons do nothing')
print('PASS: replay results, sprites, partial logs, duplicate-click protection, asynchronous navigation and native-game isolation')
