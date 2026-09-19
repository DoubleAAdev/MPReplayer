# MP Replayer 3.1.1

- Add a Restart Replay button to the pause menu, under End Replay. It is that button's own row copied, so the two match in size, colour and font whatever the menu around them is built from.
- Stop asking for the same confirmation twice. The approval given for a mod difference was spent by the start it was given for, and the restart cleared it as well, so restarting a replay asked the question the player had just answered. It is kept now, and a fresh Start, a changed selection or a changed set of loaded mods still ask.
- Wait for the main menu to settle before restarting. Multiplayer leaves the lobby over several frames and resets the lobby options on its way out, so a restart begun in that window had the replay's deck and rules wiped and the run started on the default deck.
- Lower the speed panel above the deck.

Validation: ten Lua suites. Restart Balatro to load the update.
