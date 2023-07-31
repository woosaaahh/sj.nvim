local Cache = require("sjx.cache")
local Config = require("sjx.config")
local Core = require("sjx.core")
local Utils = require("sjx.utils")

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.setup(opts)
	local options, warnings = Config.check_options(opts)
	if #warnings > 0 then
		return Utils.warn(warnings)
	end

	Cache.options = vim.tbl_deep_extend("force", Config.defaults, options)
	Cache.defaults = vim.deepcopy(Cache.options)
end

function M.run(opts)
	if Cache.defaults == nil or next(Cache.defaults) == nil then
		return Utils.warn("You need to call the setup() function at least once.")
	end

	local options, warnings = Config.check_options(opts)
	if #warnings > 0 then
		return Utils.warn(warnings)
	end

	Cache.options = vim.tbl_deep_extend("force", Cache.defaults, options)
	Core.run()
end

return M
