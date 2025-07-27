# logdebug.nvim
A tiny Neovim plugin to quickly insert `console` statements for the word under the cursor.
It includes helpers for removing or commenting out these statements and can toggle
between `log`, `info`, `warn` and `error` verbosity levels.

## ✨ Features
- Insert a console log above or below the current line
- Remove all console logs in the buffer (including commented ones)
- Comment out every console log in the buffer
- Toggle the verbosity level used when inserting logs
- Optionally restrict mappings to specific filetypes

## 🔧 Installation

### Lazy.nvim
```lua
{
  "RakshithNM/logdebug.nvim",
  config = function()
    require("logdebug").setup()
  end
}
```

### Packer
```lua
use {
  "RakshithNM/logdebug.nvim",
  config = function()
    require("logdebug").setup()
  end
}
```

## ⚙️ Configuration (optional)
```lua
require("logdebug").setup({
  keymap_below = "<leader>wla", -- log word below cursor
  keymap_above = "<leader>wlb", -- log word above cursor
  keymap_remove = "<leader>dl", -- delete all console logs (commented ones too)
  keymap_comment = "<leader>kl", -- comment out all console logs
  keymap_toggle = "<leader>tll", -- toggle log level
  filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "vue" } -- optional filetype filter
})
```
Provide a list of filetypes to `filetypes` to only enable the plugin's keymaps in
those buffers. When omitted, the keymaps are created globally.

## 📖 Usage
After setup the default mappings are:
```
<leader>wla  log word below cursor
<leader>wlb  log word above cursor
<leader>dl   remove all console logs
<leader>kl   comment out console logs
<leader>tll  toggle log level
```
Invoke `:help logdebug` inside Neovim to read the full documentation.

