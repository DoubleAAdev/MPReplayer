# MP Replayer 3.0.0

- Tidy the code without changing what it does: the two Start buttons share one path, UI text nodes go through one helper, log loading no longer computes offsets that are always 1, and fields nothing read (mod_missing, mod_extra, mod_versions, log_imports) and the unused mprpl_stop alias are gone.

Validation: ten Lua suites, unchanged, all passing. Restart Balatro to load the update.
