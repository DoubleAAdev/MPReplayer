"""Runs the Lua test suites with Balatro's own LuaJIT (lua51.dll) when no standalone Lua is installed.

Usage, from the repository root:  python scripts/run-lua-tests.py [tests/test_observer.lua ...]
Set BALATRO_LUA_DLL to the full path of lua51.dll if Balatro is not in a default Steam library.
"""
import ctypes, glob, os, sys

def find_dll():
    override = os.environ.get('BALATRO_LUA_DLL')
    if override:
        return override
    for library in (r'D:\SteamLibrary', r'C:\Program Files (x86)\Steam', r'C:\Program Files\Steam'):
        candidate = os.path.join(library, 'steamapps', 'common', 'Balatro', 'lua51.dll')
        if os.path.exists(candidate):
            return candidate
    sys.exit('lua51.dll not found; install a Lua 5.1 interpreter or set BALATRO_LUA_DLL')

def main(paths):
    lua = ctypes.CDLL(find_dll())
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.luaL_loadfile.restype = ctypes.c_int
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    failed = 0
    for path in paths or sorted(glob.glob('tests/*.lua')):
        sys.stdout.flush()
        state = lua.luaL_newstate()
        lua.luaL_openlibs(state)
        status = lua.luaL_loadfile(state, path.encode('utf-8')) or lua.lua_pcall(state, 0, 0, 0)
        if status:
            failed += 1
            print('FAIL', path, '->', lua.lua_tolstring(state, -1, None).decode('utf-8', 'replace'), flush=True)
        else:
            print('ok  ', path, flush=True)
        lua.lua_close(state)
    sys.exit(1 if failed else 0)

if __name__ == '__main__':
    main(sys.argv[1:])
