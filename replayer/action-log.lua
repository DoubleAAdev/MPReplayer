-- Action Recorder's exported text carries exact JSON records alongside the
-- human-readable history. Raw journals use the same records without prefixes.
return function(decode,log)
    local M={}
    local area_ids={shop_jokers=1,shop_booster=2,shop_vouchers=3,jokers=4,consumeables=5,hand=6,pack_cards=7}
    local messages={enemyInfo=true,enemyLocation=true,playerInfo=true,startBlind=true,endPvP=true,winGame=true,loseGame=true,
        asteroid=true,eatPizza=true,soldJoker=true,letsGoGamblingNemesis=true,spentLastShop=true,
        sendPhantom=true,removePhantom=true,magnet=true,magnetResponse=true}
    local function indices(cards)
        local slots={}
        for _,c in ipairs(cards or {}) do slots[#slots+1]=tostring(c.index) end
        local text=table.concat(slots,'.')
        log.indices(text)
        return text
    end
    function M.parse(text)
        assert(type(text)=='string' and #text<=128*1024*1024,'Action log exceeds 128 MB')
        local header,records={},{}
        local annotated=text:find('Replay header: ',1,true)~=nil
        for line in (text..'\n'):gmatch('(.-)\r?\n') do
            local h=annotated and line:match('^Replay header: (.*)$')
            local r=annotated and line:match('^Replay record: (.*)$')
            if h then assert(not header.recording,'Duplicate replay header');header=decode(h)
            elseif r then records[#records+1]=decode(r)
            elseif not annotated and line:match('%S') then
                local value=decode(line)
                if not header.recording then header=value else records[#records+1]=value end
            end
        end
        assert((header.schema_version==1 or header.schema_version==2) and header.index_base==1 and type(header.recording)=='table','Missing action-log header; export with Observer 2.0.0')
        local setup=header.recording
        assert(not setup.partial,'Resumed recordings cannot recreate the beginning of a run')
        assert(type(setup.seed)=='string' and setup.seed~='' and type(setup.deck)=='string','Recording is missing seed or deck')
        assert(type(setup.stake)=='number' and setup.stake>=1 and setup.stake%1==0,'Invalid stake')
        local mp=setup.multiplayer
        assert(not mp or setup.replay_format==2,'This older Multiplayer recording lacks replay messages; record with Observer 2.0.0')
        local manifest={seed=setup.seed,deck=setup.deck,stake=setup.stake,challenge=setup.challenge,lobby_config={},mods=setup.mods,hand_sort=setup.hand_sort}
        if mp then for k,v in pairs(mp) do manifest[k]=v end end
        manifest.deck=setup.deck
        local run={source='action_log',singleplayer=not mp,manifest=manifest,manifest_text='(Action Recorder setup)',entries={},actions=0,complete=false}
        local catalog,pending_blind={},false
        local actions,outcomes={},{}
        local function resolve(list)
            if list==nil then return nil end
            assert(type(list)=='table','Invalid card list')
            for _,c in ipairs(list) do
                assert(type(c)=='table' and type(c.index)=='number' and c.index>=1 and c.index%1==0,'Invalid card position')
                if not c.hidden then c.descriptor=assert(catalog[tostring(c.card)],'Unknown card descriptor') end
            end
            return list
        end
        local function add(e) e.position=#run.entries+1;run.entries[#run.entries+1]=e end
        for _,record in ipairs(records) do
            assert(type(record)=='table','Invalid replay record')
            for id,description in pairs(record.cards or {}) do
                assert(not catalog[id] and type(description)=='table','Duplicate or invalid card descriptor')
                catalog[id]=description
            end
            if record.action then
                local a=record.action
                assert(a.n==run.actions+1,'Missing or duplicate action sequence')
                run.actions=a.n;actions[a.n]=a
                local e={kind='action',seq=a.n,op=a.type,args={},text=a.type,recorded=a,money={}}
                a.cards=resolve(a.cards);a.targets=resolve(a.targets);a.hand_before=resolve(a.hand_before)
                local op=a.type
                if op=='buy' or op=='sell' or op=='use' or op=='pack_pick' then assert(a.cards and #a.cards==1,'Expected exactly one card') end
                if op=='play' or op=='discard' then e.args={indices(a.cards)}
                elseif op=='buy' or op=='sell' then e.args={tostring(assert(area_ids[a.area],'Invalid area')),indices(a.cards)}
                elseif op=='use' or op=='pack_pick' then e.args={indices(a.cards)};if a.targets and #a.targets>0 then e.args[2]=indices(a.targets) end
                elseif op=='reorder' then
                    assert(type(a.order)=='table','Missing reorder permutation')
                    local parts={};for _,i in ipairs(a.order) do parts[#parts+1]=tostring(i) end
                    e.args={tostring(assert(area_ids[a.area],'Invalid reorder area')),table.concat(parts,'.')};log.indices(e.args[2])
                elseif op=='select_blind' or op=='skip_blind' or op=='pack_skip' then e.args={'0'}
                elseif op=='ready_blind' then assert(a.value=='0' or a.value=='1','Invalid ready state');e.args={a.value}
                elseif op~='reroll' then error('Unsupported recorded action '..tostring(op)) end
                if mp and op=='select_blind' and pending_blind then e.automatic_blind=true;pending_blind=false end
                e.text=op..(#e.args>0 and ' '..table.concat(e.args,' ') or '')
                add(e)
            elseif record.network then
                local fields=record.network
                assert(mp and messages[fields.action],'Unsupported Multiplayer message')
                for _,v in pairs(fields) do assert(type(v)=='string' or type(v)=='number' or type(v)=='boolean','Invalid Multiplayer field') end
                if fields.action=='startBlind' then pending_blind=true end
                add({kind='message',action=fields.action,fields=fields})
            elseif record.opponent then
                assert(mp,'Opponent state outside Multiplayer')
                local public={}
                for _,key in ipairs({'nemesis_location','nemesis_location_blind','nemesis_score','nemesis_hands','nemesis_lives'}) do
                    local v=record.opponent[key]
                    assert(v==nil or type(v)=='string' or type(v)=='number','Invalid opponent state')
                    public[key]=v
                end
                add({kind='opponent',state=public})
            elseif record.observation then
                local o=record.observation
                if o.hand_after then
                    assert(type(o.after_action)=='number' and o.after_action<=run.actions,'Invalid hand outcome')
                    assert(actions[o.after_action] and actions[o.after_action].hand_before and not outcomes[o.after_action],'Orphan or duplicate hand outcome')
                    outcomes[o.after_action]=true
                    -- Before-next-input snapshots can include the next drag's order;
                    -- the next action validates that exact boundary instead.
                    if o.hand_boundary=='settled' then add({kind='hand_check',cards=resolve(o.hand_after),text='hand after action '..o.after_action}) end
                end
            else error('Unknown action-log record') end
        end
        assert(run.actions>0,'No actions in this recording')
        return {run}
    end
    return M
end
