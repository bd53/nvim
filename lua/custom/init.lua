local modules = {
    "finder",
    "gruvbox",
    "comments",
    "git",
    "status",
    "window",
}

local loaded = {}

for _, module_name in ipairs(modules) do
    local ok, mod = pcall(require, ("custom.%s"):format(module_name))
    if not ok then
        vim.notify(("Failed to load module: %s"):format(module_name), vim.log.levels.ERROR)
        goto continue_module
    end
    loaded[module_name] = mod
    if type(mod.setup) == "function" then mod.setup() end
    ::continue_module::
end

return loaded
