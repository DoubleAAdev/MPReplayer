# MP Replayer 2.9.13

- Stop at the first round whose deck differs from the log: each round's IDOL_ROLL deck counts must match the logged ones, and the failure names the differing cards and log line.
- Record the hand before every replayed action in mp_replayer/status.json ("hands") for diagnosing drift.
- Replace the fast-forward button with arrows that halve or double the speed between 1x and 512x, placed higher above the deck.

Validation: ten Lua suites. Restart Balatro to load the update.

