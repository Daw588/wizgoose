local function MapChanges(a: any, b: any, prevRoot: any?, prevChangeLog: any?)
	local changeLog = prevChangeLog or {}
	local root = prevRoot or {}

	if type(a) == type(b) then
		-- print("Data type did not change")
		if type(a) ~= "table" then
			if a ~= b then
				-- Change
				table.insert(changeLog, {
					path = if next(root) == nil then {} else {unpack(root)},
					oldValue = a,
					newValue = b
				})
				return changeLog -- Cannot iterate over an non-table value, stop here!
			end
		end
	else
		-- print("Data type changed")
		-- Change
		table.insert(changeLog, {
			path = if next(root) == nil then {} else {unpack(root)},
			oldValue = a,
			newValue = b
		})
		return changeLog
	end

	local function recordChanges(key)
		local nextRoot = if not root then {} else {unpack(root)}
		table.insert(nextRoot, key)
		
		table.insert(changeLog, {
			path = nextRoot,
			oldValue = a[key],
			newValue = b[key]
		})
	end
	
	--[[
		Decide which table to use as comparator (previous)
		
		If table A happens to have more items than table B,
		we can assume that table A has more because
		
		A) item has been added to table A
		B) item has been removed from table B
		
		Therefore, we have a "probable cause" to assume
		that table A can be used as comparator.
		
		If it happens that table B has more items than table A,
		it will be vice versa.
		
		Also if any of the tables happen to be empty,
		other table will be used in place of said table.
		
		For example, if table A is chosen given the assumptions
		listed previously, and it also happens that it is empty,
		table B will be used in place of it.
	]]
	local sample = {}
	
	if #a < #b then
		sample = if next(b) == nil then a else b
	else
		sample = if next(a) == nil then b else a
	end
	
	-- print("Checking", a, b, "Chose", sample)
	
	for key, value in sample do
		if type(a[key]) == type(b[key]) then
			-- No change
			if type(a[key]) == "table" then
				-- print("Nested table", a[key], b[key])
				-- Nested table
				local nextRoot = if not root then {} else {unpack(root)}
				table.insert(nextRoot, key)
				
				MapChanges(a[key], b[key], nextRoot, changeLog)
			else
				-- print("Flat table", a[key], b[key])
				-- Not a nested table, phew!
				if a[key] ~= b[key] then
					-- Change
					recordChanges(key)
				end
			end
		else
			-- Change
			recordChanges(key)
		end
	end

	return changeLog
end

return MapChanges