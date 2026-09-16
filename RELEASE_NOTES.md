# MP Replayer 2.9.11

- Fix replays running short of money: a consumable the log used (or card it sold) after reaching the shop is no longer used on the round results before cashing out. The Hermit doubled the pre-cash-out money, and the gap grew through interest until a purchase was refused.
- Read the shop setLocation line to mark which actions came after the cash out.

Validation: ten Lua suites. Restart Balatro to load the update.

