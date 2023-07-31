local Cache = require("sjx.cache")
local Utils = require("sjx.utils")

------------------------------------------------------------------------------------------------------------------------

local function get_search_function(pattern_type)
	if type(pattern_type) ~= "string" then
		pattern_type = "vim"
	end

	local plain = pattern_type:find("plain$") and true or false
	local function lua_search(pattern, text, init)
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
	local function vim_search(pattern, text, init)
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

local function search_from_lines(search_function, pattern, lines, first_line)
	first_line = first_line or 1

	local iters
	local start_col, end_col, init_pos

	coroutine.yield()

	for index, line in ipairs(lines) do
		iters = 0
		while iters < #line do
			iters = iters + 1

			--- skip errors due to % at the end (lua), unbalanced braces, ...
			_, start_col, end_col, init_pos = pcall(search_function, pattern, line, init_pos)
			if not start_col then
				break
			end

			coroutine.yield(
				first_line + index - 1,
				start_col,
				line:sub(start_col, end_col),
				line:sub(end_col + 1, end_col + 1)
			)
		end
	end
end

local function search_from_window(search_function, pattern, win)
	local lines = vim.api.nvim_buf_get_lines(win.buf_nr, win.first_line - 1, win.last_line, false)
	search_from_lines(search_function, pattern, lines, win.first_line)
end

------------------------------------------------------------------------------------------------------------------------

local M = {}
M.__index = M

function M.new(opts)
	opts = vim.tbl_deep_extend("force", Cache.options, type(opts) == "table" and opts or {})

	local obj = {
		forward_search = opts.forward_search,
		pattern_type = opts.pattern_type,
		relative_labels = opts.relative_labels,
	}

	obj.smartcase = vim.o.smartcase and obj.pattern_type:find("vim")
	obj.search_function = get_search_function(obj.pattern_type)

	return setmetatable(obj, M)
end

function M:__call(pattern, win)
	if self.smartcase and pattern:find("%u") then
		pattern = "\\C" .. pattern
	end

	local forward = self.forward_search
	local relative = self.relative_labels
	local search_function = self.search_function

	local row, start_col, text, next_char
	local match
	local cursor_row, cursor_col = win.cursor_pos[1], win.cursor_pos[2] + 1
	local prev_matches, next_matches = {}, {}

	local co = coroutine.create(search_from_window)
	local ok = coroutine.resume(co, search_function, pattern, win)

	while ok do
		ok, row, start_col, text, next_char = coroutine.resume(co)
		if not ok or not row then
			break
		end

		match = { row, start_col, text, next_char }

		if row < cursor_row then
			table.insert(prev_matches, match)
		elseif row > cursor_row then
			table.insert(next_matches, match)
		else
			if (not forward and start_col < cursor_col) or (forward and start_col <= cursor_col) then
				table.insert(prev_matches, match)
			elseif (not forward and start_col >= cursor_col) or (forward and start_col > cursor_col) then
				table.insert(next_matches, match)
			end
		end
	end

	local matches = {}

	if not forward and not relative then
		matches = Utils.list_reverse(Utils.list_extend(prev_matches, next_matches))
	elseif not forward and relative then
		matches = Utils.list_extend(Utils.list_reverse(prev_matches), Utils.list_reverse(next_matches))
	elseif forward and not relative then
		matches = Utils.list_extend(prev_matches, next_matches)
	elseif forward and relative then
		matches = Utils.list_extend(next_matches, prev_matches)
	end

	return matches
end

return M
