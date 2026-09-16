-- Replayer wiring: config buttons, log loading, and the game hooks the
-- session needs (update, run start, main menu).
return function(mod, JSON)
    if not G or not G.FUNCS then return end
    local function load(name) return assert(SMODS.load_file('replayer/' .. name, mod.id))() end
    local json = require('json')
    local log = load('log.lua')(json.decode)
    local driver = load('driver.lua')(log)
    local session = load('session.lua')(log, driver, JSON, {
        clock = function() return love.timer.getTime() end,
        channel = function(name) return love.thread.getChannel(name) end,
        encode = json.encode,
    })
    -- Install after all mods have registered their input hooks.
    local input_guard
    local menu_hooked = false
    local function install_menu_hook()
        if menu_hooked or type(create_UIBox_mods) ~= 'function' then return end
        menu_hooked = true
        local original = create_UIBox_mods
        create_UIBox_mods = function(...)
            if G.ACTIVE_MOD_UI ~= mod then return original(...) end
            -- Keep Steamodded's native gear, but suppress its separate Config tab.
            local config_tab = mod.config_tab
            mod.config_tab = nil
            if SMODS.LAST_SELECTED_MOD_TAB == 'config' then
                SMODS.LAST_SELECTED_MOD_TAB = mod.id .. '_1'
            end
            local ok, result = pcall(original, ...)
            mod.config_tab = config_tab
            if not ok then error(result, 0) end
            return result
        end
    end
    local function guard()
        install_menu_hook()
        if not input_guard then input_guard = load('input-guard.lua')(session) end
        return input_guard
    end
    local pick_file = load('file-picker.lua')
    BalatroReplayer = session
    local limit = 16 * 1024 * 1024

    local function protect(fn, fatal)
        local ok, err = pcall(fn)
        if ok then return end
        local message = tostring(err):gsub('^.-:%d+: ', '')
        if fatal and session.phase ~= 'idle' then session.fail(message) else session.status('Replayer: ' .. message) end
    end

    local function show_replays()
        SMODS.LAST_SELECTED_MOD_TAB = mod.id .. '_1'
        local open = G.FUNCS['openModUI_' .. mod.id]
        if open then open() end
    end
    G.FUNCS.brpl_load = function()
        protect(function()
            assert(session.phase == 'idle', 'Finish the current replay before loading another log')
            local path = pick_file()
            if not path then return end
            local info = NFS.getInfo(path)
            assert(info and info.type == 'file' and info.size and info.size <= limit, 'Select a log file smaller than 16 MB')
            session.load(assert(NFS.read(path), 'Could not read the selected log'), path)
            show_replays()
        end)
    end
    local pending_confirmation
    local show_confirmation
    local function after_start()
        guard().update()
        if session.phase == 'idle' and session.confirmed then
            pending_confirmation = {run = session.confirmed, mods = session.confirmed_mods}
            -- Only the popup's Continue action may reuse this approval request.
            session.confirmed, session.confirmed_mods = nil, nil
            show_confirmation()
        elseif session.phase == 'idle' and G.OVERLAY_MENU then
            show_replays()
        end
    end
    G.FUNCS.brpl_start_listed = function(e)
        pending_confirmation = nil
        session.confirmed, session.confirmed_mods = nil, nil
        protect(function() session.start_listed(e.config.ref_table) end)
        after_start()
    end
    G.FUNCS.brpl_cancel_replay = function()
        pending_confirmation = nil
        session.confirmed, session.confirmed_mods = nil, nil
        session.status('Replay cancelled.')
        show_replays()
    end
    G.FUNCS.brpl_continue_replay = function()
        local pending = pending_confirmation
        pending_confirmation = nil
        if not pending or session.phase ~= 'idle' then return end
        if not session.runs or session.runs[session.index] ~= pending.run then
            session.status('Replay selection changed. Start again.')
            show_replays()
            return
        end
        session.confirmed, session.confirmed_mods = pending.run, pending.mods
        protect(session.start)
        after_start()
    end
    G.FUNCS.brpl_remove = function()
        protect(session.remove_run)
        guard().update()
    end
    G.FUNCS.brpl_next = function() protect(session.next_run) end
    G.FUNCS.brpl_start = function()
        pending_confirmation = nil
        session.confirmed, session.confirmed_mods = nil, nil
        protect(session.start)
        after_start()
    end
    local function change_log_page(delta)
        session.log_page(delta)
        if G.FUNCS['openModUI_' .. mod.id] then
            SMODS.LAST_SELECTED_MOD_TAB = mod.id .. '_1'
            G.FUNCS['openModUI_' .. mod.id]()
        end
    end
    G.FUNCS.brpl_log_prev = function() change_log_page(-1) end
    G.FUNCS.brpl_log_next = function() change_log_page(1) end
    G.FUNCS.brpl_mod_prev = function() session.mod_page(-1) end
    G.FUNCS.brpl_mod_next = function() session.mod_page(1) end
    G.FUNCS.brpl_end = function()
        if session.phase == 'idle' then return end
        protect(function()
            if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
            session.stop()
        end)
        guard().update()
    end
    G.FUNCS.brpl_stop = G.FUNCS.brpl_end

    local previous_drop = love.filedropped
    love.filedropped = function(file)
        if file:getFilename():lower():match('%.log$') then
            protect(function()
                assert(session.phase == 'idle', 'Finish the current replay before loading another log')
                assert(file:getSize() <= limit, 'Log exceeds 16 MB')
                file:open('r')
                local text = file:read()
                file:close()
                session.load(text, file:getFilename())
                if G.OVERLAY_MENU then show_replays() end
            end)
        elseif previous_drop then
            return previous_drop(file)
        end
    end

    local function pack(...) return {n = select('#', ...), ...} end
    local previous_update = Game.update
    function Game:update(dt)
        guard().update()
        local result = pack(previous_update(self, dt))
        protect(function() session.update(dt) end, true)
        return unpack(result, 1, result.n)
    end
    local previous_start = Game.start_run
    if previous_start then
        function Game:start_run(...)
            local result = pack(previous_start(self, ...))
            protect(session.on_run_started, true)
            return unpack(result, 1, result.n)
        end
    end
    local previous_menu = Game.main_menu
    if previous_menu then
        function Game:main_menu(...)
            protect(session.on_main_menu)
            guard().update()
            return previous_menu(self, ...)
        end
    end

    -- Native UIBox buttons use Balatro's font, shadows, sizing and focus rules.
    local function row(field, scale)
        return {n = G.UIT.R, config = {align = 'cm', padding = 0.025}, nodes = {
            {n = G.UIT.T, config = {ref_table = session, ref_value = field, scale = scale or 0.38, colour = G.C.WHITE, shadow = true}}}}
    end
    local function button(label, callback, width, colour)
        return UIBox_button{label = {label}, button = callback, minw = width or 3.1,
            minh = 0.65, scale = 0.42, colour = colour or G.C.BLUE, col = true}
    end
    local function buttons(left, right)
        return {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = {
            left, {n = G.UIT.C, config = {minw = 0.12}}, right}}
    end
    show_confirmation = function()
        local function message(text, scale)
            return {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = {
                {n = G.UIT.T, config = {text = text, scale = scale or 0.38, colour = G.C.WHITE, shadow = true}}}}
        end
        G.FUNCS.overlay_menu{definition = create_UIBox_generic_options{no_back = true, contents = {
            message('Mods differ', 0.55),
            message('Some mods may affect this replay.'),
            message('It may play differently or stop early.'),
            buttons(button('Cancel', 'brpl_cancel_replay'), button('Continue', 'brpl_continue_replay', nil, G.C.GREEN)),
        }}}
        -- Escape closes the popup without starting; a fresh Start always asks again.
    end
    G.FUNCS.brpl_details_back = show_replays
    G.FUNCS.brpl_details = function()
        session.refresh_mods()
        local rows = {
            {n = G.UIT.R, config = {align = 'cm', padding = 0.12}, nodes = {
                {n = G.UIT.T, config = {text = 'Compare Mods', scale = 0.55, colour = G.C.WHITE, shadow = true}}}},
            row('mod_overview', 0.44),
        }
        if session.mod_hint ~= '' then rows[#rows + 1] = row('mod_hint', 0.34) end
        if #session.mod_pages > 0 then
            rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.18, r = 0.12,
                colour = G.C.BLACK or G.C.CLEAR, minw = 6.3}, nodes = {
                {n = G.UIT.C, config = {align = 'cl', padding = 0.06}, nodes = {
                    row('mod_detail1', 0.4), row('mod_detail2', 0.38), row('mod_detail3', 0.38)}}}}
            if #session.mod_pages > 1 then
                rows[#rows + 1] = row('mod_position', 0.3)
                rows[#rows + 1] = buttons(button('Previous', 'brpl_mod_prev'), button('Next', 'brpl_mod_next'))
            end
        end
        G.FUNCS.overlay_menu{definition = create_UIBox_generic_options{back_func = 'brpl_details_back', contents = rows}}
    end
    mod.config_tab = function() return mod.extra_tabs()[1].tab_definition_function() end
    if SMODS.LAST_SELECTED_MOD_TAB == 'config' then SMODS.LAST_SELECTED_MOD_TAB = mod.id .. '_1' end
    local function text(value, scale, colour)
        return {n = G.UIT.T, config = {text = value, scale = scale or 0.32, colour = colour or G.C.WHITE, shadow = true}}
    end
    local function icon(atlas, pos, w, h, fallback)
        if Sprite and atlas then
            local sprite = Sprite(0, 0, w, h, atlas, pos or {x = 0, y = 0})
            sprite.states.drag.can, sprite.states.collide.can = false, false
            return {n = G.UIT.O, config = {object = sprite}}
        end
        return text(fallback, 0.28)
    end
    mod.extra_tabs = function()
        return {{label = 'Replays', tab_definition_function = function()
            session.log_page()
            local rows = {buttons(button('Load Log', 'brpl_load', 4.0), button('Compare Mods', 'brpl_details', 4.0)),
                row('log_filename', 0.38), row('log_count', 0.3)}
            local runs = session.log_runs or {}
            for slot = 1, 3 do
                local run = runs[(session.log_page_index - 1) * 3 + slot]
                if run then
                    local m = run.manifest
                    local deck = session.deck_center(m.deck)
                    local stake = ((G.P_CENTER_POOLS or {}).Stake or {})[m.stake]
                    local atlases = G.ASSET_ATLAS or {}
                    local _, multiplayer = session.game_type(m)
                    local names = session['log_game' .. slot]:gsub('^%d+%. ', '')
                    if not multiplayer then names = tostring(m.player or 'Unknown player'):sub(1, 30) end
                    rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cl', padding = 0.1, r = 0.12,
                        minw = 8.2, colour = G.C.BLACK or G.C.CLEAR}, nodes = {
                        {n = G.UIT.C, config = {align = 'cm', minw = 0.4}, nodes = {text(tostring(run.label_number) .. '.', 0.4)}},
                        {n = G.UIT.C, config = {align = 'cm', padding = 0.12}, nodes = {
                            icon(deck and atlases[deck.atlas or 'centers'], deck and deck.pos, 0.78, 1.06, '?')}},
                        {n = G.UIT.C, config = {align = 'cl', padding = 0.08, minw = 4.7}, nodes = {
                            {n = G.UIT.R, config = {align = 'cl'}, nodes = {text(names, 0.36)}},
                            {n = G.UIT.R, config = {align = 'cl', padding = 0.04}, nodes = {
                                icon(stake and atlases[stake.atlas or 'chips'], stake and stake.pos, 0.32, 0.32, '?'),
                                text(session.stake_name(m.stake), 0.3)}}}},
                        UIBox_button{label = {'Start Replay'}, button = 'brpl_start_listed', ref_table = run,
                            minw = 1.8, minh = 0.65, scale = 0.32, col = true, colour = G.C.GREEN or G.C.BLUE}

                    }}
                end
            end
            if #runs == 0 then rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm'}, nodes = {text('Load a log to see its games.')}} end
            if #runs > 3 then
                rows[#rows + 1] = row('log_position', 0.3)
                rows[#rows + 1] = buttons(button('Previous', 'brpl_log_prev'), button('Next', 'brpl_log_next'))
            end
            for _, field in ipairs({'line1', 'line2', 'line3', 'line4'}) do
                if not session.text:match('^Ready to replay') and session[field] ~= '' then
                    rows[#rows + 1] = row(field, 0.28)
                end
            end
            return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.12}, nodes = rows}
        end}}
    end
    return session
end
