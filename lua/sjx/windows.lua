local Cache = require("sjx.cache")

------------------------------------------------------------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window.new(win_id)
	local buf_nr = vim.api.nvim_win_get_buf(win_id)
	return setmetatable({
		buf_nr = buf_nr,
		cursor_pos = vim.api.nvim_win_get_cursor(win_id),
		first_line = vim.fn.line("w0", win_id),
		last_line = vim.fn.line("w$", win_id),
		win_id = win_id,
		---
		matches_ns = vim.api.nvim_create_namespace(("sjx_matches_%d"):format(win_id)),
		overlay_ns = vim.api.nvim_create_namespace(("sjx_overlay_%d"):format(win_id)),
		---
		labels_map = {},
	}, Window)
end

------------------------------------------------------------------------------------------------------------------------

local Windows = {}
Windows.__index = Windows

function Windows.filter_wins(wins_ids)
	local current_win_id = vim.api.nvim_get_current_win()
	local filtered_wins_ids = {}
	for _, win_id in ipairs(wins_ids) do
		local win_conf = vim.api.nvim_win_get_config(win_id)
		if win_id ~= current_win_id and type(win_conf.relative) == "string" and win_conf.relative == "" then
			table.insert(filtered_wins_ids, win_id)
		end
	end
	return filtered_wins_ids
end

function Windows.new()
	local win
	local obj = {}

	if Cache.options.multi_windows == false then
		local win_id = vim.api.nvim_get_current_win()
		win = Window.new(win_id)
		win.label = ""
		obj[win_id] = win
	else
		local wins_ids = vim.api.nvim_tabpage_list_wins(0)
		wins_ids = Windows.filter_wins(wins_ids)

		for win_idx, win_id in ipairs(wins_ids) do
			obj[win_id] = Window.new(win_id)
			if #wins_ids > 1 then
				obj[win_id].label = Cache.options.labels[win_idx]
			else
				obj[win_id].label = ""
			end
		end

		if #wins_ids == 1 then
			Cache.options.multi_windows = false
		end
	end

	return setmetatable(obj, Windows)
end

return Windows
