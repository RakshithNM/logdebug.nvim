local M = {}

local function insert_log_line(below)
	local word = vim.fn.expand("<cword>")
	local line_num = vim.fn.line(".")
	local log_line = string.format("console.log({ %s });", word)
	if below then
	vim.fn.append(line_num, log_line)
	else
	vim.fn.append(line_num - 1, log_line)
	end
end

function M.log_word_below_cursor()
	insert_log_line(true)
end

function M.log_word_above_cursor()
	insert_log_line(false)
end

function M.setup(opts)
	opts = opts or {}
	local keymap_below = opts.keymap_below or "<leader>wl"
	local keymap_above = opts.keymap_above
	
	vim.keymap.set("n", keymap_below, M.log_word_below_cursor, { desc = "Console log word below cursor" })
	if keymap_above then
	vim.keymap.set("n", keymap_above, M.log_word_above_cursor, { desc = "Console log word above cursor" })
	end
end

return M
