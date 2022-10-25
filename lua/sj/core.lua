local cache = require("sj.cache")
local ui = require("sj.ui")
local utils = require("sj.utils")

local keymaps = {
	cancel = vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
	validate = vim.api.nvim_replace_termcodes("<CR>", true, false, true),
	prev_match = vim.api.nvim_replace_termcodes("<A-,>", true, false, true),
	next_match = vim.api.nvim_replace_termcodes("<A-;>", true, false, true),
	prev_pattern = vim.api.nvim_replace_termcodes("<C-p>", true, false, true),
	next_pattern = vim.api.nvim_replace_termcodes("<C-n>", true, false, true),

	delete_prev_char = vim.api.nvim_replace_termcodes("<BS>", true, false, true),
	delete_prev_word = vim.api.nvim_replace_termcodes("<C-W>", true, false, true),
	delete_pattern = vim.api.nvim_replace_termcodes("<C-U>", true, false, true),
	restore_pattern = vim.api.nvim_replace_termcodes("<A-BS>", true, false, true),

	send_to_qflist = vim.api.nvim_replace_termcodes("<A-q>", true, false, true),
}

local search_history = {}
local pattern_index = #search_history + 1

------------------------------------------------------------------------------------------------------------------------

local function update_search_register(pattern, pattern_type)
	if type(pattern) ~= "string" or #pattern == 0 then
		return
	end

	if pattern_type == "vim_very_magic" then
		pattern = "\\v" .. pattern
	end

	vim.fn.setreg("/", pattern)
end

local function send_to_qflist(matches)
	if type(matches) ~= "table" then
		return
	end

	local lnum, start_idx, end_idx, line
	local qf_list = {}
	for match_num, match_range in ipairs(matches) do
		lnum, start_idx, end_idx = unpack(match_range)
		line = vim.fn.getline(lnum + 1)
		qf_list[match_num] = {
			text = line,
			bufnr = vim.api.nvim_get_current_buf(),
			lnum = lnum + 1,
			col = start_idx,
			end_col = end_idx,
		}
	end
	vim.fn.setqflist(qf_list)
end

local function get_prev_pattern()
	pattern_index = pattern_index <= 1 and 1 or pattern_index - 1
	return search_history[pattern_index]
end

local function get_next_pattern()
	pattern_index = pattern_index >= #search_history and #search_history or pattern_index + 1
	return search_history[pattern_index]
end

local function update_search_history(pattern)
	if type(pattern) ~= "string" or #pattern == 0 then
		return
	end

	table.insert(search_history, pattern)

	local last_pattern = pattern
	local new_search_history = {}

	for _, pattern in ipairs(search_history) do
		if pattern ~= last_pattern then
			table.insert(new_search_history, pattern)
		end
	end

	table.insert(new_search_history, last_pattern)
	search_history = new_search_history
end

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
	local iters, text_len = 0, #text
	local start_idx, end_idx, init
	local ranges = {}

	if text_len == 0 then
		return ranges
	end

	while iters <= text_len do
		iters = iters + 1

		start_idx, end_idx, init = search(text, pattern, init)
		if start_idx == nil then
			break
		end

		table.insert(ranges, { start_idx, end_idx })
	end

	return ranges
end

local function get_search_function(pattern_type)
	if type(pattern_type) ~= "string" then
		pattern_type = "vim"
	end

	local plain = pattern_type:find("plain$") and true or false
	local function lua_search(text, pattern, init)
		if vim.o.ignorecase == true and not (vim.o.smartcase == true and pattern:find("%u") ~= nil) then
			text = text:lower()
			pattern = pattern:lower()
		end
		local start_idx, end_idx = text:find(pattern, init, plain)
		if start_idx ~= nil then
			return start_idx, end_idx, start_idx and start_idx == end_idx and end_idx + 1 or end_idx
		end
	end

	local prefix = pattern_type == "vim_very_magic" and "\\v" or ""
	local function vim_search(text, pattern, init)
		local _, start_idx, end_idx = unpack(vim.fn.matchstrpos(text, prefix .. pattern, init))
		if start_idx ~= -1 then
			return start_idx + 1, end_idx, end_idx
		end
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

	local cursor_lnum, cursor_col = cache.state.cursor_pos[1], cache.state.cursor_pos[2] + 1

	local forward = cache.options.forward_search == true
	local relative = cache.options.relative_labels == true

	local match_lnum, match_col, match_end_col
	local prev_matches, next_matches = {}, {}

	for i, line in ipairs(lines) do
		if #matches > #cache.options.labels then
			break
		end

		--- skip errors due to % at the end (lua), unbalanced (), ...
		local ok, ranges = pcall(pattern_ranges, line, pattern, search)

		if ok then
			for _, match_range in ipairs(ranges) do
				match_lnum, match_col, match_end_col = first_line - 1 + i, unpack(match_range)
				match_range = { match_lnum - 1, match_col, match_end_col }

				--- prev matches
				if match_lnum < cursor_lnum then
					table.insert(prev_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == false and match_col < cursor_col then
					table.insert(prev_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == true and match_col <= cursor_col then
					table.insert(prev_matches, match_range)

				--- next matches
				elseif match_lnum == cursor_lnum and forward == false and match_col >= cursor_col then
					table.insert(next_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == true and match_col > cursor_col then
					table.insert(next_matches, match_range)
				elseif match_lnum > cursor_lnum then
					table.insert(next_matches, match_range)
				end

				---
			end
		end
	end

	if relative == false and forward == false then
		matches = utils.list_reverse(utils.list_extend(prev_matches, next_matches))
	elseif relative == false and forward == true then
		matches = utils.list_extend(prev_matches, next_matches)
	elseif relative == true and forward == false then
		matches = utils.list_extend(utils.list_reverse(prev_matches), utils.list_reverse(next_matches))
	elseif relative == true and forward == true then
		matches = utils.list_extend(next_matches, prev_matches)
	end

	return matches
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

function M.manage_keymaps(new_keymaps)
	for action, _ in pairs(keymaps) do
		if type(new_keymaps[action]) == "string" and #new_keymaps[action] > 0 then
			keymaps[action] = vim.api.nvim_replace_termcodes(new_keymaps[action], true, false, true)
		end
	end
end

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

function M.search_pattern(pattern, first_line, last_line)
	local matches = find_matches(pattern, first_line, last_line)
	local labels_map = create_labels_map(cache.options.labels, matches, false)
	return matches, labels_map
end

function M.get_lines(search_scope)
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

function M.get_user_input()
	local keynum, ok, char
	local user_input = ""
	local pattern, label, last_matching_pattern = "", "", ""
	local matches, labels_map = {}, {}
	local need_looping = true
	local first_line, last_line = M.get_lines(cache.options.search_scope)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local delete_prev_word_rx = [=[\v[[:keyword:]]\zs[^[:keyword:]]+$|[[:keyword:]]+$]=]

	pattern_index = #search_history + 1

	cache.state.first_line, cache.state.last_line = first_line, last_line
	cache.state.cursor_pos = cursor_pos

	cache.state.label_index = 1

	if cache.options.use_last_pattern == true and type(cache.state.last_used_pattern) == "string" then
		user_input = cache.state.last_used_pattern
		pattern = cache.state.last_used_pattern
		matches, labels_map = M.search_pattern(user_input, first_line, last_line)
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
			if char == keymaps.cancel or keynum == keymaps.cancel then
				user_input, labels_map = "", {}
				break
			elseif char == keymaps.validate or keynum == keymaps.validate then
				break
			elseif char == keymaps.delete_prev_char or keynum == keymaps.delete_prev_char then
				user_input = #user_input > 0 and user_input:sub(1, #user_input - 1) or user_input
			elseif char == keymaps.delete_prev_word or keynum == keymaps.delete_prev_word then
				user_input = vim.fn.substitute(user_input, delete_prev_word_rx, "", "")
			elseif char == keymaps.restore_pattern or keynum == keymaps.restore_pattern then
				user_input = last_matching_pattern
			elseif char == keymaps.delete_pattern or keynum == keymaps.delete_pattern then
				user_input = ""
			elseif char == keymaps.prev_pattern or keynum == keymaps.prev_pattern then
				user_input = get_prev_pattern()
			elseif char == keymaps.next_pattern or keynum == keymaps.next_pattern then
				user_input = get_next_pattern()
			elseif char == keymaps.prev_match or keynum == keymaps.prev_match then
				cache.state.label_index = cache.state.label_index - 1
			elseif char == keymaps.next_match or keynum == keymaps.next_match then
				cache.state.label_index = cache.state.label_index + 1
			elseif char == keymaps.send_to_qflist or keynum == keymaps.send_to_qflist then
				send_to_qflist(matches)
				break
			elseif cache.options.max_pattern_length > 0 and #pattern >= cache.options.max_pattern_length then
				user_input = user_input .. cache.options.separator .. char
			else
				user_input = user_input .. char
			end
		end

		--- matches

		pattern, label = extract_pattern_and_label(user_input, cache.options.separator)

		matches, labels_map = M.search_pattern(pattern, first_line, last_line)
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
	update_search_history(pattern)

	if cache.options.update_search_register == true then
		update_search_register(cache.state.last_used_pattern, cache.options.pattern_type)
	end

	if char == keymaps.cancel then
		M.jump_to({ cursor_pos[1] - 1, cursor_pos[2] + 1 })
		return
	end

	if
		char == keymaps.validate
		or keynum == keymaps.validate
		or char == keymaps.send_to_qflist
		or keynum == keymaps.send_to_qflist
	then
		return
	end

	return user_input, labels_map
end

return M
