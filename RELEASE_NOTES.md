# MP Replayer 2.9.16

- Fix the round deck check stopping a replay at its very start when the logged game was started twice: the abandoned start printed its Idol roll after the real game's manifest. Idol rolls now count only after the first action, in the log and in the replay.

Validation: ten Lua suites. Restart Balatro to load the update.

