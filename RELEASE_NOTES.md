# MP Replayer 2.9.19

- Fix replays stalling on a joker drag the player made right after a round ended, before the game removed a joker (such as an eaten Pizza on the round results). Joker drags are now done while the game is still resolving, once the replay has passed as many round ends as the log shows before the drag and the joker count has matched for an update.

Validation: ten Lua suites. Restart Balatro to load the update.

