# MP Replayer

A Steamodded mod that replays a Multiplayer game from its Lovely log, action by action.

## Requirements

- [Steamodded](https://github.com/Steamodded/smods) 1.0.0 beta or newer
- The Multiplayer mod, at the version the log was played with or above (named in the log's manifest)

## Install

Copy this repository into `%APPDATA%\Balatro\Mods\MPReplayer`, or run `./scripts/install.ps1`. Restart Balatro.

## Use

1. Open **Mods > MP Replayer > Replays** and choose **Load Log** to pick a Lovely log (`%APPDATA%\Balatro\Mods\lovely\log`), or drop a `.log` file onto Balatro. A log can hold several games; **Next Replay** cycles through them.
2. From the main menu, choose **Start Replay**. The game joins a copy of the recorded lobby with the recorded seed, deck, stake, ruleset and options, then executes the logged actions in order. Progress is shown in `%APPDATA%\Balatro\mp_replayer\status.json`.
3. When the replay completes, choose **End Replay** from the pause menu. If Balatro Observer is installed, export the run from **Mods > Balatro Observer > Config > Open Action Recorder**.
4. Ending the replay returns to the main menu and restores normal Multiplayer play.

While a replay is active it's read-only: card dragging, selection, sorting, playing/discarding, purchases, sales and consumable use are all blocked. Menus, settings, and hover inspection still work.

## How it works

MP Replayer reads every logged player action (skipping the internal `set_ante_key` housekeeping line) and replays them in order through the same callbacks the game's buttons use — nothing skipped, repeated, or reordered. A lobby copy is used because Multiplayer's jokers, rulesets and PvP resolution only exist inside a lobby.

A replay stops and reports why if an action can't be executed as logged (wrong card in a slot, an unaffordable cost, a screen mismatch, or no response within 45 seconds), leaving the run at that point for inspection.

Replays don't write anything back into the Lovely log — nothing logs a replay as if it were a new game.

## Limits

- The Multiplayer version, ruleset, game mode, and deck must match the log, and installed mods should match what the log was played with. The **Compare Mods** tool in the config tab flags differences; **Start Replay** asks for confirmation when mods differ.
- Challenge runs aren't supported.
- A few rare cases (buy-vs-buy&use ambiguity, hand-order ties between identical cards, manual consumable reordering) are resolved heuristically and can cause an early stop — the mod explains why when it happens.
- The round timer runs faster than normal during replay; this affects nothing gameplay-related.
- Replayed games don't count toward Multiplayer match history or career stats.
