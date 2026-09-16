# MP Replayer 2.9.8

- Fix replays stalling after the last hand of a PvP blind when the log reorders the leftover hand while that hand scored.
- Perform such reorders during scoring, before the hand empties and endPvP is delivered.

Validation: ten Lua suites. Restart Balatro to load the update.

