local M = {}

function M.new(data, wrap)
	data = vim.tbl_islist(data) and vim.deepcopy(data) or {}
	wrap = type(wrap) == "boolean" and wrap or false
	local cursor = 1

	local mt = {}
	mt.__index = mt

	function mt:position()
		return cursor
	end

	function mt:current()
		return self[cursor]
	end

	function mt:first()
		return self[1]
	end

	function mt:last()
		return self[#self]
	end

	function mt:previous()
		if cursor <= 1 and wrap == false then
			cursor = 1
		elseif cursor <= 1 and wrap == true then
			cursor = #self
		else
			cursor = cursor - 1
		end
		return self[cursor]
	end

	function mt:next()
		if cursor >= #self and wrap == false then
			cursor = #self
		elseif cursor >= #self and wrap == true then
			cursor = 1
		else
			cursor = cursor + 1
		end
		return self[cursor]
	end

	function mt:seek(position)
		if type(position) ~= "number" or position < 0 or position > #self + 1 then
			cursor = 1
		else
			cursor = position
		end
		return self[cursor]
	end

	function mt:insert_uniq(new_value)
		local new_data = {}

		for _, value in pairs(self) do
			if value ~= new_value then
				table.insert(new_data, value)
			end
		end
		table.insert(new_data, new_value)

		return setmetatable(new_data, mt)
	end

	function mt:uniq()
		local seen = {}
		local new_data = {}

		for _, value in pairs(self) do
			if seen[value] == nil then
				seen[value] = true
				table.insert(new_data, value)
			end
		end

		cursor = 1
		return setmetatable(new_data, mt)
	end

	return setmetatable(data, mt)
end

return M
