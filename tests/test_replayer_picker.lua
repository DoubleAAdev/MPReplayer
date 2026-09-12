-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_picker.lua
local ffi = require('ffi')
local original_load = ffi.load
local mode = 'select'
local selected = 'C:/logs/שלום replay.log'
local initial_seen
love = {system = {getOS = function() return 'Windows' end}}
package.loaded.lovely = {log_path = 'C:/Users/me/AppData/Roaming/Balatro/Mods/lovely/log/lovely-1.log'}
ffi.load = function(name)
    if name == 'user32' then return {GetActiveWindow = function() return nil end} end
    if name == 'comdlg32' then return {
        GetOpenFileNameW = function(options)
            assert(options.lStructSize == (ffi.abi('64bit') and 152 or 88))
            assert(options.nMaxFile == 32768 and options.Flags == 0x81808)
            local kernel = original_load('kernel32')
            local buffer = ffi.new('char[512]')
            assert(kernel.WideCharToMultiByte(65001, 0, options.lpstrInitialDir, -1, buffer, 512, nil, nil) > 0)
            initial_seen = ffi.string(buffer)
            if mode ~= 'select' then return 0 end
            assert(kernel.MultiByteToWideChar(65001, 0, selected, -1, options.lpstrFile, options.nMaxFile) > 0)
            return 1
        end,
        CommDlgExtendedError = function() return mode == 'cancel' and 0 or 1 end,
    } end
    return original_load(name)
end
local pick = dofile('replayer/file-picker.lua')
assert(pick() == selected)
assert(initial_seen == 'C:\\Users\\me\\AppData\\Roaming\\Balatro\\Mods\\lovely\\log', 'the dialog opens in the Lovely log folder: ' .. tostring(initial_seen))
mode = 'cancel'
assert(pick() == nil)
mode = 'error'
assert(not pcall(pick))
ffi.load = original_load
print('PASS: native picker structure, existing-file flags, log folder start, UTF-8 filenames, cancellation and error handling')
