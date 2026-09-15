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
