--!strict

local Connection = require(script.Connection)

export type Connection = {
	Disconnect: () -> (),
}

export type Class = {
	new: () -> Class,
	__index: { [any]: any },
	Connect: () -> Connection,
	Once: () -> Connection,
	Wait: () -> any,
	Fire: (...any) -> (),
	DisconnectAll: () -> (),
	Disconnected: (() -> ()) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		connections = {},
		disconnected = nil :: (() -> ()) | nil,
	}, Signal)
end

function Signal:Connect(callback)
	local connection = Connection.new(self, callback)
	self.connections[connection] = true
	return connection
end

function Signal:Disconnected(callback: () -> ())
	self.disconnected = callback
end

function Signal:DisconnectAll()
	table.clear(self.connections)
end

function Signal:Fire(...)
	if next(self.connections) then
		for handler, _ in pairs(self.connections) do
			handler._handler(...)
		end
	end
end

function Signal:Wait()
	local waitingCoroutine = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

return Signal
