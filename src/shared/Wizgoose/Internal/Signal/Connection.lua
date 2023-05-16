local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({
		_handler = handler,
		_signal = signal,
	}, Connection)
end

function Connection:Disconnect()
	self._signal.connections[self] = nil

	if self._signal.disconnected then
		self._signal.disconnected()
	end
end

return Connection
