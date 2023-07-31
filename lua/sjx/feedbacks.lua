local Cache = require("sjx.cache")

local hl_group_links = {
	SjxLabel = "IncSearch",
	SjxMatches = "Search",
	SjxNoMatches = "WarningMsg",
	SjxOverlay = "Comment",
}
for hl_group, hl_target in pairs(hl_group_links) do
	vim.api.nvim_set_hl(0, hl_group, { link = hl_target, default = true })
end

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.show_overlay(win)
	if not Cache.options.use_overlay then
		return
	end

	vim.api.nvim_buf_set_extmark(win.buf_nr, win.overlay_ns, win.first_line - 1, 0, {
		end_row = win.last_line,
		hl_group = "SjxOverlay",
		priority = 1000 - win.buf_nr,
	})
end

function M.show_matches(win, labels_map)
	local lnum, col, text
	for label, match in pairs(labels_map) do
		lnum, col, text = unpack(match)
		vim.api.nvim_buf_set_extmark(win.buf_nr, win.matches_ns, lnum - 1, col - 1, {
			priority = 1200 + (win.win_id - 1000),
			virt_text = { { label, "SjxLabel" }, { text, "SjxMatches" } },
			virt_text_pos = "overlay",
		})
	end
end

function M.echo_pattern(pattern, found_matches)
	if pattern == nil then
		pattern = ""
	else
		pattern = Cache.options.prompt_prefix .. pattern
	end

	local highlight = ""
	if found_matches == false then
		highlight = "SjxNoMatches"
	end

	vim.api.nvim_echo({ { pattern, highlight } }, false, {})
end

function M.clear_namespace(buf_nr, namespace)
	vim.api.nvim_buf_clear_namespace(buf_nr, namespace, 0, -1)
end

function M.redraw()
	vim.cmd("redraw")
end

return M
