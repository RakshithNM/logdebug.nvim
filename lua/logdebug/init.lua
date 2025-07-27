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

function M.remove_all_logs()
	local bufnr = vim.api.nvim_get_current_buf()
	for i = vim.api.nvim_buf_line_count(bufnr), 1, -1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
		if line:match("^%s*console%.log%(") then
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
		end
	end
end

function M.comment_all_logs()
	local bufnr = vim.api.nvim_get_current_buf()
	for i = vim.api.nvim_buf_line_count(bufnr), 1, -1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
		if line:match("^%s*console%.log%(") then
			local indent = line:match("^%s*") or ""
			local uncommented = line:sub(#indent + 1)
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { indent .. "//" .. uncommented })
		end
	end
end
function M.setup(opts)
	opts = opts or {}
	local keymap_below = opts.keymap_below or "<leader>wl"
	local keymap_above = opts.keymap_above
	local keymap_remove = opts.keymap_remove or "<leader>wd"
	local keymap_comment = opts.keymap_comment or "<leader>wc"

	vim.keymap.set("n", keymap_below, M.log_word_below_cursor, { desc = "Console log word below cursor" })
	if keymap_above then
		vim.keymap.set("n", keymap_above, M.log_word_above_cursor, { desc = "Console log word above cursor" })
	end
	if keymap_remove then
		vim.keymap.set("n", keymap_remove, M.remove_all_logs, { desc = "Remove console logs" })
	end
	if keymap_comment then
		vim.keymap.set("n", keymap_comment, M.comment_all_logs, { desc = "Comment out console logs" })
	end
end

return M
