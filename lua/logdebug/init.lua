local M = {}

M.log_levels = { "log", "info", "warn", "error" }
M.current_level_index = 1

local function is_console_line(line)
	for _, level in ipairs(M.log_levels) do
		if line:match("^%s*console%." .. level .. "%(") then
			return true
		end
	end
	return false
end

local function is_commented_console_line(line)
	for _, level in ipairs(M.log_levels) do
		if line:match("^%s*//%s*console%." .. level .. "%(") then
			return true
		end
	end
	return false
end

local function insert_log_line(below)
	local word = vim.fn.expand("<cword>")
	local line_num = vim.fn.line(".")
	local level = M.log_levels[M.current_level_index]
	local log_line = string.format("console.%s({ %s });", level, word)
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
		if is_console_line(line) or is_commented_console_line(line) then
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
		end
	end
end

function M.comment_all_logs()
	local bufnr = vim.api.nvim_get_current_buf()
	for i = vim.api.nvim_buf_line_count(bufnr), 1, -1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
		if is_console_line(line) then
			local indent = line:match("^%s*") or ""
			local uncommented = line:sub(#indent + 1)
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { indent .. "//" .. uncommented })
		end
	end
end

function M.toggle_verbosity()
	M.current_level_index = M.current_level_index % #M.log_levels + 1
	local level = M.log_levels[M.current_level_index]
	vim.notify("logdebug: using console." .. level)
end

function M.setup(opts)
	opts = opts or {}
	local keymap_below = opts.keymap_below or "<leader>wla"
	local keymap_above = opts.keymap_above or "<leader>wlb"
	local keymap_remove = opts.keymap_remove or "<leader>dl"
	local keymap_comment = opts.keymap_comment or "<leader>kl"
	local keymap_toggle = opts.keymap_toggle or "<leader>tll"
	local filetypes = opts.filetypes

	local function set_maps(buf)
		vim.keymap.set(
			"n",
			keymap_below,
			M.log_word_below_cursor,
			{ desc = "Console log word below cursor", buffer = buf }
		)
		if keymap_above then
			vim.keymap.set(
				"n",
				keymap_above,
				M.log_word_above_cursor,
				{ desc = "Console log word above cursor", buffer = buf }
			)
		end
		if keymap_remove then
			vim.keymap.set("n", keymap_remove, M.remove_all_logs, { desc = "Remove console logs", buffer = buf })
		end
		if keymap_comment then
			vim.keymap.set("n", keymap_comment, M.comment_all_logs, { desc = "Comment out console logs", buffer = buf })
		end
		if keymap_toggle then
			vim.keymap.set("n", keymap_toggle, M.toggle_verbosity, { desc = "Toggle log level", buffer = buf })
		end
	end

	if filetypes then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = filetypes,
			callback = function(args)
				set_maps(args.buf)
			end,
		})
	else
		set_maps(nil)
	end
end

return M
