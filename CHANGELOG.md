# MP Replayer 2.9.13

- Stop at the first round whose deck differs from the log: each round's IDOL_ROLL deck counts must match the logged ones, and the failure names the differing cards and log line.
- Record the hand before every replayed action in mp_replayer/status.json ("hands") for diagnosing drift.
- Replace the fast-forward button with arrows that halve or double the speed between 1x and 512x, placed higher above the deck.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.12

- Fix free shop consumables (such as Astronomer planets) always being kept: like paid ones, a later use of their slot now decides between Buy and Buy & Use. A kept Planet X filled the rack, so a later Hermit had no room.
- Add a fast-forward button above the deck during replays: 1x, 2x, 4x ... 512x, then back to 1x. It runs more game updates per frame, and replay timers follow game time.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.11

- Fix replays running short of money: a consumable the log used (or card it sold) after reaching the shop is no longer used on the round results before cashing out. The Hermit doubled the pre-cash-out money, and the gap grew through interest until a purchase was refused.
- Read the shop setLocation line to mark which actions came after the cash out.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.10

- Record the money held after every replayed action in mp_replayer/status.json ("dollars") and on Debug rows, to locate where a replay's economy leaves the log's.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.9

- Fix replays failing with "the game did not record" on a hand reorder right after a discard (regression in 2.9.8).
- Perform early reorders only while a played hand is scoring; reorders after a discard wait for the redraw to settle again.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.8

- Fix replays stalling after the last hand of a PvP blind when the log reorders the leftover hand while that hand scored.
- Perform such reorders during scoring, before the hand empties and endPvP is delivered.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.7

- Show only Debug in the MP Replayer menu while a replay is active, including failed/finished sessions awaiting exit.
- Hide the description and Replays tabs during playback, removing access to replay-start controls.
- Restore the normal menu after ending the replay; keep Debug pagination working in its sole tab.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.6

- Open Debug from the mod gear while a replay session is active; hide the tab after exiting.
- Show replay progress, status, game state, errors, seed and paginated actions/network events with log line numbers.
- Label entries DONE, NEXT, SENT or WAIT and offer a Current action shortcut.
- Keep diagnostics read-only and retain the clean Replays page.

Validation: ten Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.5

- Show a Replay already active popup when Start Replay is pressed during an existing replay.
- Explain that the current replay must end first, with a Back to Replays button.
- Preserve the current replay and selection, including failed or finished sessions awaiting exit.

Validation: nine Lua suites. Restart Balatro to load the update.

# MP Replayer 2.9.4

- Remove every status-text row beneath the replay list, including cancellation, progress and error messages.
- Keep diagnostics in status.json and retain replay-start confirmation dialogs.

Validation: nine Lua suites passed. Restart Balatro to load the update.

# MP Replayer 2.9.3

- Fix access to mod configuration gears and nested settings in Steamodded's scrollable menus while a replay is running, failed or finished.
- Keep gameplay buttons, card movement and background controls locked during replay sessions.
- Always show the active Cocktail deck icons during runs, including replays, even when Show active decks during run is disabled.
- Preserve the saved Cocktail setting, selected decks and replay actions.

Validation: nine Lua suites, including nested config navigation and Cocktail rendering with hidden and forced decks. Restart Balatro to load the update.

# MP Replayer 2.9.2

- Explain Steamodded compatibility explicitly in the replay-start confirmation.
- Show the loaded version and recommend 1.0.0~BETA-1620a or newer for older or unverifiable builds.
- Accept 1620a and later releases without an outdated-version warning; preserve other mod mismatch warnings.
- Keep Cancel and Continue and recheck the loaded version before starting.

Validation: eight Lua suites passed, including version boundaries and popup controls. Restart Balatro to load the update.

# MP Replayer 2.9.1

- Replace Multiplayer's replay result screen with a friendly Replay Ended summary.
- Show the deck artwork, stake chip, seed, recorded action count and named winner/loser.
- Mark partial or missing outcomes without guessing a winner.
- Restart the same replay, return to the Replays tab, or exit to Balatro's main menu after replay cleanup.
- Preserve normal Multiplayer end screens outside replays.

Validation: eight Lua suites, including native UI construction, navigation, input access and early-end handling. A live game visual check is still needed.
Restart Balatro to load this update.

# MP Replayer 2.9.0

- Rename the mod ID, repository, installation folder, metadata and release packages to MP Replayer.
- Store replay diagnostics in mp_replayer and preserve previous diagnostics during installation.
- Migrate the old installation out of the Mods folder to prevent duplicate loading.
- Ignore both current and legacy replayer IDs when comparing recorded mods.

Restart Balatro after installing to load the new identity.

## 2.8.4

- Rename the displayed mod to MP Replayer and use Balatro's Boss Tag icon for its loaded-mod entry.
- Make Cancel red in the mismatch popup.
- Preserve native menu button typography, label layout and dimensions when replacing lobby exits with End Replay.
- Retain the MPReplayer internal ID and installation folder for compatibility.

## 2.8.3

- Replace the critical-mod second-press warning with a concise popup offering Cancel and Continue.
- Cancel returns to Replays without starting. Continue revalidates the selected replay and mod signature; changed mods prompt again.
- Noncritical differences continue to start immediately.

## 2.8.2

- Hide the routine Ready to replay footer without reserving empty space. Warnings, errors, and replay progress remain visible.

## 2.8.1

- Simplify Compare Mods to a short summary and one large difference card.
- Remove repeated replay labels, category counts, and explanatory headers; show navigation only for multiple detail pages.
- Keep full mismatch details and compatibility checks unchanged.

## 2.8.0

- Remove the Config tab and rename Log Info to Replays.
- Place Load Log and Compare Mods above the source filename and replay list.
- Refresh the list immediately after loading a log and return comparison-page navigation to the native Replays tab.
- Preserve per-game Start Replay, named stakes, large deck icons, and critical-mismatch confirmation.

## 2.7.1

- Remove the game-type badge from replay list rows.
- Widen each row and its player-name column, and enlarge the deck sprite while preserving its aspect ratio.
- Keep the side index, aligned player/stake rows, and direct Start Replay button.

## 2.7.0

- Place replay indices in a separate left column, align player names, remove deck text, and stack stake icon/name directly under the multiplayer badge.
- Only potentially critical mod differences require two presses. Reviewed Handy and JokerDisplay control/display differences remain visible but do not block a first press; unknown mod IDs remain potentially critical.
- Show the compatibility assessment on Compare Replay Mods. Existing hard requirements, including Multiplayer version compatibility, remain enforced.

## 2.6.0

- Add Start Replay beside each game in Log Info, selecting that exact game even after pagination or removal from the replay list.
- Preserve the two-press mod mismatch confirmation and show status messages on the list page.
- Replace numeric stake labels with localized stake names, including White Stake, in both Log Info and Config.

## 2.5.0

- Render Log Info as distinct aligned game rows with native deck and stake sprites and a Multiplayer icon.
- Clearly label Multiplayer, Single-player, Practice (solo), and unknown game types based on recorded metadata. Missing evidence is never treated as proof of a solo game.
- Hide pagination for short logs and rebuild icon rows when changing pages.
- Retain text fallbacks when a recorded deck or stake asset is unavailable. Only games containing supported replay records can be listed; ordinary unrecorded solo runs cannot be reconstructed.

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

- Check the mods before replaying. Start Replay compares the mods and versions the log's manifest lists with the ones installed, leaving out Balatro Observer and MP Replayer, and names every difference; pressing it again replays anyway. A game recorded under Steamodded 1.0.0~BETA-1620a rolls a different boss blind under Steamodded 26.829.0, so such a replay stopped at its first boss with no hint why.
- Name logs written by old replays. Replays before this mod wrote their own run into the Lovely log; loading one now says it was written by an old replay, not a game you played.
- Show the status on up to four lines in the config tab instead of one line running off the panel.

# 1.0.0

- The Replayer from Balatro Observer 1.10.0, as its own mod. Its buttons are in **Mods > MP Replayer > Config**; it needs Balatro Observer installed for Action Recorder. Behaviour is unchanged: the log's actions are filtered out of it and executed in order, each once, and the replay stops at the first action it cannot execute. Nothing is written to the Lovely log.
