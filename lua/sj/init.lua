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

return M
