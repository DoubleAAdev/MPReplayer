# Balatro Replayer v2.0.0

Load Observer Action Recorder v2.0.0 `.txt` exports or `.jsonl` journals. Single-player runs start with the recorded seed, deck and stake. Multiplayer recordings reconstruct the lobby and deliver captured PvP and opponent messages locally. Lovely-log replay remains supported.

Replay records preserve exact purchases, card slots, visible identities and hand sorting. The driver checks cards and settled hands, stops on divergence, and acknowledges each action once without requiring Multiplayer logging for single-player runs.

Use a fresh v2.0.0 recording for Multiplayer. Older single-player journals with setup can be re-exported with Observer v2.0.0. Resumed segments, challenges and unsupported custom network effects are not replayed. Match the original game and gameplay mod versions. Hidden information is not reconstructed.

Validation includes the real Observer server-exported text fixture, importer rejection cases, single-player importer/driver/session execution, Multiplayer event order and action acknowledgement, legacy driver/session tests, picker and lifecycle tests. A full live Multiplayer match was not played during this update.

Extract BalatroReplayer into your Balatro Mods folder and restart Balatro. Observer is optional during playback; install Observer v2.0.0 to record and export new runs.
