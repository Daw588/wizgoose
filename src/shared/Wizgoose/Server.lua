--!strict

local Proxify = require(script.Parent.Internal.Proxify)
local MapChanges = require(script.Parent.Internal.MapChanges)
local Shared = require(script.Parent.Internal.Shared)
local Types = require(script.Parent.Internal.Types)
local Config = require(script.Parent.Config)

local Wizgoose = {}
Wizgoose.Instances = {}

local CommunicationFolder = Instance.new("Folder")
CommunicationFolder.Name = Config.COMMUNICATION_FOLDER.NAME
CommunicationFolder.Parent = Config.COMMUNICATION_FOLDER.WHERE

local RawInterface = {}

function RawInterface.raw(tbl: any)
	return getmetatable(tbl).__index(tbl, nil, "raw")
end

function Wizgoose.__index(_, key)
	return RawInterface[key]
end

function Wizgoose.__newindex(self, key, value)
	-- If user attempts to overwrite the key "Value"
	-- with a regular table (not "userdata"), then
	-- wrap the new value with proxify and set it to
	-- the proxy table instead of the raw value to
	-- allow for change tracking, etc. Then alert
	-- proxy action listener about the write operation.
	if key == "Value" and typeof(value) == "table" then
		-- Remember, the .Value is a proxy table, extract the raw contents first
		local oldTable = RawInterface.raw(RawInterface["Value"])

		-- Use the proxified value
		RawInterface[key] = Proxify(value, self.OnProxyOperationDetected)

		-- Alert the listener about the proxy write operation
		self.OnProxyOperationDetected("WRITE", value, oldTable)
	else
		-- Use the raw value
		RawInterface[key] = value
	end
end

function RawInterface.new(id: string, value: Types.UserTable, clients: { Player }?)
	local self = setmetatable({}, Wizgoose)

	-- Remote event to replicate changes to the client
	local changeEvent = Instance.new("RemoteEvent")
	changeEvent.Name = id .. ".change"
	changeEvent.Parent = CommunicationFolder

	self.OnProxyOperationDetected = function(operation, newTable, oldTable)
		-- Only WRITE operations will be taken into account
		if operation ~= "WRITE" then
			return
		end

		-- Update the current table
		self.Raw = newTable

		local changes = MapChanges(oldTable, newTable)

		-- Notify all observers that change was made
		for _, callback in self.ChangeCallbacks do
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
					return self.Raw
				end
			end
		end
		return self.Raw
	end

	-- Remote function to replicate initially to the client
	local initEvent = Instance.new("RemoteFunction")
	initEvent.Name = id .. ".init"
	initEvent.OnServerInvoke = initialReplication :: any
	initEvent.Parent = CommunicationFolder

	self.Raw = value
	self.Value = Proxify(value, self.OnProxyOperationDetected)
	self.ChangeCallbacks = {}
	self.Id = id

	Wizgoose.Instances[self.Id] = self

	return self
end

export type Instance = typeof(RawInterface.new("", {}, {}))

function RawInterface.get(id: string)
	local calls = 0

	-- Wait for box to be created
	while not Wizgoose.Instances[id] do
		calls += 1
		if calls > 100_000 then
			error("Tried to retrieve a box but reached the wait limit, did you forget to create the box?")
		end
		task.wait()
	end

	return Wizgoose.Instances[id]
end

function RawInterface:Changed(path: string)
	return Shared.onChanged(Wizgoose.Instances[self.Id], path)
end

function RawInterface:ItemAddedIn(path: string)
	return Shared.onItemAdded(Wizgoose.Instances[self.Id], path)
end

function RawInterface:ItemRemovedIn(path: string)
	return Shared.onItemRemoved(Wizgoose.Instances[self.Id], path)
end

function RawInterface:Destroy()
	Wizgoose.Instances[self.Id] = nil

	self.Value = nil
	self.ChangedCallbacks = {}
end

return RawInterface
