local Proxify = require(script.Parent.Internal.Proxify)
local MapChanges = require(script.Parent.Internal.MapChanges)
local Shared = require(script.Parent.Internal.Shared)
local Types = require(script.Parent.Internal.Types)
local Config = require(script.Parent.Config)
local Signal = require(script.Parent.Internal.Signal)

local CommunicationFolder = Instance.new("Folder")
CommunicationFolder.Name = Config.COMMUNICATION_FOLDER.NAME
CommunicationFolder.Parent = Config.COMMUNICATION_FOLDER.WHERE

local Box = {}
Box.Boxes = {}

function Box.new(id: string, value: Types.UserTable, clients: { Player }?)
	local onProxyOperationDetected
	
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)
	local data = {}
	
	meta.__index = function(_, key)
		--print("__index", key, data[key])
		return data[key]
	end
	
	meta.__newindex = function(_, key, value)
		--print("__newindex", key, value)
		
		-- If user attempts to overwrite the key "Value"
		-- with a regular table (not "userdata"), then
		-- wrap the new value with proxify and set it to
		-- the proxy table instead of the raw value to
		-- allow for change tracking, etc. Then alert
		-- proxy action listener about the write operation.
		if key == "Value" and typeof(value) == "table" then
			print("Swapped", value)

			-- Remember, the .Value is a proxy table, extract the raw contents first
			local oldTable = data.raw(data.Value)

			-- Use the proxified value
			data.Value = Proxify(value, onProxyOperationDetected)

			-- Alert the listener about the proxy write operation
			onProxyOperationDetected("WRITE", value, oldTable)
		else
			-- Use the raw value
			data[key] = value
		end
	end
	
	--print("init", proxy, typeof(proxy), "INIT!")
	
	data.Id = id
	data.Raw = value
	data.ChangeCallbacks = {}
	data.ValueChanged = Signal.new()
	
	function data.raw(tbl)
		return getmetatable(tbl).__index(tbl, nil, "raw")
	end
	
	function data:Changed(path: string)
		--print("Changed", self.Id, path)
		return Shared.onChanged(self, path)
	end

	function data:ItemAddedIn(path: string)
		--print("ItemAddedIn", self.Id, path)
		return Shared.onItemAdded(self, path)
	end

	function data:ItemRemovedIn(path: string)
		--print("ItemRemovedIn", self.Id, path)
		return Shared.onItemRemoved(self, path)
	end

	function data:Destroy()
		--print("Destroyed", self.Id)
		Box.Boxes[id] = nil
		self.ValueChanged:DisconnectAll()
		self.Value = nil
		self.ChangeCallbacks = {}
	end
	
	-- Remote event to replicate changes to the client
	local changeEvent = Instance.new("RemoteEvent")
	changeEvent.Name = id .. ".change"
	changeEvent.Parent = CommunicationFolder

	onProxyOperationDetected = function(operation, newTable, oldTable)
		-- Only WRITE operations will be taken into account
		if operation ~= "WRITE" then
			return
		end
		
		data.ValueChanged:Fire()
		print("Operation Detected")

		--print("Operation Detected", id, newTable, oldTable)

		-- Update the current table
		data.Raw = newTable

		local changes = MapChanges(oldTable, newTable)

		-- Notify all observers that change was made
		for _, callback in data.ChangeCallbacks do
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
					[3] = change.oldValue,
				})
			end

			-- Are clients passed?
			if clients then
				-- Yes, send out to the specified clients
				for _, client in clients do
					changeEvent:FireClient(client, compressedChanges)
				end
			else
				-- No, send out to all clients
				changeEvent:FireAllClients(compressedChanges)
			end
		end)
	end

	local function initialReplication(sender: Player): { [any]: any }
		if clients then
			for _, client in clients do
				if client == sender then
					return data.Raw
				end
			end
		end
		return data.Raw
	end

	-- Remote function to replicate initially to the client
	local initEvent = Instance.new("RemoteFunction")
	initEvent.Name = id .. ".init"
	initEvent.OnServerInvoke = initialReplication :: any
	initEvent.Parent = CommunicationFolder

	data.Value = Proxify(value, onProxyOperationDetected)
	
	Box.Boxes[id] = proxy
	
	--print("Created Box", proxy, typeof(proxy), type(proxy), id)
	
	return proxy
end

return Box
