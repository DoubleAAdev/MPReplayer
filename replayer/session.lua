-- One replay session: the game is put into the lobby the log was played in,
-- the log's actions are executed in order, and the opponent's messages are
-- handed back to Multiplayer where the log has them.
--
-- Only the log's actions are executed, each exactly once and in log order.
-- Nothing is skipped, repeated, reordered or added, and nothing is decided
-- by comparing scores or money: an action the game cannot perform, or a line
-- the game writes that is not the action just performed, stops the replay
-- at that action and says why. The recording is then the log up to there.
--
-- Multiplayer only draws from its own card pools, applies its rulesets and
-- resolves PvP rounds while MP.LOBBY.code is set, so the session emulates the
-- lobby instead of using practice mode. Nothing reaches the server: Client
-- messages are dropped for the whole session.
--
-- A replay writes nothing into the Lovely log. From Start Replay until the
-- game is back at the main menu, every line Multiplayer would log is dropped
-- as well - the run's manifest, its actions, the money, the messages handed
-- back to it - so a replay never leaves behind a log that reads like another
-- game. Progress is shown in the config tab and mp_replayer/status.json.
return function(log, driver, JSON, deps)
    local S = {phase = 'idle', text = 'Replayer: choose Load Log to pick a Multiplayer log', index = 1}
    local directory = 'mp_replayer'
    local clock = deps.clock
    local session, saved
    -- Actions the game writes by itself when a delivered message arrives.
    local auto_ops = {net_asteroid = true, net_pizza = true, net_magnet = true, net_phantom_add = true, net_phantom_remove = true}
    -- Messages a replay may still send: none change a game.
    local allowed_sends = {username = true, version = true, keepAliveAck = true, connect = true}
    local SETTLE, STALL, RECORD, BLOCKED = 0.4, 45, 20, 10

    -- Balatro Observer's Action Recorder, when it is installed. It is optional:
    -- a replay runs the same without it, there is just no recording to export.
    local function recorder() return BalatroActionRecorder end

    local function write_status()
        local state = {phase = S.phase, status = S.text, step = session and session.done or 0,
            total = session and session.run.actions or 0, recording = recorder() and recorder().path or nil}
        if session and session.failure then state.failure = session.failure end
        pcall(function()
            love.filesystem.createDirectory(directory)
            love.filesystem.write(directory .. '/status.json', JSON.encode(state))
        end)
    end

    -- Bound every visible line; full diagnostic text remains in status.json.
    local WIDTH = 40
    local function wrap(text)
        local lines, line = {}, ''
        for word in tostring(text):gmatch('%S+') do
            if line ~= '' and #line + 1 + #word > WIDTH then
                lines[#lines + 1], line = line, ''
            end
            while #word > WIDTH do
                lines[#lines + 1], word = word:sub(1, WIDTH), word:sub(WIDTH + 1)
            end
            line = line == '' and word or (line .. ' ' .. word)
        end
        lines[#lines + 1] = line
        if #lines > 4 then lines[4] = lines[4]:sub(1, WIDTH - 3) .. '...' end
        S.line1, S.line2, S.line3, S.line4 = lines[1] or '', lines[2] or '', lines[3] or '', lines[4] or ''
    end
    wrap(S.text)

    function S.status(text)
        S.text = text
        wrap(text)
        write_status()
    end

    local function progress()
        return (session.done or 0) .. '/' .. session.run.actions
    end

    local function clean(message)
        return tostring(message):gsub('^.-:%d+: ', '')
    end

    local function fail(message)
        if not session or session.failure then return end
        local entry = session.entries[session.cursor]
        local where = entry and entry.kind == 'action' and (' at action ' .. entry.seq .. ' (' .. entry.text .. ')') or ''
        session.failure = {step = session.done, message = clean(message), action = entry and entry.text or nil, line = entry and entry.line or nil}
        S.phase = 'failed'
        S.status('Replay stopped' .. where .. ': ' .. clean(message) .. ' - ' .. progress() .. ' actions done, the run is left open')
    end
    S.fail = fail

    -- Multiplayer prints each round's deck counts as IDOL_ROLL. A replay whose
    -- deck no longer matches the log's stops at that round, not rounds later.
    local function idol_counts(payload)
        local ok, text = pcall(function() return love.data.decode('string', 'base64', payload) end)
        local counts = {}
        for token in (ok and text or ''):gmatch('"(%w%w%d+)"') do counts[token:sub(1, 2)] = token:sub(3) end
        return counts
    end
    local function check_idol(message)
        local payload = session and (S.phase == 'running' or S.phase == 'starting') and tostring(message):match('^IDOL_ROLL::(%S+)')
        if not payload then return end
        session.idol = (session.idol or 0) + 1
        local expected = (session.run.idols or {})[session.idol]
        if not expected or expected.payload == payload then return end
        local logged, played, diff = idol_counts(expected.payload), idol_counts(payload), {}
        for card, count in pairs(logged) do
            if played[card] ~= count then diff[#diff + 1] = card .. ' log ' .. count .. ' replay ' .. (played[card] or 0) end
        end
        for card, count in pairs(played) do
            if not logged[card] then diff[#diff + 1] = card .. ' log 0 replay ' .. count end
        end
        table.sort(diff)
        fail('the deck differs from the log at the round end near log line ' .. expected.line
            .. (#diff > 0 and (': ' .. table.concat(diff, ', ')) or ''))
    end

    -- Multiplayer's positional argument formatting, token for token.
    local function format_args(args)
        if args == nil then return '' end
        if type(args) ~= 'table' then return tostring(args) end
        local parts = {}
        for _, token in ipairs(args) do
            if type(token) == 'table' then
                local sub = {}
                for _, value in ipairs(token) do sub[#sub + 1] = tostring(value) end
                parts[#parts + 1] = table.concat(sub, '.')
            else
                parts[#parts + 1] = tostring(token)
            end
        end
        return table.concat(parts, ' ')
    end
    S.format_args = format_args

    -- Installed over MP.RLOG.record for the session. The game reports every
    -- action it performs here, and it must be the log's next action. The
    -- report is not passed on to Multiplayer's replay log while the replay
    -- runs. set_ante_key is the game's bookkeeping, not an action.
    function S.record(op, args, human)
        local original = saved and saved.record
        if not session or (S.phase ~= 'running' and S.phase ~= 'starting') or session.failure then
            return original(op, args, human)
        end
        if op == 'set_ante_key' then return end
        local entry = session.entries[session.cursor]
        local argstr = format_args(args)
        local actual = op .. (argstr ~= '' and (' ' .. argstr) or '')
        if entry and entry.kind == 'action' and actual == entry.text then
            session.cursor = session.cursor + 1
            session.done = session.done + 1
            session.issued, session.waiting_since = nil, nil
            session.consumed = clock()
            if op == 'play' or op == 'discard' then
                local cards = type(args) == 'table' and type(args[1]) == 'table' and #args[1] or 0
                session.hand_pending = {op = op, line = entry.line, began = clock(), cards = cards}
            end
            -- Multiplayer passes the mirrored payload with its "action:" prefix.
            local mirrored = human and tostring(human):gsub('^action:', '') or nil
            S.status('Replay ' .. progress() .. ' - ' .. actual .. (mirrored and (' - ' .. mirrored) or ''))
        else
            fail('the game did "' .. actual .. '", which is not the log\'s next action' ..
                (entry and entry.kind == 'action' and (' "' .. entry.text .. '"') or ''))
        end
    end

    local function deck_key(deck)
        if type(deck) ~= 'string' then return nil end
        if ((G.P_CENTERS or {})[deck] or {}).set == 'Back' then return deck end
        for key, centre in pairs(G.P_CENTERS or {}) do
            if centre.set == 'Back' and centre.name == deck then return key end
        end
        return nil
    end

    local function split_name(text, fallback)
        if type(text) ~= 'string' then return fallback, 1 end
        local name, col = text:match('^(.-)~(%d+)$')
        return name or text, tonumber(col) or 1
    end

    -- Lists the chosen run's actions where the player can read them, in the
    -- layout of their filter script, and names the run in the status.
    local function short(value, limit)
        local text = tostring(value or ''):gsub('[%c]', ' ')
        return #text > limit and (text:sub(1, limit - 3) .. '...') or text
    end
    function S.deck_center(value)
        local key = deck_key(value)
        return key and G.P_CENTERS[key], key
    end
    local function deck_name(m)
        local center, key = S.deck_center(m.deck)
        local localized = (((G.localization or {}).descriptions or {}).Back or {})[key or m.deck]
        if localized and type(localized.name) == 'string' then return localized.name end
        local name = (center or {}).name
        if name and not name:match('^b_') then return name end
        local fallback = tostring(m.deck):gsub('^b_mp_', ''):gsub('^b_', ''):gsub('_', ' ')
        fallback = fallback:gsub('(%a)([%w]*)', function(first, rest) return first:upper() .. rest end)
        return fallback:match(' Deck$') and fallback or (fallback .. ' Deck')
    end
    S.deck_name = deck_name
    function S.stake_name(index)
        local stake = ((G.P_CENTER_POOLS or {}).Stake or {})[index]
        local localized = stake and ((((G.localization or {}).descriptions or {}).Stake or {})[stake.key])
        if localized and type(localized.name) == 'string' then return localized.name end
        if stake and stake.name and not stake.name:match('^stake_') then return stake.name end
        local names = {'White Stake', 'Red Stake', 'Green Stake', 'Black Stake', 'Blue Stake', 'Purple Stake', 'Orange Stake', 'Gold Stake'}
        return names[index] or 'Unknown Stake'
    end
    function S.game_type(m)
        if m.practice == true or m.is_practice == true then return 'Practice (solo)', false end
        if m.multiplayer == false or m.is_multiplayer == false then return 'Single-player', false end
        if type(m.lobby_code) == 'string' and m.lobby_code ~= '' and m.lobby_code ~= 'nolobby' then return 'Multiplayer', true end
        if m.multiplayer == true or m.is_multiplayer == true then return 'Multiplayer', true end
        return 'Game type unknown', false
    end
    function S.log_page(delta)
        local runs = S.log_runs or {}
        local pages = math.max(1, math.ceil(#runs / 3))
        S.log_page_index = ((S.log_page_index or 1) - 1 + (delta or 0)) % pages + 1
        S.log_filename = S.log_source or 'No log loaded'
        S.log_count = #runs .. ' replays loaded'
        S.log_position = 'Page ' .. S.log_page_index .. ' of ' .. pages
        for slot = 1, 3 do
            local run = runs[(S.log_page_index - 1) * 3 + slot]
            local title, setup = '', ''
            if run then
                local m = run.manifest
                title = run.label_number .. '. ' .. short(m.player or 'Unknown player', 15) .. ' vs ' .. short(m.opponent or 'Unknown opponent', 15)
                setup = 'Deck: ' .. short(deck_name(m), 22) .. ' | ' .. S.stake_name(m.stake)
            end
            S['log_game' .. slot], S['log_setup' .. slot] = title, setup
        end
    end
    S.log_page()
    function S.label_run()
        local run = S.runs and S.runs[S.index]
        if not run then
            S.replay_title, S.replay_players, S.replay_setup, S.replay_seed = 'No replay selected', 'Choose Load Log to get started', '', ''
            return
        end
        local m = run.manifest
        S.replay_title = 'Replay ' .. tostring(run.label_number or S.index) .. '  (' .. S.index .. ' of ' .. #S.runs .. ')'
        S.replay_players = short(m.player or 'Unknown player', 18) .. ' vs ' .. short(m.opponent or 'Unknown opponent', 18)
        S.replay_setup = short(deck_name(m), 24) .. '  |  ' .. S.stake_name(m.stake)
        S.replay_seed = 'Seed: ' .. short(m.seed, 24)
        S.replay_title = S.replay_title .. (run.replayed and ' - old replay' or (run.complete and ' - complete' or ' - partial'))
    end
    S.label_run()
    local function show_run()
        local run = S.runs[S.index]
        S.label_run()
        S.confirmed = nil
        S.refresh_mods()
        pcall(function()
            love.filesystem.createDirectory(directory)
            love.filesystem.write(directory .. '/actions.txt', log.table(run))
        end)
        S.status(run.replayed and 'Recorded by an older replay.' or ('Ready to replay - ' .. run.actions .. ' actions.'))
    end

    function S.load(text, source)
        assert(S.phase == 'idle', 'Finish the current replay before loading another log')
        local imported = log.parse(text) -- Parse before mutating the existing list.
        S.runs, S.log_runs = {}, {}
        local first = #S.runs + 1
        local first_log = #S.log_runs + 1
        local filename = short(tostring(source or 'Loaded log'):gsub('\\', '/'):match('[^/]+$'), 40)
        for _, run in ipairs(imported) do
            run.label_number = #S.log_runs + 1
            run.source_name = filename
            S.runs[#S.runs + 1] = run
            S.log_runs[#S.log_runs + 1] = run
        end
        S.log_imports = 1
        S.log_source = filename
        S.log_page_index = math.floor((first_log - 1) / 3) + 1
        S.log_page()
        S.index = first
        show_run()
    end

    function S.next_run()
        if not S.runs or S.phase ~= 'idle' then return end
        S.index = S.index % #S.runs + 1
        show_run()
    end

    function S.start_listed(run)
        assert(S.phase == 'idle', 'End the current replay first')
        local found = false
        for _, candidate in ipairs(S.log_runs or {}) do if candidate == run then found = true end end
        assert(found, 'This game is no longer in the loaded log')
        S.runs = S.runs or {}
        local index
        for i, candidate in ipairs(S.runs) do if candidate == run then index = i end end
        if not index then
            S.runs[#S.runs + 1] = run; index = #S.runs
            S.confirmed, S.confirmed_mods = nil, nil
        end
        if S.runs[S.index] ~= run or S.index ~= index then
            S.index = index
            show_run()
        else
            S.label_run()
        end
        S.start()
    end

    function S.remove_run()
        if not S.runs then return end
        if S.phase ~= 'idle' then S.stop() end
        table.remove(S.runs, S.index)
        S.confirmed, S.confirmed_mods = nil, nil
        if #S.runs == 0 then
            S.runs, S.index = nil, 1
            S.label_run()
            S.refresh_mods()
            pcall(function() love.filesystem.write(directory .. '/actions.txt', '') end)
            S.status('Replay removed. Load a log to choose another.')
        else
            S.index = math.min(S.index, #S.runs)
            show_run()
        end
    end

    local function validate(run)
        local m = run.manifest
        assert(MP and MP.LOBBY and MP.RLOG and MP.Rulesets and MP.Gamemodes and MP.GAME, 'Multiplayer is required')
        assert(G.STAGE == G.STAGES.MAIN_MENU, 'Return to the main menu first')
        assert(not MP.LOBBY.code, 'Leave the Multiplayer lobby first')
        assert(Client and type(Client.send) == 'function', 'Multiplayer networking is not loaded')
        assert(MP.Rulesets[m.ruleset], 'Ruleset ' .. m.ruleset .. ' is not installed')
        assert(MP.Gamemodes[m.gamemode], 'Game mode ' .. m.gamemode .. ' is not installed')
        assert(not m.challenge or m.challenge == '', 'Challenge runs cannot be replayed')
        local installed = SMODS.Mods and SMODS.Mods.Multiplayer
        assert(installed and installed.version == m.mod_version, 'Install Multiplayer ' .. tostring(m.mod_version) .. ' (installed: ' .. tostring(installed and installed.version) .. ')')
        local key = assert(deck_key(m.deck), 'Deck ' .. m.deck .. ' is not installed')
        local name = G.P_CENTERS[key].name or key
        assert(MP.UTILS and MP.UTILS.get_deck_key_from_name(name) == key, 'Multiplayer cannot resolve deck ' .. name)
        if key == 'b_mp_cocktail' then
            local cocktail = m.lobby_config.cocktail
            assert(type(cocktail) == 'string' and cocktail:match('^[012]+[HS]$'), 'Manifest missing Cocktail settings')
            assert(MP.get_cocktail_decks and #MP.get_cocktail_decks() + 1 == #cocktail, 'The installed Cocktail deck pool differs from the log')
        end
        return key, name
    end

    -- Actions the game writes by itself: the PvP blind the server starts
    -- after Ready, and the effects of the opponent's cards.
    local function classify(entries)
        local previous
        for _, entry in ipairs(entries) do
            if entry.kind == 'action' then
                entry.auto = auto_ops[entry.op] or (entry.op == 'select_blind' and previous ~= nil and previous.op == 'ready_blind' and previous.args[1] == '1') or nil
                previous = entry
            end
        end
    end
    S.classify = classify

    -- Multiplayer writes every enabled mod and its version into the manifest,
    -- in the same form it keeps in MP.MOD_STRING. The replay's own mods are
    -- left out: they change no card.
    local function mods_of(text)
        local set = {}
        for item in text:gmatch('[^;]+') do
            item = item:match('^%s*(.-)%s*$')
            local id, version = item:match('^(.-)%-(%d.*)$')
            id = id or item
            if not item:find('=', 1, true) and id ~= 'BalatroObserver' and id ~= 'MPReplayer' and id ~= 'BalatroReplayer' then
                set[id] = version or ''
            end
        end
        return set
    end

    function S.mod_page(delta)
        local pages = S.mod_pages or {}
        S.mod_page_index = #pages > 0 and ((S.mod_page_index or 1) - 1 + (delta or 0)) % #pages + 1 or 1
        local page = pages[S.mod_page_index] or {}
        S.mod_detail1, S.mod_detail2, S.mod_detail3 = page[1] or '', page[2] or '', page[3] or ''
        S.mod_position = #pages > 0 and (S.mod_page_index .. ' / ' .. #pages) or ''
    end

    -- Reviewed presentation/control mods; unknown IDs remain potentially critical.
    -- https://github.com/SleepyG11/HandyBalatro
    -- https://github.com/nh6574/JokerDisplay
    local noncritical_mods = {Handy = true, JokerDisplay = true}
    function S.mod_is_critical(id) return not noncritical_mods[id] end

    -- Compare the beta build numerically; newer date-based releases also pass.
    function S.steamodded_supported(version)
        if type(version) ~= 'string' then return nil end
        local major, minor, patch, suffix = version:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
        if not major then return nil end
        major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
        if major ~= 1 then return major > 1 end
        if minor > 0 or patch > 0 then return true end
        if suffix == '' or suffix:sub(1, 1) == '+' then return true end
        local build, letter = suffix:match('^~BETA%-(%d+)(%a*)$')
        if not build then return nil end
        build = tonumber(build)
        return build > 1620 or (build == 1620 and letter >= 'a')
    end

    -- Compare the manifest with mods loaded by this running game, not files on disk.
    function S.refresh_mods()
        local run = S.runs and S.runs[S.index]
        local recorded = run and run.manifest.mod_hash
        local current = MP and MP.MOD_STRING
        S.mod_pages, S.mod_page_index = {}, 1
        S.mod_summary = not run and 'Load a replay to compare mods' or 'Mod information unavailable'
        S.mod_missing, S.mod_extra, S.mod_versions = '', '', ''
        S.mod_overview = not run and 'Load a log first' or 'No mod data in this log'
        S.mod_hint = ''
        S.steamodded_warning, S.steamodded_loaded = nil, nil
        local differences = {}
        local critical = 0
        S.mod_risk = 'Compatibility not assessed'
        if type(recorded) == 'string' and recorded ~= '' and type(current) == 'string' and current ~= '' then
            local logged, loaded = mods_of(recorded), mods_of(current)
            local missing, extra, changed = {}, {}, {}
            for id, version in pairs(logged) do
                if loaded[id] == nil then missing[#missing + 1] = id
                elseif loaded[id] ~= version then changed[#changed + 1] = id end
            end
            for id in pairs(loaded) do if logged[id] == nil then extra[#extra + 1] = id end end
            table.sort(missing); table.sort(extra); table.sort(changed)
            for _, group in ipairs({missing, extra, changed}) do
                for _, id in ipairs(group) do if S.mod_is_critical(id) then critical = critical + 1 end end
            end
            S.mod_risk = critical > 0 and (critical .. ' potentially critical differences') or 'No critical mod differences'
            S.mod_summary = 'Missing: ' .. #missing .. ' | Extra: ' .. #extra .. ' | Versions: ' .. #changed
            S.mod_missing = 'Missing from this game: ' .. #missing
            S.mod_extra = 'Extra in this game: ' .. #extra
            S.mod_versions = 'Different versions: ' .. #changed
            for _, id in ipairs(missing) do differences[#differences + 1] = {'Missing: ' .. id, 'Log: ' .. logged[id], 'Loaded: absent'} end
            for _, id in ipairs(extra) do differences[#differences + 1] = {'Extra: ' .. id, 'Log: absent', 'Loaded: ' .. loaded[id]} end
            for _, id in ipairs(changed) do differences[#differences + 1] = {'Version: ' .. id, 'Log: ' .. logged[id], 'Loaded: ' .. loaded[id]} end
            if #differences == 0 then S.mod_summary = 'Mods match the log' end
            S.mod_overview = #differences == 0 and 'Mods match' or (#differences .. (#differences == 1 and ' difference' or ' differences'))
            S.mod_hint = critical > 0 and 'May affect replay' or (#differences > 0 and 'Display / controls only' or '')
        end
        local loaded = type(current) == 'string' and mods_of(current) or {}
        local logged = type(recorded) == 'string' and mods_of(recorded) or {}
        local version = (SMODS and SMODS.version) or loaded.Steamodded
        if run and (version ~= nil or logged.Steamodded ~= nil) then
            local supported = S.steamodded_supported(version)
            if supported ~= true then
                S.steamodded_loaded = version and version ~= '' and version or 'Unknown'
                S.steamodded_warning = supported == false and 'Steamodded is too old for this replay.'
                    or 'Steamodded compatibility could not be verified.'
                critical = math.max(critical, 1)
                S.mod_risk, S.mod_hint = 'Steamodded compatibility warning', 'Steamodded 1620a or newer needed'
                if #differences == 0 then
                    S.mod_overview, S.mod_summary = 'Check Steamodded version', S.steamodded_warning
                end
            end
        end
        for _, entry in ipairs(differences) do
            local lines = {}
            for _, line in ipairs(entry) do
                for start = 1, #line, WIDTH do lines[#lines + 1] = line:sub(start, start + WIDTH - 1) end
            end
            for start = 1, #lines, 3 do S.mod_pages[#S.mod_pages + 1] = {lines[start], lines[start + 1], lines[start + 2]} end
        end
        S.mod_page()
        return critical > 0, tostring(recorded) .. '\n' .. tostring(current) .. '\n' .. tostring(version)
    end
    S.refresh_mods()

    function S.start()
        assert(S.runs, 'Load a log first')
        assert(S.phase == 'idle', 'A replay is already running')
        local run = S.runs[S.index]
        local m = run.manifest
        local key, deck_name = validate(run)
        local differs, signature = S.refresh_mods()
        if differs and (S.confirmed ~= run or S.confirmed_mods ~= signature) then
            S.confirmed, S.confirmed_mods = run, signature
            S.status('Critical or unknown mods differ. Replay may stop early.')
            return
        end
        S.confirmed = nil
        classify(run.entries)
        saved = {send = Client.send, record = MP.RLOG.record, record_match = MP.STATS and MP.STATS.record_match,
            modifiers = MP.MODIFIERS, sp = {}, lobby = {}}
        for k, v in pairs(MP.SP or {}) do saved.sp[k] = v end
        for _, field in ipairs({'code', 'connected', 'is_host', 'username', 'blind_col', 'host', 'guest', 'config', 'deck', 'type'}) do
            saved.lobby[field] = MP.LOBBY[field]
        end
        -- The lobby options exactly as the host had them, on top of the
        -- mod's current defaults for anything the manifest does not carry.
        MP.reset_lobby_config()
        local config = MP.LOBBY.config
        for k, v in pairs(m.lobby_config) do
            if k ~= 'action' and (type(v) == 'boolean' or type(v) == 'number' or type(v) == 'string') then config[k] = v end
        end
        config.ruleset, config.gamemode, config.back, config.stake, config.challenge = m.ruleset, m.gamemode, deck_name, m.stake, ''
        config.modifier_layers = m.modifier_layers or config.modifier_layers or ''
        if type(m.the_order_enabled) == 'boolean' then config.the_order = m.the_order_enabled end
        -- A replay runs at animation speed, not at the original pace, so the
        -- round timer would expire on its own. It changes no card.
        config.timer = false
        MP.LOBBY.deck = {back = deck_name, stake = m.stake, challenge = '', sleeve = config.sleeve, cocktail = config.cocktail}
        local lobby = run.lobby or {}
        local host_name, host_col = split_name(lobby.host, m.is_host and m.player or m.opponent or 'Host')
        local guest_name, guest_col = split_name(lobby.guest, m.is_host and (m.opponent or 'Guest') or m.player)
        MP.LOBBY.host = {username = host_name, blind_col = host_col, hash_str = '', hash = '', cached = true, config = {}}
        MP.LOBBY.guest = {username = guest_name, blind_col = guest_col, hash_str = '', hash = '', cached = true, config = {}}
        MP.LOBBY.is_host = m.is_host == true
        MP.LOBBY.username = m.player or (MP.LOBBY.is_host and host_name or guest_name)
        MP.LOBBY.blind_col = MP.LOBBY.is_host and host_col or guest_col
        MP.LOBBY.connected = true
        MP.modifiers_parse(config.modifier_layers)
        if MP.SP then MP.SP.practice = false end
        if MP.GHOST and MP.GHOST.clear then MP.GHOST.clear() end
        Client.send = function(msg)
            -- Multiplayer reports the score after evaluation, then stays in
            -- HAND_PLAYED on its last hand until the server ends the PvP round.
            if type(msg) == 'table' and msg.action == 'playHand' and session
                and session.hand_pending and session.hand_pending.op == 'play' then
                session.hand_pending.score_reported = true
            end
            if type(msg) == 'table' and allowed_sends[msg.action] then return saved.send(msg) end
        end
        MP.RLOG.record = S.record
        if MP.STATS then MP.STATS.record_match = function() end end
        -- Steamodded sends every log line through this one function, and
        -- Multiplayer names itself as the logger on all of its lines.
        saved.console = sendMessageToConsole
        if saved.console then
            sendMessageToConsole = function(level, logger, message)
                if logger == 'IdolAlgo' then pcall(check_idol, message) end
                if logger ~= 'MULTIPLAYER' then return saved.console(level, logger, message) end
            end
        end
        session = {run = run, entries = run.entries, cursor = 1, done = 0, key = key, began = clock(), tick = 0}
        session.code = m.lobby_code or 'REPLAY'
        -- Setting the code is what joining a lobby does; Multiplayer notices
        -- on its next update and re-enters the menu as a lobby member.
        MP.LOBBY.code = session.code
        if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
        S.phase = 'joining'
        S.status('Replay joining lobby ' .. session.code .. ' - ' .. run.actions .. ' actions')
    end

    local function cleanup()
        if not saved then return end
        Client.send = saved.send
        MP.RLOG.record = saved.record
        if MP.STATS then MP.STATS.record_match = saved.record_match end
        for field, value in pairs(saved.lobby) do MP.LOBBY[field] = value end
        MP.LOBBY.code = saved.lobby.code
        MP.MODIFIERS = saved.modifiers
        if MP.SP then for k, v in pairs(saved.sp) do MP.SP[k] = v end end
        if MP.reset_game_states then MP.reset_game_states() end
        if saved.console then sendMessageToConsole = saved.console end
        saved = nil
    end

    local function finish()
        S.phase = 'finished'
        local rec = recorder()
        local text = session.run.complete and ('Replay complete - all ' .. session.run.actions .. ' actions')
            or ('Replay reached the end of a partial log - ' .. progress() .. ' actions')
        if session.recording and rec then text = text .. ', ' .. tostring(rec.action_count or 0) .. ' recorded actions in ' .. tostring(rec.path) end
        S.status(text)
    end

    function S.stop()
        if S.phase == 'idle' then return end
        S.phase = 'stopped'
        S.status('Replay stopped by the player - ' .. (session and progress() or ''))
        if G.STAGE == G.STAGES.RUN then
            -- Multiplayer leaves a run and returns to the menu when the lobby
            -- code goes away; the menu hook restores the rest.
            MP.LOBBY.code = nil
        else
            cleanup()
            S.phase = 'idle'
            session = nil
        end
    end

    -- Game.main_menu: the lobby transition on joining, and the way out.
    function S.on_main_menu()
        if not session then return end
        if S.phase == 'joining' then
            session.rejoined = session.rejoined or clock()
        elseif S.phase == 'running' or S.phase == 'finished' or S.phase == 'failed' or S.phase == 'stopped' then
            cleanup()
            S.phase = 'idle'
            S.status('Replayer: returned to the menu (' .. progress() .. ' actions)')
            session = nil
        end
    end

    -- Game.start_run, after the run exists.
    function S.on_run_started()
        if not session then return end
        if S.phase == 'running' then return fail('a new run started during the replay') end
        if S.phase ~= 'starting' then return end
        local m = session.run.manifest
        local seed = ((G.GAME or {}).pseudorandom or {}).seed
        if seed ~= m.seed and seed ~= '*' .. m.seed then return fail('the run started with seed ' .. tostring(seed) .. ', the log has ' .. m.seed) end
        local deck = ((((G.GAME or {}).selected_back or {}).effect or {}).center or {}).key
        if deck ~= session.key then return fail('the run started with deck ' .. tostring(deck) .. ', the log has ' .. session.key) end
        local rec = recorder()
        session.recording = rec and rec.ok and rec.path or nil
        S.phase = 'running'
        session.signature, session.signature_at = nil, nil
        S.status('Replay running - ' .. progress() .. ' actions')
    end

    -- The player may pause or open a menu without ending the replay.
    local function paused()
        if G.OVERLAY_MENU then return 'an overlay menu is open' end
        if (G.SETTINGS or {}).paused then return 'the game is paused' end
        return nil
    end

    local function busy()
        if not G.STATE_COMPLETE then return driver.state_name() .. ' is not complete' end
        for name, locked in pairs((G.CONTROLLER or {}).locks or {}) do
            if locked then return 'controller lock ' .. tostring(name) end
        end
        if ((G.GAME or {}).STOP_USE or 0) > 0 then return 'cards cannot be used yet' end
        if MP.GAME and MP.GAME.pvp_countdown_in_progress then return 'the PvP countdown' end
        for name, queue in pairs((G.E_MANAGER or {}).queues or {}) do
            for _, event in ipairs(queue) do
                if event.blocking and not event.complete then return 'events in the ' .. name .. ' queue' end
            end
        end
        return nil
    end

    local function deliver(entry)
        deps.channel('networkToUi'):push(deps.encode(entry.fields))
        session.delivered = clock()
    end

    -- Waiting is fine while the game can still get to the action. The screen
    -- tells when it cannot: a hand to play while the game sits in the shop
    -- means the two did not finish a round together.
    local function waiting(reason)
        local now = clock()
        session.waiting_since = session.waiting_since or now
        local entry = session.entries[session.cursor]
        if driver.reachable(entry) then
            if now - session.waiting_since > STALL then fail('waited ' .. math.floor(now - session.waiting_since) .. ' s for ' .. reason) end
        elseif now - session.waiting_since > BLOCKED then
            local state = driver.state_name()
            local hint = ''
            if state == 'SELECTING_HAND' then
                hint = ' - the log had finished this round with the hands before it and the game has not, so the blind was not beaten here'
            elseif entry.op == 'play' or entry.op == 'discard' then
                hint = ' - the game finished this round sooner than the log did'
            end
            fail('the game cannot do "' .. entry.text .. '" from ' .. state .. hint)
        end
    end

    function S.update(dt)
        if not session then return end
        local now = clock()
        if S.phase == 'joining' then
            if not session.rejoined and G.F_NO_SAVING then session.rejoined = now end
            if not session.rejoined then
                if now - session.began > 20 then fail('Multiplayer did not enter the lobby') end
                return
            end
            local wiping = ((G.CONTROLLER or {}).locks or {}).wipe
            if G.STAGE == G.STAGES.MAIN_MENU and now - session.rejoined > 0.8 and not wiping and not G.OVERLAY_MENU then
                S.phase = 'starting'
                session.started_at = now
                deliver({action = 'startGame', fields = {action = 'startGame', seed = session.run.manifest.seed, stake = session.run.manifest.stake}, line = session.run.line})
                S.status('Replay starting run ' .. session.run.manifest.seed)
            elseif now - session.rejoined > STALL then
                fail('the menu did not settle after joining the lobby')
            end
            return
        end
        if S.phase == 'starting' then
            if now - session.started_at > STALL then fail('the run did not start') end
            return
        end
        if S.phase ~= 'running' then return end
        if MP.LOBBY.code ~= session.code then MP.LOBBY.code = session.code end
        if G.STAGE ~= G.STAGES.RUN then
            S.phase = 'stopped'
            S.status('Replay stopped: the run ended - ' .. progress() .. ' actions')
            return
        end
        -- A recording that was running must not go missing halfway through.
        local rec = recorder()
        if session.recording and not (rec and rec.ok) then return fail('Action Recorder stopped writing') end
        -- RLOG acknowledges the input before scoring/discard animations and their
        -- triggered effects finish. Do not deliver round-ending messages or issue
        -- another input while that hand operation is still resolving.
        if session.hand_pending then
            if paused() then session.hand_pending.began = now; return end
            local state = driver.state_name()
            local waiting_for_opponent = state == 'HAND_PLAYED' and session.hand_pending.score_reported
                and MP.is_pvp_boss and MP.is_pvp_boss()
                and ((G.GAME.current_round or {}).hands_left or 1) < 1
                and G.hand and G.hand.cards and #G.hand.cards == 0
            local resolving = (state == 'HAND_PLAYED' and not waiting_for_opponent) or state == 'DRAW_TO_HAND' or state == 'DISCARD'
                or state == 'NEW_ROUND' or (G.play and G.play.cards and #G.play.cards > 0)
            if resolving or busy() or now - (session.consumed or 0) < SETTLE then
                -- A drag logged while the hand scores must happen while it scores:
                -- after the last PvP hand the leftover cards are gone by the time
                -- scoring settles, and endPvP waits behind the reorder. Only while
                -- scoring: during a draw the hand's size changes, and Multiplayer
                -- ignores a reorder that lands on the same frame as a size change.
                -- And only once every played card has reached the play area: until
                -- then the hand can still hold as many cards as the drag names.
                local next_entry = session.entries[session.cursor]
                if next_entry and next_entry.op == 'reorder' and not session.issued
                    and session.hand_pending.op == 'play' and state == 'HAND_PLAYED'
                    and G.play and G.play.cards and #G.play.cards >= session.hand_pending.cards then
                    local cursor = session.cursor
                    local ok, result = pcall(driver.perform, next_entry, session.entries)
                    if ok and result == 'done' and session.cursor == cursor and not session.failure then session.issued = now end
                end
                if now - session.hand_pending.began > STALL then
                    return fail(session.hand_pending.op .. ' at log line ' .. tostring(session.hand_pending.line)
                        .. ' did not finish resolving; no following input was issued')
                end
                return
            end
            session.hand_pending = nil
        end
        local entry = session.entries[session.cursor]
        if not entry then return finish() end
        if entry.kind == 'message' then
            while entry and entry.kind == 'message' do
                deliver(entry)
                session.cursor = session.cursor + 1
                entry = session.entries[session.cursor]
            end
            return
        end
        if session.issued then
            if now - session.issued > RECORD then fail('the game did not record "' .. entry.text .. '" after it was performed') end
            return
        end
        local halted = paused()
        if halted then
            session.waiting_since = nil
            return
        end
        if entry.auto then return waiting('the game to produce "' .. entry.text .. '"') end
        local reason = busy()
        if reason then return waiting(reason) end
        local signature = driver.signature()
        if signature ~= session.signature then
            session.signature, session.signature_at = signature, now
            return
        end
        if now - session.signature_at < SETTLE or now - (session.consumed or 0) < SETTLE or now - (session.delivered or 0) < SETTLE then return end
        if now - session.tick < 0.1 then return end
        session.tick = now
        -- Most callbacks write their MP_RLOG line before returning, so the
        -- cursor may already have moved on by the time perform comes back.
        local cursor = session.cursor
        local ok, result, detail = pcall(driver.perform, entry, session.entries)
        if not ok then return fail(result) end
        if result == 'done' then
            if session.cursor == cursor and not session.failure then session.issued = now end
            session.waiting_since = nil
        else
            waiting(detail or 'the game')
        end
    end

    -- Keep the exact run available until the exit transition has cleaned up.
    function S.active_run() return session and session.run end
    function S.debug_snapshot()
        return {phase = S.phase, status = S.text, run = session and session.run,
            entries = session and session.entries or {}, cursor = session and session.cursor or 1,
            done = session and session.done or 0, failure = session and session.failure,
            state = driver.state_name(), issued = session and session.issued ~= nil}
    end

    function S.end_screen_reached()
        if not session or S.phase ~= 'running' then return end
        if session.entries[session.cursor] then
            fail('the game ended before all recorded actions were played')
        else
            finish()
        end
    end

    function S.current()
        return session and session.entries[session.cursor] or nil
    end

    function S.progress()
        return session and progress() or ''
    end

    return S
end
