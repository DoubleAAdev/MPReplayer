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
-- game. Progress is shown in the config tab and balatro_replayer/status.json.
return function(log, driver, JSON, deps)
    local S = {phase = 'idle', text = 'Replayer: choose Load Log to pick an action log or Multiplayer log', index = 1}
    local directory = 'balatro_replayer'
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

    -- The config tab has room for four lines of about this many characters;
    -- the last line takes whatever is left.
    local WIDTH = 60
    local function wrap(text)
        local lines, line = {}, ''
        for word in tostring(text):gmatch('%S+') do
            if line ~= '' and #line + 1 + #word > WIDTH and #lines < 3 then
                lines[#lines + 1] = line
                line = word
            else
                line = line == '' and word or (line .. ' ' .. word)
            end
        end
        lines[#lines + 1] = line
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
        if session and session.run.source=='action_log' then return end
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
    local function show_run()
        local run = S.runs[S.index]
        pcall(function()
            love.filesystem.createDirectory(directory)
            love.filesystem.write(directory .. '/actions.txt', log.table(run))
        end)
        S.status('Replayer: run ' .. S.index .. '/' .. #S.runs .. ' - ' .. run.actions .. ' actions, seed ' .. run.manifest.seed ..
            (run.replayed and ' - WRITTEN BY AN OLD REPLAY, NOT A GAME YOU PLAYED' or '') .. ' - listed in balatro_replayer/actions.txt')
    end

    function S.load(text)
        assert(S.phase == 'idle', 'Finish the current replay before loading another log')
        S.runs = log.parse(text)
        S.index = 1
        show_run()
    end

    function S.next_run()
        if not S.runs or S.phase ~= 'idle' then return end
        S.index = S.index % #S.runs + 1
        show_run()
    end

    local function validate(run)
        local m = run.manifest
        if run.singleplayer then
            assert(G.STAGE==G.STAGES.MAIN_MENU,'Return to the main menu first')
            assert(not (MP and MP.LOBBY and MP.LOBBY.code),'Leave the Multiplayer lobby first')
            assert(not m.challenge or m.challenge=='','Challenge runs cannot be replayed')
            local key=assert(deck_key(m.deck),'Recorded deck is not installed')
            return key,G.P_CENTERS[key].name or key
        end
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
        for item in tostring(text):gmatch('[^;]+') do
            if not item:find('=', 1, true) and not item:match('^BalatroObserver%-') and not item:match('^BalatroReplayer%-') then
                set[item] = true
            end
        end
        return set
    end

    -- Another mod set deals another game from the same seed: an updated
    -- Steamodded, for one, rolls a different boss blind. Said before the run
    -- starts rather than found out at the first thing that differs.
    local function mod_difference(m)
        if m.mods then
            local recorded,current={},{}
            local function relevant(id) return id~='BalatroObserver' and id~='BalatroReplayer' end
            for _,mod in ipairs(m.mods) do if relevant(mod.id) then recorded[mod.id]=mod.version end end
            for id,mod in pairs((SMODS or {}).Mods or {}) do if relevant(id) and not mod.disabled then current[id]=mod.version end end
            for id,v in pairs(recorded) do if current[id]~=v then return 'Mods differ from the log: '..id..' version '..tostring(v) end end
            for id in pairs(current) do if not recorded[id] then return 'Mods differ from the log: additional '..id end end
        end
        if type(m.mod_hash) ~= 'string' or type(MP.MOD_STRING) ~= 'string' or MP.MOD_STRING == '' then return nil end
        local logged, installed = mods_of(m.mod_hash), mods_of(MP.MOD_STRING)
        local missing, extra = {}, {}
        for item in pairs(logged) do if not installed[item] then missing[#missing + 1] = item end end
        for item in pairs(installed) do if not logged[item] then extra[#extra + 1] = item end end
        if #missing == 0 and #extra == 0 then return nil end
        table.sort(missing)
        table.sort(extra)
        local parts = {}
        if #missing > 0 then parts[#parts + 1] = 'the log had ' .. table.concat(missing, ', ') end
        if #extra > 0 then parts[#parts + 1] = 'this game has ' .. table.concat(extra, ', ') end
        return 'Mods differ from the log: ' .. table.concat(parts, '; ')
    end

    function S.start()
        assert(S.runs, 'Load a log first')
        assert(S.phase == 'idle', 'A replay is already running')
        local run = S.runs[S.index]
        local m = run.manifest
        local key, deck_name = validate(run)
        local differs = mod_difference(m)
        if differs and S.confirmed ~= run then
            S.confirmed = run
            error(differs .. '. The replay may stop early. Press Start Replay again to replay anyway', 0)
        end
        S.confirmed = nil
        if driver.reset then driver.reset() end
        if run.source~='action_log' then classify(run.entries) end
        if run.singleplayer then
            saved={singleplayer=true,viewed_back=(G.GAME or {}).viewed_back}
            session={run=run,entries=run.entries,cursor=1,done=0,key=key,began=clock(),tick=0,started_at=clock()}
            G.GAME.viewed_back=Back(key)
            if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
            S.phase='starting'
            S.status('Replay starting action log '..m.seed)
            -- The button callback clears the title screen and queues run creation.
            -- Game.start_run's hook marks playback ready only after that completes.
            G.FUNCS.start_run(nil,{seed=m.seed,stake=m.stake})
            return
        end
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
            if type(msg) == 'table' and allowed_sends[msg.action] then return saved.send(msg) end
        end
        MP.RLOG.record = S.record
        if MP.STATS then MP.STATS.record_match = function() end end
        -- Steamodded sends every log line through this one function, and
        -- Multiplayer names itself as the logger on all of its lines.
        saved.console = sendMessageToConsole
        if saved.console then
            sendMessageToConsole = function(level, logger, message)
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
        if saved.singleplayer then
            if G.GAME then G.GAME.viewed_back=saved.viewed_back end
            saved=nil
            return
        end
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
        local text = session.run.source=='action_log' and ('Replay reached the end of the action log - '..progress()..' recorded actions')
            or session.run.complete and ('Replay complete - all ' .. session.run.actions .. ' actions')
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
            if session.run.singleplayer then G:main_menu('game') else MP.LOBBY.code = nil end
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
        if m.hand_sort and G.hand and G.hand.config then G.hand.config.sort=m.hand_sort end
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
        if MP and MP.GAME and MP.GAME.pvp_countdown_in_progress then return 'the PvP countdown' end
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
        if not session.run.singleplayer and MP.LOBBY.code ~= session.code then MP.LOBBY.code = session.code end
        if G.STAGE ~= G.STAGES.RUN then
            S.phase = 'stopped'
            S.status('Replay stopped: the run ended - ' .. progress() .. ' actions')
            return
        end
        -- A recording that was running must not go missing halfway through.
        local rec = recorder()
        if session.recording and not (rec and rec.ok) then return fail('Action Recorder stopped writing') end
        local entry = session.entries[session.cursor]
        if not entry then
            if paused() or busy() then return end
            return finish()
        end
        if paused() then session.waiting_since=nil;return end
        if entry.kind=='opponent' then
            local enemy=MP.GAME.enemy or {};MP.GAME.enemy=enemy
            local state=entry.state
            for key,field in pairs({nemesis_location='location',nemesis_location_blind='location_blind',nemesis_score='score_text',nemesis_hands='hands_text',nemesis_lives='lives'}) do
                if state[key]~=nil then enemy[field]=state[key] end
            end
            session.cursor=session.cursor+1
            return
        end
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
            if session.cursor == cursor and not session.failure then
                if session.run.source=='action_log' then
                    session.cursor=session.cursor+1
                    if entry.kind=='action' then session.done=session.done+1 end
                    session.consumed=now
                    session.signature=nil
                    S.status('Replay '..progress()..' - '..entry.text)
                else session.issued=now end
            end
            session.waiting_since = nil
        else
            waiting(detail or 'the game')
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
