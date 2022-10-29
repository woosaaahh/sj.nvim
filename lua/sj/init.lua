local config = require("sj.config")
local core = require("sj.core")
local cache = require("sj.cache")
local ui = require("sj.ui")
local utils = require("sj.utils")

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.debug_cache(key)
	print(vim.inspect(type(key) == "string" and cache[key] or cache))
end

function M.setup(opts)
	cache.defaults = vim.tbl_deep_extend("force", config.defaults, config.filter_options(opts or {}))
	cache.options = vim.deepcopy(cache.defaults)

	core.manage_keymaps(cache.options.keymaps)
	ui.manage_highlights(cache.options.highlights, cache.options.preserve_highlights)
end

function M.run(opts)
	if cache.defaults == nil or next(cache.defaults) == nil then
		return utils.warn("You need to call require('sj').setup() at least once.")
	end

	cache.options = vim.tbl_deep_extend("force", cache.defaults, config.filter_options(opts or {}))
	local user_input, labels_map = core.get_user_input()
	core.extract_range_and_jump_to(user_input, labels_map)
end

function M.redo(opts)
	if cache.defaults == nil or next(cache.defaults) == nil then
		return utils.warn("You need to call require('sj').setup() at least once.")
	end

	opts = opts or {}
	opts.use_last_pattern = true

	cache.options = vim.tbl_deep_extend("force", cache.options, config.filter_options(opts))
	local user_input, labels_map = core.get_user_input()
	core.extract_range_and_jump_to(user_input, labels_map)
end

function M.prev_match()
	local forward_search_bak = cache.options.forward_search
	cache.options.forward_search = not cache.options.forward_search

	M.next_match()

	cache.options.forward_search = forward_search_bak
end

function M.next_match()
	if cache.defaults == nil or next(cache.defaults) == nil then
		return utils.warn("You need to call require('sj').setup() at least once.")
	end

	local pattern = cache.state.last_used_pattern or ""
	if type(pattern) ~= "string" or #pattern == 0 then
		return
	end

	local relative_labels = cache.options.relative_labels
	cache.options.relative_labels = true

	local win_id = vim.api.nvim_get_current_win()
	local buf_nr = vim.api.nvim_win_get_buf(win_id)
	local search_opts = {
		forward = cache.options.forward_search,
		pattern_type = cache.options.pattern_type,
		relative = cache.options.relative_labels,
		scope = cache.options.search_scope,
	}

	local matches = core.win_find_pattern(win_id, pattern, search_opts)
	local labels_map = core.create_labels_map(cache.options.labels, matches, false)

	ui.cancel_highlights_timer()
	ui.highlight_matches(buf_nr, labels_map, pattern, false)
	core.focus_label(1, matches)

	cache.options.relative_labels = relative_labels
end

return M
