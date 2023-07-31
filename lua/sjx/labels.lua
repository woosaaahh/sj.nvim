local Cache = require("sjx.cache")

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.discard_wins_labels(wins)
	if Cache.options.multi_windows ~= true then
		return
	end

	local wins_labels = {}
	for _, win in pairs(wins) do
		wins_labels[win.label] = true
	end

	local new_labels = {}
	for _, label in ipairs(Cache.options.labels) do
		if wins_labels[label:sub(1, 1)] == nil then
			table.insert(new_labels, label)
		end
	end

	Cache.options.labels = new_labels
end

--- Discarding labels avoid confusion between a character typed for the pattern
--- and a character typed for a label (or a window label).
--- This gives the priority to the pattern and avoid premature jumps.
function M.discard_labels(labels, matches, last_char, window_label)
	if type(matches) ~= "table" or #matches == 0 then
		return labels
	end

	local discardable = {}
	for _, match in pairs(matches) do
		--- The last element of a "match" is the next character following a match.
		discardable[match[#match] .. window_label] = true
	end
	if Cache.options.multi_windows == true then
		discardable[last_char .. window_label] = true
	end

	local new_labels = {}
	for _, label in ipairs(labels) do
		if discardable[label .. window_label] ~= true then
			table.insert(new_labels, label .. window_label)
		end
	end
	return new_labels
end

function M.create_matches_map(labels, matches)
	local label
	local labels_map = {}

	for match_num, _ in pairs(matches) do
		label = labels[match_num]
		if not label then
			break
		end
		labels_map[label] = matches[match_num]
	end

	return labels_map
end

return M
