local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
local world = require(std.world)
local cts = require(std.components)

local SystemData = world:entity()
world:set(SystemData, cts.PendingMovements, {})
world:set(SystemData, cts.PendingStateChanges, {})

return 0