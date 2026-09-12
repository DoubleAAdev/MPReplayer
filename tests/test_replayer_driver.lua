-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_driver.lua
local log = dofile('replayer/log.lua')(function() return {} end)
local driver = dofile('replayer/driver.lua')(log)

local function card(name, set, extra)
    local c = {ability = {name = name, set = set, consumeable = set == 'Tarot' or set == 'Planet' or set == 'Spectral' or nil,
        card_limit = 0, extra_slots_used = 0}, config = {center = {key = name}}, cost = 3, states = {drag = {is = false}}}
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function playing(rank, suit)
    local c = card('Default Base', 'Default')
    c.base = {value = rank, suit = suit}
    local ranks = {['2'] = 2, ['3'] = 3, ['7'] = 7, ['9'] = 9, Ace = 14}
    local suits = {Spades = 4, Hearts = 3, Clubs = 2, Diamonds = 1}
    c.get_nominal = function(self, kind)
        if kind == 'suit' then return suits[suit] * 100 + ranks[rank] end
        return ranks[rank] * 10 + suits[suit]
    end
    return c
end
local function area(cards, kind)
    local a = {cards = cards, highlighted = {}, config = {type = kind or 'hand', card_limit = 5, highlighted_limit = 5, sort = 'desc'}}
    function a:unhighlight_all()
        for i = #self.highlighted, 1, -1 do
            if not self.highlighted[i].ability.forced_selection then table.remove(self.highlighted, i) end
        end
    end
    function a:add_to_highlighted(c) if #self.highlighted < self.config.highlighted_limit then self.highlighted[#self.highlighted + 1] = c end end
    function a:set_ranks() self.ranked = true end
    function a:align_cards() self.aligned = true end
    function a:sort(method) self.config.sort = method; self.sorted = method end
    return a
end
local calls = {}
local function record(name) return function(e) calls[#calls + 1] = {name, e} end end
G = {STATES = {SELECTING_HAND = 1, HAND_PLAYED = 2, SHOP = 5, BLIND_SELECT = 7, ROUND_EVAL = 8, SMODS_BOOSTER_OPENED = 999, GAME_OVER = 4},
    STATE = 1, GAME = {dollars = 10, current_round = {reroll_cost = 5}, round_resets = {ante = 1}, blind_on_deck = 'Small'},
    FUNCS = {}, CONTROLLER = {locks = {}},
    P_CENTERS = {c_fool = {name = 'The Fool', set = 'Tarot', consumeable = true}, c_mars = {name = 'Mars', set = 'Planet', consumeable = true},
        c_temperance = {name = 'Temperance', set = 'Tarot', consumeable = true}, c_mp_asteroid = {name = 'c_mp_asteroid', set = 'Planet', consumeable = true},
        c_hanged_man = {name = 'The Hanged Man', set = 'Tarot', consumeable = true}, p_arcana = {name = 'Arcana Pack', set = 'Booster'},
        v_overstock = {name = 'Overstock', set = 'Voucher'}, j_misprint = {name = 'Misprint', set = 'Joker'}}}
MP = {GAME = {ready_blind = false}}
local ace, king, seven, nine, two = playing('Ace', 'Spades'), playing('9', 'Hearts'), playing('7', 'Clubs'), playing('9', 'Spades'), playing('2', 'Diamonds')
G.hand = area({ace, king, seven, nine, two})
G.jokers = area({card('Blueprint', 'Joker'), card('Misprint', 'Joker')}, 'joker')
G.consumeables = area({card('The Fool', 'Tarot'), card('Mars', 'Planet')}, 'joker')
G.consumeables.config.card_limit = 2
G.jokers.config.card_limit = 5
for _, name in ipairs({'can_play', 'can_discard', 'can_reroll'}) do
    G.FUNCS[name] = function(e) e.config.button = ({can_play = 'play_cards_from_highlighted', can_discard = 'discard_cards_from_highlighted', can_reroll = 'reroll_shop'})[name] end
end
G.FUNCS.can_buy = function(e) e.config.button = e.config.ref_table.cost <= G.GAME.dollars and 'buy_from_shop' or nil end
G.FUNCS.can_buy_and_use = G.FUNCS.can_buy
G.FUNCS.can_open = function(e) if MP.GAME.ready_blind then e.config.button = nil else e.config.button = 'use_card' end end
G.FUNCS.can_redeem = function(e) e.config.button = 'use_card' end
G.FUNCS.can_use_consumeable = function(e) e.config.button = 'use_card' end
G.FUNCS.can_select_card = function(e) e.config.button = 'use_card' end
G.FUNCS.can_skip_booster = function(e) e.config.button = G.pack_cards and 'skip_booster' or nil end
for _, name in ipairs({'play_cards_from_highlighted', 'discard_cards_from_highlighted', 'buy_from_shop', 'use_card', 'reroll_shop',
    'skip_booster', 'sell_card', 'cash_out', 'toggle_shop', 'select_blind', 'skip_blind', 'mp_toggle_ready'}) do
    G.FUNCS[name] = record(name)
end
local function last() return calls[#calls] and calls[#calls][1], calls[#calls] and calls[#calls][2] end
local function entry(op, args, human, money, position) return {kind = 'action', op = op, args = args, text = op, human = human, money = money or {}, position = position} end
local function fails(fn, pattern)
    local ok, err = pcall(fn)
    assert(not ok, 'expected a failure matching ' .. pattern)
    assert(tostring(err):find(pattern), 'unexpected failure: ' .. tostring(err))
end

-- play / discard select exactly the logged slots, then press the real button.
assert(driver.perform(entry('play', {'1.3.5'})) == 'done' and last() == 'play_cards_from_highlighted')
assert(#G.hand.highlighted == 3 and G.hand.highlighted[1] == ace and G.hand.highlighted[3] == two)
assert(driver.perform(entry('discard', {'2'})) == 'done' and last() == 'discard_cards_from_highlighted' and G.hand.highlighted[1] == king and #G.hand.highlighted == 1)
fails(function() driver.perform(entry('play', {'9'})) end, 'log selects slot 9')
ace.ability.forced_selection = true
G.hand.highlighted = {ace}
assert(driver.perform(entry('play', {'1.2'})) == 'done' and #G.hand.highlighted == 2, 'a forced card is kept, not doubled')
fails(function() driver.perform(entry('play', {'2.3'})) end, 'keeps a card selected')
ace.ability.forced_selection = nil
G.hand.highlighted = {}
G.FUNCS.can_play = function(e) e.config.button = nil end
fails(function() driver.perform(entry('play', {'1'})) end, 'refuses to play')
G.FUNCS.can_play = function(e) e.config.button = 'play_cards_from_highlighted' end

-- The screens the log never records are pressed through to reach an action.
G.STATE = G.STATES.ROUND_EVAL
G.round_eval = {}
local status, why = driver.perform(entry('play', {'1'}))
assert(status == 'wait' and why == 'cashing out' and last() == 'cash_out')
G.round_eval = nil
G.STATE = G.STATES.SHOP
status, why = driver.perform(entry('play', {'1'}))
assert(status == 'wait' and why:find('not selecting a hand') and last() ~= 'play_cards_from_highlighted')

-- buy: the slot must hold the named card at the logged price.
G.shop_jokers = area({card('Square Joker', 'Joker', {cost = 4}), card('Mail-In Rebate', 'Joker', {cost = 4})}, 'shop')
G.shop_booster = area({card('Buffoon Pack', 'Booster', {cost = 4})}, 'shop')
G.shop_vouchers = area({card('Overstock', 'Voucher', {cost = 10})}, 'shop')
-- Purchases carry the money the log traced after them; a joker is a plain buy.
local paid = {'-4'}
fails(function() driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', paid)) end, 'slot 1 holds Square Joker, log says Mail%-In Rebate')
fails(function() driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:7', paid)) end, 'costs %$4, the log paid %$7')
fails(function() driver.perform(entry('buy', {'1', '3'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', paid)) end, 'has 2 card%(s%), no slot 3')
assert(driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', paid)) == 'done')
local name, e = last()
assert(name == 'buy_from_shop' and e.config.ref_table == G.shop_jokers.cards[2] and e.config.id == 'buy')
assert(driver.note == 'Mail-In Rebate: buy (not a consumable)', tostring(driver.note))
G.GAME.dollars = 1
fails(function() driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', paid)) end, 'not enough money')
G.GAME.dollars = 10
-- No payment in the log means the click was refused; the game must refuse it too.
G.jokers.config.card_limit = 2
G.FUNCS.buy_from_shop = function() return false end
assert(driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', {})) == 'done')
assert(driver.note:find('refused'), driver.note)
fails(function() driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', paid)) end, 'rejected buying Mail%-In Rebate %(no room%)')
G.FUNCS.buy_from_shop = record('buy_from_shop')
fails(function() driver.perform(entry('buy', {'1', '2'}, 'boughtCardFromShop,card:Mail-In Rebate,cost:4', {})) end, 'refused purchase of Mail%-In Rebate, but the game accepted it')
G.jokers.config.card_limit = 5
-- "Buy & Use" is logged like a buy. Money moving right after the purchase
-- is the clearest sign: the Hermit doubled the money here.
local hermit = card('The Hermit', 'Tarot')
hermit.can_use_consumeable = function() return true end
G.shop_jokers.cards[1] = hermit
assert(driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:The Hermit,cost:3', {'-3', '20'})) == 'done')
assert(select(2, last()).config.id == 'buy_and_use' and driver.note:find('money moved'), driver.note)
-- A consumable the shop cannot use (it needs selected cards) is a plain buy.
local hanged = card('The Hanged Man', 'Tarot')
hanged.can_use_consumeable = function() return false end
G.shop_jokers.cards[1] = hanged
assert(driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:The Hanged Man,cost:3', {'-3'})) == 'done')
assert(select(2, last()).config.id == 'buy' and driver.note:find('cannot be used from the shop'), driver.note)
-- No free slot: only "Buy & Use" was possible.
G.shop_jokers.cards[1] = card('Temperance', 'Tarot')
G.shop_jokers.cards[1].can_use_consumeable = function() return true end
assert(driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:Temperance,cost:3', {'-3'})) == 'done')
assert(select(2, last()).config.id == 'buy_and_use' and driver.note:find('no free consumable slot'), driver.note)
-- With a free slot the later use or sale of that slot decides. The rack
-- holds The Fool and Mars; the bought asteroid would take slot 3.
G.consumeables.config.card_limit = 3
local asteroid = card('c_mp_asteroid', 'Planet')
asteroid.can_use_consumeable = function() return true end
G.shop_jokers.cards[1] = asteroid
local function stream(...)
    local list = {entry('buy', {'1', '1'}, 'boughtCardFromShop,card:c_mp_asteroid,cost:3', {'-3'}, 1)}
    for _, item in ipairs({...}) do list[#list + 1] = item end
    return list
end
local kept = stream(entry('use', {'1'}, 'usedCard,card:Arcana Pack'), entry('sell', {'5', '1'}, 'soldCard,card:The Fool'),
    entry('use', {'2'}, 'usedCard,card:c_mp_asteroid'))
assert(driver.perform(kept[1], kept) == 'done' and select(2, last()).config.id == 'buy' and driver.note:find('its slot is used at action'), driver.note)
local fired = stream(entry('reroll', {}, 'rerollShop,cost:5'), entry('use', {'1'}, 'usedCard,card:Mars'), entry('use', {'2'}, 'usedCard,card:Temperance'))
assert(driver.perform(fired[1], fired) == 'done' and select(2, last()).config.id == 'buy_and_use' and driver.note:find('another card is in its slot'), driver.note)
local silent = stream(entry('use', {'1'}, 'usedCard,card:Overstock'), entry('sell', {'4', '3'}, 'soldCard,card:Misprint'))
assert(driver.perform(silent[1], silent) == 'done' and select(2, last()).config.id == 'buy' and driver.note:find('no later use'), driver.note)
assert(driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:c_mp_asteroid,cost:3', {'-3'})) == 'done' and select(2, last()).config.id == 'buy')
G.consumeables.config.card_limit = 2
G.FUNCS.buy_from_shop = function() return false end
fails(function() driver.perform(entry('buy', {'1', '1'}, 'boughtCardFromShop,card:c_mp_asteroid,cost:3', {'-3'})) end, 'rejected buying')
G.FUNCS.buy_from_shop = record('buy_from_shop')

-- use: the mirrored name decides between consumables, shop packs and vouchers.
assert(driver.perform(entry('use', {'1'}, 'usedCard,card:Buffoon Pack')) == 'done' and select(2, last()).config.ref_table == G.shop_booster.cards[1])
assert(driver.perform(entry('use', {'1'}, 'usedCard,card:Overstock')) == 'done' and select(2, last()).config.ref_table == G.shop_vouchers.cards[1])
assert(driver.perform(entry('use', {'2'}, 'usedCard,card:Mars')) == 'done' and select(2, last()).config.ref_table == G.consumeables.cards[2])
fails(function() driver.perform(entry('use', {'1'}, 'usedCard,card:Mars')) end, 'no Mars to use: consumeables slot 1 holds The Fool; shop_booster slot 1 holds Buffoon Pack; shop_vouchers slot 1 holds Overstock')
fails(function() driver.perform(entry('use', {'1'})) end, 'does not name the card')
MP.GAME.ready_blind = true
fails(function() driver.perform(entry('use', {'1'}, 'usedCard,card:Buffoon Pack')) end, 'refuses to use Buffoon Pack')
MP.GAME.ready_blind = false
G.STATE = G.STATES.SELECTING_HAND
G.hand.highlighted = {king}
assert(driver.perform(entry('use', {'1', '2.3'}, 'usedCard,card:The Fool')) == 'done')
assert(#G.hand.highlighted == 2 and G.hand.highlighted[1] == king and G.hand.highlighted[2] == seven, 'targets are selected before the consumable is used')
assert(driver.perform(entry('use', {'2'}, 'usedCard,card:Mars')) == 'done' and #G.hand.highlighted == 0, 'no targets means nothing selected')
G.STATE = G.STATES.ROUND_EVAL
G.round_eval = {}
status, why = driver.perform(entry('use', {'1'}, 'usedCard,card:Buffoon Pack'))
assert(status == 'wait' and why == 'cashing out', 'a shop item named during cash out means the shop comes next')
assert(driver.perform(entry('use', {'1'}, 'usedCard,card:The Fool')) == 'done', 'a consumable can be used while cashing out')
G.round_eval = nil

-- pack_pick waits for the pack, then checks the card.
G.STATE = G.STATES.SHOP
status, why = driver.perform(entry('pack_pick', {'1'}, 'usedCard,card:Splash'))
assert(status == 'wait' and why:find('no booster pack is open'))
G.STATE = G.STATES.SMODS_BOOSTER_OPENED
G.pack_cards = area({card('Splash', 'Joker')}, 'shop')
status, why = driver.perform(entry('pack_pick', {'2'}, 'usedCard,card:Runner'))
assert(status == 'wait' and why:find('shows 1 card'))
G.pack_cards.cards[2] = card('Runner', 'Joker')
fails(function() driver.perform(entry('pack_pick', {'2'}, 'usedCard,card:Splash')) end, 'slot 2 holds Runner, log says Splash')
assert(driver.perform(entry('pack_pick', {'2'}, 'usedCard,card:Runner')) == 'done' and select(2, last()).config.ref_table == G.pack_cards.cards[2])
assert(driver.perform(entry('pack_skip', {'0'})) == 'done' and last() == 'skip_booster')
G.pack_cards = nil
status = driver.perform(entry('pack_skip', {'0'}))
assert(status == 'wait')

-- sell checks the name and the game's own permission.
G.STATE = G.STATES.SHOP
local sold = card('Misprint', 'Joker')
G.jokers.cards[2] = sold
sold.can_sell_card = function() return false end
status, why = driver.perform(entry('sell', {'4', '2'}, 'soldCard,card:Misprint'))
assert(status == 'wait' and why:find('does not allow selling'))
sold.can_sell_card = function() return true end
assert(driver.perform(entry('sell', {'4', '2'}, 'soldCard,card:Misprint')) == 'done' and select(2, last()).config.ref_table == sold)
fails(function() driver.perform(entry('sell', {'5', '1'}, 'soldCard,card:Mars')) end, 'holds The Fool, log says Mars')
fails(function() driver.perform(entry('sell', {'1', '1'}, 'soldCard,card:Mars')) end, 'not possible')

-- reroll must cost what the log paid.
fails(function() driver.perform(entry('reroll', {}, 'rerollShop,cost:6')) end, 'costs %$5, the log paid %$6')
assert(driver.perform(entry('reroll', {}, 'rerollShop,cost:5')) == 'done' and last() == 'reroll_shop')

-- reorder: joker drags permute in place, hand sorts are detected.
G.jokers.cards = {card('A', 'Joker'), card('B', 'Joker'), card('C', 'Joker')}
local a, b, c = G.jokers.cards[1], G.jokers.cards[2], G.jokers.cards[3]
assert(driver.perform(entry('reorder', {'4', '3.1.2'})) == 'done')
assert(G.jokers.cards[1] == c and G.jokers.cards[2] == a and G.jokers.cards[3] == b and G.jokers.ranked and G.jokers.aligned)
status, why = driver.perform(entry('reorder', {'4', '1.2'}))
assert(status == 'wait' and why:find('holds 3 card%(s%), the log reorders 2'))
-- A drag lifts one card and drops it elsewhere; a sort button permutes the
-- whole area and changes how every later draw is sorted. Only the second
-- may be applied as a sort, or every hand after it comes out different.
assert(driver.single_move({1, 2, 4, 3, 5}) and driver.single_move({5, 1, 2, 3, 4}) and driver.single_move({2, 3, 4, 5, 1}))
assert(not driver.single_move({2, 5, 4, 3, 1}) and not driver.single_move({3, 4, 5, 1, 2}))
G.STATE = G.STATES.SELECTING_HAND
local aceD, nineS, sevenC, nineH, twoS = playing('Ace', 'Diamonds'), playing('9', 'Spades'), playing('7', 'Clubs'), playing('9', 'Hearts'), playing('2', 'Spades')
G.hand.cards = {aceD, nineS, sevenC, nineH, twoS}
G.hand.sorted = nil
-- By rank this hand sorts to 1.2.4.3.5, which is also a one-card drag.
assert(driver.perform(entry('reorder', {'6', '1.2.4.3.5'})) == 'done' and G.hand.sorted == nil, 'a one-card drag stays a drag')
assert(G.hand.cards[3] == nineH and G.hand.cards[4] == sevenC)
G.hand.cards = {aceD, nineS, sevenC, nineH, twoS}
assert(driver.perform(entry('reorder', {'6', '2.5.4.3.1'})) == 'done' and G.hand.sorted == 'suit desc', 'a whole-area permutation matching a sort is the sort button')
G.hand.cards = {aceD, nineS, sevenC, nineH, twoS}
G.hand.sorted = nil
assert(driver.perform(entry('reorder', {'6', '5.1.2.3.4'})) == 'done' and G.hand.sorted == nil and G.hand.cards[1] == twoS and G.hand.cards[2] == aceD)

-- Blind panels: the on-deck column's own button, reached through nested boxes.
local function element(config, children) return {config = config or {}, children = children or {}} end
local function uibox(root) local box = {config = {}, children = {}, UIRoot = root}; return box end
local panels, selects, skips = {}, {}, {}
for _, slot in ipairs({'Boss', 'Big', 'Small'}) do
    local key = ({Boss = 'bl_boss', Big = 'bl_big', Small = 'bl_small'})[slot]
    selects[slot] = element({id = 'select_blind_button', button = 'select_blind', ref_table = {key = key}})
    skips[slot] = element({button = 'skip_blind', ref_table = {slot = slot}})
    local inner = uibox(element({}, {element({}, {selects[slot]}), element({}, {skips[slot]})}))
    panels[slot:lower()] = uibox(element({}, {element({object = inner})}))
end
G.blind_select_opts = panels
G.STATE = G.STATES.SHOP
status, why = driver.perform(entry('select_blind', {'0'}, 'selectBlind,blind:bl_small'))
assert(status == 'wait' and why == 'leaving the shop' and last() == 'toggle_shop')
G.STATE = G.STATES.BLIND_SELECT
status, why = driver.perform(entry('select_blind', {'0'}, 'selectBlind,blind:bl_small'))
assert(status == 'wait' and why:find('blind select is not open'))
G.blind_select = {}
fails(function() driver.perform(entry('select_blind', {'0'}, 'selectBlind,blind:bl_big')) end, 'Small blind is bl_small, the log chose bl_big')
assert(driver.perform(entry('select_blind', {'0'}, 'selectBlind,blind:bl_small')) == 'done' and select(2, last()) == selects.Small)
G.GAME.blind_on_deck = 'Boss'
assert(driver.perform(entry('skip_blind', {'0'})) == 'done' and select(2, last()) == skips.Boss)
-- A PvP blind carries the Ready toggle instead of Select.
selects.Boss.config.button = 'mp_toggle_ready'
fails(function() driver.perform(entry('select_blind', {'0'}, 'selectBlind,blind:bl_mp_nemesis')) end, 'needs Ready first')
assert(driver.perform(entry('ready_blind', {'1'})) == 'done' and select(2, last()) == selects.Boss)
MP.GAME.ready_blind = true
fails(function() driver.perform(entry('ready_blind', {'1'})) end, 'already ready')
assert(driver.perform(entry('ready_blind', {'0'})) == 'done')
G.GAME.blind_on_deck = 'Big'
status, why = driver.perform(entry('ready_blind', {'1'}))
assert(status == 'wait' and why:find('no mp_toggle_ready button on the Big blind'))
fails(function() driver.perform(entry('open_pack', {'1', '1'})) end, 'cannot perform open_pack')

-- Which screen can still answer which input. A round that ran shorter here
-- than in the log leaves the game in the shop while the log still plays.
G.STATE = G.STATES.SHOP
assert(not driver.reachable(entry('play', {'1.2'})), 'the shop never plays a hand')
assert(not driver.reachable(entry('discard', {'1.2'})))
assert(not driver.reachable(entry('reorder', {'6', '2.1'})), 'the hand is not in the shop')
assert(driver.reachable(entry('reorder', {'4', '2.1'})), 'jokers reorder wherever they are shown')
assert(driver.reachable(entry('buy', {'1', '1'})) and driver.reachable(entry('reroll', {})))
assert(driver.reachable(entry('select_blind', {'0'})), 'the shop is left for the blind select')
assert(driver.reachable(entry('use', {'1'})) and driver.reachable(entry('sell', {'4', '1'})))
assert(not driver.reachable(entry('pack_pick', {'1'})), 'no pack is open')
G.STATE = G.STATES.SELECTING_HAND
assert(driver.reachable(entry('play', {'1.2'})) and not driver.reachable(entry('buy', {'1', '1'})))
G.STATE = G.STATES.ROUND_EVAL
assert(driver.reachable(entry('buy', {'1', '1'})), 'the cash out leads to the shop')
assert(not driver.reachable(entry('play', {'1.2'})), 'the round is over')
G.STATE = G.STATES.SMODS_BOOSTER_OPENED
assert(driver.reachable(entry('pack_pick', {'1'})) and not driver.reachable(entry('buy', {'1', '1'})))
G.STATE = G.STATES.HAND_PLAYED
assert(driver.reachable(entry('play', {'1.2'})), 'a screen in motion is waited out, not skipped')
G.STATE = G.STATES.SHOP

-- The settle signature changes with anything an input could wait on.
local before = driver.signature()
G.GAME.dollars = 11
assert(driver.signature() ~= before)
G.shop_jokers.cards = nil
assert(driver.signature():find('%-'), 'a removed area reads as absent, not as an error')
print('PASS: selections, transitions, named-card checks, purchase modes, use resolution, packs, sells, rerolls, reorders, blind buttons and readiness')
