-- Native file dialogs, started in the Lovely log folder when available.
local function log_folder()
    local ok, lovely = pcall(require, 'lovely')
    return ok and type(lovely) == 'table' and type(lovely.log_path) == 'string'
        and lovely.log_path:match('^(.*)[/\\]') or nil
end

-- Pass paths as shell-quoted arguments, never as AppleScript source.
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local mac_script = [[
on run argv
    set initialFolder to missing value
    if (count of argv) > 0 and item 1 of argv is not "" then
        try
            set initialFolder to (POSIX file (item 1 of argv)) as alias
        end try
    end if
    try
        activate
        if initialFolder is missing value then
            set selectedFile to choose file with prompt "Replayer - choose a Multiplayer log" of type {"log"}
        else
            set selectedFile to choose file with prompt "Replayer - choose a Multiplayer log" of type {"log"} default location initialFolder
        end if
        return "SELECTED:" & POSIX path of selectedFile
    on error messageText number errorNumber
        if errorNumber is -128 then return "CANCELLED:"
        return "ERROR:" & messageText
    end try
end run
]]

local function mac_picker()
    local command = '/usr/bin/osascript -e ' .. shell_quote(mac_script) .. ' ' .. shell_quote(log_folder() or '') .. ' 2>&1'
    local pipe = assert(io.popen(command, 'r'), 'macOS could not open the file picker')
    local output = pipe:read('*a')
    pipe:close()
    assert(output, 'macOS could not read the selected filename')
    -- osascript appends one newline; retain whitespace belonging to the path.
    output = output:gsub('\n$', '')
    if output == 'CANCELLED:' then return nil end
    if output:sub(1, 9) == 'SELECTED:' then
        local path = output:sub(10)
        assert(path ~= '', 'macOS returned an empty filename')
        return path
    end
    error('macOS could not open the file picker: ' .. output:gsub('^ERROR:', ''), 0)
end

return function()
    local platform = love.system.getOS()
    if platform == 'OS X' then return mac_picker() end
    assert(platform == 'Windows', 'Drop a .log file onto Balatro on this platform')
    local ffi = require('ffi')
    if not pcall(ffi.typeof, 'BOBS_OPENFILENAMEW') then
        ffi.cdef[[
            typedef struct {
                unsigned long lStructSize; void *hwndOwner; void *hInstance;
                const wchar_t *lpstrFilter; wchar_t *lpstrCustomFilter;
                unsigned long nMaxCustFilter; unsigned long nFilterIndex;
                wchar_t *lpstrFile; unsigned long nMaxFile;
                wchar_t *lpstrFileTitle; unsigned long nMaxFileTitle;
                const wchar_t *lpstrInitialDir; const wchar_t *lpstrTitle;
                unsigned long Flags; unsigned short nFileOffset; unsigned short nFileExtension;
                const wchar_t *lpstrDefExt; intptr_t lCustData; void *lpfnHook;
                const wchar_t *lpTemplateName; void *pvReserved;
                unsigned long dwReserved; unsigned long FlagsEx;
            } BOBS_OPENFILENAMEW;
            int GetOpenFileNameW(BOBS_OPENFILENAMEW*);
            unsigned long CommDlgExtendedError(void);
            void *GetActiveWindow(void);
            int MultiByteToWideChar(unsigned int,unsigned long,const char*,int,wchar_t*,int);
            int WideCharToMultiByte(unsigned int,unsigned long,const wchar_t*,int,char*,int,const char*,int*);
        ]]
    end
    local kernel, dialog, user = ffi.load('kernel32'), ffi.load('comdlg32'), ffi.load('user32')
    local function wide(text)
        local length = kernel.MultiByteToWideChar(65001, 0, text, #text, nil, 0)
        assert(length > 0, 'Invalid dialog text')
        local buffer = ffi.new('wchar_t[?]', length + 1)
        assert(kernel.MultiByteToWideChar(65001, 0, text, #text, buffer, length) > 0)
        return buffer
    end
    local filename = ffi.new('wchar_t[32768]')
    local filter = wide('Lovely logs (*.log)\0*.log\0All files (*.*)\0*.*\0\0')
    local title = wide('Replayer - choose a Multiplayer log')
    local options = ffi.new('BOBS_OPENFILENAMEW')
    options.lStructSize = ffi.sizeof(options)
    options.hwndOwner = user.GetActiveWindow()
    options.lpstrFilter = filter
    options.nFilterIndex = 1
    options.lpstrFile = filename
    options.nMaxFile = 32768
    options.lpstrTitle = title
    -- Start where Lovely writes its logs, when the mod loader exposes it.
    local initial
    local folder = log_folder()
    if folder and folder ~= '' then
        initial = wide((folder:gsub('/', '\\')))
        options.lpstrInitialDir = initial
    end
    -- Explorer style, existing files and paths only, keep the game's working directory.
    options.Flags = 0x80000 + 0x1000 + 0x800 + 0x8
    if dialog.GetOpenFileNameW(options) == 0 then
        assert(dialog.CommDlgExtendedError() == 0, 'Windows could not open the file picker')
        return nil
    end
    local length = kernel.WideCharToMultiByte(65001, 0, filename, -1, nil, 0, nil, nil)
    assert(length > 0, 'Invalid selected filename')
    local path = ffi.new('char[?]', length)
    assert(kernel.WideCharToMultiByte(65001, 0, filename, -1, path, length, nil, nil) > 0)
    return ffi.string(path)
end
