-- Read-only, paginated diagnostics; opening a menu pauses replay execution.
return function(session, mod, JSON)
    local M, page, last_run = {}, nil, nil
    local function lines()
        local snapshot = session.debug_snapshot()
        local result, current_line = {}, 1
        local function add(value)
            value = tostring(value or ''):gsub('[%c]', ' ')
            repeat
                result[#result + 1] = value:sub(1, 64)
                value = value:sub(65)
            until value == ''
        end
        add('Status: ' .. snapshot.status)
        add('Game state: ' .. tostring(snapshot.state))
        if snapshot.failure then
            add('Error: ' .. snapshot.failure.message)
            add('Log line: ' .. tostring(snapshot.failure.line or 'unknown'))
        end
        if snapshot.run then add('Seed: ' .. snapshot.run.manifest.seed) end
        add('--- Actions and network events ---')
        for index, entry in ipairs(snapshot.entries) do
            if index == snapshot.cursor then current_line = #result + 1 end
            local marker = index < snapshot.cursor and 'DONE' or index == snapshot.cursor and 'NEXT' or 'WAIT'
            if index == snapshot.cursor and snapshot.issued then marker = 'SENT' end
            local detail = entry.kind == 'action' and ('Action ' .. tostring(entry.seq) .. ': ' .. entry.text .. (entry.dollars and (' $' .. entry.dollars) or ''))
                or ('Event: ' .. tostring(entry.action) .. ' ' .. JSON.encode(entry.fields or {}))
            add(marker .. ' | line ' .. tostring(entry.line or '?') .. ' | ' .. detail)
        end
        if snapshot.cursor > #snapshot.entries then current_line = math.max(1, #result) end
        return result, snapshot, current_line
    end
    function M.definition()
        local all, snapshot, current = lines()
        if last_run ~= snapshot.run then page, last_run = nil, snapshot.run end
        local pages = math.max(1, math.ceil(#all / 9))
        page = math.max(1, math.min(page or math.ceil(current / 9), pages))
        local function row(value, scale)
            return {n = G.UIT.R, config = {align = 'cl', padding = 0.04}, nodes = {
                {n = G.UIT.T, config = {text = value, scale = scale or 0.28, colour = G.C.WHITE, shadow = true}}}}
        end
        local rows = {row('Debug  |  ' .. snapshot.phase .. '  |  ' .. snapshot.done .. '/' ..
            tostring(snapshot.run and snapshot.run.actions or 0) .. ' actions', 0.4)}
        for index = (page - 1) * 9 + 1, math.min(page * 9, #all) do rows[#rows + 1] = row(all[index]) end
        rows[#rows + 1] = row('Page ' .. page .. ' of ' .. pages, 0.3)
        local controls = {}
        for _, control in ipairs({{'Previous', 'prev'}, {'Current action', 'current'}, {'Next', 'next'}}) do
            controls[#controls + 1] = UIBox_button{label = {control[1]}, button = 'mprpl_debug_' .. control[2],
                minw = 2.2, minh = 0.6, scale = 0.34, colour = G.C.BLUE, col = true}
        end
        rows[#rows + 1] = {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = controls}
        return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR, padding = 0.15, minw = 8}, nodes = rows}
    end
    local function navigate(delta)
        if session.phase == 'idle' then return end
        if delta then page = (page or 1) + delta else page = nil end
        SMODS.LAST_SELECTED_MOD_TAB = mod.id .. '_1'
        local open = G.FUNCS['openModUI_' .. mod.id]
        if open then open() end
    end
    G.FUNCS.mprpl_debug_prev = function() navigate(-1) end
    G.FUNCS.mprpl_debug_next = function() navigate(1) end
    G.FUNCS.mprpl_debug_current = function() navigate() end
    return M
end
