local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wizgoose = require(ReplicatedStorage.Shared.Wizgoose.Server)

Wizgoose.new("Player1", {
	money = 0,
})

--tbl.Value.money += 50

--changed:Disconnect()
--added:Disconnect()
--removed:Disconnect()
