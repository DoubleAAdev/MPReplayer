# Balatro Replayer 2.3.0

- Redesign the config with larger native Balatro buttons and shadowed text, arranged in two rows.
- Label loaded replays with stable numbers, players, deck, stake, seed, and complete/partial/old-replay status.
- Replace the config End Replay button with Remove Replay. Removing a running replay ends it and removes the selected entry from the in-memory list; source logs are untouched and reloading restores their entries.
- Move mod comparison counts and paged recorded/loaded version details into a dedicated Mod Details page with Back navigation.
- Keep End Replay in the pause menu, gameplay input locks, and the two-press mod-mismatch confirmation.

Validation: seven Lua suites, including replay removal, labels, details-page navigation, and existing replay/input regressions. Restart Balatro to load the new UI.
