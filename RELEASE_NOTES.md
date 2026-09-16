# MP Replayer 2.9.14

- Fix hand drags logged right after a play being applied to the hand before the played cards left it. The drag was then undone by the redraw, so later Death, Chariot and Strength targets hit different cards and the deck drifted from the log.
- Make the fast-forward arrows smaller and wrap between 1x and 512x in both directions.
- Remove the money and hand diagnostics from status.json and Debug rows.

Validation: ten Lua suites. Restart Balatro to load the update.

