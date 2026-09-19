# MP Replayer 3.2.0

- Challenge a replay instead of watching it. Every game in the Replays list has a Challenge button that drops you into the lobby the log was played in, on its deck, stake and seed, with the player from the log as your nemesis. You play the run yourself and they answer with what they actually scored.
- Their PvP score moves a hand at a time with yours, and the hands they have left come down with it. Both sides of every PvP blind are read out of the log when the replay starts.
- PvP blinds settle the way Multiplayer settles them. Once your hands are spent the higher score takes the blind and the loser is a life down, with the comeback bonus and round-loss gold rules applied. Both sides start on the lobby's life count, and a life count reaching zero ends the run.
- Past the last PvP blind the log holds, the nemesis carries on from the best score they managed, multiplied again for each blind beyond the log by a quarter more than their median growth between blinds, and never by less than 1.75.
- The pause menu keeps End Replay and Restart Replay throughout, named for a challenge while you are in one, and restarting a challenge starts a challenge rather than a replay.

Known limits: the opponent's location and score are only driven during PvP blinds, and a normal round you lose costs no life, because in a live game the server is what takes it.
