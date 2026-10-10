-- Read metadata in a restricted environment. No resource scripts are run.
-- The Python caller also applies a time limit to computed manifests.
local records = {}
local aliases = {
    client_scripts = 'client_script', server_scripts = 'server_script',
    shared_scripts = 'shared_script', files = 'file', games = 'game',
    dependencies = 'dependency', server_exports = 'server_export',
    client_exports = 'client_export', exports = 'export',
}
local function record(key, value)
    if type(value) == 'table' then
        for index in pairs(value) do
            assert(type(index) == 'number' and index % 1 == 0 and index >= 1 and index <= #value,
                'Manifest lists must be dense arrays: ' .. key)
        end
        for _, entry in ipairs(value) do
            record(key, entry)
        end
        return
    end
    assert(type(value) == 'string', 'Manifest values must be strings: ' .. key)
    assert(not value:find('[\t\r\n]'), 'Manifest values must be single-line: ' .. key)
    records[#records + 1] = key .. '\t' .. value
end
local environment = setmetatable({}, {
    __index = function(_, key)
        if key == 'data_file' then
            return function(kind)
                assert(type(kind) == 'string' and kind:match('^[A-Z0-9_]+$'),
                    'data_file needs a valid type')
                return function(path) record('data_file:' .. kind, path) end
            end
        end
        return function(value)
            record(aliases[key] or key, value)
            -- FiveM allows extra metadata following a declaration.
            return function(_) end
        end
    end,
})
local chunk = assert(loadfile(assert(arg[1]), 't', environment))
chunk()
for _, line in ipairs(records) do print(line) end
