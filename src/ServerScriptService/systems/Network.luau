--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(game:GetService("ServerScriptService").net)
local std = ReplicatedStorage.std

local world = require(std.world)
local cts = require(std.components)
local scheduler = require(std.scheduler)
local phases = require(std.phases)
local PendingMovements = cts.PendingMovements

-- Network constants
local TICK_HZ = 30
local TICK = 1 / TICK_HZ
local FULL_SYNC_INTERVAL = 5
local MAX_BATCH_SIZE = 64

local lastFullSync = 0
local last_accum = 0
local ToSendFull = table.create(128)
local ToSendDelta = table.create(MAX_BATCH_SIZE)

local moving_mobs = world:query(cts.Transform, cts.Velocity, cts.Size):with(cts.Mob):cached()

local function networkSystem(dt: number)
    lastFullSync += dt
    last_accum += dt

    if last_accum < TICK then return end

    local step_dt = last_accum
    last_accum = 0

    table.clear(ToSendDelta)

    -- Delta sync logic
    for _, movement in world:query(PendingMovements) do
        for _, m in ipairs(movement) do
            ToSendDelta[#ToSendDelta + 1] = m
           -- print("ToSendDelta:", ToSendDelta)
            if #ToSendDelta >= MAX_BATCH_SIZE then
            blink.UpdateTransformDelta.FireAll(ToSendDelta)
            table.clear(ToSendDelta)
            end
        end
    end

    -- Full sync logic
    if lastFullSync >= FULL_SYNC_INTERVAL then
        lastFullSync = 0
        table.clear(ToSendFull)
        
        for mob, transform in moving_mobs do
            ToSendFull[#ToSendFull + 1] = { 
                id = mob,
                dp = transform.new.Position
            }
        end

        if #ToSendFull >= 128 then
			blink.UpdateTransformFull.FireAll(ToSendFull)
			table.clear(ToSendFull)
		end
        -- Send full state to correct any drift
		if #ToSendFull > 0 then
        	blink.UpdateTransformFull.FireAll(ToSendFull)
			table.clear(ToSendFull)
		end
    else
        if #ToSendDelta > 0 then
            blink.UpdateTransformDelta.FireAll(ToSendDelta)
        end
    end
end

scheduler.SYSTEM(networkSystem, phases.NetworkDelta)

return {}