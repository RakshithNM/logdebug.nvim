# logdebug.nvim
A tiny Neovim plugin to insert `console.log({ word })` for the word under the cursor — perfect for debugging!

## 🔧 Installation

### Lazy.nvim

```lua
{
  "RakshithNM/logdebug.nvim",
  config = function()
    require("logger").setup()
  end
}
```

### Packer

```lua
use {
  "yourgithub/console-log.nvim",
  config = function()
    require("console_log").setup()
  end
}
```

### Configuration(optional)

```lua
```
require("console_log").setup({
  keymap = "<leader>lg" -- default is <leader>cl
})
```
```
