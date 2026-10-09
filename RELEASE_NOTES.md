# MP Replayer 3.2.2

- Fix replay stops when a consumable or sale recorded in the shop follows the final PvP hand. Wait through the round-end transition, cash out, and reach the shop before issuing the action.
- Preserve consumable uses recorded before Cash Out.

Validation: wrote a regression test that reproduced the Eris refusal before the fix; it passes with the fix, along with the existing replay suites. Runtime UI source checks and the Windows-only picker are unavailable on this Mac.
