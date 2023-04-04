--!strict

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Internal.Shared)
local Util = require(script.Parent.Internal.Util)

local streams = {}

local Client = {}

function Client.get(name: string)
	-- Dont make multiple remote events when there is 2 that already exist for this table
	if streams[name] then
		local calls = 0
		repeat
			task.wait()
			
			-- Prevent infinite yield
			calls += 1
			if calls > 100_000 then
				error("Tried to retrieve a stream but reached the wait limit, did you forget to create the stream?")
			end
		until streams[name].dataWithInterface ~= nil
		
		return streams[name].dataWithInterface
	end
	
	-- Create a stream object
	streams[name] = {
		rawData = {}, -- Raw data (no metatables), just for keeping up-to-date copy of data
		trackerCallbacks = {}, -- Tracker callbacks so that they can be called when changes are made
		trackers = {}, -- List of :Track() functions
		dataWithInterface = nil -- Proxy data (readonly)
	}
	
	-- The code below must execute only once, no more than once!
	local initEvent = Workspace.Terrain:WaitForChild("NetTbl.".. name.. ".Init", 25) :: RemoteFunction
	
	-- Initial data request
	streams[name].rawData = initEvent:InvokeServer()
	
	-- Listen for data change requests
	local changeEvent = Workspace.Terrain:WaitForChild("NetTbl.".. name.. ".Change", 25) :: RemoteEvent
	local changeListener = changeEvent.OnClientEvent:Connect(function(changes)
		local oldTable = Util.deepCopyTable(streams[name].rawData :: any)
		
		for _, change in changes do
			-- Go through the path
			local keyLocation = streams[name].rawData
			
			local path = change[1]
			local newValue = change[2]

			for i, key in path do
				-- Resolve the path step by step

				if keyLocation[key] == nil then -- Does the key exist?
					-- If the key that was sent to us doesn't exist, it probably
					-- means that it was added, therefore we need to add it as well!

					-- Create the missing location/key
					keyLocation[key] = {}
				end

				if i >= #path then -- Are were at our destination?
					local oldValue = keyLocation[key]

					-- Update the value at our destination
					keyLocation[key] = newValue

					-- Allow for tracking changes externally
					for _, callback in streams[name].trackerCallbacks :: any do
						local newTable = streams[name].rawData
						callback(changes, oldTable, newTable)
					end
					break
				else
					-- Move into that location
					keyLocation = keyLocation[key]
				end
			end
		end
	end)
	
	local proxyInterface = {
		Value = streams[name].rawData
	}
	
	function proxyInterface:Changed(path: string)
		return Shared.onChanged(streams[name] :: any, path)
	end
	
	function proxyInterface:ItemAddedIn(path: string)
		return Shared.onItemAdded(streams[name] :: any, path)
	end
	
	function proxyInterface:ItemRemovedIn(path: string)
		return Shared.onItemRemoved(streams[name] :: any, path)
	end
	
	-- Listen for stream removal
	local originalParent = changeEvent.Parent
	changeEvent:GetPropertyChangedSignal("Parent"):Connect(function()
		-- When parent changes, destroy the stream
		if changeEvent.Parent ~= originalParent then
			-- Disconnet the change listener
			changeListener:Disconnect()

			-- Disconnect all of the trackers
			for _, tracker in streams[name].trackers :: any do
				tracker:Disconnect()
			end

			proxyInterface.Value = nil :: any
			proxyInterface = nil :: any

			-- Get rid of the stream
			streams[name] = nil
		end
	end)
	
	streams[name].dataWithInterface = proxyInterface :: any
	return streams[name].dataWithInterface
end

return Client