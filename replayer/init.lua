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
            session.load(assert(NFS.read(path), 'Could not read the selected log'))
        end)
    end
    G.FUNCS.brpl_next = function() protect(session.next_run) end
    G.FUNCS.brpl_start = function()
        protect(session.start)
        guard().update()
    end
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
                session.load(text)
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

    local previous_tab = mod.config_tab
    mod.config_tab = function()
        local tab = previous_tab and previous_tab() or {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.2}, nodes = {}}
        for _, line in ipairs({'line1', 'line2', 'line3', 'line4'}) do
            tab.nodes[#tab.nodes + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.02}, nodes = {
                {n = G.UIT.T, config = {ref_table = session, ref_value = line, scale = 0.26, colour = G.C.WHITE}}}}
        end
        local buttons = {}
        for _, item in ipairs({{'Load Log', 'brpl_load'}, {'Next Run', 'brpl_next'}, {'Start Replay', 'brpl_start'}, {'End Replay', 'brpl_end'}}) do
            buttons[#buttons + 1] = {n = G.UIT.C, config = {align = 'cm', button = item[2], colour = G.C.BLUE, padding = 0.12, r = 0.1, hover = true, shadow = true},
                nodes = {{n = G.UIT.T, config = {text = item[1], scale = 0.28, colour = G.C.WHITE}}}}
        end
        tab.nodes[#tab.nodes + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = buttons}
        for _, field in ipairs({'mod_summary', 'mod_detail1', 'mod_detail2', 'mod_detail3'}) do
            tab.nodes[#tab.nodes + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.02}, nodes = {
                {n = G.UIT.T, config = {ref_table = session, ref_value = field, scale = 0.24, colour = G.C.WHITE}}}}
        end
        local navigation = {}
        for _, item in ipairs({{'<', 'brpl_mod_prev'}, {'>', 'brpl_mod_next'}}) do
            navigation[#navigation + 1] = {n = G.UIT.C, config = {align = 'cm', button = item[2], colour = G.C.BLUE, padding = 0.08, r = 0.1, hover = true},
                nodes = {{n = G.UIT.T, config = {text = item[1], scale = 0.26, colour = G.C.WHITE}}}}
        end
        table.insert(navigation, 2, {n = G.UIT.C, config = {align = 'cm', padding = 0.08}, nodes = {
            {n = G.UIT.T, config = {ref_table = session, ref_value = 'mod_position', scale = 0.24, colour = G.C.WHITE}}}})
        tab.nodes[#tab.nodes + 1] = {n = G.UIT.R, config = {align = 'cm'}, nodes = navigation}
        return tab
    end
    return session
end
