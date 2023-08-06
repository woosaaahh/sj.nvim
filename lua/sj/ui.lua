local cache = require("sj.cache")
local utils = require("sj.utils")

local clear_timer
local augroup = vim.api.nvim_create_augroup("SJ", { clear = true })
local namespace = vim.api.nvim_create_namespace("SJ")

local hl_group_links = {
	SjFocusedLabel = "DiffText",
	SjLabel = "IncSearch",
	SjLimitReached = "WildMenu",
	SjMatches = "Search",
	SjNoMatches = "ErrorMsg",
	SjOverlay = "Comment",
}

local M = {}

------------------------------------------------------------------------------------------------------------------------

local function valid_buf_nr(buf_nr)
	return type(buf_nr) == "number" and vim.api.nvim_buf_is_valid(buf_nr)
end

local function init_highlights()
	for hl_group, hl_target in pairs(hl_group_links) do
		vim.api.nvim_set_hl(0, hl_group, { link = hl_target, default = true })
	end
end
init_highlights()

local function replace_highlights(new_highlights)
	if type(new_highlights) ~= "table" then
		return
	end

	local old_hl_conf, new_hl_conf

	for hl_group in pairs(hl_group_links) do
		old_hl_conf = vim.api.nvim_get_hl_by_name(hl_group, true)
		new_hl_conf = new_highlights[hl_group] or old_hl_conf
		vim.api.nvim_set_hl(0, hl_group, new_hl_conf)
	end
end

local function clear_highlights(buf_nr)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0
	vim.api.nvim_buf_clear_namespace(buf_nr, namespace, 0, -1)
end

------------------------------------------------------------------------------------------------------------------------

local function apply_overlay(buf_nr, redraw)
	if cache.options.use_overlay ~= true then
		return
	end
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0

	local first_line, last_line = 0, vim.fn.line("$")
	if cache.options.search_scope == "current_line" then
		last_line = last_line - 1
	end

	if cache.options.search_scope == "current_line" then
		local win_id = vim.api.nvim_get_current_win()
		first_line, last_line = unpack(vim.api.nvim_win_get_cursor(win_id))
		first_line, last_line = first_line - 1, first_line - 0
	end

	vim.api.nvim_buf_set_extmark(buf_nr, namespace, first_line, 0, {
		end_row = last_line,
		hl_group = "SjOverlay",
		priority = 1000 + buf_nr,
		virt_text_pos = "overlay",
	})

	if redraw ~= false then
		vim.cmd.redraw()
	end
end

local function echo_pattern(pattern, matches)
	local highlight = ""
	if pattern ~= nil and #pattern > 0 and type(matches) == "table" and #matches < 1 then
		highlight = "SjNoMatches"
	end

	if pattern ~= nil and type(cache.options.prompt_prefix) == "string" then
		pattern = cache.options.prompt_prefix .. pattern
	else
		pattern = ""
	end

	vim.api.nvim_echo({ { pattern, highlight } }, false, {})
	vim.cmd("redraw!")
end

local function win_show_indicators(_, buf_nr, first_line, last_line, label)
	vim.api.nvim_buf_set_extmark(buf_nr, namespace, first_line - 1, 0, {
		virt_text = { { label, "SjLimitReached" } },
		virt_text_pos = "overlay",
		virt_text_win_col = -1,
	})
	vim.api.nvim_buf_set_extmark(buf_nr, namespace, first_line - 1, 0, {
		virt_text = { { label, "SjLimitReached" } },
		virt_text_pos = "right_align",
	})
	vim.api.nvim_buf_set_extmark(buf_nr, namespace, last_line - 1, 0, {
		virt_text = { { label, "SjLimitReached" } },
		virt_text_pos = "overlay",
		virt_text_win_col = -1,
	})
	vim.api.nvim_buf_set_extmark(buf_nr, namespace, last_line - 1, 0, {
		virt_text = { { label, "SjLimitReached" } },
		virt_text_pos = "right_align",
	})
	vim.cmd("redraw")
end

------------------------------------------------------------------------------------------------------------------------

function M.manage_highlights(new_highlights, preserve_highlights)
	local buf_nr = vim.api.nvim_get_current_buf()

	replace_highlights(new_highlights)

	if preserve_highlights == true then
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = augroup,
			pattern = "*",
			desc = "Preserve highlights",
			callback = function()
				replace_highlights(new_highlights)
			end,
		})
	else
		vim.api.nvim_clear_autocmds({ group = augroup, event = "ColorScheme" })
	end

	vim.api.nvim_create_autocmd({ "CursorHold", "ModeChanged" }, {
		group = augroup,
		pattern = "*",
		desc = "Clear highlights when the cursor stopped moving for a while or the mode changed",
		callback = function(args)
			if args.event == "CursorHold" and cache.options.highlights_timeout > 0 then
				clear_timer = vim.defer_fn(function()
					clear_highlights(buf_nr)
				end, cache.options.highlights_timeout)
			else
				clear_highlights(buf_nr)
			end
		end,
	})
end

function M.highlight_matches(buf_nr, labels_map, pattern, show_labels, focused_label)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0

	local lnum, start_idx, match_text, label_pos

	local label_highlight = "SjLabel"
	if cache.options.max_pattern_length > 0 and #pattern >= cache.options.max_pattern_length then
		label_highlight = "SjLimitReached"
	end

	clear_highlights(buf_nr)
	apply_overlay(buf_nr, false) -- redrawing here would cause flickering

	for label, match_range in pairs(labels_map) do
		lnum, start_idx, match_text = unpack(match_range)
		label_pos = math.max(start_idx - 1, 0)

		vim.api.nvim_buf_set_extmark(buf_nr, namespace, lnum, start_idx - 1, {
			priority = 1100 + buf_nr,
			virt_text = { { match_text, "SjMatches" } },
			virt_text_pos = "overlay",
		})

		if show_labels ~= false then
			vim.api.nvim_buf_set_extmark(buf_nr, namespace, lnum, label_pos, {
				priority = 1200 + buf_nr,
				virt_text = { { label, label == focused_label and "SjFocusedLabel" or label_highlight } },
				virt_text_pos = "overlay",
			})
		end
	end

	vim.cmd.redraw()
end

function M.show_feedbacks(buf_nr, pattern, matches, labels_map, focused_label)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0
	apply_overlay(buf_nr)
	M.highlight_matches(buf_nr, labels_map, pattern, true, focused_label)
	echo_pattern(pattern, matches)
end

function M.clear_feedbacks(buf_nr)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0
	clear_highlights(buf_nr)
	echo_pattern(nil, {})
	vim.cmd("redraw!")
end

function M.cancel_highlights_timer()
	if clear_timer ~= nil then
		pcall(vim.loop.timer_stop, clear_timer)
		pcall(vim.loop.timer_close, clear_timer)
	end
end

function M.multi_win_show_indicators(wins_list, wins_ctxt)
	local c
	utils.multi_win_call(wins_list, function(win_id)
		c = wins_ctxt[win_id]
		win_show_indicators(win_id, c.buf_nr, c.first_line, c.last_line, c.label)
	end)
end

function M.multi_win_hide_indicators(wins_list, wins_ctxt)
	local c
	utils.multi_win_call(wins_list, function(win_id)
		c = wins_ctxt[win_id]
		clear_highlights(c.buf_nr)
	end)
end

return M
