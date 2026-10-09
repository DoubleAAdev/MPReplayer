# MP Replayer 3.2.1

- Fix Load Log on macOS with a native file picker. It starts in the Lovely log folder when available, supports Unicode filenames, and treats Cancel as a normal return.
- Keep the existing native Windows picker and drag-and-drop loading.

Validation: nine existing Lua suites and the new macOS picker suite passed with Balatro's LuaJIT; the runtime UI suite skipped its game-source checks because the local patched source is unavailable. macOS dialog script compiled successfully and native cancellation was verified. The Windows-only picker suite was not run on macOS.
