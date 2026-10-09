-- Buy and Buy & Use share a log entry. A round can generate another copy,
-- so a later use of the same slot is not conclusive evidence of a plain buy.
local log = dofile('replayer/log.lua')(function() return {} end)
local driver = dofile('replayer/driver.lua')(log)
G = {consumeables = {cards = {}, config = {card_limit = 3}}, jokers = {cards = {}, config = {card_limit = 5}}}
local eris = {cost = 3, ability = {name = 'Eris', consumeable = true, set = 'Planet'}, config = {center = {key = 'c_eris'}}, can_use_consumeable = function() return true end}
local buy = {kind='action', op='buy', args={'1','2'}, money={-3}, position=1, seq=271, human='boughtCardFromShop,card:Eris,cost:3'}
local use = {kind='action', op='use', args={'1'}, seq=293, human='usedCard,card:Eris'}
local entries = {buy,use}
assert(driver.purchase_mode(buy,eris,entries)=='buy')
driver.remember_purchase(buy,eris,entries)
assert(not driver.retry_purchase('shop_jokers slot 1 holds Earth, log says Mars'))
assert(driver.retry_purchase('shop_jokers slot 1 holds Earth, log says Eris'))
assert(driver.purchase_mode(buy,eris,entries)=='buy_and_use')
assert(not driver.retry_purchase('shop_jokers slot 1 holds Earth, log says Eris'), 'each alternative is tried once')
driver.reset_purchases(true)
assert(driver.purchase_mode(buy,eris,entries)=='buy_and_use', 'automatic restart retains the choice')
driver.reset_purchases()
assert(driver.purchase_mode(buy,eris,entries)=='buy', 'a new playback starts fresh')
eris.can_use_consumeable=function() return false end
driver.remember_purchase(buy,eris,entries)
assert(not driver.retry_purchase('shop_jokers slot 1 holds Earth, log says Eris'), 'an unusable card cannot be bought and used')
print('PASS: ambiguous consumable purchases can be retried once using later named-card evidence')
