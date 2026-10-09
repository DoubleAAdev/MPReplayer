-- Run with Lua or LuaJIT from the repository root.
local original_popen = io.popen
local response, seen_command, closed
love = {system = {getOS = function() return 'OS X' end}}
local folder = "/Users/me/Library/Application Support/Balatro/שלום's $(touch nope) `echo nope`/log"
package.loaded.lovely = {log_path = folder .. '/lovely-1.log'}
io.popen = function(command, mode)
    assert(mode == 'r')
    seen_command, closed = command, false
    return {read = function(_, format) assert(format == '*a'); return response end,
        close = function() closed = true end}
end
local pick = dofile('replayer/file-picker.lua')
local selected = folder .. '/שלום replay.log'
response = 'SELECTED:' .. selected .. '\n'
assert(pick() == selected and closed)
-- Parse POSIX shell quotes to check script/path stay separate literal arguments.
local args, current, quoted, i = {}, '', false, 1
while i <= #seen_command do
    local c = seen_command:sub(i, i)
    if c == "'" then quoted = not quoted
    elseif c == '\\' and not quoted then i = i + 1; current = current .. seen_command:sub(i, i)
    elseif c == ' ' and not quoted then args[#args + 1] = current; current = ''
    else current = current .. c end
    i = i + 1
end
args[#args + 1] = current
assert(not quoted and #args == 5)
assert(args[1] == '/usr/bin/osascript' and args[2] == '-e')
assert(args[3]:find('on run argv', 1, true) and args[3]:find('errorNumber is -128', 1, true))
assert(args[4] == folder and args[5] == '2>&1')
response = 'SELECTED:/tmp/line\nbreak .log\n'
assert(pick() == '/tmp/line\nbreak .log')
response = 'CANCELLED:\n'
assert(pick() == nil and closed)
response = 'ERROR:permission denied\n'
local ok, err = pcall(pick)
assert(not ok and err:find('permission denied', 1, true) and closed)
response = 'osascript: command failed\n'
assert(not pcall(pick))
response = 'SELECTED:\n'
assert(not pcall(pick))
package.loaded.lovely = {}
response = 'SELECTED:/tmp/fallback.log\n'
assert(pick() == '/tmp/fallback.log')
assert(seen_command:sub(-9) == " '' 2>&1" or seen_command:match(" '' 2>&1$"))
io.popen = function() return nil end
assert(not pcall(pick))
io.popen = original_popen
print('PASS: macOS selection, UTF-8, shell quoting, cancellation and failures')
