local HttpService = game:GetService("HttpService")

local Util = require(script.Parent.Util)

local function Proxify(rawTable, actionCallback)
	local previousTable = Util.deepCopyTable(rawTable)

	local function recursion(currentTable: {any}, key: any?)
		local proxy = newproxy(true)
		local meta = getmetatable(proxy)
		
		-- Read call (accessing property)
		meta.__index = function(self, paramKey, customMethodName: string?)
			if customMethodName == "raw" then -- Returns raw table without any metatables and proxy stuff
				return currentTable
			end

			local idx = currentTable[paramKey]

			if idx and type(idx) == "table" then
				idx = recursion(idx, true)
			else
				-- Prevent outside environment from yielding this metatable
				-- by wrapping in task.spawn
				task.spawn(function()
					actionCallback("READ", rawTable)
				end)
			end

			return idx
		end
		
		-- Write call (assigning new value to property)
		meta.__newindex = function(self, key, newValue)
			if currentTable[key] ~= newValue then
				local oldTable = Util.deepCopyTable(rawTable)

				currentTable[key] = newValue
				
				-- Prevent outside environment from yielding this metatable
				-- by wrapping in task.spawn
				-- as if something yields, it will yield here too and
				-- metatables cannot yield, thus it will lead to an error
				-- that reads "thread is not yieldable"
				task.spawn(function()
					actionCallback("WRITE", rawTable, oldTable)
				end)
			end
		end
		
		-- Implement iteration
		meta.__iter = function()
			return next, currentTable
		end
		
		-- Implement "#array" length feature
		meta.__len = function()
			return #currentTable
		end
		
		-- Can't return the object, return stringified version instead
		meta.__tostring = function()
			return HttpService:JSONEncode(currentTable)
		end

		return proxy
	end

	return recursion(rawTable)
end

return Proxify