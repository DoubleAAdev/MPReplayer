# MP Replayer 2.9.9

- Fix replays failing with "the game did not record" on a hand reorder right after a discard (regression in 2.9.8).
- Perform early reorders only while a played hand is scoring; reorders after a discard wait for the redraw to settle again.

Validation: ten Lua suites. Restart Balatro to load the update.

