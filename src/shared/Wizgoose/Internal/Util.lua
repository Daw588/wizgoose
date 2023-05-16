--!strict

local Util = {}

function Util.deepCopyTable(tbl: any, seen: any?): any
	seen = seen or {}

	if tbl == nil then
		return nil
	end

	if seen then -- FIXES EDITOR ERRORS
		if seen[tbl] then
			return seen[tbl]
		end
	end

	local no
	if type(tbl) == "table" then
		no = {}

		if seen then -- FIXES EDITOR ERRORS
			seen[tbl] = no :: any
		end

		for k, v in next, tbl, nil do
			no[Util.deepCopyTable(k, seen)] = Util.deepCopyTable(v, seen)
		end
		setmetatable(no, Util.deepCopyTable(getmetatable(tbl), seen))
	else -- number, string, boolean, etc
		no = tbl :: any
	end
	return no :: any
end

function Util.isArray(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	-- Objects always return empty size
	if #value > 0 then
		return true
	end

	-- Only object can have empty length with elements inside
	for _, _ in pairs(value) do
		return false
	end

	-- If no elements it can be array and not at same time
	return true
end

return Util
