local modules = {
  finder = "finder",
  gruvbox = "gruvbox",
}

local loaded = {}

for key, name in pairs(modules) do
  local ok, mod = pcall(require, ("custom.%s"):format(name))
  if not ok then
    print(("Failed to load module: %s"):format(name))
    goto continue
  end
  loaded[key] = mod
  if type(mod.setup) == "function" then
    mod.setup()
  end
  ::continue::
end

local finder = loaded.finder
if finder and finder.toggle then
  vim.keymap.set("n", "<C-p>", finder.toggle)
end

local gruvbox = loaded.gruvbox
if gruvbox then
  if gruvbox.apply then gruvbox.apply() end
  if gruvbox.toggle then
    vim.keymap.set("n", "<leader>b", gruvbox.toggle)
  end
end
