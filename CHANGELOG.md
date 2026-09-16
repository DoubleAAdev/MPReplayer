## 2.4.0

- Simplify the selected replay summary: readable deck names, separate seed, and a short ready status without duplicated identifiers or export paths.
- Add the native Log Info tab alongside the mod description and Config. Show the source filename and game count, with paged player-versus-player, deck, and stake entries for every playable game in the original log.
- Rename Mod Details to Compare Replay Mods to explain its purpose.
- Keep source-log information after entries are removed from the loaded replay list.

## 2.3.0

- Redesign the config with larger native Balatro buttons and shadowed text, arranged in two rows.
- Label loaded replays with stable numbers, players, deck, stake, seed, and complete/partial/old-replay status.
- Replace the config End Replay button with Remove Replay. Removing a running replay ends it and removes the selected entry from the in-memory list; source logs are untouched and reloading restores their entries.
- Move mod comparison counts and paged recorded/loaded version details into a dedicated Mod Details page with Back navigation.
- Keep End Replay in the pause menu, gameplay input locks, and the two-press mod-mismatch confirmation.

## 2.2.2

- Enable View Deck by clicking the deck pile during replays, including mouse, touch, and controller click dispatch.
- Keep card selection, dragging, and controller reordering locked, including on the deck pile.

## 2.2.1

- Restore Saturn, Settings, Mods, Stats, Collection, Customize Deck, and Lobby Info access during replays.
- Allow active menu controls, including submenu navigation, toggles, sliders, text fields, and scrolling, while keeping background gameplay and card reordering locked.
- Preserve End Replay and the two-press mismatch confirmation.

## 2.2.0

- Lock player gameplay input during replay playback, including mouse/touch card dragging, joker and consumable reordering, sorting, selection, use/sell/buy actions, keyboard shortcuts, and gamepad reordering.
- Preserve hover inspection, run/deck information, and pause/resume access. The lock remains through completed or failed replays until End Replay returns to the menu.
- Replace Leave Lobby and Return to Lobby with one End Replay control, and remove the replay-unsafe Unstuck option. End Replay closes overlays and uses the existing cleanup path.
- Keep the two-press Start Replay confirmation for mismatched mods.

## 2.1.0

- Replace the overflowing mod mismatch error with missing, extra, and changed-version counts and paged details of logged versus loaded mods.
- Keep the two-press Start Replay confirmation; changing the selected run or loaded mod list requires fresh confirmation.
- Bound all four status lines, retaining complete diagnostics in status.json.

# 2.0.5

- Fix a deadlock after the final PvP hand: Multiplayer intentionally waits in HAND_PLAYED for the opponent result.
- Recognize the completed score report and wait for remaining effects before releasing incoming messages. Keep discard completion protection and suppress outgoing replay traffic.

# 2.0.4

- Wait for played/discarded hands, redraws, and queued effects to finish after the input is acknowledged.
- Hold subsequent opponent messages and actions until completion, preventing round-end messages from interrupting the hand. Stop with a source-line diagnostic if resolution stalls.
- Regression coverage verifies each hand input runs once and pending effects complete before the next message or action.

# 2.0.3

- Restore the pre-v2.0 Replayer implementation from v1.3.0: load original Multiplayer Lovely logs and replay through the recorded lobby.
- Remove Action Recorder text/JSONL replay support. Observer and Action Recorder are unchanged.

# 2.0.2

- Start action-log runs through Balatro's normal transition so the title screen is removed before the run appears.
- Wait for the run-start hook before executing replay actions.

# 2.0.1

- Explain how to recover older text exports from the original JSONL journal instead of showing a JSON parser error.
- Accept UTF-8 BOMs in action-log exports and journals.

# 2.0.0

- Load Action Recorder text exports and JSONL journals, retaining Lovely-log support.
- Start single-player seed/deck/stake runs and recreate Multiplayer lobbies with recorded opponent events.
- Validate physical cards and settled hands; preserve exact purchases, targets and sorting.
- Acknowledge action-log callbacks once without depending on Multiplayer RLOG hooks.
- Accept .txt/.jsonl files in the picker and drag/drop; reject incomplete setup, resumed runs and unsupported inputs clearly.

# 1.3.0

- Keep a replay out of the Lovely log entirely. From Start Replay until the game is back at the main menu, every line Multiplayer logs is dropped: the manifest it wrote at the start of each replayed run, the money, the opponent's messages handed back to it, its status lines. A replay's log used to open with a manifest like a real game's, which is how an old replay of a game came to look like a second game. Other mods' lines are unaffected.

# 1.2.0

- Drop the Balatro Observer requirement. The mod no longer depends on Balatro Observer and a replay starts without Action Recorder. When Action Recorder is installed and recording, the replay still stops if the recording stops, and the closing status still names the recording.

# 1.1.0

- Check the mods before replaying. Start Replay compares the mods and versions the log's manifest lists with the ones installed, leaving out Balatro Observer and Balatro Replayer, and names every difference; pressing it again replays anyway. A game recorded under Steamodded 1.0.0~BETA-1620a rolls a different boss blind under Steamodded 26.829.0, so such a replay stopped at its first boss with no hint why.
- Name logs written by old replays. Replays before this mod wrote their own run into the Lovely log; loading one now says it was written by an old replay, not a game you played.
- Show the status on up to four lines in the config tab instead of one line running off the panel.

# 1.0.0

- The Replayer from Balatro Observer 1.10.0, as its own mod. Its buttons are in **Mods > Balatro Replayer > Config**; it needs Balatro Observer installed for Action Recorder. Behaviour is unchanged: the log's actions are filtered out of it and executed in order, each once, and the replay stops at the first action it cannot execute. Nothing is written to the Lovely log.
