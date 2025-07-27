local M = {}

function M.log_word_under_cursor()
	local word = vim.fn.expand("<cword>")
	local line_num = vim.fn.line(".")
	local log_line = string.format("console.log({ %s });", word)
	vim.fn.append(line_num, log_line)
end

function M.setup(opts)
	opts = opts or {}
	local keymap = opts.keymap or "<leader>cl"

	vim.keymap.set("n", keymap, M.log_word_under_cursor, { desc = "Console log word under cursor" })
end

return M
