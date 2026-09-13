# 1.2.0

- Drop the Balatro Observer requirement. The mod no longer depends on Balatro Observer and a replay starts without Action Recorder. When Action Recorder is installed and recording, the replay still stops if the recording stops, and the closing status still names the recording.

# 1.1.0

- Check the mods before replaying. Start Replay compares the mods and versions the log's manifest lists with the ones installed, leaving out Balatro Observer and Balatro Replayer, and names every difference; pressing it again replays anyway. A game recorded under Steamodded 1.0.0~BETA-1620a rolls a different boss blind under Steamodded 26.829.0, so such a replay stopped at its first boss with no hint why.
- Name logs written by old replays. Replays before this mod wrote their own run into the Lovely log; loading one now says it was written by an old replay, not a game you played.
- Show the status on up to four lines in the config tab instead of one line running off the panel.

# 1.0.0

- The Replayer from Balatro Observer 1.10.0, as its own mod. Its buttons are in **Mods > Balatro Replayer > Config**; it needs Balatro Observer installed for Action Recorder. Behaviour is unchanged: the log's actions are filtered out of it and executed in order, each once, and the replay stops at the first action it cannot execute. Nothing is written to the Lovely log.
