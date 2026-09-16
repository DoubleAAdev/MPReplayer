# Balatro Replayer 2.5.0

- Render Log Info as distinct aligned game rows with native deck and stake sprites and a Multiplayer icon.
- Clearly label Multiplayer, Single-player, Practice (solo), and unknown game types based on recorded metadata. Missing evidence is never treated as proof of a solo game.
- Hide pagination for short logs and rebuild icon rows when changing pages.
- Retain text fallbacks when a recorded deck or stake asset is unavailable. Only games containing supported replay records can be listed; ordinary unrecorded solo runs cannot be reconstructed.

Seven Lua suites passed, including list/icon construction and game-type classification. Restart Balatro to load the update.
