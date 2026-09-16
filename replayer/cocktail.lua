-- Always display the active Cocktail components, without changing the deck
-- selection, saved lobby option, RNG, or replay action stream.
return function()
    local M, hooked = {}, false
    function M.install()
        if hooked then return end
        local steps = SMODS and SMODS.DrawSteps or {}
        local step = steps.mp_back_cocktail or steps.back_cocktail
        if not step or type(step.func) ~= 'function' then return end
        hooked = true
        local original = step.func
        step.func = function(card, ...)
            local modifiers = G.GAME and G.GAME.modifiers
            if G.STAGE ~= G.STAGES.RUN or not modifiers or not modifiers.mp_cocktail then
                return original(card, ...)
            end
            local previous = modifiers.mp_cocktail_sticker
            modifiers.mp_cocktail_sticker = modifiers.mp_cocktail
            local ok, result = pcall(original, card, ...)
            modifiers.mp_cocktail_sticker = previous
            if not ok then error(result, 0) end
            return result
        end
    end
    return M
end
