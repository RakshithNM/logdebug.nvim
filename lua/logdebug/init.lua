local M = {}

-- Configuration defaults
M.log_levels = { "log", "info", "warn", "error" }
-- Default config options
local default_config = {
	log_levels = { "log", "info", "warn", "error" },
	use_labels = false, -- Whether to include labels like "var: {var}"
}

-- Per-language logging configuration
-- Users can extend/override this via `setup({ languages = { ... } })`.
local language_configs = {
	-- Default: JS/TS-style console logs
	default = {
		build_log = function(indent, level, expr)
			return string.format("%sconsole.%s({ %s });", indent, level, expr)
		end,
		is_log_line = function(line, log_levels)
			for _, level in ipairs(log_levels) do
				if line:match("^%s*console%." .. level .. "%(") then
					return true
				end
			end
			return false
		end,
	},
}

local function get_lang_config(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	return (ft and language_configs[ft]) or language_configs.default
end

-- State management: buffer-local state for log level indices
local state = {}
local augroup_id = nil
local autocmd_id = nil
local config = {} -- Plugin configuration

-- Helper function to get buffer-local log level index
local function get_level_index(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not state[bufnr] then
		state[bufnr] = { level_index = 1 }
	end
	return state[bufnr].level_index
end

-- Helper function to set buffer-local log level index
local function set_level_index(bufnr, index)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not state[bufnr] then
		state[bufnr] = { level_index = 1 }
	end
	state[bufnr].level_index = index
end

-- Helper function to get comment prefix for current buffer
local function get_comment_prefix(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local commentstring = vim.bo[bufnr].commentstring
	if commentstring and commentstring ~= "" then
		-- Extract comment prefix (e.g., "//" from "// %s" or "# " from "# %s")
		local prefix = commentstring:match("^(.-)%%s") or commentstring:match("^([^%s]+)")
		if prefix then
			return prefix:gsub("%%s", ""):gsub(" ", "")
		end
	end
	-- Default to // for JavaScript/TypeScript
	return "//"
end

-- Private helper: Check if line is a log line for the current language
local function is_console_line(line, bufnr)
	if not line or type(line) ~= "string" then
		return false
	end
	local cfg = get_lang_config(bufnr)
	local log_levels = config.log_levels or M.log_levels
	return cfg.is_log_line(line, log_levels) == true
end

-- Private helper: Check if line is a commented log line
local function is_commented_console_line(line, comment_prefix, bufnr)
	if not line or type(line) ~= "string" then
		return false
	end
	comment_prefix = comment_prefix or "//"
	-- Escape special regex characters in comment prefix
	local escaped_prefix = comment_prefix:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
	-- Strip indent + comment prefix, then delegate to language-specific matcher
	local uncommented = line:match("^%s*" .. escaped_prefix .. "(.*)")
	if not uncommented then
		return false
	end
	local cfg = get_lang_config(bufnr)
	local log_levels = config.log_levels or M.log_levels
	return cfg.is_log_line(uncommented, log_levels) == true
end

-- Private helper: Get indentation from a line
local function get_indent(line)
	if not line or type(line) ~= "string" then
		return ""
	end
	return line:match("^%s*") or ""
end

-- Private helper: Validate buffer and get current line safely
local function validate_buffer_and_line(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Check if buffer is valid
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil, nil, "Invalid buffer"
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count == 0 then
		return nil, nil, "Buffer is empty"
	end

	local current_line = vim.fn.line(".")
	if current_line < 1 or current_line > line_count then
		return nil, nil, "Invalid line number"
	end

	return bufnr, current_line, nil
end

-- Private helper: Get selected text or word under cursor
local function get_selected_text()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		-- Visual mode: get selected text
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local start_line = start_pos[2] - 1
		local end_line = end_pos[2] - 1
		local start_col = start_pos[3] - 1
		local end_col = end_pos[3]

		local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
		if not lines or #lines == 0 then
			return nil
		end

		if #lines == 1 then
			-- Single line selection
			local line = lines[1]
			return line:sub(start_col + 1, end_col)
		else
			-- Multi-line selection
			local first_line = lines[1]:sub(start_col + 1)
			local last_line = lines[#lines]:sub(1, end_col)
			local middle_lines = {}
			for i = 2, #lines - 1 do
				table.insert(middle_lines, lines[i])
			end
			return table.concat({ first_line, table.unpack(middle_lines), last_line }, "\n")
		end
	else
		-- Normal mode: get word under cursor
		return vim.fn.expand("<cword>")
	end
end

-- Private helper: Insert log line with proper error handling and undo support
local function insert_log_line(below, expr)
	local bufnr, line_num, err = validate_buffer_and_line()
	if err then
		vim.notify("logdebug: " .. err, vim.log.levels.WARN)
		return
	end

	-- Get expression to log (provided or from selection/word)
	local expression = expr
	if not expression then
		expression = get_selected_text()
	end
	if not expression or expression == "" then
		vim.notify("logdebug: No expression to log", vim.log.levels.WARN)
		return
	end

	-- Get current line to preserve indentation
	local current_line_content = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
	if not current_line_content then
		vim.notify("logdebug: Could not read current line", vim.log.levels.ERROR)
		return
	end

	local indent = get_indent(current_line_content)
	local level_index = get_level_index(bufnr)
	local log_levels = config.log_levels or M.log_levels
	local level = log_levels[level_index]
	local lang_cfg = get_lang_config(bufnr)

	-- Format expression with label if enabled
	local expr_to_log = expression
	if config.use_labels and expression:match("^[%w_][%w_]*$") then
		-- Only add label for simple identifiers
		expr_to_log = string.format('"%s:", %s', expression, expression)
	end

	local log_line = lang_cfg.build_log(indent, level, expr_to_log)

	-- Use nvim_buf_set_lines for proper undo support
	local insert_line = below and line_num or (line_num - 1)
	local success, result = pcall(vim.api.nvim_buf_set_lines, bufnr, insert_line, insert_line, false, { log_line })

	if not success then
		vim.notify("logdebug: Failed to insert log line: " .. tostring(result), vim.log.levels.ERROR)
		return
	end
end

-- Public API: Log word/selection below cursor
function M.log_word_below_cursor()
	local success, err = pcall(insert_log_line, true)
	if not success then
		vim.notify("logdebug: Error inserting log below: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Public API: Log word/selection above cursor
function M.log_word_above_cursor()
	local success, err = pcall(insert_log_line, false)
	if not success then
		vim.notify("logdebug: Error inserting log above: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Public API: Log visual selection (for visual mode mappings)
function M.log_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		vim.notify("logdebug: Not in visual mode", vim.log.levels.WARN)
		return
	end
	-- Get selection before exiting visual mode
	local expr = get_selected_text()
	vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
	if expr then
		local success, err = pcall(insert_log_line, true, expr)
		if not success then
			vim.notify("logdebug: Error inserting log: " .. tostring(err), vim.log.levels.ERROR)
		end
	end
end

-- Public API: Remove all console logs
function M.remove_all_logs()
	local bufnr, _, err = validate_buffer_and_line()
	if err then
		vim.notify("logdebug: " .. err, vim.log.levels.WARN)
		return
	end

	local comment_prefix = get_comment_prefix(bufnr)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local removed_count = 0

	-- Group operations for undo (may fail if no undo history, that's ok)
	pcall(vim.cmd, "undojoin")

	-- Iterate backwards to avoid index shifting issues
	for i = line_count, 1, -1 do
		local success, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, i - 1, i, false)
		if success and lines and lines[1] then
			local line = lines[1]
			if is_console_line(line, bufnr) or is_commented_console_line(line, comment_prefix, bufnr) then
				local remove_success = pcall(vim.api.nvim_buf_set_lines, bufnr, i - 1, i, false, {})
				if remove_success then
					removed_count = removed_count + 1
				end
			end
		end
	end

	if removed_count > 0 then
		vim.notify(string.format("logdebug: Removed %d log line(s)", removed_count), vim.log.levels.INFO)
	end
end

-- Public API: Comment all console logs
function M.comment_all_logs()
	local bufnr, _, err = validate_buffer_and_line()
	if err then
		vim.notify("logdebug: " .. err, vim.log.levels.WARN)
		return
	end

	local comment_prefix = get_comment_prefix(bufnr)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local commented_count = 0

	-- Group operations for undo (may fail if no undo history, that's ok)
	pcall(vim.cmd, "undojoin")

	-- Iterate backwards to avoid index shifting issues
	for i = line_count, 1, -1 do
		local success, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, i - 1, i, false)
		if success and lines and lines[1] then
			local line = lines[1]
			if is_console_line(line, bufnr) then
				local indent = get_indent(line)
				local uncommented = line:sub(#indent + 1)
				local commented_line = indent .. comment_prefix .. uncommented
				local comment_success = pcall(vim.api.nvim_buf_set_lines, bufnr, i - 1, i, false, { commented_line })
				if comment_success then
					commented_count = commented_count + 1
				end
			end
		end
	end

	if commented_count > 0 then
		vim.notify(string.format("logdebug: Commented %d log line(s)", commented_count), vim.log.levels.INFO)
	end
end

-- Public API: Toggle verbosity level (buffer-local)
function M.toggle_verbosity()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_index = get_level_index(bufnr)
	local log_levels = config.log_levels or M.log_levels
	local new_index = (current_index % #log_levels) + 1
	set_level_index(bufnr, new_index)
	local level = log_levels[new_index]
	vim.notify("logdebug: using level " .. level, vim.log.levels.INFO)
end

-- Public API: Find all log statements and populate quickfix
function M.find_all_logs()
	local bufnr, _, err = validate_buffer_and_line()
	if err then
		vim.notify("logdebug: " .. err, vim.log.levels.WARN)
		return
	end

	local comment_prefix = get_comment_prefix(bufnr)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local locations = {}

	for i = 1, line_count do
		local success, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, i - 1, i, false)
		if success and lines and lines[1] then
			local line = lines[1]
			if is_console_line(line, bufnr) or is_commented_console_line(line, comment_prefix, bufnr) then
				table.insert(locations, {
					bufnr = bufnr,
					lnum = i,
					col = 1,
					text = vim.trim(line),
				})
			end
		end
	end

	if #locations > 0 then
		vim.fn.setqflist(locations, "r")
		vim.cmd("copen")
		vim.notify(string.format("logdebug: Found %d log line(s)", #locations), vim.log.levels.INFO)
	else
		vim.notify("logdebug: No log statements found", vim.log.levels.INFO)
	end
end

-- Private helper: Validate keymap string
local function validate_keymap(keymap)
	if keymap == nil then
		return true -- nil is allowed (disables the keymap)
	end
	if type(keymap) ~= "string" then
		return false, "Keymap must be a string"
	end
	if keymap == "" then
		return false, "Keymap cannot be empty"
	end
	return true
end

-- Private helper: Validate filetypes
local function validate_filetypes(filetypes)
	if filetypes == nil then
		return true -- nil is allowed
	end
	if type(filetypes) ~= "table" then
		return false, "filetypes must be a table"
	end
	for _, ft in ipairs(filetypes) do
		if type(ft) ~= "string" then
			return false, "All filetypes must be strings"
		end
	end
	return true
end

-- Private helper: Clean up autocmds
local function cleanup_autocmds()
	if augroup_id then
		pcall(vim.api.nvim_clear_autocmds, { group = augroup_id })
		augroup_id = nil
		autocmd_id = nil
	end
end

-- Public API: Setup plugin
function M.setup(opts)
	opts = opts or {}

	-- Merge configuration
	config = vim.tbl_deep_extend("force", default_config, config or {}, opts.config or {})

	-- Update log levels if provided
	if opts.log_levels and type(opts.log_levels) == "table" and #opts.log_levels > 0 then
		M.log_levels = opts.log_levels
		config.log_levels = opts.log_levels
	else
		config.log_levels = config.log_levels or M.log_levels
	end

	-- Input validation
	local keymap_below = opts.keymap_below or "<leader>wla"
	local keymap_above = opts.keymap_above or "<leader>wlb"
	local keymap_remove = opts.keymap_remove or "<leader>dl"
	local keymap_comment = opts.keymap_comment or "<leader>kl"
	local keymap_toggle = opts.keymap_toggle or "<leader>tll"
	local keymap_find = opts.keymap_find or nil
	local keymap_visual = opts.keymap_visual or nil
	local filetypes = opts.filetypes
	local languages = opts.languages

	-- Validate keymaps
	local valid, err = validate_keymap(keymap_below)
	if not valid then
		vim.notify("logdebug: Invalid keymap_below: " .. err, vim.log.levels.ERROR)
		return
	end

	valid, err = validate_keymap(keymap_above)
	if not valid then
		vim.notify("logdebug: Invalid keymap_above: " .. err, vim.log.levels.ERROR)
		return
	end

	valid, err = validate_keymap(keymap_remove)
	if not valid then
		vim.notify("logdebug: Invalid keymap_remove: " .. err, vim.log.levels.ERROR)
		return
	end

	valid, err = validate_keymap(keymap_comment)
	if not valid then
		vim.notify("logdebug: Invalid keymap_comment: " .. err, vim.log.levels.ERROR)
		return
	end

	valid, err = validate_keymap(keymap_toggle)
	if not valid then
		vim.notify("logdebug: Invalid keymap_toggle: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Validate filetypes
	valid, err = validate_filetypes(filetypes)
	if not valid then
		vim.notify("logdebug: Invalid filetypes: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Merge user-provided language configs
	if languages and type(languages) == "table" then
		for ft, cfg in pairs(languages) do
			if type(ft) == "string" and type(cfg) == "table" then
				language_configs[ft] = cfg
			end
		end
	end

	-- Clean up existing autocmds if setup is called again
	cleanup_autocmds()

	-- Create augroup for autocmds
	augroup_id = vim.api.nvim_create_augroup("Logdebug", { clear = true })

	-- Function to set keymaps
	local function set_maps(buf)
		if keymap_below then
			vim.keymap.set("n", keymap_below, M.log_word_below_cursor, {
				desc = "Log word/selection below cursor",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_above then
			vim.keymap.set("n", keymap_above, M.log_word_above_cursor, {
				desc = "Log word/selection above cursor",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_visual then
			vim.keymap.set("v", keymap_visual, M.log_selection, {
				desc = "Log visual selection",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_remove then
			vim.keymap.set("n", keymap_remove, M.remove_all_logs, {
				desc = "Remove all logs",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_comment then
			vim.keymap.set("n", keymap_comment, M.comment_all_logs, {
				desc = "Comment out all logs",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_toggle then
			vim.keymap.set("n", keymap_toggle, M.toggle_verbosity, {
				desc = "Toggle log level",
				buffer = buf,
				silent = true,
			})
		end
		if keymap_find then
			vim.keymap.set("n", keymap_find, M.find_all_logs, {
				desc = "Find all logs (quickfix)",
				buffer = buf,
				silent = true,
			})
		end
	end

	-- Set up autocmd or global keymaps
	if filetypes then
		autocmd_id = vim.api.nvim_create_autocmd("FileType", {
			group = augroup_id,
			pattern = filetypes,
			callback = function(args)
				set_maps(args.buf)
			end,
		})
	else
		set_maps(nil)
	end
end

-- Public API: Disable plugin (cleanup)
function M.disable()
	cleanup_autocmds()
	-- Clear state for all buffers
	state = {}
	vim.notify("logdebug: Plugin disabled", vim.log.levels.INFO)
end

return M
