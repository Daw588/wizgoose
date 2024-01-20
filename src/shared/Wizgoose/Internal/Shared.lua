--!strict

local Util = require(script.Parent.Util)
local Signal = require(script.Parent.Signal)

local Shared = {}

local function onChanged(box: any, userPath: string, onChangeCallback: any)
	local path = string.split(userPath, ".")
	local changeCallbackIndex = #box.ChangeCallbacks + 1

	local function onChangeInternalMapped(changes, oldTable, newTable)
		-- Imagine if you were listening to data.inventory,
		-- if the change was data.inventory.towers.minigunner,
		-- then only data.inventory has to match.

		for _, rawChange in changes do
			-- Decode change, on client it will be in a form
			-- of an array rather than dictionary/hashmap
			local change = {
				path = rawChange.path or rawChange[1],
				newValue = rawChange.newValue or rawChange[2],
				oldValue = rawChange.oldValue or rawChange[3],
			}

			-- Does path match?
			local pathMatches = true
			for index, key in path do
				if key ~= change.path[index] then
					pathMatches = false
					break
				end
			end

			-- No, go to another change
			if not pathMatches then
				continue
			end

			-- Resolve values based on tracked path
			local oldValue = oldTable
			local newValue = newTable

			for _, key in path do
				oldValue = oldValue[key]
				newValue = newValue[key]
			end

			-- Tell the user about the change
			task.defer(function()
				onChangeCallback(newValue, oldValue, change)
			end)
		end
	end

	-- Register the change callback
	table.insert(box.ChangeCallbacks, onChangeInternalMapped)

	--[[
		Current value
		
		local currentValue = stream.rawData
		for _, key in path do
			currentValue = currentValue[key]
		end
		callback(currentValue)
	]]

	local connection = {}
	function connection:Disconnect()
		table.remove(box.ChangeCallbacks, changeCallbackIndex)
	end
	return connection
end

function Shared.onChanged(box: any, userPath: string)
	local signal = Signal.new()

	local changeTracker = onChanged(box, userPath, function(...)
		--print("Change detected", userPath, ...)
		signal:Fire(...)
	end)

	signal:Disconnected(function()
		changeTracker:Disconnect()
	end)

	return signal
end

function Shared.onItemAdded(box: any, userPath: string)
	local signal = Signal.new()

	local changeTracker = onChanged(box, userPath, function(newValue, oldValue, change)
		-- Both values must be arrays, if not, return
		if not Util.isArray(newValue) or not Util.isArray(oldValue) then
			return
		end

		-- The item was removed, return
		if not change.newValue then
			return
		end

		signal:Fire(change.newValue)
	end)

	signal:Disconnected(function()
		changeTracker:Disconnect()
	end)

	return signal
end

function Shared.onItemRemoved(box: any, userPath: string)
	local signal = Signal.new()

	local changeTracker = onChanged(box, userPath, function(newValue, oldValue, change)
		-- Both values must be arrays, if not, return
		if not Util.isArray(newValue) or not Util.isArray(oldValue) then
			print("Failed, not arrays")
			return
		end

		local index = change.path[#change.path]

		if not change.oldValue then
			return
		end

		-- Send previous value (of the item at the index)
		signal:Fire(oldValue[index])
	end)

	signal:Disconnected(function()
		changeTracker:Disconnect()
	end)

	return signal
end

return Shared
