-- Optional integration check against the user's locally patched game sources.
-- No Balatro source is bundled in this repository or release.
local appdata = os.getenv('APPDATA')
local root = appdata and (appdata .. '/Balatro/Mods/lovely/dump/')
local file = root and io.open(root .. 'functions/UI_definitions.lua', 'r')
if not file then print('SKIP: locally patched Balatro UI source unavailable'); return end
local source = file:read('*a'); file:close()
local function load_function(name)
    local first = assert(source:find('function ' .. name .. '(', 1, true), name)
    local last = assert(source:find('\nend', first, true), name)
    assert(loadstring(source:sub(first, last + 3)))()
end
G = {UIT = {ROOT = 'ROOT', R = 'R', C = 'C', T = 'T', O = 'O'},
    C = {WHITE = {}, RED = {}, BLACK = {}, BLUE = {}, ORANGE = {}, GREY = {0,0,0}, UI = {TEXT_LIGHT = {}}},
    ROOM = {T = {w = 10, h = 10}}, GAME = {pseudorandom = {seed = 'TEST'}}, STAGE = 1,
    STAGES = {RUN = 1, MAIN_MENU = 2}, STATE = 2, STATES = {MENU = 1},
    E_MANAGER = {add_event = function() end}, FUNCS = {}}
MP = {LOBBY = {code = 'REPLAY'}}
-- Installed mods patch this source but are not loaded here; Malverk adds a button colour.
Malverk = {}
function localize(value) return value end
function Event(value) return value end
function Moveable() return {} end
function darken(value) return value end
load_function('UIBox_button')
UIBox_button_custom = UIBox_button
load_function('create_UIBox_generic_options')
load_function('create_UIBox_options')
local session = {phase = 'running'}
UIElement = {click = function(self) return self.config.button end}
local guard = dofile('replayer/input-guard.lua')(session)
local function collect(node, out)
    out = out or {}
    if node.config and node.config.button then out[node.config.button] = (out[node.config.button] or 0) + 1 end
    for _, child in pairs(node.nodes or {}) do collect(child, out) end
    return out
end
local before = collect(create_UIBox_options())
assert(before.lobby_leave == 1 and before.mp_return_to_lobby == 1, 'expected installed Multiplayer exit controls')
local transformed = guard.rewrite(create_UIBox_options())
local after = collect(transformed)
assert(after.mprpl_end == 1 and not after.lobby_leave and not after.mp_return_to_lobby and not after.mp_unstuck)
assert(after.exit_overlay_menu == 1, 'the pause menu must still close')
G.OVERLAY_MENU = {}
local function check_clicks(node)
    if node.config and node.config.button then
        node.UIBox = G.OVERLAY_MENU
        assert(UIElement.click(node) == node.config.button, 'pause button blocked: ' .. node.config.button)
    end
    for _, child in pairs(node.nodes or {}) do check_clicks(child) end
end
check_clicks(transformed)
G.OVERLAY_MENU = nil
assert(UIElement.click({config = {button = 'lobby_info'}}) == 'lobby_info')
local function find_end(node)
    if node.config and node.config.button == 'mprpl_end' then return node end
    for _, child in pairs(node.nodes or {}) do local found = find_end(child); if found then return found end end
end
assert(find_end(transformed).nodes[1].nodes[1].config.scale == 0.5, 'End Replay inherits native font size')
assert(find_end(transformed).nodes[1].config.minw == 5, 'End Replay retains the original pause-button width')
session.phase = 'idle'
local restored = collect(guard.rewrite(create_UIBox_options()))
assert(restored.lobby_leave == 1 and restored.mp_return_to_lobby == 1 and not restored.mprpl_end)
print('PASS: installed Multiplayer pause definition has one full-width End Replay and restores both normal lobby controls')

-- Build the new screen with Balatro's actual UI constructors, then exercise
-- its buttons through the installed input guard.
G.C.GREEN, G.C.GOLD, G.C.CLEAR = {}, {}, {}
local run = {manifest = {seed = 'TEST', deck = 'b_red', stake = 1, player = 'Me', opponent = 'Them'},
    result = 'win', complete = true, actions = 5}
session.active_run = function() return run end
session.deck_center = function() return nil end
session.deck_name = function() return 'Red Deck' end
session.stake_name = function() return 'White Stake' end
local screen = dofile('replayer/end-screen.lua')(session, function() end, function() end)
session.phase = 'finished'
local definition = screen.definition(run)
local controls = collect(definition)
assert(controls.mprpl_restart == 1 and controls.mprpl_replays == 1 and controls.mprpl_main_menu == 1)
assert(not controls.lobby_leave and not controls.mp_return_to_lobby)
G.OVERLAY_MENU = {}
check_clicks(definition)
print('PASS: native UI constructors build all three replay-summary buttons and replay input guard allows them')
