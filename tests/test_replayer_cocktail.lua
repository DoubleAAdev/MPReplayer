local actual, seen, fail = {'b_red', 'b_blue', 'b_yellow'}, nil, false
local hidden = {}
G = {STAGE = 2, STAGES = {MAIN_MENU = 1, RUN = 2}, GAME = {modifiers = {
    mp_cocktail = actual, mp_cocktail_sticker = hidden}}}
SMODS = {DrawSteps = {mp_back_cocktail = {func = function()
    seen = G.GAME.modifiers.mp_cocktail_sticker
    if fail then error('draw failure') end
    return 'drawn'
end}}}
local hook = dofile('replayer/cocktail.lua')()
hook.install(); hook.install()
local draw = SMODS.DrawSteps.mp_back_cocktail.func
assert(draw({}) == 'drawn' and seen == actual)
assert(G.GAME.modifiers.mp_cocktail_sticker == hidden, 'hidden setting must be restored')
local forced = {'b_red'}
G.GAME.modifiers.mp_cocktail_sticker = forced
draw({}); assert(seen == actual and G.GAME.modifiers.mp_cocktail_sticker == forced)
fail = true; assert(not pcall(draw, {}))
assert(G.GAME.modifiers.mp_cocktail_sticker == forced, 'restore state after a draw error')
fail = false; G.STAGE = G.STAGES.MAIN_MENU
draw({}); assert(seen == forced)
G.STAGE = G.STAGES.RUN; G.GAME.modifiers.mp_cocktail = nil
draw({}); assert(seen == forced, 'ordinary decks keep their normal drawing')
print('PASS: all Cocktail components display with hidden/forced settings, and drawing restores game state')
