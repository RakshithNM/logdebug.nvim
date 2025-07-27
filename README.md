# logdebug.nvim
A tiny Neovim plugin to insert `console.log({ word })` for the word under the cursor — perfect for debugging!

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
  keymap_below = "<leader>lg", -- default is <leader>wl
  -- keymap_above = "<leader>lh" -- map to insert above cursor
  -- keymap_remove = "<leader>ld" -- remove all console logs
  -- keymap_comment = "<leader>lc" -- comment out all console logs
})
```
