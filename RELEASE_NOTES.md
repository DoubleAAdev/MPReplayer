# MP Replayer 3.2.3

- Resolve ambiguous consumable purchases using later named-card evidence. Multiplayer records Buy and Buy & Use identically; when a generated copy makes the initial inference inconsistent, retry playback with the alternative purchase mode. Each alternative is tried once, and no recorded action is skipped or card substituted. Automatic recovery is disabled during Take Over or an external action recording.
- Apply scoring-time joker drags after hand evaluation, preserving the evaluated score while still moving the jokers during the animation.
- Preserve the logged deck and lobby options through queued menu transitions and automatic restarts. Keep the selected replay speed during recovery.

Validation: regression tests were written before execution; all 11 available Lua suites pass with Balatro's macOS LuaJIT. The Downloads replay completed all 417 actions in-game at 128x, including automatic purchase recovery, and reached the replay end screen. All 37 recorded PvP hand scores matched the log. Temporary diagnostics and automatic log loading were removed. The Windows-only picker suite was not run on macOS.
