# Balatro Replayer

A Steamodded mod that replays a Multiplayer game from its Lovely log, action by action. With [Balatro Observer](https://github.com/DoubleAAdev/BalatroObserver) installed, its Action Recorder records the replay with card identities.

It was part of Balatro Observer until version 1.10.0 and moved here unchanged.

## Requirements

- [Steamodded](https://github.com/Steamodded/smods) 1.0.0 beta or newer
- The Multiplayer mod, at the version the log was played with (the log's manifest names it)

## Install

Copy this repository into `%APPDATA%\Balatro\Mods\BalatroReplayer`, or run `./scripts/install.ps1`, which copies the mod files there and verifies each one. Restart Balatro.

## Tests

`python scripts/run-lua-tests.py` runs every suite in `tests/` with Balatro's own LuaJIT.

## Use

1. Open **Mods > Balatro Replayer > Config**. Choose **Load Log** and pick the Lovely log of the game (`%APPDATA%\Balatro\Mods\lovely\log`). Dropping a `.log` onto Balatro also works. A log holding several games shows one run at a time, labeled by replay number, players, deck, stake, seed, and completion status; **Next Replay** cycles through them. Replays made before Balatro Replayer wrote their own run into the Lovely log, so some logs in that folder hold games nobody played; loading one says **written by an old replay, not a game you played**.
**Log Info** is the third mod-menu tab. It shows the source filename and all playable games in that log, with players, deck, and stake. Previous/Next pages cover longer logs; removing a replay list entry does not change this source inventory.

2. Loading writes the chosen run's actions to `%APPDATA%\Balatro\balatro_replayer\actions.txt`, one row per action — exactly what the replay will execute.
3. From the main menu, choose **Start Replay**. The game joins a copy of the recorded lobby, starts the recorded seed, deck, stake, ruleset and options, and executes the actions in order. Watch the status line in the config tab or `%APPDATA%\Balatro\balatro_replayer\status.json`.
4. When the status says the replay is complete, choose **End Replay** from the pause menu. If Balatro Observer is installed, open **Mods > Balatro Observer > Config > Open Action Recorder** and export the run named in the status. Without Balatro Observer the replay runs the same, with nothing recorded.
5. Ending the replay returns to the main menu, dismantles the lobby copy, restores player controls, and leaves Multiplayer as it was.

**End Replay** replaces **Leave Lobby** and **Return to Lobby** during playback in the pause menu. The config instead offers **Remove Replay**, which ends the selected replay if active and removes it from the loaded list. Source logs are kept; loading a log again restores its entries. Pausing or opening a menu only pauses the replay.

Replays are read-only until you end them: mouse/touch card dragging, card selection, sorting, playing/discarding, purchases, sales, consumable use, and keyboard/gamepad gameplay shortcuts are blocked. Hover inspection, run/deck information, Lobby Info, and all pause-menu entries remain available, including Saturn, Settings, Mods, Stats, Collection, and Customize Deck. Submenu buttons, toggles, sliders, text fields, and scrolling work while the replay is paused. The lock also applies when playback has completed or stopped on a mismatch, so manual input cannot alter the displayed result. Logged replay actions and game effects continue normally.

## What is executed

The actions are filtered out of the log: every `MP_RLOG:` line that is not a `Client` line, except `set_ante_key`, up to the run's `END` line. `set_ante_key` is not something the player did — Multiplayer rolls a throwaway key when a blind is selected so the ante cannot be raised twice at once, and its value changes no card.

Those actions are executed in log order, each exactly once, through the same game callbacks the buttons use. Nothing is skipped, repeated, reordered or added. Two other kinds of line are read, and neither is executed:

- `Client sent message: action:` lines name the card, cost or blind each action touched. In the shop `use 1` can mean a consumable, a pack or a voucher, and Buy and Buy & Use are logged alike; this line and the money after the action are the only record of which one it was. The card in the logged slot must carry the logged name before the action is executed.
- `Client got ... message:` lines are what the server and opponent sent: opponent scores, PvP round results, lives, the start of each PvP blind, asteroids. A PvP blind cannot start or end without them, so they are handed back to Multiplayer where the log has them. Nothing is sent to the server.

The lobby copy is needed because Multiplayer's jokers, rulesets and PvP resolution only exist inside a lobby; practice and ghost modes draw from different pools.

Multiplayer logs neither the cash out button nor the shop's next-round button, so the replay presses them when the next action needs the screen behind them.

## When it stops

The replay stops at the action it could not execute and says why, leaving the run open. The recording is then the log up to that action. It stops when:

- the card in the logged slot is not the one the log names, or a purchase or reroll costs something else;
- the game refuses the action (not enough money, no room, a selection it will not accept);
- the game performs something that is not the log's next action;
- the game is on a screen the action cannot be done from — a hand to play while the game sits in the shop, a shop purchase while it is still mid-round. That means the round ended here at a different point than in the log: the log does not record the score of an ordinary blind, so this is the first place such a drift can be seen;
- the game does not accept the action within 45 seconds.

## The Lovely log

A replay writes nothing into the Lovely log. From **Start Replay** until you are back at the main menu, every line Multiplayer would log is dropped too - the run's manifest, its actions, the money and the opponent's messages - so a replay never leaves behind a log that reads like another game. Lines from other mods are logged as usual. Progress is shown only in the config tab and `status.json`.

## Limits

- The Multiplayer version, ruleset, game mode, deck and Cocktail deck pool must match the log.
- The other installed mods should be the ones the game was played with, at the same versions. A different mod set deals a different game from the same seed - an updated Steamodded rolls a different boss blind, for one. **The config tab** compares logged mods with the mods loaded in the running game. Choose **Compare Replay Mods** for missing, extra, and changed-version counts, plus Previous/Next buttons showing full names and logged/loaded versions. **Start Replay** asks for a second press when they differ; pressing it again replays anyway. Restart Balatro after changing mod files.
- Challenge runs are not replayed.
- Multiplayer logs "Buy" and "Buy & Use" the same way. The replay decides from the evidence, in this order: money moving right after the purchase means the card was used at once (a Hermit or Temperance); a consumable the shop cannot use (it needs selected cards) was bought only; no free consumable slot means Buy & Use; otherwise the first later use or sale of the slot the card would occupy tells, since every card the game adds later lands behind it and every removal in front of it is logged. Without any later reference it is a plain buy. A purchase the log shows no payment for is replayed as the refused click it was.
- Multiplayer does not log drag reorders of the consumable rack. A run that reordered consumables by hand stops at the first use or sale that names a different card.
- The log records positions, never which card sits in one. Two cards of the same rank and suit sit next to each other in the sorted hand and are told apart only by the order the game created them in, which the log does not record and a replay cannot set. If the two swap, hands score the same until something tells them apart, such as a seal or an enhancement on one of them; the run then parts company and the replay stops at the first action that can no longer be done.
- A hand reorder that leaves the hand exactly as the sort-by-suit or sort-by-rank button would is applied as that button, so later draws sort the same way.
- The Multiplayer round timer is off during a replay, since a replay runs at animation speed. It changes no card.
- Replayed wins and losses are not written to Multiplayer's match history. Career statistics count as in practice mode.

Log Info uses native deck/stake icons and a Multiplayer badge. Explicit solo/practice metadata is labeled accordingly; incomplete metadata shows Game type unknown. Ordinary solo games without supported replay records are not discoverable from this log format. Missing mod assets use text fallbacks.
