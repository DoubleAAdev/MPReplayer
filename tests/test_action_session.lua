local json=dofile(os.getenv('BALATRO_JSON_LUA') or (os.getenv('APPDATA')..'/Balatro/Mods/Steamodded/libs/json/json.lua'))
local JSON=dofile('json.lua')
local log=dofile('replayer/log.lua')(json.decode)
local importer=dofile('replayer/action-log.lua')(json.decode,log)
log.parse=importer.parse
local driver=dofile('replayer/driver.lua')(log)
local now,calls=0,0
love={filesystem={createDirectory=function()return true end,write=function()return true end}}
local card={facing='front',base={value='Ace',suit='Spades'},config={center={key='c_base'}},ability={perma_bonus=0}}
G={STAGE=1,STAGES={MAIN_MENU=1,RUN=2},STATES={SELECTING_HAND=1},STATE=1,STATE_COMPLETE=true,SETTINGS={},GAME={},FUNCS={},P_CENTERS={b_red={key='b_red',name='Red Deck',set='Back'}}}
MP=nil;BalatroActionRecorder=nil
Back=function(key)return {name='Red Deck',effect={center=G.P_CENTERS[key]}}end
G.hand={cards={card},highlighted={}}
function G.hand:unhighlight_all()self.highlighted={}end
function G.hand:add_to_highlighted(c)self.highlighted[#self.highlighted+1]=c end
G.FUNCS.can_play=function(e)e.config.button='play_cards_from_highlighted'end
G.FUNCS.play_cards_from_highlighted=function()calls=calls+1;G.hand.cards={}end
local session=dofile('replayer/session.lua')(log,driver,JSON,{clock=function()return now end})
function G:start_run(args)
 self.STAGE=2;self.GAME.pseudorandom={seed=args.seed};self.GAME.selected_back=self.GAME.viewed_back
 session.on_run_started() -- same lifecycle hook as production
end
function G:main_menu()self.STAGE=1;session.on_main_menu()end
local h={schema_version=2,index_base=1,recording={seed='TEST',deck='b_red',stake=1,partial=false}}
local ref={card='1',instance=1,index=1}
local a={cards={['1']={key='c_base',rank='Ace',suit='Spades'}},action={n=1,type='play',area='hand',cards={ref},hand_before={ref}}}
local o={observation={after_action=1,areas={},hand_after={},hand_boundary='settled'}}
local text='Replay header: '..json.encode(h)..'\nReplay record: '..json.encode(a)..'\nReplay record: '..json.encode(o)
session.load(text);session.start();assert(session.phase=='running',session.text)
for i=1,8 do now=now+.5;session.update(.5) end
assert(session.phase=='finished' and calls==1 and session.progress()=='1/1',session.text)
G:main_menu();assert(session.phase=='idle')
-- A mismatching card must fail before any input, even if the slot exists.
G.hand.cards={card};card.base.value='King';session.load(text);session.start()
for i=1,4 do now=now+.5;session.update(.5) end
assert(session.phase=='failed' and calls==1 and session.text:find('rank differs'),session.text)
session.stop();assert(session.phase=='idle')
-- Explicit purchase mode wins over legacy guesses about money movements.
assert(driver.purchase_mode({recorded={use_after_buy=true}}, {})=='buy_and_use')
assert(driver.purchase_mode({recorded={use_after_buy=false}}, {})=='buy')
print('PASS: real importer/driver/session single-player playback, start hook, one callback, post-hand validation, mismatch refusal and cleanup')
