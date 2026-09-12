-- Windows' own Open dialog, started in the Lovely log folder. The chosen
-- path comes back as UTF-8; no shell is involved.
return function()
    assert(love.system.getOS() == 'Windows', 'Drop a .log file onto Balatro on this platform')
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
    local ok, lovely = pcall(require, 'lovely')
    local folder = ok and type(lovely) == 'table' and type(lovely.log_path) == 'string' and lovely.log_path:match('^(.*)[/\\]') or nil
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
