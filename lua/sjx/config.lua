local function is_boolean(v)
	return type(v) == "boolean"
end

local function is_char(v)
	return type(v) == "string" and #v == 1
end

local function is_string(v)
	return type(v) == "string"
end

local function valid_labels(labels)
	if type(labels) ~= "table" then
		return false
	end

	return #labels > 0 and #vim.tbl_filter(is_char, labels) == #labels
end

local function valid_pattern_type(pattern_type)
	if type(pattern_type) ~= "string" or pattern_type == "" then
		return false
	end

	local valid_values = { "lua", "lua_plain", "vim", "vim_very_magic" }
	for _, expected in ipairs(valid_values) do
		if pattern_type == expected then
			return true
		end
	end

	return false
end

------------------------------------------------------------------------------------------------------------------------

local checks = {
	forward_search = {
		func = is_boolean,
		message = "must be a boolean",
	},
	labels = {
		func = valid_labels,
		message = "must be a list of characters",
	},
	multi_windows = {
		func = is_boolean,
		message = "must be a boolean",
	},
	pattern_type = {
		func = valid_pattern_type,
		message = "must be one of lua,lua_plain,vim,vim_very_magic",
	},
	prompt_prefix = {
		func = is_string,
		message = "must be a string",
	},
	relative_labels = {
		func = is_boolean,
		message = "must be a boolean",
	},
	use_overlay = {
		func = is_boolean,
		message = "must be a boolean",
	},
}

local M = {
	defaults = {
		forward_search = true, -- if false, the search will be done from bottom to top
		multi_windows = true, -- if false, perform a search only for the current window
		pattern_type = "vim", -- how to interpret the pattern (lua, lua_plain, vim, vim_very_magic)
		prompt_prefix = "", -- if set, the string will be used as a prefix in the command line
		relative_labels = false, -- if true, labels are ordered from the cursor position, not from the top of the buffer
		use_overlay = true, -- if true, apply an overlay to better identify labels and matches

		--- labels used for each matches. (list of characters only)
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

function M.check_options(opts)
	if opts ~= nil and type(opts) ~= "table" then
		return {}, { "'opts' must be nil or a table" }
	end

	if opts == nil or next(opts) == nil then
		return {}, {}
	end

	local valid_opts = {}
	local warnings = {}

	local check
	for key, val in pairs(opts) do
		check = checks[key]
		if check ~= nil then
			if check.func(val) then
				valid_opts[key] = val
			else
				table.insert(warnings, ("'%s' option " .. check.message):format(key))
			end
		end
	end

	return valid_opts, warnings
end

return M
