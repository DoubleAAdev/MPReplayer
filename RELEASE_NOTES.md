# Balatro Replayer 2.0.4

Fix replay advancing after a play/discard callback while the hand is still resolving. Subsequent network messages and inputs now wait for scoring, redraws, and queued effects. Original Lovely-log loading is unchanged.

Restart Balatro and replay the log from the beginning; an already-diverged run cannot be repaired by this update.

Validation: five Lua suites, including play/discard completion regressions. Full in-game replay of the supplied log remains unverified.
