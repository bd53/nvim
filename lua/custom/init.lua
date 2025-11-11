local modules = {
  { name = "finder", key = "<C-p>" },
  { name = "gruvbox", key = "<leader>b" },
  { name = "comments", key = "<leader>/" },
}

local loaded = {}

for _, module in pairs(modules) do
  local ok, mod = pcall(require, ("custom.%s"):format(module.name))
  if not ok then
    print(("Failed to load module: %s"):format(module.name))
    goto continue_module
  end
  loaded[module.name] = mod
  if type(mod.setup) == "function" then mod.setup() end
  if mod.toggle then vim.keymap.set("n", module.key, mod.toggle) end
  ::continue_module::
end
