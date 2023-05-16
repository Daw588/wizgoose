local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wizgoose = require(ReplicatedStorage.Shared.Wizgoose.Client)

local PlayerData = Wizgoose.get("Player1")

print(PlayerData.Value)

PlayerData:Changed("money"):Connect(function(new, old)
	print("Changed", new, old)
end)
