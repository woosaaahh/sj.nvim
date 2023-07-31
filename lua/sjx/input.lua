local keycodes = {
	BS = vim.api.nvim_replace_termcodes("<BS>", true, true, true),
	ESC = vim.api.nvim_replace_termcodes("<ESC>", true, true, true),
}

------------------------------------------------------------------------------------------------------------------------

local M = {}
M.__index = M

function M.new()
	return setmetatable({ user_input = "" }, M)
end

function M:__call()
	return self.user_input
end

function M:collect()
	local ok, char = pcall(vim.fn.getcharstr)

	if not ok or char == keycodes.ESC then
		self.user_input = nil
		return nil
	end

	if char == keycodes.BS then
		self.user_input = self.user_input:sub(1, -2)
	else
		self.user_input = self.user_input .. char
	end

	return true
end

return M
