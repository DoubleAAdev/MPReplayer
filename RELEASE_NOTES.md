# Balatro Replayer 2.2.0

- Lock player gameplay input during replay playback, including mouse/touch card dragging, joker and consumable reordering, sorting, selection, use/sell/buy actions, keyboard shortcuts, and gamepad reordering.
- Preserve hover inspection, run/deck information, and pause/resume access. The lock remains through completed or failed replays until End Replay returns to the menu.
- Replace Leave Lobby and Return to Lobby with one End Replay control, and remove the replay-unsafe Unstuck option. End Replay closes overlays and uses the existing cleanup path.
- Keep the two-press Start Replay confirmation for mismatched mods.

Validation: seven Lua suites, including input-device regression coverage, driver checks with the guard installed, and integration with the locally installed Multiplayer pause-menu definition.

Restart Balatro after installing. Live in-game verification requires loading this version; the running game is not restarted automatically.
