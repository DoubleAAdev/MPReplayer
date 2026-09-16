# MP Replayer 2.9.12

- Fix free shop consumables (such as Astronomer planets) always being kept: like paid ones, a later use of their slot now decides between Buy and Buy & Use. A kept Planet X filled the rack, so a later Hermit had no room.
- Add a fast-forward button above the deck during replays: 1x, 2x, 4x ... 512x, then back to 1x. It runs more game updates per frame, and replay timers follow game time.

Validation: ten Lua suites. Restart Balatro to load the update.

