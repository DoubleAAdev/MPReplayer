-- Reads a Lovely log into replayable runs.
--
-- The actions are filtered out of the log the way the player's own filter
-- script does it: every "MP_RLOG:" line that is not a "Client" line, except
-- set_ante_key. Those actions, in log order, are what a replay executes and
-- all it executes. set_ante_key is left out because it is not something the
-- player did: Multiplayer rolls a throwaway key when a blind is selected so
-- the ante cannot be raised twice at once, and its value changes no card.
--
-- Two other kinds of line are kept, neither of them executed:
--   * "Client sent message: action:<...>"     names the card, cost or blind an
--     action touched. In the shop "use 1" can mean a consumable, a pack or a
--     voucher, and Buy and Buy & Use are logged alike; this line and the
--     money after an action are the only record of which one it was.
--   * "Client got <action> message: (k: v)"   what the opponent and server
--     sent. A PvP blind cannot start or end without them, so they are handed
--     back to Multiplayer where the log has them.
--
-- A run ends at its END line. The player's script stops at the first
-- "LONG DT", but Balatro prints that for any slow frame, before a game as
-- well as in the middle of one.
return function(decode)
    local M = {}

    -- Actions with a positional argument list, and how many tokens each takes.
    local arity = {
        play = {1, 1}, discard = {1, 1}, buy = {2, 2}, sell = {2, 2}, reroll = {0, 0},
        use = {1, 2}, pack_pick = {1, 2}, pack_skip = {1, 1}, reorder = {2, 2},
        select_blind = {1, 1}, skip_blind = {1, 1}, open_pack = {2, 2}, voucher = {2, 2},
        ready_blind = {1, 1}, set_ante_key = {1, 1},
        net_asteroid = {0, 0}, net_pizza = {1, 1}, net_magnet = {0, 0},
        net_phantom_add = {1, 1}, net_phantom_remove = {1, 1},
    }
    M.arity = arity
    -- Actions that Multiplayer mirrors with a human-readable line.
    local mirrored = {
        play = true, discard = true, buy = true, sell = true, reroll = true, use = true,
        pack_pick = true, pack_skip = true, reorder = true, select_blind = true, skip_blind = true,
        open_pack = true, voucher = true, net_asteroid = true, net_pizza = true, net_magnet = true,
        net_phantom_add = true, net_phantom_remove = true,
    }
    -- Messages the game emits itself once the run is going. Everything else
    -- the server sent during the game is delivered again during the replay.
    local not_delivered = {
        connected = true, version = true, disconnected = true, reconnecting = true, error = true,
        keepAlive = true, keepAliveAck = true, dataSync = true,
        joinedLobby = true, rejoinedLobby = true, lobbyInfo = true, lobbyOptions = true,
        enemyDisconnected = true, enemyReconnected = true, startGame = true, stopGame = true,
    }
    -- Multiplayer prints every value with %s, so types are recovered from the
    -- key: these are numbers in the wire format, everything else stays text
    -- ("score" is a string the mod parses digit by digit, and a username or
    -- seed can look numeric).
    local numeric = {
        lives = true, handsLeft = true, skips = true, amount = true, time = true, pos = true,
        whole = true, timeout = true, timer = true, stake = true, reroll_count = true,
        reroll_cost_total = true, furthestBlind = true, ante = true,
    }

    function M.indices(text)
        assert(type(text) == 'string' and text:match('^%d+[%.%d]*$') and not text:find('%.%.') and text:sub(-1) ~= '.',
            'Invalid card positions "' .. tostring(text) .. '"')
        local out, seen = {}, {}
        for item in text:gmatch('%d+') do
            local n = tonumber(item)
            assert(n >= 1 and n <= 1000 and not seen[n], 'Invalid or duplicate card position ' .. item)
            seen[n] = true
            out[#out + 1] = n
        end
        return out
    end

    local function validate_action(op, tokens)
        local range = assert(arity[op], 'Unsupported action "' .. tostring(op) .. '"')
        assert(#tokens >= range[1] and #tokens <= range[2], 'Invalid arguments for ' .. op)
        if op == 'play' or op == 'discard' then
            M.indices(tokens[1])
        elseif op == 'reorder' then
            assert(tokens[1] == '4' or tokens[1] == '6', 'Invalid reorder area ' .. tokens[1])
            M.indices(tokens[2])
        elseif op == 'buy' or op == 'sell' or op == 'open_pack' or op == 'voucher' then
            assert(tokens[1]:match('^[1-7]$'), 'Invalid area ' .. tokens[1])
            assert(#M.indices(tokens[2]) == 1, 'Invalid slot ' .. tokens[2])
        elseif op == 'use' or op == 'pack_pick' then
            assert(#M.indices(tokens[1]) == 1, 'Invalid slot ' .. tokens[1])
            if tokens[2] then M.indices(tokens[2]) end
        elseif op == 'set_ante_key' then
            assert(tonumber(tokens[1]), 'Invalid ante key')
        elseif op == 'ready_blind' then
            assert(tokens[1] == '0' or tokens[1] == '1', 'Invalid ready state')
        elseif op == 'net_pizza' then
            assert(tonumber(tokens[1]), 'Invalid pizza discards')
        elseif op == 'pack_skip' or op == 'select_blind' or op == 'skip_blind' then
            assert(tokens[1] == '0', 'Invalid argument for ' .. op)
        end
    end

    -- "Client got enemyInfo message:  (skips: 0)  (lives: 4)" -> table
    function M.message_fields(action, rest)
        local fields = {action = action}
        for key, value in rest:gmatch('%((%w+):%s*([^)]*)%)') do
            value = value:match('^%s*(.-)%s*$')
            if key ~= 'action' then
                if value == 'true' then fields[key] = true
                elseif value == 'false' then fields[key] = false
                elseif numeric[key] and tonumber(value) then fields[key] = tonumber(value)
                else fields[key] = value end
            end
        end
        return fields
    end

    local function parse_manifest(payload)
        local manifest = decode(payload)
        assert(type(manifest) == 'table', 'Invalid manifest')
        for _, key in ipairs({'seed', 'deck', 'ruleset', 'gamemode'}) do
            assert(type(manifest[key]) == 'string' and #manifest[key] > 0, 'Manifest missing ' .. key)
        end
        if type(manifest.lobby_config) ~= 'table' then manifest.lobby_config = {} end
        manifest.stake = tonumber(manifest.stake) or tonumber(manifest.lobby_config.stake)
        assert(manifest.stake and manifest.stake >= 1 and manifest.stake % 1 == 0, 'Manifest missing stake')
        return manifest
    end

    -- Returns the runs found in the text. Each run holds the manifest, the
    -- entries to replay in log order (actions and delivered messages) and the
    -- lobby names seen before the game started.
    function M.parse(text)
        assert(type(text) == 'string' and #text <= 16 * 1024 * 1024, 'Log exceeds 16 MB')
        local runs, run, lobby, pending, paying, number = {}, nil, nil, nil, nil, 0
        for line in (text .. '\n'):gmatch('(.-)\r?\n') do
            number = number + 1
            -- The filter: an MP_RLOG line that is not a Client line. Matching the
            -- tag right after the channel name is what keeps Client lines out -
            -- they carry copies of MP_RLOG text inside their JSON - without
            -- dropping a manifest whose player happens to be named "Client".
            local payload = line:match('^MP_RLOG: (.*)$') or line:match(':: MULTIPLAYER :: MP_RLOG: (.*)$')
            if payload then
                if payload:match('^MANIFEST ') then
                    run = {manifest = parse_manifest(payload:sub(10)), manifest_text = payload:sub(10), entries = {}, actions = 0, seq = 0,
                        complete = false, lobby = lobby, line = number}
                    runs[#runs + 1] = run
                    pending, paying = nil, nil
                elseif payload:match('^END ') then
                    assert(run, 'END without a manifest')
                    local ok, outcome = pcall(decode, payload:sub(5))
                    run.complete = true
                    run.result = ok and type(outcome) == 'table' and outcome.result or nil
                    run = nil
                    pending, paying = nil, nil
                elseif not payload:match('^CHK ') then
                    assert(run, 'Action outside a run at line ' .. number)
                    local seq, op, args = payload:match('^(%d+) ([%w_]+)%s*(.-)%s*$')
                    assert(seq, 'Unreadable action at line ' .. number)
                    assert(tonumber(seq) == run.seq + 1, 'Missing or duplicate action sequence at line ' .. number)
                    run.seq = run.seq + 1
                    local tokens = {}
                    for token in args:gmatch('%S+') do tokens[#tokens + 1] = token end
                    validate_action(op, tokens)
                    if op ~= 'set_ante_key' then
                        run.actions = run.actions + 1
                        pending = {kind = 'action', seq = tonumber(seq), op = op, args = tokens, money = {},
                            text = op .. (#tokens > 0 and (' ' .. table.concat(tokens, ' ')) or ''), line = number,
                            position = #run.entries + 1}
                        run.entries[#run.entries + 1] = pending
                        paying = pending
                    end
                end
            else
                local human = line:match(':: MULTIPLAYER :: Client sent message: action:(.*)$')
                if human then
                    -- ease_dollars traces every money change with the same
                    -- prefix. Those belong to the last action until the next
                    -- one; the mirrored line is the first other line after it.
                    local amount = human:match('^moneyMoved,amount:(%S+)')
                    if amount then
                        if paying then paying.money[#paying.money + 1] = amount end
                    elseif pending and mirrored[pending.op] and not pending.human then
                        pending.human = human:match('^%s*(.-)%s*$')
                        pending = nil
                    end
                else
                    local action, rest = line:match(':: MULTIPLAYER :: Client got (%w+) message:%s*(.*)$')
                    if action == 'lobbyInfo' then
                        local fields = M.message_fields(action, rest)
                        lobby = {host = fields.host, guest = fields.guest, is_host = fields.isHost}
                    elseif action and run and not not_delivered[action] then
                        run.entries[#run.entries + 1] = {kind = 'message', action = action,
                            fields = M.message_fields(action, rest), line = number, position = #run.entries + 1}
                        -- The one opponent effect that moves money must not
                        -- be read as the effect of the player's last action.
                        if action == 'letsGoGamblingNemesis' then paying = nil end
                    end
                end
            end
        end
        assert(#runs > 0, 'No MP_RLOG manifest found in this log')
        -- An abandoned lobby leaves a manifest without a single action.
        local playable = {}
        for _, candidate in ipairs(runs) do
            if candidate.actions > 0 then playable[#playable + 1] = candidate end
        end
        assert(#playable > 0, 'No MP_RLOG run in this log contains actions')
        return playable
    end

    -- The run's actions laid out the way the player's filter script prints
    -- them: the manifest, then one row per action.
    function M.table(run)
        local rows, wide_num, wide_op = {}, 0, 0
        for _, entry in ipairs(run.entries) do
            if entry.kind == 'action' then
                local num, op = 'OP_NUM: ' .. entry.seq, 'OP: ' .. entry.op
                rows[#rows + 1] = {num, op, #entry.args > 0 and ('ON_WHAT: ' .. table.concat(entry.args, ', ')) or ''}
                wide_num, wide_op = math.max(wide_num, #num), math.max(wide_op, #op)
            end
        end
        local out = {'MANIFEST ' .. run.manifest_text}
        for _, row in ipairs(rows) do
            out[#out + 1] = row[1] .. string.rep(' ', wide_num - #row[1]) .. ' || ' .. row[2] .. string.rep(' ', wide_op - #row[2]) ..
                (row[3] ~= '' and (' || ' .. row[3]) or ' ||')
        end
        return table.concat(out, '\n') .. '\n'
    end

    -- The card, blind or cost named by a mirrored line, checked before an
    -- action is executed so it touches what the player's action touched.
    function M.expectation(entry)
        local human = entry.human
        if not human then return {} end
        local name, cost = human:match('^boughtCardFromShop,card:(.*),cost:(%-?%d+)$')
        if name then return {name = name, cost = tonumber(cost)} end
        name = human:match('^usedCard,card:(.*)$') or human:match('^soldCard,card:(.*)$')
        if name then return {name = name} end
        local blind = human:match('^selectBlind,blind:(.*)$')
        if blind then return {blind = blind} end
        cost = human:match('^rerollShop,cost:(%-?%d+)$')
        if cost then return {cost = tonumber(cost)} end
        return {}
    end

    return M
end
