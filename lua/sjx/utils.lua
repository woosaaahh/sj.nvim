local warn_title = "SJX"
local warn_prefix = ("[%s] "):format(warn_title)
if type(vim.notify) == "table" then
	warn_prefix = ""
end

------------------------------------------------------------------------------------------------------------------------

local function string_add_prefix(s, prefix)
	return s:sub(1, #prefix) == prefix and s or prefix .. s
end

local M = {}

function M.warn(message)
	if #message == 0 then
		return
	end

	if type(message) == "string" then
		message = string_add_prefix(message, warn_prefix)
		return vim.notify(message, vim.log.levels.WARN, { title = warn_title })
	end

	message = M.tbl_map(message, function(v)
		return string_add_prefix(v, warn_prefix)
	end)
	message = table.concat(message, "\n")
	vim.notify(message, vim.log.levels.WARN, { title = warn_title })
end

function M.list_extend(base, extras)
	local extended_list = vim.deepcopy(base)
	for _, element in ipairs(extras) do
		table.insert(extended_list, element)
	end
	return extended_list
end

function M.list_reverse(list)
	local reversed_list = {}
	for i = 1, #list do
		table.insert(reversed_list, list[#list + 1 - i])
	end
	return reversed_list
end

function M.tbl_map(tbl, func)
	local modified_table = {}
	for key, val in pairs(tbl) do
		modified_table[key] = func(val)
	end
	return modified_table
end

return M
