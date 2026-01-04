# logdebug.nvim
A tiny Neovim plugin to quickly insert log statements for the word under the cursor.
This plugin can be configured to log word under cursor above or below the current line in different languages.
It includes helpers for removing or commenting out these statements and can toggle
between `log`, `info`, `warn` and `error` verbosity levels in javascript/typescript files.

## ✨ Features
- Insert a console log above or below the current line
- Remove all console logs in the buffer (including commented ones)
- Comment out every console log in the buffer
- Toggle the verbosity level used when inserting logs
- Optionally restrict mappings to specific filetypes
- The console levels are local to individual buffers, so each buffer can have it's own level

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

### VIM pack
vim.pack.add({
    ....
  { src = "https://github.com/RakshithNM/logdebug.nvim", opt = true },
    ....
})
Then run `:lua vim.pack.update()` and `:write`

## ⚙️ Configuration (optional)
```lua
vim.schedule(function()
  vim.cmd("packadd logdebug.nvim")
  local logdebug_ok, logdebug = pcall(require, "logdebug")
  if logdebug_ok then
    local logdebug_filetypes = {
      "javascript", "typescript", "javascriptreact", "typescriptreact",
      "vue", "go", "lua", "ruby", "python"
    }
    logdebug.setup {
      keymap_below = "<leader>wlb", -- log word below cursor
      keymap_above = "<leader>wla", -- log word above cursor
      keymap_remove = "<leader>dl", -- delete all console logs
      keymap_comment = "<leader>kl", -- comment out all console logs
      keymap_toggle = "<leader>tll", -- toggle log level
      keymap_visual = "<leader>lv", -- visual mode log
      keymap_find = "<leader>fl", -- find logs
      filetypes = logdebug_filetypes,
      languages = {
        go = {
          build_log = function(indent, _level, expr)
            return string.format('%slog.Printf("%%+v", %s)', indent, expr)
          end,
          is_log_line = function(line, _levels)
            return line:match("^%s*log%.Printf%(") ~= nil
          end,
        },
        lua = {
          build_log = function(indent, _level, expr)
            return string.format("%sprint(vim.inspect(%s))", indent, expr)
          end,
          is_log_line = function(line, _levels)
            return line:match("^%s*print%(") ~= nil
              or line:match("^%s*vim%.print%(") ~= nil
          end,
        },
        ruby = {
          build_log = function(indent, _level, expr)
            return string.format("%sputs(%s.inspect)", indent, expr)
          end,
          is_log_line = function(line)
            return line:match("^%s*puts%(") ~= nil
          end,
        },
        python = {
          build_log = function(indent, _level, expr)
            return string.format("%sprint(%s)", indent, expr)
          end,
          is_log_line = function(line)
            return line:match("^%s*print%(") ~= nil
          end,
        },
      },
    }
  end
end)
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

