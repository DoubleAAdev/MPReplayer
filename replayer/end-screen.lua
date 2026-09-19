-- Replay-only replacement for Multiplayer's result screen. Native games pass through.
return function(session, show_replays, after_start)
    local M, pending, shown, hooked = {}, nil, nil, false
    -- Frames the main menu must hold still before a restart begins.
    local SETTLE = 45
    local function clean(value, limit)
        local s = tostring(value or 'Unknown'):gsub('[%c]', ' ')
        return #s > limit and (s:sub(1, limit - 3) .. '...') or s
    end
    local function text(value, scale, colour)
        return {n = G.UIT.T, config = {text = value, scale = scale or 0.36,
            colour = colour or G.C.WHITE, shadow = true}}
    end
    local function row(nodes, align, padding)
        return {n = G.UIT.R, config = {align = align or 'cm', padding = padding or 0.08}, nodes = nodes}
    end
    local function sprite(center, atlas, w, h, fallback)
        local asset = center and (G.ASSET_ATLAS or {})[center.atlas or atlas]
        if not Sprite or not asset then return text(fallback, 0.34) end
        local object = Sprite(0, 0, w, h, asset, center.pos or {x = 0, y = 0})
        object.states.drag.can, object.states.collide.can = false, false
        return {n = G.UIT.O, config = {object = object}}
    end
    local function button(label, callback, colour, width)
        return UIBox_button{label = {label}, button = callback, colour = colour,
            minw = width or 3.35, minh = 0.7, scale = 0.4, col = true}
    end
    local function names(run)
        local m, lobby = run.manifest, run.lobby or {}
        local is_host = m.is_host
        if is_host == nil then is_host = lobby.is_host end
        local player, opponent = m.player, m.opponent
        if is_host ~= nil then
            player = player or (is_host and lobby.host or lobby.guest)
            opponent = opponent or (is_host and lobby.guest or lobby.host)
        end
        return clean(player and player:gsub('~%d+$', '') or 'Unknown player', 24),
            clean(opponent and opponent:gsub('~%d+$', '') or 'Unknown opponent', 24)
    end
    function M.definition(run)
        local m = run.manifest
        local player, opponent = names(run)
        local deck = session.deck_center(m.deck)
        local stake = ((G.P_CENTER_POOLS or {}).Stake or {})[m.stake]
        local rows = {row({text('Replay Ended', 0.68, G.C.GOLD or G.C.ORANGE)}),
            row({text('Thanks for watching!', 0.32)})}
        rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.2,
            r = 0.15, colour = G.C.BLACK, minw = 7}, nodes = {
            {n = G.UIT.C, config = {align = 'cm', padding = 0.18}, nodes = {
                sprite(deck, 'centers', 1.15, 1.56, 'Deck unavailable')}},
            {n = G.UIT.C, config = {align = 'cl', padding = 0.08, minw = 4.7}, nodes = {
                row({text(clean(session.deck_name(m), 30), 0.42)}, 'cl'),
                row({sprite(stake, 'chips', 0.4, 0.4, ''), text(session.stake_name(m.stake), 0.36)}, 'cl'),
                row({text('Seed: ' .. clean(m.seed, 28), 0.34)}, 'cl'),
            }}
        }}
        local winner, loser
        if run.result == 'win' then winner, loser = player, opponent
        elseif run.result == 'loss' then winner, loser = opponent, player end
        if winner then
            local function result_card(label, name, colour)
                return {n = G.UIT.C, config = {align = 'cm', padding = 0.12, r = 0.12,
                    colour = G.C.BLACK, minw = 3.35}, nodes = {
                    row({text(label, 0.3, colour)}), row({text(name, 0.36)})}}
            end
            rows[#rows + 1] = row({text('Recorded result', 0.28)})
            rows[#rows + 1] = row({result_card('WINNER', winner, G.C.GREEN),
                {n = G.UIT.C, config = {minw = 0.15}}, result_card('LOSER', loser, G.C.RED)})
        else
            rows[#rows + 1] = row({text(player .. ' vs ' .. opponent, 0.32)})
            rows[#rows + 1] = row({text('Result not recorded', 0.38, G.C.ORANGE)})
        end
        if session.phase == 'failed' then
            rows[#rows + 1] = row({text('Playback stopped before the log ended.', 0.3, G.C.ORANGE)})
        elseif not run.complete then
            rows[#rows + 1] = row({text('End of the available recording', 0.3, G.C.ORANGE)})
        end
        rows[#rows + 1] = row({button('Restart Replay', 'mprpl_restart', G.C.GREEN),
            {n = G.UIT.C, config = {minw = 0.15}}, button('Replays', 'mprpl_replays', G.C.BLUE)})
        rows[#rows + 1] = row({button('Main Menu', 'mprpl_main_menu', G.C.RED, 6.9)})
        return create_UIBox_generic_options{no_back = true, no_esc = true, contents = rows}
    end
    local function leave(destination)
        local run = session.active_run()
        if not run or pending then return end
        -- Multiplayer owns the asynchronous return to the main menu. Wait for
        -- session cleanup before restarting or opening the mod's Replays tab.
        pending = {destination = destination, run = run}
        if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
        session.stop()
    end
    G.FUNCS.mprpl_restart = function() leave('restart') end
    G.FUNCS.mprpl_replays = function() leave('replays') end
    G.FUNCS.mprpl_main_menu = function() leave('menu') end
    function M.install()
        if hooked or not (MP and MP.UI and type(MP.UI.create_UIBox_mp_game_end) == 'function') then return end
        hooked = true
        local original = MP.UI.create_UIBox_mp_game_end
        MP.UI.create_UIBox_mp_game_end = function(...)
            local run = session.active_run()
            if not run or session.phase == 'stopped' then return original(...) end
            session.end_screen_reached()
            shown = run
            return M.definition(run)
        end
    end
    function M.update()
        if pending and session.phase == 'idle' and G.STAGE == G.STAGES.MAIN_MENU then
            -- Multiplayer leaves the lobby over several frames and resets the
            -- lobby options on its way out. A replay started into that teardown
            -- has its deck and rules wiped from under it and the run begins on
            -- the default deck, so the menu has to settle first, the way the
            -- replay waits for it before starting a run.
            if pending.destination == 'restart' then
                local wiping = ((G.CONTROLLER or {}).locks or {}).wipe
                if G.OVERLAY_MENU or wiping then pending.settling = nil; return end
                pending.settling = (pending.settling or 0) + 1
                if pending.settling < SETTLE then return end
            end
            local next_action = pending
            pending, shown = nil, nil
            if next_action.destination == 'restart' then
                -- Whatever the player confirmed to start this run stands for
                -- restarting it; asking the same question twice is noise.
                session.start_listed(next_action.run)
                after_start()
            elseif next_action.destination == 'replays' then
                show_replays()
            end
            return
        end
        local run = session.active_run()
        if not run then shown = nil; return end
        -- Partial logs may finish without generating Multiplayer's game-over UI.
        if session.phase == 'finished' and shown ~= run and not G.OVERLAY_MENU then
            shown = run
            G.FUNCS.overlay_menu{definition = M.definition(run), config = {no_esc = true}}
        end
    end
    return M
end
