local warn_title = "SJ.nvim"
local warn_prefix = ("[%s] "):format(warn_title)

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
	local prefix = type(vim.notify) == "table" and "" or warn_prefix

	if message_type ~= "string" and message_type ~= "table" then
		return vim.notify(
			prefix .. "'message' for warnings must be a string or a table",
			vim.log.levels.WARN,
			{ title = warn_title }
		)
	end

	if #message == 0 then
		return
	end

	if type(message) == "table" then
		message = M.tbl_map(message, function(v)
			return string_add_prefix(v, prefix)
		end)
		message = table.concat(message, "\n")
	else
		message = string_add_prefix(message, prefix)
	end

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

function M.tab_list_wins(tab_nr)
	tab_nr = (type(tab_nr) == "number" and vim.api.nvim_tabpage_is_valid(tab_nr)) and tab_nr or 0

	return vim.tbl_filter(function(win_id)
		local win_conf = vim.api.nvim_win_get_config(win_id)
		if type(win_conf.relative) == "string" and win_conf.relative == "" then
			return win_id
		end
	end, vim.api.nvim_tabpage_list_wins(tab_nr))
end

function M.multi_win_call(wins_list, func, ...)
	if type(wins_list) ~= "table" or type(func) ~= "function" then
		return {}
	end

	local args = { ... }
	local results = {}

	for _, win_id in ipairs(wins_list) do
		results[win_id] = vim.api.nvim_win_call(win_id, function()
			return func(win_id, unpack(args))
		end)
	end

	return results
end

return M
