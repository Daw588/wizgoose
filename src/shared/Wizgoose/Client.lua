--!strict

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Internal.Util)
local Shared = require(script.Parent.Internal.Shared)

local Wizgoose = {}
Wizgoose.__index = Wizgoose
Wizgoose.Instances = {}

local CommunicationFolder = Config.COMMUNICATION_FOLDER.WHERE:WaitForChild(Config.COMMUNICATION_FOLDER.NAME)

function Wizgoose.new(id: string)
	local self = setmetatable({}, Wizgoose)

	-- The code below must execute only once, no more than once!
	local initEvent = CommunicationFolder:WaitForChild(id .. ".init", 25) :: RemoteFunction

	-- Initial data request
	self.Value = initEvent:InvokeServer()
	self.ChangeCallbacks = {}
	self.Id = id

	-- Listen for data change requests
	local changeEvent = CommunicationFolder:WaitForChild(id .. ".change", 25) :: RemoteEvent
	self.ChangeReceiver = changeEvent.OnClientEvent:Connect(function(changes)
		local oldTable = Util.deepCopyTable(self.Value)

		for _, change in changes do
			-- Go through the path
			local keyLocation = self.Value

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
					--local oldValue = keyLocation[key]

					-- Update the value at our destination
					keyLocation[key] = newValue

					-- Allow for tracking changes externally
					for _, callback in pairs(self.ChangeCallbacks) do
						local newTable = self.Value
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

	-- Listen for stream removal
	local originalParent = changeEvent.Parent
	changeEvent:GetPropertyChangedSignal("Parent"):Connect(function()
		-- When parent changes, destroy the stream
		if changeEvent.Parent ~= originalParent then
			self:Destroy()
		end
	end)

	Wizgoose.Instances[self.Id] = self

	return self
end

function Wizgoose.get(id: string)
	-- Dont make multiple remote events when there is 2 that already exist for this table
	if Wizgoose.Instances[id] then
		local calls = 0

		while not Wizgoose.Instances[id] do
			-- Prevent infinite yield
			calls += 1
			if calls > 100_000 then
				error("Tried to retrieve a box but reached the wait limit, did you forget to create the box?")
			end
			task.wait()
		end

		return Wizgoose.Instances[id]
	end

	return Wizgoose.new(id)
end

function Wizgoose:Changed(path: string)
	return Shared.onChanged(Wizgoose.Instances[self.Id], path)
end

function Wizgoose:ItemAddedIn(path: string)
	return Shared.onItemAdded(Wizgoose.Instances[self.Id], path)
end

function Wizgoose:ItemRemovedIn(path: string)
	return Shared.onItemRemoved(Wizgoose.Instances[self.Id], path)
end

function Wizgoose:Destroy()
	self.ChangeReceiver:Disconnect()
end

return Wizgoose
