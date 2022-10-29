local cache = require("sj.cache")

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

	for lnum = 0, vim.fn.line("$") - 1 do
		vim.api.nvim_buf_add_highlight(buf_nr, namespace, "SjOverlay", lnum, 0, -1)
	end

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

function M.highlight_matches(buf_nr, labels_map, pattern, show_labels)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0

	local lnum, start_idx, end_idx, label_pos
	local cursor_label

	local label_highlight = "SjLabel"
	if cache.options.max_pattern_length > 0 and #pattern >= cache.options.max_pattern_length then
		label_highlight = "SjLimitReached"
	end
	local last_label_highlight = label_highlight

	clear_highlights(buf_nr)
	apply_overlay(buf_nr, false) -- redrawing here would cause flickering

	for label, match_range in pairs(labels_map) do
		lnum, start_idx, end_idx = unpack(match_range)
		label_pos = math.max(start_idx - 1, 0)

		cursor_label = cache.options.labels[cache.state.label_index]
		if label == cursor_label then
			label_highlight = "SjFocusedLabel"
		else
			label_highlight = last_label_highlight
		end

		vim.api.nvim_buf_add_highlight(buf_nr, namespace, "SjMatches", lnum, start_idx - 1, end_idx)

		if show_labels ~= false then
			vim.api.nvim_buf_set_extmark(buf_nr, namespace, lnum, label_pos, {
				virt_text = { { label, label_highlight } },
				virt_text_pos = "overlay",
			})
		end
	end

	vim.cmd.redraw()
end

function M.show_feedbacks(buf_nr, pattern, matches, labels_map)
	buf_nr = valid_buf_nr(buf_nr) and buf_nr or 0
	apply_overlay(buf_nr)
	M.highlight_matches(buf_nr, labels_map, pattern)
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

return M
