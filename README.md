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
  keymap = "<leader>lg" -- default is <leader>cl
})
```
