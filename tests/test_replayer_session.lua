-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_session.lua
local JSON = dofile('json.lua')
local now = 100
-- Whatever the replay writes into the Lovely log lands in these.
local writes, lovely = {}, {}
love = {timer = {getTime = function() return now end},
    filesystem = {createDirectory = function() return true end, write = function(p, t) writes[p] = t; return true end}}
function sendDebugMessage(text) lovely[#lovely + 1] = text end
function sendTraceMessage(text) lovely[#lovely + 1] = text end
local channel = {items = {}}
function channel:push(v) self.items[#self.items + 1] = v end
function channel:pop() return table.remove(self.items, 1) end

local performed, outcome = {}, 'done'
local reachable = function() return true end
local driver = {perform = function(entry) performed[#performed + 1] = entry.text; return outcome, 'not yet' end,
    signature = function() return 'stable' end, state_name = function() return 'STATE' end,
    reachable = function(entry) return reachable(entry) end}
local encoded, pushed = {}, {}
local function encode(t) encoded[#encoded + 1] = t; return 'json' .. #encoded end
function channel:push(v) self.items[#self.items + 1] = v; pushed[#pushed + 1] = encoded[tonumber(v:match('%d+'))] end
local function sent_last() return pushed[#pushed] end

G = {STAGE = 1, STAGES = {MAIN_MENU = 1, RUN = 2}, STATES = {SELECTING_HAND = 1}, STATE = 1, STATE_COMPLETE = true, SETTINGS = {},
    GAME = {}, FUNCS = {exit_overlay_menu = function() G.OVERLAY_MENU = nil end}, CONTROLLER = {locks = {}}, E_MANAGER = {queues = {base = {}}},
    P_CENTERS = {b_red = {key = 'b_red', set = 'Back', name = 'Red Deck'}, b_mp_cocktail = {key = 'b_mp_cocktail', set = 'Back', name = 'b_mp_cocktail'}}}
local sends, records, matches = {}, {}, 0
Client = {send = function(msg) sends[#sends + 1] = msg end}
local original_send, original_config = Client.send, {ruleset = 'old', timer = true}
MP = {LOBBY = {config = original_config, deck = {back = 'Red Deck'}, username = 'Old', host = {}, guest = {}, blind_col = 3},
    RLOG = {record = function(op, args, human) records[#records + 1] = {op, args, human} end},
    Rulesets = {ruleset_mp_standard_ranked = {}}, Gamemodes = {gamemode_mp_attrition = {}}, GAME = {}, SP = {practice = true, ruleset = 'x'},
    GHOST = {clear = function() MP.GHOST.cleared = true end}, MODIFIERS = {'old_layer'}, STATS = {record_match = function() matches = matches + 1 end},
    UTILS = {get_deck_key_from_name = function(name) for k, v in pairs(G.P_CENTERS) do if v.name == name then return k end end end},
    get_cocktail_decks = function() return {'b_red', 'b_blue'} end}
function MP.reset_lobby_config() MP.LOBBY.config = {ruleset = 'ruleset_mp_blitz', timer = true, the_order = true, sleeve = 'none', cocktail = '', multiplayer_jokers = true} end
function MP.modifiers_parse(s) MP.MODIFIERS = {}; for n in s:gmatch('[^,]+') do MP.MODIFIERS[#MP.MODIFIERS + 1] = n end end
function MP.reset_game_states() MP.GAME = {reset = true} end
SMODS = {Mods = {Multiplayer = {version = '0.5.5'}}}
BalatroActionRecorder = {ok = true, path = nil, action_count = 0}

-- Eight MP_RLOG lines, two of them set_ante_key: six actions to execute.
local P = ':: MULTIPLAYER :: '
local text = table.concat({
    P .. 'Client got lobbyInfo message:  (host: Me~7)  (guest: Them~2)  (isHost: true) ',
    P .. 'MP_RLOG: MANIFEST {}',
    P .. 'Client got playerInfo message:  (lives: 4)  (action: playerInfo) ',
    P .. 'MP_RLOG: 1 set_ante_key 0.111',
    P .. 'MP_RLOG: 2 select_blind 0',
    P .. 'Client sent message: action:selectBlind,blind:bl_small',
    P .. 'MP_RLOG: 3 play 1.2',
    P .. 'Client sent message: action:play,cards:1.2',
    P .. 'Client sent message: action:moneyMoved,amount:3',
    P .. 'Client sent message: {"action":"playHand","handsLeft":2,"score":"4210"}',
    P .. 'Client got enemyInfo message:  (lives: 4)  (action: enemyInfo)  (noScore: true) ',
    P .. 'Client got enemyLocation message:  (location: loc_shop-bl_big)  (action: enemyLocation) ',
    P .. 'MP_RLOG: 4 ready_blind 1',
    P .. 'Client got startBlind message:  (firstPlayer: guest)  (action: startBlind) ',
    P .. 'MP_RLOG: 5 set_ante_key 0.222',
    P .. 'MP_RLOG: 6 select_blind 0',
    P .. 'Client sent message: action:selectBlind,blind:bl_mp_nemesis',
    P .. 'MP_RLOG: 7 buy 1 1',
    P .. 'Client sent message: action:boughtCardFromShop,card:Misprint,cost:4',
    P .. 'MP_RLOG: 8 reroll',
    P .. 'Client sent message: action:rerollShop,cost:5',
    P .. 'MP_RLOG: END {}',
}, '\n')
package.loaded.json = nil
local manifest = {seed = 'TESTSEED', deck = 'b_red', ruleset = 'ruleset_mp_standard_ranked', gamemode = 'gamemode_mp_attrition', stake = 1,
    mod_version = '0.5.5', lobby_code = 'VILVX', is_host = true, player = 'Me', opponent = 'Them', the_order_enabled = true, modifier_layers = 'classic,ranked',
    lobby_config = {stake = 1, the_order = true, timer = true, action = 'lobbyOptions', starting_lives = 6, hide_score_until_played = true, back = 'b_red'}}
local log = dofile('replayer/log.lua')(function(text_) if text_ == '{}' then return manifest end return {} end)
local session = dofile('replayer/session.lua')(log, driver, JSON,
    {clock = function() return now end, channel = function(name) assert(name == 'networkToUi'); return channel end, encode = encode})

-- Loading filters the log to its actions and lists them for the player.
session.load(text)
assert(session.runs and session.runs[1].actions == 6 and session.text:find('6 actions, seed TESTSEED'), session.text)
local listed = writes['balatro_replayer/actions.txt']
assert(listed:find('^MANIFEST {}\n') and listed:find('OP_NUM: 3 || OP: play') and not listed:find('set_ante_key'), listed)

-- Starting is refused outside the main menu, inside a lobby, or without the recorder.
G.STAGE = 2
assert(not pcall(session.start))
G.STAGE = 1
MP.LOBBY.code = 'LIVE'
local ok, err = pcall(session.start)
assert(not ok and err:find('Leave the Multiplayer lobby'))
MP.LOBBY.code = nil
BalatroActionRecorder.ok = false
ok, err = pcall(session.start)
assert(not ok and err:find('Action Recorder'))
BalatroActionRecorder.ok = true
SMODS.Mods.Multiplayer.version = '0.5.4'
ok, err = pcall(session.start)
assert(not ok and err:find('Install Multiplayer 0.5.5'))
SMODS.Mods.Multiplayer.version = '0.5.5'
assert(session.phase == 'idle' and MP.LOBBY.config == original_config and Client.send == original_send, 'a refused start changes nothing')

-- Starting emulates the lobby the log was played in.
G.OVERLAY_MENU = {}
session.start()
assert(session.phase == 'joining' and not G.OVERLAY_MENU)
assert(MP.LOBBY.code == 'VILVX' and MP.LOBBY.connected and MP.LOBBY.is_host and MP.LOBBY.username == 'Me')
assert(MP.LOBBY.host.username == 'Me' and MP.LOBBY.host.blind_col == 7 and MP.LOBBY.guest.username == 'Them' and MP.LOBBY.guest.blind_col == 2 and MP.LOBBY.blind_col == 7)
local config = MP.LOBBY.config
assert(config ~= original_config and config.ruleset == 'ruleset_mp_standard_ranked' and config.gamemode == 'gamemode_mp_attrition')
assert(config.starting_lives == 6 and config.hide_score_until_played == true and config.action == nil and config.the_order == true)
assert(config.timer == false, 'the round timer is off: a replay runs at animation speed')
assert(config.back == 'Red Deck' and config.stake == 1 and config.modifier_layers == 'classic,ranked' and MP.LOBBY.deck.back == 'Red Deck')
assert(MP.MODIFIERS[1] == 'classic' and MP.MODIFIERS[2] == 'ranked' and MP.SP.practice == false and MP.GHOST.cleared)
Client.send({action = 'setLocation', location = 'loc_shop'})
Client.send({action = 'username'})
assert(#sends == 1 and sends[1].action == 'username', 'game messages are dropped, harmless ones pass')
MP.STATS.record_match(true)
assert(matches == 0, 'a replayed win is not a recorded match')
assert(#channel.items == 0, 'the run does not start before Multiplayer has entered the lobby')

-- Multiplayer re-enters the menu on joining; the run starts once it settles.
now = now + 1
session.update(0.1)
assert(#channel.items == 0)
session.on_main_menu()
session.update(0.1)
assert(#channel.items == 0, 'the menu gets a moment to rebuild')
now = now + 1
session.update(0.1)
assert(#channel.items == 1 and session.phase == 'starting', 'startGame is delivered like the server did')
assert(sent_last().action == 'startGame' and sent_last().seed == 'TESTSEED' and sent_last().stake == 1)
channel:pop()

-- The started run must be the logged one.
G.STAGE = 2
G.GAME = {pseudorandom = {seed = 'OTHER'}, selected_back = {effect = {center = {key = 'b_red'}}}}
BalatroActionRecorder.path = 'run.jsonl'
session.on_run_started()
assert(session.phase == 'failed' and session.text:find('seed OTHER'))
session.on_main_menu()
assert(session.phase == 'idle' and MP.LOBBY.code == nil and Client.send == original_send and MP.LOBBY.config == original_config and MP.RLOG.record ~= session.record)

local function begin()
    G.STAGE = 1
    session.start()
    session.on_main_menu()
    now = now + 2
    session.update(0.1)
    channel.items = {}
    G.STAGE = 2
    G.GAME = {pseudorandom = {seed = '*TESTSEED'}, selected_back = {effect = {center = {key = 'b_red'}}}}
    session.on_run_started()
    assert(session.phase == 'running', session.text)
end
begin()

-- Messages before the first action are delivered first, in log order.
now = now + 1
session.update(0.1)
assert(#channel.items == 1 and sent_last().action == 'playerInfo' and sent_last().lives == 4)
channel:pop()
-- The first action is select_blind, executed once the game holds still.
now = now + 1
session.update(0.1)
assert(#performed == 0, 'the game must hold still before an action is executed')
now = now + 1
session.update(0.1)
assert(performed[1] == 'select_blind 0')
-- The game rolls its own ante key: not an action, so it neither advances the
-- replay nor stops it.
MP.RLOG.record('set_ante_key', '0.98765')
assert(session.progress() == '0/6' and session.phase == 'running')
MP.RLOG.record('select_blind', 0, 'action:selectBlind,blind:bl_small')
assert(session.progress() == '1/6' and session.phase == 'running')
assert(#records == 0, 'the replayed actions are kept out of Multiplayer\'s replay log')
now = now + 0.2
session.update(0.1)
assert(#performed == 1, 'an action just recorded gets a settle period')
now = now + 1
session.update(0.1)
assert(performed[2] == 'play 1.2')
now = now + 1
session.update(0.1)
assert(#performed == 2, 'no action is repeated while its record is awaited')
MP.RLOG.record('play', {{1, 2}}, 'action:play,cards:1.2')
assert(session.progress() == '2/6')
-- Two messages, then Ready, then the PvP blind the server starts.
now = now + 1
session.update(0.1)
assert(#channel.items == 2 and sent_last().action == 'enemyLocation' and pushed[#pushed - 1].noScore == true)
channel.items = {}
now = now + 1
session.update(0.1)
now = now + 1
session.update(0.1)
assert(performed[3] == 'ready_blind 1')
MP.RLOG.record('ready_blind', 1)
now = now + 1
session.update(0.1)
assert(sent_last().action == 'startBlind' and sent_last().firstPlayer == 'guest')
channel.items = {}
for _ = 1, 5 do now = now + 1; session.update(0.1) end
assert(#performed == 3, 'a PvP blind is selected by the game after Ready, never by the replay')
MP.RLOG.record('set_ante_key', '0.5')
MP.RLOG.record('select_blind', 0, 'action:selectBlind,blind:bl_mp_nemesis')
assert(session.progress() == '4/6')
-- A pause never counts as a stall.
G.SETTINGS.paused = true
for _ = 1, 10 do now = now + 10; session.update(0.1) end
assert(session.phase == 'running' and #performed == 3)
G.SETTINGS.paused = false
now = now + 1
session.update(0.1)
now = now + 1
session.update(0.1)
assert(performed[4] == 'buy 1 1')
-- The game does something that is not the log's next action: the replay stops
-- there instead of looking for a way to carry on.
MP.RLOG.record('buy', {1, 2}, 'action:boughtCardFromShop,card:Square Joker,cost:4')
assert(session.phase == 'failed', session.text)
assert(session.text:find('at action 7 %(buy 1 1%)') and session.text:find('the game did "buy 1 2", which is not the log\'s next action "buy 1 1"'), session.text)
assert(writes['balatro_replayer/status.json']:find('"phase":"failed"'))
-- Once stopped, the player's own moves are logged as usual.
MP.RLOG.record('reroll', nil, 'action:rerollShop,cost:5')
assert(#records == 1 and session.progress() == '4/6', 'after a failure records pass through untouched')

-- Stopping from a run drops the lobby code; the menu hook restores the rest.
session.stop()
assert(session.phase == 'stopped' and MP.LOBBY.code == nil)
session.on_main_menu()
assert(session.phase == 'idle' and Client.send == original_send and MP.LOBBY.config == original_config and MP.LOBBY.username == 'Old')
assert(MP.MODIFIERS[1] == 'old_layer' and MP.SP.practice == true and MP.GAME.reset and MP.STATS.record_match ~= nil)
MP.STATS.record_match(true)
assert(matches == 1)

-- An action the game never accepts ends the replay with the reason.
performed, outcome = {}, 'wait'
begin()
for _ = 1, 60 do now = now + 1; session.update(0.1) end
assert(session.phase == 'failed' and session.text:find('waited %d+ s for not yet') and session.progress() == '0/6', session.text)
session.stop()
session.on_main_menu()

-- An action the game refuses outright ends it at once; nothing is skipped.
driver.perform = function() error('no Mercury to use: consumeables has 0 card(s), no slot 1') end
begin()
for _ = 1, 5 do now = now + 1; session.update(0.1) end
assert(session.phase == 'failed' and session.text:find('no Mercury to use') and session.progress() == '0/6', session.text)
session.stop()
session.on_main_menu()

-- A screen the action cannot be done from stops the replay after a short
-- wait, saying which way the round went.
driver.perform = function(entry) performed[#performed + 1] = entry.text; return 'wait', 'the shop is not open' end
driver.state_name = function() return 'SELECTING_HAND' end
reachable = function() return false end
begin()
for _ = 1, 20 do now = now + 1; session.update(0.1) end
assert(session.phase == 'failed' and session.text:find('the game cannot do "select_blind 0" from SELECTING_HAND')
    and session.text:find('the blind was not beaten here'), session.text)
session.stop()
session.on_main_menu()
driver.state_name = function() return 'SHOP' end
reachable = function(entry) return entry.op ~= 'play' end
begin()
now = now + 1
session.update(0.1)
channel.items = {}
MP.RLOG.record('select_blind', 0, 'action:selectBlind,blind:bl_small')
for _ = 1, 20 do now = now + 1; session.update(0.1) end
assert(session.phase == 'failed' and session.text:find('the game finished this round sooner than the log did'), session.text)
session.stop()
session.on_main_menu()
driver.state_name = function() return 'STATE' end
reachable = function() return true end

-- A complete log ends the session with the recording named. Here the stub
-- game writes its MP_RLOG lines inside the callback, as the real callbacks
-- do, and produces the PvP blind by itself.
local function emit(entry)
    if entry.op == 'select_blind' then MP.RLOG.record('set_ante_key', '0.999'); MP.RLOG.record('select_blind', 0, 'action:' .. entry.human)
    elseif entry.op == 'play' then MP.RLOG.record('play', {{1, 2}}, 'action:' .. entry.human)
    elseif entry.op == 'ready_blind' then MP.RLOG.record('ready_blind', 1)
    elseif entry.op == 'buy' then MP.RLOG.record('buy', {1, 1}, 'action:' .. entry.human)
    elseif entry.op == 'reroll' then MP.RLOG.record('reroll', nil, 'action:' .. entry.human) end
end
performed, records = {}, {}
driver.perform = function(entry)
    performed[#performed + 1] = entry.text
    emit(entry)
    return 'done'
end
begin()
for _ = 1, 80 do
    now = now + 1
    session.update(0.1)
    channel.items = {}
    if session.phase ~= 'running' then break end
    local current = session.current()
    if current and current.kind == 'action' and current.auto then emit(current) end
end
assert(session.phase == 'finished', session.text)
assert(table.concat(performed, ',') == 'select_blind 0,play 1.2,ready_blind 1,buy 1 1,reroll', table.concat(performed, ','))
assert(session.text:find('Replay complete %- all 6 actions') and session.text:find('run.jsonl'), session.text)
assert(#records == 0 and #channel.items == 0)
session.on_main_menu()
assert(session.phase == 'idle' and MP.LOBBY.code == nil)

-- Nothing the replay did reached the Lovely log.
assert(#lovely == 0, 'the replay wrote to the Lovely log: ' .. tostring(lovely[1]))

print('PASS: action filter, lobby emulation, refused starts, run start checks, delivery order, settling, ante keys ignored, PvP blinds, pauses, stops on any mismatch, refusal or stall, a quiet Lovely log, and cleanup')
