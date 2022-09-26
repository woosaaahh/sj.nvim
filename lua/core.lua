local cache = require("sj.cache")
local ui = require("sj.ui")

local keys = {
	ESC = vim.api.nvim_replace_termcodes("<Esc>", true, false, true),

	CR = vim.api.nvim_replace_termcodes("<CR>", true, false, true),
	NL = vim.api.nvim_replace_termcodes("<NL>", true, false, true),

	BS = vim.api.nvim_replace_termcodes("<BS>", true, false, true),
	C_H = vim.api.nvim_replace_termcodes("<C-H>", true, false, true),

	A_BS = vim.api.nvim_replace_termcodes("<A-BS>", true, false, true),

	C_U = vim.api.nvim_replace_termcodes("<C-U>", true, false, true),

	A_COMMA = vim.api.nvim_replace_termcodes("<A-,>", true, false, true),
	A_SEMICOLON = vim.api.nvim_replace_termcodes("<A-;>", true, false, true),
}

------------------------------------------------------------------------------------------------------------------------

local function create_labels_map(labels, matches, reverse)
	local label
	local labels_map = {}

	for match_num, _ in pairs(matches) do
		label = labels[match_num]
		if not label then
			break
		end

		if reverse == true then
			labels_map[label] = matches[#matches + 1 - match_num]
		else
			labels_map[label] = matches[match_num]
		end
	end

	return labels_map
end

local function pattern_ranges(text, pattern, search)
	local start_idx, end_idx, init
	local iters, text_len, ranges = 0, #text, {}

	start_idx, end_idx = search(text, pattern)

	while end_idx and end_idx > 0 do
		if iters > text_len then
			break
		end
		iters = iters + 1

		if start_idx == end_idx then
			init = end_idx + 1
		else
			init = end_idx
		end

		table.insert(ranges, { start_idx, end_idx })
		start_idx, end_idx = search(text, pattern, init)
	end

	return ranges
end

local function get_search_function(pattern_type)
	if type(pattern_type) ~= "string" then
		pattern_type = "vim"
	end

	local plain = pattern_type:find("plain$") and true or false
	local function lua_search(text, pattern, init)
		return text:find(pattern, init, plain)
	end

	local prefix = pattern_type == "vim_very_magic" and "\\v" or ""
	local function vim_search(text, pattern, init)
		local _, start_idx, end_idx = unpack(vim.fn.matchstrpos(text, prefix .. pattern, init))
		return start_idx + 1, end_idx
	end

	if pattern_type:find("^lua") then
		return lua_search
	else
		return vim_search
	end
end

local function find_matches(pattern, first_line, last_line)
	if type(pattern) ~= "string" or #pattern < 1 then
		return {}
	end

	local lines = vim.api.nvim_buf_get_lines(0, first_line - 1, last_line, false)
	local search = get_search_function(cache.options.pattern_type)
	local matches = {}

	if vim.opt.smartcase and not pattern:find("%u") then
		pattern = pattern:lower()
	end

	for i, line in ipairs(lines) do
		if #matches > #cache.options.labels then
			break
		end

		--- skip errors due to % at the end (lua), unbalanced (), ...
		local ok, ranges = pcall(pattern_ranges, line, pattern, search)
		if ok then
			for _, match_range in ipairs(ranges) do
				table.insert(matches, { first_line + i - 2, unpack(match_range) })
			end
		end
	end

	return matches
end

local function get_lines(search_scope)
	local cursor_line = vim.fn.line(".")
	local first_visible_line, last_visible_line = vim.fn.line("w0"), vim.fn.line("w$")
	local first_buffer_line, last_buffer_line = 1, vim.fn.line("$")

	local cases = {
		current_line = { cursor_line, cursor_line },
		visible_lines_above = { first_visible_line, cursor_line - 1 },
		visible_lines_below = { cursor_line + 1, last_visible_line },
		visible_lines = { first_visible_line, last_visible_line },
		buffer = { first_buffer_line, last_buffer_line },
	}

	return unpack(cases[search_scope] or cases["visible_lines"])
end

local function extract_pattern_and_label(user_input, separator)
	if type(separator) ~= "string" then
		separator = ":"
	end
	local separator_pos = user_input:match("^.*()" .. vim.pesc(separator))

	if separator_pos then
		return user_input:sub(1, separator_pos - 1), user_input:sub(separator_pos + separator:len())
	else
		return user_input, ""
	end
end

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.jump_to(range)
	if type(range) ~= "table" then
		return
	end

	local lnum, col = unpack(range)
	if type(lnum) == "number" and type(col) == "number" then
		vim.api.nvim_win_set_cursor(0, { lnum + 1, col - 1 })
	end
end

function M.extract_range_and_jump_to(user_input, labels_map)
	if type(user_input) ~= "string" or type(labels_map) ~= "table" then
		return
	end

	local _, label = extract_pattern_and_label(user_input, cache.options.separator)

	if #user_input and label == "" then -- auto_jump
		label = cache.options.labels[1]
	end

	M.jump_to(labels_map[label])
end

function M.focus_label(label_index, matches)
	if type(label_index) ~= "number" then
		label_index = 1
	end

	local wrap_jumps = cache.options.wrap_jumps == true
	local match_range = {}

	if label_index <= 0 then
		label_index = wrap_jumps and #matches or 1
		match_range = matches[label_index]
	elseif label_index > #matches then
		label_index = wrap_jumps and 1 or #matches
		match_range = matches[label_index]
	else
		match_range = matches[label_index]
	end

	cache.state.label_index = label_index
	M.jump_to(match_range)
end

function M.search_pattern(pattern)
	local first_line, last_line = get_lines(cache.options.search_scope)
	local matches = find_matches(pattern, first_line, last_line)
	local labels_map = create_labels_map(cache.options.labels, matches, false)
	return matches, labels_map
end

function M.get_user_input()
	local keynum, ok, char
	local user_input = ""
	local pattern, label, last_matching_pattern = "", "", ""
	local matches, labels_map = {}, {}
	local need_looping = true
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	cache.state.label_index = 1

	if cache.options.use_last_pattern == true and type(cache.state.last_used_pattern) == "string" then
		user_input = cache.state.last_used_pattern
		pattern = cache.state.last_used_pattern
		matches, labels_map = M.search_pattern(user_input)
		M.focus_label(cache.state.label_index, matches)
	end

	if cache.options.auto_jump and #matches == 1 then
		need_looping = false
	end

	if need_looping == true then
		ui.show_feedbacks(pattern, matches, labels_map)
	end

	while need_looping == true do
		--- user input

		ok, keynum = pcall(vim.fn.getchar)
		if ok then
			char = type(keynum) == "number" and vim.fn.nr2char(keynum) or ""
			if char == keys.ESC then
				user_input, labels_map = "", {}
				break
			elseif char == keys.CR or char == keys.NL then
				break
			elseif keynum == keys.BS or char == keys.C_H then
				user_input = #user_input > 0 and user_input:sub(1, #user_input - 1) or user_input
			elseif keynum == keys.A_BS then
				user_input = last_matching_pattern
			elseif char == keys.C_U then
				user_input = ""
			elseif keynum == keys.A_COMMA then
				cache.state.label_index = cache.state.label_index - 1
			elseif keynum == keys.A_SEMICOLON then
				cache.state.label_index = cache.state.label_index + 1
			elseif cache.options.max_pattern_length > 0 and #pattern >= cache.options.max_pattern_length then
				user_input = user_input .. cache.options.separator .. char
			else
				user_input = user_input .. char
			end
		end

		--- matches

		pattern, label = extract_pattern_and_label(user_input, cache.options.separator)

		matches, labels_map = M.search_pattern(pattern)
		M.focus_label(cache.state.label_index, matches)
		ui.show_feedbacks(pattern, matches, labels_map)

		if #matches > 0 then
			last_matching_pattern = pattern
		end

		if #pattern > 0 and #label > 0 then
			break
		end

		if cache.options.auto_jump and #matches == 1 then
			break
		end

		---
	end
	ui.clear_feedbacks()
	cache.state.last_used_pattern = pattern

	if char == keys.ESC then
		M.jump_to({ cursor_pos[1] - 1, cursor_pos[2] + 1 })
		return
	end

	if char == keys.CR or char == keys.NL then
		return
	end

	return user_input, labels_map
end

return M