# MP Replayer 3.2.3

- Add a native macOS log picker with Unicode filename and cancellation support.
- Wait for Cash Out before replaying shop consumable uses and sales after the final PvP hand.
- Resolve ambiguous consumable purchases using later named-card evidence. Multiplayer records Buy and Buy & Use identically; when a generated copy makes the initial inference inconsistent, retry playback with the alternative purchase mode. Each alternative is tried once, and no recorded action is skipped or card substituted. Automatic recovery is disabled during Take Over or an external action recording.
- Apply scoring-time joker drags after hand evaluation, preserving the evaluated score while still moving the jokers during the animation.
- Preserve the logged deck and lobby options through queued menu transitions and automatic restarts. Keep the selected replay speed during recovery.

Validation: all 13 Lua suites passed on Windows with Balatro's LuaJIT, including Windows and macOS picker checks and the installed-game UI checks. Earlier macOS in-game validation completed all 417 replay actions at 128x and matched all 37 recorded PvP hand scores. The test suites and runner remain on the tests branch and are excluded from main and the release ZIP.
