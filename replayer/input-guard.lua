-- Guard human input at its dispatch boundaries. The replay driver and queued
-- game effects still call the original gameplay callbacks directly.
return function(session)
    local M = {}
    local function active() return session.phase ~= 'idle' end
    M.active = active
    local safe_buttons = {
        options = true, exit_overlay_menu = true, brpl_end = true,
        run_info = true, deck_info = true, change_tab = true, lobby_info = true,
        saturn_config = true, settings = true, mods_button = true,
        high_scores = true, your_collection = true, customize_deck = true,
        brpl_mod_prev = true, brpl_mod_next = true,
    }
    local exits = {mp_return_to_lobby = true, lobby_leave = true}
    local function is_card(node)
        return node and Card and (getmetatable(node) == Card or (node.is and node:is(Card)))
    end
    local function deck_view_target(node)
        return is_card(node) and G.deck and node.area == G.deck
            and G.deck.cards and G.deck.cards[1] == node and not node.under_overlay
    end
    local gameplay_buttons = {
        play_cards_from_highlighted = true, discard_cards_from_highlighted = true,
        use_card = true, sell_card = true, buy_from_shop = true, buy_and_use = true,
        reroll_shop = true, skip_booster = true, select_blind = true, skip_blind = true,
        mp_toggle_ready = true, sort_hand_value = true, sort_hand_suit = true,
        cash_out = true, toggle_shop = true, start_setup_run = true, setup_run = true,
        start_run = true, go_to_menu = true, mp_unstuck = true, mp_unstuck_blind = true,
        mp_unstuck_arcana = true, lobby_leave = true, mp_return_to_lobby = true,
        lobby_choose_deck = true, brpl_start = true, brpl_load = true, brpl_next = true,
    }
    local function in_overlay(node)
        return G.OVERLAY_MENU ~= nil and node and node.UIBox == G.OVERLAY_MENU and not node.under_overlay
    end
    local function editing_text(controller)
        return controller and in_overlay(controller.text_input_hook)
    end
    local function safe_node(node)
        if not node then return false end
        if is_card(node) then return deck_view_target(node) end
        local config = node.config or {}
        if gameplay_buttons[config.button] then return false end
        -- Overlay ownership admits settings, mod pages, tabs, toggles, sliders,
        -- and their navigation without admitting the gameplay UI behind them.
        return safe_buttons[config.button] == true or in_overlay(node)
    end
    local function hook(object, name, wrapper)
        if object and type(object[name]) == 'function' then
            local original = object[name]
            object[name] = function(...) return wrapper(original, ...) end
        end
    end

    -- Cancel input queued before starting and any stale drag without invoking
    -- stop_drag, which would commit the player's reordered cards.
    function M.clear_pending(controller)
        if not controller then return end
        for _, field in ipairs({'dragging', 'cursor_down', 'cursor_up', 'clicked', 'released_on'}) do
            local state = controller[field]
            if state then
                if is_card(state.target) and state.target.states and state.target.states.drag then
                    state.target.states.drag.is = false
                end
                state.target, state.prev_target, state.handled = nil, nil, true
            end
        end
        controller.L_cursor_queue, controller.is_cursor_down = nil, false
        for _, field in ipairs({'pressed_keys', 'released_keys', 'held_keys', 'held_key_times',
            'pressed_buttons', 'released_buttons', 'held_buttons', 'held_button_times'}) do
            controller[field] = {}
        end
    end
    local was_active = false
    function M.update()
        local now_active = active()
        if now_active ~= was_active then M.clear_pending(G.CONTROLLER) end
        was_active = now_active
    end

    hook(Card, 'click', function(original, self, ...)
        if active() then
            -- The deck pile is the game's View Deck control. Open its read-only
            -- view directly without invoking card-selection or mod click hooks.
            if deck_view_target(self) then return G.FUNCS.deck_info() end
            return
        end
        return original(self, ...)
    end)
    for _, name in ipairs({'drag', 'stop_drag', 'release'}) do
        hook(Card, name, function(original, self, ...)
            if active() then return end
            return original(self, ...)
        end)
    end
    hook(UIElement, 'click', function(original, self, ...)
        if active() and not safe_node(self) then return end
        return original(self, ...)
    end)
    hook(Controller, 'L_cursor_press', function(original, self, ...)
        local target = (self.HID.touch and self.cursor_hover.target) or self.hovering.target or self.focused.target
        if active() and not safe_node(target) then return end
        return original(self, ...)
    end)
    hook(Controller, 'queue_R_cursor_press', function(original, self, ...)
        if active() then return end
        return original(self, ...)
    end)
    hook(Controller, 'capture_focused_input', function(original, self, ...)
        if active() and (is_card(self.focused.target) or not safe_node(self.focused.target)) then return false end
        return original(self, ...)
    end)
    hook(Controller, 'key_press_update', function(original, self, key, ...)
        if active() and key ~= 'escape' and not editing_text(self) then return end
        return original(self, key, ...)
    end)
    for _, name in ipairs({'key_hold_update', 'key_release_update'}) do
        hook(Controller, name, function(original, self, ...)
            if active() then return end
            return original(self, ...)
        end)
    end

    -- Route physical input straight to the controller during replays, bypassing
    -- shortcut mods that may execute an action before the normal input handler.
    hook(love, 'keypressed', function(original, key, ...)
        if not active() then return original(key, ...) end
        if key == 'escape' or editing_text(G.CONTROLLER) then G.CONTROLLER:key_press(key) end
    end)
    hook(love, 'keyreleased', function(original, key, ...)
        if not active() then return original(key, ...) end
        G.CONTROLLER:key_release(key)
    end)
    hook(love, 'mousepressed', function(original, x, y, button, touch, ...)
        if not active() then return original(x, y, button, touch, ...) end
        G.CONTROLLER:set_HID_flags(touch and 'touch' or 'mouse')
        if button == 1 then G.CONTROLLER:queue_L_cursor_press(x, y) end
    end)
    hook(love, 'mousereleased', function(original, x, y, button, ...)
        if not active() then return original(x, y, button, ...) end
        if button == 1 then G.CONTROLLER:L_cursor_release(x, y) end
    end)
    hook(love, 'wheelmoved', function(original, ...)
        if active() and not G.OVERLAY_MENU then return end
        return original(...)
    end)
    for _, event in ipairs({'pressed', 'released'}) do
        hook(love, 'gamepad' .. event, function(original, joystick, button, ...)
            if not active() then return original(joystick, button, ...) end
            button = (G.button_mapping or {})[button] or button
            G.CONTROLLER:set_gamepad(joystick)
            G.CONTROLLER:set_HID_flags('button', button)
            if event == 'pressed' then G.CONTROLLER:button_press(button)
            else G.CONTROLLER:button_release(button) end
        end)
    end

    -- Transform the final UI definition, including Multiplayer's patched pause
    -- menu and its game-over screen. One End Replay replaces both lobby exits.
    function M.rewrite(definition)
        if not active() then return definition end
        local end_added = false
        local function visit(node)
            if type(node) ~= 'table' then return node end
            local config = node.config or {}
            if config.button == 'mp_unstuck' then return nil end
            if exits[config.button] then
                if end_added then return nil end
                end_added = true
                config.button, config.func, config.id = 'brpl_end', nil, 'brpl_end'
                local label = node.nodes and node.nodes[1] and node.nodes[1].config or {}
                node.nodes = {{n = G.UIT.R, config = {align = 'cm', minw = label.minw or config.minw or 4, maxw = label.maxw}, nodes = {
                    {n = G.UIT.T, config = {text = 'End Replay', scale = 0.4, colour = G.C.WHITE}}}}}
                return node
            end
            if node.nodes then
                local keys, children = {}, {}
                for key in pairs(node.nodes) do if type(key) == 'number' then keys[#keys + 1] = key end end
                table.sort(keys)
                for _, key in ipairs(keys) do
                    local child = visit(node.nodes[key])
                    if child then children[#children + 1] = child end
                end
                if #keys > 0 and #children == 0 then return nil end
                node.nodes = children
            end
            return node
        end
        return visit(definition)
    end
    hook(UIBox, 'init', function(original, self, args, ...)
        if active() and args and args.definition then args.definition = M.rewrite(args.definition) end
        return original(self, args, ...)
    end)
    return M
end
