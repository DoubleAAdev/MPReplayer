-- A shop consumable following the last PvP hand must wait through NEW_ROUND.
local log = dofile('replayer/log.lua')(function() return {seed = 'TEST', deck = 'b_red', ruleset = 'r', gamemode = 'g', stake = 1} end)
local P = 'INFO - [G] 2026-10-03 12:50:55 :: TRACE :: MULTIPLAYER :: '
local run = log.parse(table.concat({
    P .. 'MP_RLOG: MANIFEST {}',
    P .. 'MP_RLOG: 1 play 1.2.3.4.5',
    P .. 'Client sent message: action:play,cards:1.2.3.4.5',
    P .. 'Client got endPvP message:  (lost: true)  (action: endPvP)',
    P .. 'Client sent message: {"location":"loc_shop-bl_small","action":"setLocation"}',
    P .. 'MP_RLOG: 2 use 1',
    P .. 'Client sent message: action:usedCard,card:Eris',
}, '\n'))[1]
local entry = run.entries[#run.entries]
assert(entry.op == 'use' and entry.after_cash_out, 'the original shop location must mark Eris as after cash out')
local used, cashed, sold, checked = 0, 0, 0, 0
local eris = {ability = {name = 'Eris', set = 'Planet', consumeable = {hand_type = 'Flush Five'}}}
G = {STATES = {NEW_ROUND = 1, ROUND_EVAL = 2, SHOP = 3, HAND_PLAYED = 4}, STATE = 1,
    consumeables = {cards = {eris}}, FUNCS = {}}
G.FUNCS.can_use_consumeable = function(e)
    checked = checked + 1
    e.config.button = G.STATE == G.STATES.SHOP and 'use_card' or nil
end
G.FUNCS.use_card = function(e) assert(e.config.ref_table == eris); used = used + 1 end
G.FUNCS.cash_out = function() cashed = cashed + 1 end
G.FUNCS.sell_card = function() sold = sold + 1 end
local driver = dofile('replayer/driver.lua')(log)
local status = driver.perform(entry)
assert(status == 'wait' and used == 0 and checked == 0 and cashed == 0, 'Eris must wait during NEW_ROUND without probing or issuing it')
G.STATE = G.STATES.ROUND_EVAL
G.round_eval = {}
assert(driver.perform(entry) == 'wait' and cashed == 1 and used == 0)
G.STATE = G.STATES.SHOP
G.round_eval = nil
assert(driver.perform(entry) == 'done' and used == 1 and checked == 1)
local sale = {op = 'sell', args = {'5', '1'}, human = 'soldCard,card:Eris', after_cash_out = true}
G.STATE = G.STATES.NEW_ROUND
assert(driver.perform(sale) == 'wait' and sold == 0, 'a shop sale also waits for round results')
G.STATE = G.STATES.ROUND_EVAL
G.round_eval = {}
assert(driver.perform(sale) == 'wait' and cashed == 2 and sold == 0)
G.STATE = G.STATES.SHOP
assert(driver.perform(sale) == 'done' and sold == 1)
print('PASS: shop consumables and sales wait for cash out through the PvP round transition')
