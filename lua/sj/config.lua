local utils = require("sj.utils")

------------------------------------------------------------------------------------------------------------------------

local function is_boolean(v)
	return type(v) == "boolean"
end

local function is_char(v)
	return type(v) == "string" and v:len() == 1
end

local function is_unsigned_number(v)
	return type(v) == "number" and v > -1
end

local function is_string(v)
	return type(v) == "string"
end

local function valid_keymaps(v)
	if type(v) ~= "table" then
		return false
	end

	for key, val in pairs(v) do
		if type(key) ~= "string" or type(val) ~= "string" then
			return false
		end
	end

	return true
end

local function valid_highlights(v)
	if type(v) ~= "table" then
		return false
	end

	for _, val in pairs(v) do
		if type(val) ~= "table" then
			return false
		end
	end

	return true
end

local function valid_labels(labels)
	if type(labels) ~= "table" then
		return false
	else
		return #labels > 0 and #vim.tbl_filter(is_char, labels) == #labels
	end
end

------------------------------------------------------------------------------------------------------------------------

local checks = {
	auto_jump = { func = is_boolean, message = "must be a boolean" },
	forward_search = { func = is_boolean, message = "must be a boolean" },
	highlights = { func = valid_highlights, message = "must be a table with tables as values" },
	highlights_timeout = { func = is_unsigned_number, message = "must be an unsigned number" },
	inclusive = { func = is_boolean, message = "must be a boolean" },
	keymaps = { func = valid_keymaps, message = "must be a table with string as values" },
	labels = { func = valid_labels, message = "must be a list of characters" },
	max_pattern_length = { func = is_unsigned_number, message = "must be an unsigned number" },
	pattern = { func = is_string, message = "must be a string" },
	pattern_type = { func = is_string, message = "must be a string" },
	preserve_highlights = { func = is_boolean, message = "must be a boolean" },
	prompt_prefix = { func = is_string, message = "must be a string" },
	relative_labels = { func = is_boolean, message = "must be a boolean" },
	search_scope = { func = is_string, message = "must be a string" },
	select_window = { func = is_boolean, message = "must be a boolean" },
	separator = { func = is_string, message = "must be a string" },
	stop_on_fail = { func = is_boolean, message = "must be a boolean" },
	update_search_register = { func = is_boolean, message = "must be a boolean" },
	use_overlay = { func = is_boolean, message = "must be a boolean" },
	use_last_pattern = { func = is_boolean, message = "must be a boolean" },
	wrap_jumps = { func = is_boolean, message = "must be a boolean" },

	--- Deprecated
	label_as_prefix = { func = is_boolean, message = "must be a boolean" },
	update_highlights = { func = is_boolean, message = "must be a boolean" },
	use_highlights_autocmd = { func = is_boolean, message = "must be a boolean" },
}

local deprecated = {
	label_as_prefix = { message = "was removed since 0.5" },
	update_highlights = { message = "was removed since 0.5" },
	use_highlights_autocmd = {
		message = "was renamed. The old name will be removed from 0.6 and more. Please use '%s'",
		alternative = "preserve_highlights",
	},
}

local M = {
	defaults = {
		auto_jump = false, -- if true, automatically jump on the sole match
		forward_search = true, -- if true, the search will be done from top to bottom
		highlights_timeout = 0, -- if > 0, wait for 'updatetime' + N ms to clear hightlights (sj.prev_match/sj.next_match)
		inclusive = false, -- if true, the jump target will be included with 'operator-pending' keymaps
		max_pattern_length = 0, -- if > 0, wait for a label after N characters
		pattern = "", -- predefined pattern to use at the start of a search
		pattern_type = "vim", -- how to interpret the pattern (lua_plain, lua, vim, vim_very_magic)
		preserve_highlights = true, -- if true, create an autocmd to preserve highlights when switching colorscheme
		prompt_prefix = "", -- if set, the string will be used as a prefix in the command line
		relative_labels = false, -- if true, labels are ordered from the cursor position, not from the top of the buffer
		search_scope = "visible_lines", -- (current_line, visible_lines_above, visible_lines_below, visible_lines, buffer)
		select_window = false, -- if true, ask for a window to jump to before starting the search
		separator = ":", -- character used to split the user input in <pattern> and <label> (can be empty)
		stop_on_fail = true, -- if true, the search will stop when a search fails (no matches)
		update_search_register = false, -- if true, update the search register with the last used pattern
		use_last_pattern = false, -- if true, reuse the last pattern for next calls
		use_overlay = true, -- if true, apply an overlay to better identify labels and matches
		wrap_jumps = vim.o.wrapscan, -- if true, wrap the jumps when focusing previous or next label

		--- keymaps used during the search
		keymaps = {
			cancel = "<Esc>", -- cancel the search
			validate = "<CR>", -- jump to the focused match
			prev_match = "<A-,>", -- focus the previous match
			next_match = "<A-;>", -- focus the next match
			prev_pattern = "<C-p>", -- select the previous pattern while searching
			next_pattern = "<C-n>", -- select the next pattern while searching
			---
			delete_prev_char = "<BS>", -- delete the previous character
			delete_prev_word = "<C-w>", -- delete the previous word
			delete_pattern = "<C-u>", -- delete the whole pattern
			restore_pattern = "<A-BS>", -- restore the pattern to the last version having matches
			---
			send_to_qflist = "<A-q>", --- send the search results to the quickfix list
		},

		--- labels used for each matches. (one-character strings only)
		-- stylua: ignore
		labels = {
			"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
			"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
			"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
			"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
			"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ";", "!",
		},
	},
}

function M.filter_options(opts)
	local filtered = {}
	local warnings = {}

	for key, o in pairs(checks) do
		if o.func(opts[key]) == true then
			filtered[key] = opts[key]
		else
			filtered[key] = o.default
		end

		if opts[key] ~= nil and filtered[key] == nil then
			table.insert(warnings, ("'%s' option " .. o.message):format(key))
		end
	end

	for key, o in pairs(deprecated) do
		if filtered[key] ~= nil then
			if o.alternative ~= nil then
				filtered[o.alternative] = filtered[key]
			end
			filtered[key] = nil

			table.insert(warnings, ("'%s' option " .. o.message):format(key, o.alternative))
		end
	end

	utils.warn(warnings)
	return filtered
end

return M
