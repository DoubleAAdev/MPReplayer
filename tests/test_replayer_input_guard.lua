-- Human dispatch is blocked; programmatic replay actions stay available.
local counts = {}
local function hit(name) counts[name] = (counts[name] or 0) + 1; return name end
local function count(name) return counts[name] or 0 end
local session = {phase = 'idle'}
Card = {}; Card.__index = Card
function Card:is(class) return class == Card end
function Card:click() self.selected = not self.selected; hit('card_click') end
function Card:drag() self.area.cards[1], self.area.cards[2] = self.area.cards[2], self.area.cards[1]; hit('drag') end
function Card:stop_drag() hit('stop_drag') end
function Card:release() hit('release') end
UIElement = {}
function UIElement:click() return G.FUNCS[self.config.button](self) end
UIBox = {init = function(self, args) self.definition = args.definition; return 'box' end}
Controller = {}; Controller.__index = Controller
function Controller:L_cursor_press() hit('press') end
function Controller:queue_R_cursor_press() hit('deselect') end
function Controller:capture_focused_input() hit('controller_reorder'); return true end
function Controller:key_press_update(key) hit('key_' .. key) end
function Controller:key_hold_update(key) hit('hold_' .. key) end
function Controller:key_release_update(key) hit('release_' .. key) end
function Controller:key_press(key) self.pressed_keys[key] = true end
function Controller:key_release(key) self.held_keys[key] = nil; self.released_keys[key] = true end
function Controller:button_press(button) hit('pad_press_' .. button) end
function Controller:button_release(button) hit('pad_release_' .. button) end
function Controller:set_gamepad() end
function Controller:set_HID_flags(kind) self.HID.touch = kind == 'touch' end
function Controller:queue_L_cursor_press() self:L_cursor_press() end
function Controller:L_cursor_release() hit('pointer_release') end
local controller = setmetatable({HID = {}, hovering = {}, focused = {}, cursor_hover = {}, locks = {}}, Controller)
G = {CONTROLLER = controller, UIT = {R = 'R', C = 'C', T = 'T'}, C = {WHITE = {}}, FUNCS = {}}
local gameplay = {'play_cards_from_highlighted', 'discard_cards_from_highlighted', 'use_card', 'sell_card',
    'buy_from_shop', 'reroll_shop', 'skip_booster', 'select_blind', 'skip_blind', 'mp_toggle_ready',
    'sort_hand_value', 'sort_hand_suit', 'cash_out', 'toggle_shop', 'start_setup_run', 'mp_unstuck'}
for _, name in ipairs(gameplay) do G.FUNCS[name] = function() return hit(name) end end
for _, name in ipairs({'options', 'exit_overlay_menu', 'mprpl_end', 'run_info', 'deck_info', 'change_tab'}) do
    G.FUNCS[name] = function() return hit(name) end
end
love = {}
for _, name in ipairs({'keypressed', 'keyreleased', 'mousepressed', 'mousereleased', 'gamepadpressed', 'gamepadreleased', 'wheelmoved'}) do
    love[name] = function() return hit('shortcut_' .. name) end
end
local guard = dofile('replayer/input-guard.lua')(session)
local function card_area()
    local area = {cards = {}}
    for i = 1, 2 do area.cards[i] = setmetatable({area = area, states = {drag = {is = false}}}, Card) end
    return area
end
local hand, jokers, consumables = card_area(), card_area(), card_area()
-- A drag and held restart key that predate Start Replay cannot leak through.
controller.dragging = {target = jokers.cards[1]}
controller.dragging.target.states.drag.is = true
controller.cursor_down = {target = jokers.cards[1], handled = false}
controller.clicked = {target = hand.cards[1], handled = false}
controller.held_keys = {r = true}; controller.held_key_times = {r = 10}
controller.L_cursor_queue = {x = 1, y = 2}
session.phase = 'joining'; guard.update()
assert(controller.dragging.target == nil and not jokers.cards[1].states.drag.is)
assert(controller.clicked.handled and controller.L_cursor_queue == nil and next(controller.held_keys) == nil)
assert(next(controller.locks) == nil, 'the guard must not set a controller lock that stalls the driver')
for _, phase in ipairs({'joining', 'starting', 'running', 'finished', 'failed', 'stopped'}) do
    session.phase = phase
    for _, area in ipairs({hand, jokers, consumables}) do
        local first = area.cards[1]
        first:click(); first:drag(); first:stop_drag(); first:release()
        controller.hovering.target, controller.focused.target, controller.cursor_hover.target = first, first, first
        controller.HID.touch = true
        controller:L_cursor_press(); controller:queue_R_cursor_press()
        assert(controller:capture_focused_input('dpright', 'press', 0.1) == false)
        assert(area.cards[1] == first and not first.selected, 'manual input changed the ' .. phase .. ' replay')
    end
    for _, name in ipairs(gameplay) do UIElement.click({config = {button = name}}); assert(count(name) == 0) end
    love.keypressed('r'); love.keypressed('tab'); love.keyreleased('r')
    love.mousepressed(0, 0, 2); love.wheelmoved(0, 1)
    controller:key_press_update('r'); controller:key_hold_update('r'); controller:key_release_update('r')
end
assert(count('drag') == 0 and count('stop_drag') == 0 and count('controller_reorder') == 0 and count('press') == 0)
assert(count('shortcut_keypressed') == 0 and count('shortcut_mousepressed') == 0 and count('shortcut_wheelmoved') == 0)
assert(count('key_r') == 0 and count('hold_r') == 0)
-- Menu access works through mouse, touch, keyboard and gamepad dispatch.
local options = {config = {button = 'options'}}
controller.hovering.target, controller.focused.target, controller.cursor_hover.target = options, options, options
love.mousepressed(1, 1, 1, true); assert(count('press') == 1)
love.mousereleased(1, 1, 1); assert(count('pointer_release') == 1)
love.keypressed('escape'); assert(controller.pressed_keys.escape)
controller:key_press_update('escape'); assert(count('key_escape') == 1)
love.gamepadpressed({}, 'start'); love.gamepadreleased({}, 'start')
assert(count('pad_press_start') == 1 and count('pad_release_start') == 1)
for _, name in ipairs({'options', 'exit_overlay_menu', 'mprpl_end', 'run_info', 'deck_info', 'change_tab'}) do
    assert(UIElement.click({config = {button = name}}) == name)
end
-- Every requested menu entry and Lobby Info works outside an overlay too.
for _, name in ipairs({'saturn_config', 'settings', 'mods_button', 'high_scores', 'your_collection', 'customize_deck', 'lobby_info'}) do
    G.FUNCS[name] = function() return hit(name) end
    assert(UIElement.click({config = {button = name}}) == name)
end
-- Submenus are permitted by ownership, including controls without a button.
G.OVERLAY_MENU = {}
G.FUNCS.mod_setting_toggle = function() return hit('mod_setting_toggle') end
local setting = {UIBox = G.OVERLAY_MENU, config = {button = 'mod_setting_toggle'}}
assert(UIElement.click(setting) == 'mod_setting_toggle')
controller.hovering.target, controller.cursor_hover.target = setting, setting
local presses = count('press')
controller:L_cursor_press(); assert(count('press') == presses + 1)
controller.focused.target = {UIBox = G.OVERLAY_MENU, config = {focus_args = {type = 'slider'}}}
assert(controller:capture_focused_input('dpright', 'press', 0.1) == true)
controller.text_input_hook = {UIBox = G.OVERLAY_MENU}
love.keypressed('a'); assert(controller.pressed_keys.a)
controller:key_press_update('a'); assert(count('key_a') == 1)
controller.text_input_hook = nil
love.wheelmoved(0, 1); assert(count('shortcut_wheelmoved') == 1)
-- Steamodded's scroll content has multiple embedded UIBoxes between gears
-- and the overlay. Config controls must work even after a replay failure.
local nested_box = {parent = {UIBox = {parent = {UIBox = G.OVERLAY_MENU}}}}
local nested_setting = {UIBox = nested_box, config = {button = 'mod_setting_toggle'}}
G.FUNCS.openModUI_TestMod = function() return hit('open_mod') end
local gear = {UIBox = nested_box, config = {button = 'openModUI_TestMod'}}
for _, phase in ipairs({'running', 'failed', 'finished'}) do
    session.phase = phase
    assert(UIElement.click(gear) == 'open_mod')
    assert(UIElement.click(nested_setting) == 'mod_setting_toggle')
    controller.hovering.target, controller.cursor_hover.target = gear, gear
    local before = count('press')
    controller:L_cursor_press(); assert(count('press') == before + 1)
    controller.focused.target = {UIBox = nested_box, config = {focus_args = {type = 'slider'}}}
    assert(controller:capture_focused_input('dpright', 'press', 0.1))
    controller.text_input_hook = {UIBox = nested_box}
    love.keypressed('b'); assert(controller.pressed_keys.b)
    controller:key_press_update('b')
end
controller.text_input_hook = nil
local attached = {role = {major = nested_box}, config = {button = 'openModUI_TestMod'}}
assert(UIElement.click(attached) == 'open_mod')
local loop = {}; loop.parent = loop
assert(UIElement.click({UIBox = loop, config = {button = 'openModUI_TestMod'}}) == nil)
nested_box.under_overlay = true
assert(UIElement.click(gear) == nil, 'covered nested menus remain blocked')
nested_box.under_overlay = nil
for _, name in ipairs(gameplay) do
    UIElement.click({UIBox = nested_box, config = {button = name}})
    assert(count(name) == 0, 'nested panels cannot unlock gameplay')
end
-- Restore the earlier baseline for the detached/closed menu checks below.
counts.mod_setting_toggle = 1
-- Start buttons must reach their guarded UI callbacks so they can explain
-- why another replay cannot start. They remain blocked outside menus.
for _, name in ipairs({'mprpl_start_listed', 'mprpl_start', 'mprpl_active_back'}) do
    G.FUNCS[name] = function() return hit(name) end
    assert(UIElement.click({UIBox = nested_box, config = {button = name}}) == name)
    assert(UIElement.click({UIBox = {}, config = {button = name}}) == nil)
end
-- An open menu must not unlock background actions or gameplay callbacks.
for _, name in ipairs(gameplay) do
    UIElement.click({UIBox = G.OVERLAY_MENU, config = {button = name}})
    assert(count(name) == 0, name .. ' escaped the gameplay lock')
end
UIElement.click({UIBox = {}, config = {button = 'mod_setting_toggle'}})
UIElement.click({UIBox = G.OVERLAY_MENU, under_overlay = true, config = {button = 'mod_setting_toggle'}})
assert(count('mod_setting_toggle') == 1)
local first = hand.cards[1]
first:drag(); first:click(); assert(hand.cards[1] == first and not first.selected)
G.OVERLAY_MENU = nil
UIElement.click(setting); assert(count('mod_setting_toggle') == 1, 'closed menus cannot grant access')
controller:key_press_update('r'); assert(count('key_r') == 0)

-- View Deck is a clickable card pile, not a UIElement button.
G.deck = card_area()
local deck_top = G.deck.cards[1]
local deck_views = count('deck_info')
controller.hovering.target, controller.cursor_hover.target, controller.focused.target = deck_top, deck_top, deck_top
for _, touch in ipairs({false, true}) do
    local before = count('press')
    controller.HID.touch = touch
    controller:L_cursor_press(); assert(count('press') == before + 1)
    deck_top:click()
end
assert(count('deck_info') == deck_views + 2 and not deck_top.selected)
deck_top:drag(); deck_top:stop_drag(); deck_top:release()
assert(G.deck.cards[1] == deck_top and count('drag') == 0)
assert(controller:capture_focused_input('dpright', 'press', 0.1) == false)
G.deck.cards[2]:click(); assert(count('deck_info') == deck_views + 2)
deck_top.under_overlay = true; deck_top:click()
assert(count('deck_info') == deck_views + 2, 'background deck cannot open through an overlay')
deck_top.under_overlay = nil

-- The same callbacks issued by the driver, and deferred effects, remain usable.
for _, name in ipairs(gameplay) do assert(G.FUNCS[name]({config = {}}) == name) end
local function button(name)
    return {n = 'R', nodes = {{n = 'C', config = {button = name, func = 'old_enable'}, nodes = {{n = 'T', config = {text = name}}}}}}
end
local function menu()
    return {n = 'ROOT', nodes = {{n = 'C', nodes = {
        [1] = button('options'), [3] = button('mp_unstuck'), [5] = button('mp_return_to_lobby'), [8] = button('lobby_leave'),
    }}}}
end
local function buttons(node, result)
    result = result or {}
    if node.config and node.config.button then result[#result + 1] = node.config.button end
    local keys = {}
    for key in pairs(node.nodes or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do buttons(node.nodes[key], result) end
    return result
end
local box = {}
assert(UIBox.init(box, {definition = menu()}) == 'box')
assert(table.concat(buttons(box.definition), ',') == 'options,mprpl_end,mprpl_restart')
local end_node = box.definition.nodes[1].nodes[2].nodes[1]
assert(end_node.nodes[1].config.text == 'End Replay' and end_node.config.func == nil)
-- Restart Replay is the row under it, the same button copied, so the two match
-- in size and font however the menu around them was built.
local end_row, restart_row = box.definition.nodes[1].nodes[2], box.definition.nodes[1].nodes[3]
local restart_node = restart_row.nodes[1]
assert(restart_row.n == end_row.n and restart_node.n == end_node.n)
assert(restart_node.config.button == 'mprpl_restart' and restart_node.nodes[1].config.text == 'Restart Replay')
assert(restart_node ~= end_node and restart_node.config ~= end_node.config, 'the copy shares nothing the game can mutate')
-- A screen containing only Leave Lobby still gets its exit. There is no row to
-- copy there, so it gets the exit alone rather than a button laid out wrong.
assert(table.concat(buttons(guard.rewrite(button('lobby_leave'))), ',') == 'mprpl_end')
-- Take Over gives a running replay the same freedom a normal game has.
session.unlocked = true; guard.update()
assert(next(controller.pressed_keys) == nil, 'held input does not cross into the hands of the player')
hand.cards[1]:click(); assert(count('card_click') == 1)
local used = count('use_card')
UIElement.click({config = {button = 'use_card'}}); assert(count('use_card') == used + 1, 'consumables work again')
assert(table.concat(buttons(guard.rewrite(menu())), ',') == 'options,mprpl_end,mprpl_restart',
    'the replay still owns the pause menu: no Unstuck and no lobby exits')
session.unlocked = false; guard.update()
UIElement.click({config = {button = 'use_card'}}); assert(count('use_card') == used + 1, 'handing back locks the controls again')

-- Normal games get their exact controls back, with no stale held input.
session.phase = 'idle'; guard.update()
assert(next(controller.pressed_keys) == nil)
local ordinary = menu(); assert(guard.rewrite(ordinary) == ordinary)
assert(table.concat(buttons(ordinary), ',') == 'options,mp_unstuck,mp_return_to_lobby,lobby_leave')
hand.cards[1]:click(); hand.cards[1]:drag(); assert(count('card_click') == 2 and count('drag') == 1)
love.keypressed('r'); assert(count('shortcut_keypressed') == 1)
UIElement.click({config = {button = 'sell_card'}}); assert(count('sell_card') == 2)
print('PASS: replay input isolation, queued drag cancellation, mouse/touch/keyboard/gamepad menus, lobby exit replacement and restored controls')
