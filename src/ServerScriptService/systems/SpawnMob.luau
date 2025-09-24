--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(game:GetService("ServerScriptService").net)

local std = ReplicatedStorage.std
local interval = require(std.interval)
local world = require(std.world)
local cts = require(std.components)
local scheduler = require(std.scheduler)
local phases = require(std.phases)

local Transform = cts.Transform
local Velocity = cts.Velocity
local Size = cts.Size
local Mob = cts.Mob
local StateMachine = cts.StateMachine
local Wander = cts.Wander
local Patrol = cts.Patrol
local Timer = cts.Timer

local throttle = interval(.1)
local counter = interval(1)
local count = 0

local function randomPosition()
    local angle = math.random() * math.pi * 2
    local radius = math.random(50, 150)
    local x = math.cos(angle) * radius
    local z = math.sin(angle) * radius
    return Vector3.new(x, 20, z)
end

--[[local function spawnSystem()
    if throttle() then

        local e = world:entity()
        local cf = CFrame.new(randomPosition())

        -- Base components
        world:set(e, Transform, { new = cf })
        world:set(e, Velocity, math.random(30, 70))
        world:set(e, Size, math.random(1, 5))
        world:add(e, Mob)

        -- Different mob types
        local mobType = math.random(1, 3)

        if mobType == 1 then
            -- Aggressive chaser
            world:set(e, StateMachine, { 
                current = "idle", 
                states = { idle = {}, chase = {}, attack = {} }
            })
            world:set(e, Wander, {
                center = cf.Position,
                radius = 10,
                nextMove = 0
            })
            world:set(e, Timer, { remaining = 2 })
            
        elseif mobType == 2 then
            -- Patrol guard
            world:set(e, Patrol, {
                points = {
                    cf.Position,
                    cf.Position + Vector3.new(20, 0, 0),
                    cf.Position + Vector3.new(20, 0, 20),
                    cf.Position + Vector3.new(0, 0, 20),
                },
                current = 1,
                wait = 3
            })
            world:set(e, Timer, { remaining = 0 })
            
        else
            -- Peaceful wanderer
            world:set(e, Wander, {
                center = cf.Position,
                radius = 30,
                nextMove = 0
            })
            world:set(e, Timer, { remaining = 1 })
        end
        
        blink.SpawnMob.FireAll(e, cf, world:get(e, Size))
    end
end]]

local function spawnMobs()
	if throttle() then
		local cf = CFrame.new(randomPosition())
		local v = math.random(30, 70) -- Vary speed for more interesting behavior
		local size = math.random(1,5)
		local e = world:entity()

		world:set(e, Size, size)
		world:set(e, Velocity, v)
		world:set(e, Transform, { new = cf })
		world:add(e, Mob)

		blink.SpawnMob.FireAll(e, cf, size)
        count += 1
	end
end

local function countMobs()
    if counter() then
        print("Current mob count:", count)
    end
end

--Spawn mobs on Heartbeat (independent of other systems)
scheduler.SYSTEM(spawnMobs, phases.Heartbeat)
scheduler.SYSTEM(countMobs, phases.Heartbeat)
return {}