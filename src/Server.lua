--!strict

local Workspace = game:GetService("Workspace")

local Util = require(script.Parent.Internal.Util)
local Shared = require(script.Parent.Internal.Shared)

local Proxify = require(script.Parent.Internal.Proxify)
local MapChanges = require(script.Parent.Internal.MapChanges)

local streams = {}

local Server = {}

function Server.add(name: string, tbl: {any}, clients: {Player}?): any
	if streams[name] then
		error("Cannot create more than one stream under the same name!")
	end
	
	streams[name] = {
		-- This table is always gonna be up to date; (no metatables),
		-- just for keeping up-to-date copy of data that can be sent over to client
		rawData = tbl,

		-- List of tracker callbacks (used to track values)
		trackerCallbacks = {},

		-- List of :Track() functions
		trackers = {},

		-- Proxy data (write & read)
		dataWithInterface = {}
	}
	
	-- Remote event to replicate changes to the client
	local changeEvent = Instance.new("RemoteEvent")
	changeEvent.Name = "NetTbl.".. name.. ".Change"
	changeEvent.Parent = Workspace.Terrain
	
	local onAction = function(action, newTable, oldTable)
		-- If stream doesn't exist, ignore all of the changes
		if not streams[name] then
			return
		end
		
		if action ~= "WRITE" then -- Only WRITE actions will be taken into account
			return
		end

		-- Update the current table
		streams[name].rawData = newTable

		local changes = MapChanges(oldTable, newTable)

		-- Allow for tracking changes externally
		-- Call all of the trackers for this stream name
		for _, callback in streams[name].trackerCallbacks :: any do
			callback(changes, oldTable, newTable)
		end

		-- Replicate changes
		task.spawn(function()
			-- Compress the volume of data we send
			local compressedChanges = table.create(#changes)
			for _, change in changes do
				table.insert(compressedChanges, {
					[1] = change.path,
					[2] = change.newValue,
					[3] = change.oldValue
				})
			end

			if clients then
				for _, client in clients do
					changeEvent:FireClient(client, compressedChanges)
				end
			else
				changeEvent:FireAllClients(compressedChanges)
			end
		end)
	end
	
	local proxyTable = Proxify(tbl, onAction)
	
	-- Remote function to replicate initially to the client
	local initEvent = Instance.new("RemoteFunction")
	initEvent.Name = "NetTbl.".. name.. ".Init"
	initEvent.OnServerInvoke = function(sender)
		if clients then
			for _, client in clients do
				if client == sender then
					return streams[name].rawData
				end
			end
		else
			return streams[name].rawData
		end
	end
	initEvent.Parent = Workspace.Terrain
	
	local proxyInterface = {
		Value = proxyTable
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
	
	function proxyInterface:Destroy()
		-- Get rid of the references
		proxyInterface.Value = nil
		proxyInterface = nil :: any
		proxyTable = nil
		onAction = nil :: any
		
		-- Disconnect all of the trackers
		for _, tracker in streams[name].trackers :: any do
			tracker:Disconnect()
		end
		
		-- Get rid of the stream
		streams[name] = nil
		
		-- Stop replicating and let the client know to get rid
		-- of its own version of stream
		changeEvent:Destroy()
		initEvent:Destroy()
	end
	
	streams[name].dataWithInterface = proxyInterface
	return streams[name].dataWithInterface :: any
end

function Server.get(name: string): any -- Yields
	local calls = 0
	
	-- Wait for stream to be created
	while not streams[name] do
		calls += 1
		if calls > 100_000 then
			error("Tried to retrieve a stream but reached the wait limit, did you forget to create the stream?")
		end

		task.wait()
	end
	
	-- Return the data
	return streams[name].dataWithInterface
end

function Server.raw(tbl: any)
	return getmetatable(tbl).__index(tbl, nil, "raw")
end

return Server