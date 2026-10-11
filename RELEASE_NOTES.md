# MP Replayer 3.2.4

- Preserve the current hand sorting mode when a logged permutation matches both rank and suit sorting. After a suit-changing Tarot such as The Star, choosing the wrong mode reordered later draws, played a Blue Seal card that should have stayed in hand, and stopped the replay inside an Arcana Pack when the expected Venus was missing.
- Allow Take Over after a replay failure, including inside packs. Hand Back restores the stopped checkpoint and its failure instead of attempting the blocked action again.

Validation: regression tests were saved before execution; all 11 available Lua suites pass with Balatro's macOS LuaJIT. Both recordings in the supplied Downloads log completed in-game at 128x (256 and 415 replayed actions; automatic ante bookkeeping is excluded). The reported second recording reached the replay end screen after the Arcana Pack. In-game Take Over allowed a Hermit to be used from the stopped pack, and Hand Back restored the pack and money. Temporary tracing and automatic loading were removed. The Windows-only picker suite was not run on macOS.

# MP Replayer 3.2.3

- Resolve ambiguous consumable purchases using later named-card evidence. Multiplayer records Buy and Buy & Use identically; when a generated copy makes the initial inference inconsistent, retry playback with the alternative purchase mode. Each alternative is tried once, and no recorded action is skipped or card substituted. Automatic recovery is disabled during Take Over or an external action recording.
- Apply scoring-time joker drags after hand evaluation, preserving the evaluated score while still moving the jokers during the animation.
- Preserve the logged deck and lobby options through queued menu transitions and automatic restarts. Keep the selected replay speed during recovery.

Validation: regression tests were written before execution; all 11 available Lua suites pass with Balatro's macOS LuaJIT. The Downloads replay completed all 417 actions in-game at 128x, including automatic purchase recovery, and reached the replay end screen. All 37 recorded PvP hand scores matched the log. Temporary diagnostics and automatic log loading were removed. The Windows-only picker suite was not run on macOS.
