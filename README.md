# logdebug.nvim
A tiny Neovim plugin to insert `console` statements for the word under the cursor — perfect for debugging!
Toggle between `log`, `info`, `warn`, and `error` verbosity levels.

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

### Configuration(optional)

```lua
require("logdebug").setup({
  keymap_below = "<leader>wlb", -- word log below
  keymap_above = "<leader>wla" -- word log above
  keymap_remove = "<leader>dl" -- delete all console logs
  keymap_comment = "<leader>kl" -- Komment out all console logs
  keymap_toggle = "<leader>tll" -- toggle log level
})
```
