local snapshot = {phase = 'failed', status = 'Replay stopped', state = 'SHOP', done = 1, cursor = 2,
    run = {manifest = {seed = 'TEST'}, actions = 30}, failure = {message = 'Wrong card', line = 42}, entries = {}}
for i = 1, 30 do snapshot.entries[i] = {kind = 'action', seq = i, text = 'buy 1 1', line = 40 + i} end
snapshot.entries[3] = {kind = 'message', action = 'enemyInfo', fields = {lives = 2}, line = 43}
local session = {phase = 'failed', debug_snapshot = function() return snapshot end}
G = {UIT = {R = 'R', T = 'T', ROOT = 'ROOT'}, C = {WHITE = {}, BLUE = {}, CLEAR = {}}, FUNCS = {}}
SMODS = {}
function UIBox_button(args) return {config = {button = args.button}} end
local debug = dofile('replayer/debug.lua')(session, {id = 'MPReplayer'}, dofile('json.lua'))
local function read()
    local out = {}
    for _, row in ipairs(debug.definition().nodes) do
        for _, node in ipairs(row.nodes or {}) do if node.config.text then out[#out + 1] = node.config.text end end
    end
    return table.concat(out, '|')
end
local opened = 0
G.FUNCS.openModUI_MPReplayer = function() opened = opened + 1 end
local text = read()
assert(text:find('Wrong card', 1, true) and text:find('NEXT | line 42', 1, true))
assert(text:find('DONE | line 41', 1, true) and text:find('enemyInfo', 1, true))
G.FUNCS.mprpl_debug_next(); assert(opened == 1 and SMODS.LAST_SELECTED_MOD_TAB == 'MPReplayer_2')
assert(read():find('Page 2', 1, true))
snapshot.cursor, snapshot.issued = 30, true
G.FUNCS.mprpl_debug_current(); text = read()
assert(text:find('SENT | line 70', 1, true))
session.phase = 'idle'; local before = opened
G.FUNCS.mprpl_debug_next(); assert(opened == before)
assert(snapshot.done == 1 and #snapshot.entries == 30)
print('PASS: Debug exposes errors, action states, messages and pagination without changing playback')
