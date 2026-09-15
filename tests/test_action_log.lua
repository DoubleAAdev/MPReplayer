-- Uses the same JSON decoder Steamodded loads in Balatro.
local json=dofile(os.getenv('BALATRO_JSON_LUA') or (os.getenv('APPDATA')..'/Balatro/Mods/Steamodded/libs/json/json.lua'))
local log=dofile('replayer/log.lua')(json.decode)
local importer=dofile('replayer/action-log.lua')(json.decode,log)
local header={schema_version=2,index_base=1,recording={seed='TEST',deck='b_red',stake=1,partial=false,replay_format=2}}
local function text(records,h)
    local lines={'Replay header: '..json.encode(h or header)}
    for _,r in ipairs(records) do lines[#lines+1]='Replay record: '..json.encode(r) end
    return table.concat(lines,'\n')
end
local description={key='c_base',rank='Ace',suit='Spades',edition={},stickers={},perma_bonus=0}
local ref={card='1',instance=1,index=1}
local records={{cards={['1']=description},action={n=1,type='play',area='hand',cards={ref},hand_before={ref}}},
    {observation={after_action=1,areas={},hand_after={},hand_boundary='settled'}},
    {action={n=2,type='reroll',price=5}}}
local run=importer.parse(text(records))[1]
assert(run.singleplayer and run.actions==2 and #run.entries==3)
assert(run.entries[1].args[1]=='1' and run.entries[1].recorded.hand_before[1].descriptor.rank=='Ace')
assert(run.entries[2].kind=='hand_check')
local function fails(value,pattern)local ok,e=pcall(importer.parse,value);assert(not ok and tostring(e):find(pattern),tostring(e))end
header.recording.partial=true;fails(text(records),'Resumed');header.recording.partial=false
records[3].action.n=3;fails(text(records),'sequence');records[3].action.n=2
header.recording.seed=nil;fails(text(records),'seed');header.recording.seed='TEST'
records[1].action.cards[1].card='missing';fails(text(records),'Unknown card');records[1].action.cards[1].card='1'
header.recording.multiplayer={ruleset='r',gamemode='g',mod_version='0.5.5',lobby_config={}}
records={{action={n=1,type='ready_blind',value='1'}},{network={action='startBlind',firstPlayer='host'}},
    {action={n=2,type='select_blind',blind={key='bl_mp_nemesis'}}},{opponent={nemesis_location='Shop',nemesis_score='???'}},
    {network={action='enemyInfo',score='12000',handsLeft=2}}}
run=importer.parse(text(records))[1]
assert(not run.singleplayer and run.entries[3].automatic_blind)
assert(run.entries[2].fields.firstPlayer=='host' and run.entries[5].fields.score=='12000')
records[5].network.action='startGame';fails(text(records),'Unsupported Multiplayer');records[5].network.action='enemyInfo'
header.recording.replay_format=nil;fails(text(records),'older Multiplayer');header.recording.replay_format=2
-- A server-produced fixture exercises the actual text export without reconstructing it here.
local f=io.open('tests/fixtures/action-recorder-v2.txt','rb')
assert(f,'Missing cross-repository export fixture');local exported=f:read('*a');f:close()
local exportedRun=importer.parse(exported)[1]
assert(exportedRun.actions==13 and exportedRun.manifest.seed=='REPLAY42')
print('PASS: actual exported text import, single-player and Multiplayer routing, ordered network events, card references, hand outcomes and invalid-input rejection')

fails('Balatro action log | old\nRun setup: {}\n1. play', 'original %.jsonl')
assert(importer.parse(string.char(239,187,191)..exported)[1].actions==13)
local raw=json.encode({schema_version=2,index_base=1,recording={seed='TEST',deck='b_red',stake=1}})..'\n'..json.encode({action={n=1,type='reroll'}})
assert(importer.parse(string.char(239,187,191)..raw)[1].actions==1)
print('PASS: legacy text recovery guidance and UTF-8 BOM imports')