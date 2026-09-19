# MP Replayer 3.1.0

- Add 0.5x and 1.5x to the speed control: the arrows step 0.5x, 1x, 1.5x, 2x, 4x ... 512x and wrap at either end. Below 2x there is no extra update to run, so those speeds scale the frame's dt instead.
- Add a Take Over button under Pause, the same size and padding. It hands every control back to the player - cards, consumables, the shop, the keyboard - and stops the replay: nothing is performed, nothing from the log is delivered, and the player's own moves are logged the way a normal game logs them instead of being checked against the log. Hand Back locks the controls again.
- Play the PvP blind against the opponent from the log. Starting a replay reads every PvP blind it holds: who reached it first, and the opponent's score after each of their hands. At the blind the player's Ready sends the startBlind the server would have sent, the opponent's score and hands left step with the player's hands, and once the player is out of hands the higher score takes the blind and the loser loses a life, with the comeback bonus and round-loss gold rules Multiplayer applies. A life count reaching zero ends the run and brings up the replay's end screen.
- Keep End Replay as the only exit in the pause menu for as long as a replay is running. It followed the input lock before, so Take Over brought back Unstuck, Return to Lobby and Leave Lobby - three ways to drop the run mid-replay.
- Clear a leftover consumable interrupt before a replay starts its run. A replay stopped while a consumable was resolving left Balatro's G.TAROT_INTERRUPT set, and with Handy installed the next run start crashed in Steamodded's handle_card_limit on a nil extra_slots_used.

Known limit: a normal round lost during Take Over costs no life, because in a live game the server is what takes it.

Validation: ten Lua suites. Restart Balatro to load the update.
