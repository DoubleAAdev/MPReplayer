-- Small deterministic encoder. No game objects or arbitrary serializers allowed.
local M = {}
local array_mt = {}
function M.array(t) return setmetatable(t or {}, array_mt) end

local function quote(s)
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end

function M.encode(value)
    local seen = {}
    local function encode(v)
        local kind = type(v)
        if kind == 'nil' then return 'null' end
        if kind == 'boolean' then return tostring(v) end
        if kind == 'number' then
            assert(v == v and v ~= math.huge and v ~= -math.huge, 'non-finite number')
            return string.format('%.17g', v)
        end
        if kind == 'string' then return quote(v) end
        assert(kind == 'table' and not seen[v], 'unsupported or cyclic JSON value')
        seen[v] = true
        local parts = {}
        if getmetatable(v) == array_mt then
            for i = 1, #v do parts[i] = encode(v[i]) end
            seen[v] = nil
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do
            assert(type(k) == 'string', 'object key must be a string')
            keys[#keys + 1] = k
        end
        table.sort(keys)
        for _, k in ipairs(keys) do parts[#parts + 1] = quote(k) .. ':' .. encode(v[k]) end
        seen[v] = nil
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return encode(value)
end
return M
