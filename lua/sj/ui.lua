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

local function init_highlights()
	for hl_group, hl_target in pairs(hl_group_links) do
		vim.api.nvim_set_hl(cache.state.bufnr or 0, hl_group, { link = hl_target, default = true })
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
		vim.api.nvim_set_hl(cache.state.bufnr or 0, hl_group, new_hl_conf)
	end
end

local function clear_highlights()
	vim.api.nvim_buf_clear_namespace(cache.state.bufnr or 0, namespace, 0, -1)
end

------------------------------------------------------------------------------------------------------------------------

local function apply_overlay(redraw)
	if cache.options.use_overlay ~= true then
		return
	end

	for lnum = 0, vim.fn.line("$") - 1 do
		vim.api.nvim_buf_add_highlight(cache.state.bufnr or 0, namespace, "SjOverlay", lnum, 0, -1)
	end

	if redraw ~= false then
		vim.cmd.redraw()
	end
end

local function highlight_matches(labels_map, pattern)
	local lnum, start_idx, end_idx, label_pos
	local cursor_label

	local label_highlight = "SjLabel"
	if cache.options.max_pattern_length > 0 and #pattern >= cache.options.max_pattern_length then
		label_highlight = "SjLimitReached"
	end
	local last_label_highlight = label_highlight

	clear_highlights()
	apply_overlay(false) -- redrawing here would cause flickering

	for label, match_range in pairs(labels_map) do
		lnum, start_idx, end_idx = unpack(match_range)
		label_pos = math.max(start_idx - 1, 0)

		cursor_label = cache.options.labels[cache.state.label_index]
		if label == cursor_label then
			label_highlight = "SjFocusedLabel"
		else
			label_highlight = last_label_highlight
		end

		vim.api.nvim_buf_add_highlight(cache.state.bufnr or 0, namespace, "SjMatches", lnum, start_idx - 1, end_idx)

		vim.api.nvim_buf_set_extmark(cache.state.bufnr or 0, namespace, lnum, label_pos, {
			virt_text = { { label, label_highlight } },
			virt_text_pos = "overlay",
		})
	end

	vim.cmd.redraw()
end

local function echo_pattern(pattern, matches)
	local highlight = ""
	if type(matches) == "table" and #matches < 1 then
		highlight = "SjNoMatches"
	end
	vim.api.nvim_echo({ { pattern, highlight } }, false, {})
end

------------------------------------------------------------------------------------------------------------------------

function M.manage_highlights(new_highlights, preserve_highlights)
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

	vim.api.nvim_create_autocmd("CursorHold", {
		group = augroup,
		pattern = "*",
		desc = "Clear highlights when the cursor move",
		callback = function()
			if cache.options.highlights_timeout > 0 then
				clear_timer = vim.defer_fn(clear_highlights, cache.options.highlights_timeout)
			end
		end,
	})
end

function M.show_feedbacks(pattern, matches, labels_map)
	cache.state.bufnr = vim.api.nvim_get_current_buf()
	apply_overlay()
	highlight_matches(labels_map, pattern)
	echo_pattern(pattern, matches)
end

function M.clear_feedbacks()
	clear_highlights()
	echo_pattern("", {})
end

function M.cancel_highlights_timer()
	if clear_timer ~= nil then
		pcall(vim.loop.timer_stop, clear_timer)
		pcall(vim.loop.timer_close, clear_timer)
	end
end

return M
