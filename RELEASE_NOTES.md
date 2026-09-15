# Balatro Replayer 2.0.5

Fix the 2.0.4 stall on the final hand of PvP. Once Multiplayer reports the score and queued hand effects finish, the replay can deliver the opponent result even while Multiplayer remains in HAND_PLAYED. Discard completion protection remains in place.

Validation: all five Lua suites, including exhausted-hand PvP, play/discard completion and offline score-report regressions. Full in-game playback remains unverified. Restart Balatro and replay from the beginning.
