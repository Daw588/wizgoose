local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wizgoose = require(ReplicatedStorage.Shared.Wizgoose.Server)
local SpecUtil = require(script.Parent.SpecUtil)

local ITERATIONS = 100_000

local libraryTable = Wizgoose.new("Spec", {
	money = 0,
})

local nativeTable = {
	money = 0,
}

local function native()
	local sum = 0

	for _ = ITERATIONS, 1, -1 do
		local begin = os.clock()
		nativeTable.money += 25
		sum += os.clock() - begin
	end

	return SpecUtil.formatTime(sum / ITERATIONS)
end

local function library()
	local sum = 0

	for _ = ITERATIONS, 1, -1 do
		local begin = os.clock()
		libraryTable.Value.money += 25
		sum += os.clock() - begin
	end

	return SpecUtil.formatTime(sum / ITERATIONS)
end

print(`Tracking Performance\nNative: {native()}\nLibrary: {library()}`)