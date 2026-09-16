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
    local function guard()
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

    G.FUNCS.brpl_load = function()
        protect(function()
            assert(session.phase == 'idle', 'Finish the current replay before loading another log')
            local path = pick_file()
            if not path then return end
            local info = NFS.getInfo(path)
            assert(info and info.type == 'file' and info.size and info.size <= limit, 'Select a log file smaller than 16 MB')
            session.load(assert(NFS.read(path), 'Could not read the selected log'), path)
        end)
    end
    G.FUNCS.brpl_remove = function()
        protect(session.remove_run)
        guard().update()
    end
    G.FUNCS.brpl_next = function() protect(session.next_run) end
    G.FUNCS.brpl_start = function()
        protect(session.start)
        guard().update()
    end
    G.FUNCS.brpl_log_prev = function() session.log_page(-1) end
    G.FUNCS.brpl_log_next = function() session.log_page(1) end
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
    G.FUNCS.brpl_details_back = function()
        G.FUNCS.overlay_menu{definition = create_UIBox_generic_options{
            back_func = 'openModUI_' .. mod.id, contents = {mod.config_tab()}}}
    end
    G.FUNCS.brpl_details = function()
        session.refresh_mods()
        local rows = {
            {n = G.UIT.R, config = {align = 'cm', padding = 0.12}, nodes = {
                {n = G.UIT.T, config = {text = 'Compare Replay Mods', scale = 0.55, colour = G.C.WHITE, shadow = true}}}},
            row('replay_title', 0.4),
            row('mod_missing'), row('mod_extra'), row('mod_versions'),
        }
        if session.mod_missing == '' then rows[#rows + 1] = row('mod_summary') end
        rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.12}, nodes = {
            {n = G.UIT.T, config = {text = 'Recorded in log / Loaded in this game', scale = 0.35, colour = G.C.WHITE}}}}
        for _, field in ipairs({'mod_detail1', 'mod_detail2', 'mod_detail3', 'mod_position'}) do rows[#rows + 1] = row(field) end
        rows[#rows + 1] = buttons(button('Previous', 'brpl_mod_prev'), button('Next', 'brpl_mod_next'))
        G.FUNCS.overlay_menu{definition = create_UIBox_generic_options{back_func = 'brpl_details_back', contents = rows}}
    end
    mod.config_tab = function()
        session.label_run()
        local rows = {row('replay_title', 0.42), row('replay_players', 0.38), row('replay_setup', 0.36), row('replay_seed', 0.32)}
        for _, field in ipairs({'line1', 'line2', 'line3', 'line4'}) do rows[#rows + 1] = row(field, 0.32) end
        rows[#rows + 1] = buttons(button('Load Log', 'brpl_load'), button('Next Replay', 'brpl_next'))
        rows[#rows + 1] = buttons(button('Start Replay', 'brpl_start', nil, G.C.GREEN), button('Remove Replay', 'brpl_remove', nil, G.C.RED))
        rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = {button('Compare Replay Mods', 'brpl_details', 6.3)}}
        rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm'}, nodes = {
            {n = G.UIT.T, config = {text = 'Remove clears the selection from the list only.', scale = 0.28, colour = G.C.WHITE}}}}
        return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.12}, nodes = rows}
    end
    mod.extra_tabs = function()
        return {{label = 'Log Info', tab_definition_function = function()
            session.log_page()
            local rows = {row('log_filename', 0.4), row('log_count', 0.34)}
            for slot = 1, 3 do
                rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.12}, nodes = {
                    {n = G.UIT.C, config = {align = 'cm', padding = 0.06}, nodes = {
                        row('log_game' .. slot, 0.36), row('log_setup' .. slot, 0.32)}}}}
            end
            rows[#rows + 1] = row('log_position', 0.32)
            rows[#rows + 1] = buttons(button('Previous', 'brpl_log_prev'), button('Next', 'brpl_log_next'))
            return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.12}, nodes = rows}
        end}}
    end
    return session
end
