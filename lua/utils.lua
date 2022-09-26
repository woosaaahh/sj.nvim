local M = {}

function M.tbl_map(tbl, func)
	if type(tbl) ~= "table" then
		return {}
	end

	local modified = {}

	for key, val in pairs(tbl) do
		modified[key] = func(val)
	end

	return modified
end

local function string_add_prefix(s, prefix)
	return s:sub(1, prefix:len()) ~= prefix and prefix .. s or s
end

function M.warn(message)
	local message_type = type(message)
	local prefix = "[SJ] "

	if message_type ~= "string" and message_type ~= "table" then
		return vim.notify(prefix .. "'message' for warnings must be a string or a table", vim.log.levels.WARN)
	end

	if type(message) == "table" then
		message = M.tbl_map(message, function(v)
			return string_add_prefix(v, prefix)
		end)
		message = table.concat(message, "\n")
	else
		message = string_add_prefix(message, prefix)
	end

	vim.notify(message, vim.log.levels.WARN)
end

return M
