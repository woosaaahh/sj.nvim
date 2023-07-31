local Cache = require("sjx.cache")
local Feedbacks = require("sjx.feedbacks")
local Input = require("sjx.input")
local Labels = require("sjx.labels")
local Search = require("sjx.search")
local Windows = require("sjx.windows")

------------------------------------------------------------------------------------------------------------------------

local function wins_show_overlay(wins)
	for _, win in pairs(wins) do
		Feedbacks.show_overlay(win)
	end
	Feedbacks.redraw()
end

local function wins_search(wins, search, pattern)
	local label_len = Cache.options.multi_windows == false and 1 or 2
	local last_char = pattern:sub(-1, -1)
	local last_chars = pattern:sub(-label_len, -1)
	local matches, default_labels, labels = {}, Cache.options.labels, {}
	local found_matches = false

	for _, win in pairs(wins) do
		if win.labels_map[last_chars] ~= nil then
			return win.win_id, win.labels_map[last_chars]
		end

		matches = search(pattern, win)
		if #matches == 0 then
			--- No matches can also happens when a character is for a label, so we
			--- have to keep the feedbacks on screen. Displaying all previous matches
			--- would add visual noise so we extract the one matching the label.
			win.labels_map = {
				[last_char .. win.label] = win.labels_map[last_char .. win.label],
			}
		else
			labels = Labels.discard_labels(default_labels, matches, last_char, win.label)
			win.labels_map = Labels.create_matches_map(labels, matches)
			found_matches = true
		end

		Feedbacks.clear_namespace(win.buf_nr, win.matches_ns)
		Feedbacks.show_matches(win, win.labels_map)
	end

	Feedbacks.echo_pattern(pattern, found_matches)
	Feedbacks.redraw()
end

local function wins_clear_feedbacks(wins)
	for _, win in pairs(wins) do
		Feedbacks.clear_namespace(win.buf_nr, win.overlay_ns)
		Feedbacks.clear_namespace(win.buf_nr, win.matches_ns)
	end
	Feedbacks.echo_pattern()
	Feedbacks.redraw()
end

local function jump_to(win_id, target)
	if type(target) ~= "table" then
		return
	end

	local new_row, new_col = unpack(target)
	if type(new_row) ~= "number" or type(new_col) ~= "number" then
		return
	end

	vim.api.nvim_set_current_win(win_id)
	vim.api.nvim_win_set_cursor(win_id, { new_row - 0, new_col - 1 })
end

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.run()
	local input = Input.new()
	local search = Search.new()
	local wins = Windows.new()
	Labels.discard_wins_labels(wins)

	local win_id, target

	wins_show_overlay(wins)
	Feedbacks.echo_pattern(input())

	while input:collect() do
		win_id, target = wins_search(wins, search, input())
		if win_id and target then
			break
		end
	end

	wins_clear_feedbacks(wins)

	if win_id and target then
		jump_to(win_id, target)
	end
end

return M
