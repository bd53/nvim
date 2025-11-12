local modules = {
    "finder",
    "gruvbox",
    "comments",
    "git",
    "status",
    "xp",
}

local loaded = {}

for _, module_name in ipairs(modules) do
    local ok, mod = pcall(require, ("custom.%s"):format(module_name))
    if not ok then
        print(("Failed to load module: %s"):format(module_name))
        goto continue_module
    end
    loaded[module_name] = mod
    if type(mod.setup) == "function" then mod.setup() end
    ::continue_module::
end

return loaded
