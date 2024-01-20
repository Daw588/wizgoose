
--!strict

local Types = require(script.Parent.Internal.Types)
local Box = require(script.Parent.Box)

local Wizgoose = {}

function Wizgoose.new(id: string, value: Types.UserTable, clients: {Player}?)
	return Box.new(id, value, clients)
end

function Wizgoose.get(id: string)
	local calls = 0
	
	-- Wait for box to be created
	while not Box.Boxes[id] do
		calls += 1
		if calls > 100_000 then
			error("Tried to retrieve a box but reached the wait limit, did you forget to create the box?")
		end
		task.wait()
	end
	
	print("Retrieved", id, typeof(Box.Boxes[id]), Box.Boxes[id])
	
	return Box.Boxes[id]
end

function Wizgoose.raw(tbl)
	return getmetatable(tbl).__index(tbl, nil, "raw")
end

return Wizgoose
