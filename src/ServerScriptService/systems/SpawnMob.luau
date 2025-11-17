--ServerScriptService/systems/SpawnMob.luau
--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local Hitbox = cts.Hitbox

local Countvalue = ReplicatedStorage.Count

local throttle = interval(1)
local counter = interval(1)
local count = 0

local entries = {
    { value = 0.2, weight = 0.0125 },
    { value = 0.5, weight = 0.025 },
    { value = 0.7, weight = 0.5 },

    { value = 1, weight = 1 },
    { value = 2, weight = 0.5 },
    { value = 3, weight = 0.25 },
    { value = 4, weight = 0.125 },
    { value = 5, weight = 0.0625 },
}

local function randRange(min: number, max: number): number
    return min + (max - min) * math.random()
end

local function randomPosition()
    local angle = math.random() * math.pi * 2
    local radius = math.random(10, 256)
    local x = math.cos(angle) * radius
    local z = math.sin(angle) * radius
    return Vector3.new(x, math.random(5, 10), z)
end

local ReplicatedAnimals = ReplicatedStorage.Animals:getChildren()
local Animals = {}
local AnimalsList = {}

for _ , child in pairs(ReplicatedAnimals) do
	if child:IsA("BasePart") then
		if Animals[child.Name] == nil then
			Animals[child.Name] = child
		end
	end
end

for _ , child in pairs(ReplicatedAnimals) do
    if child:IsA("BasePart") then
        table.insert(AnimalsList, child.Name)
    end
end

local function RandomAnimals()
    return AnimalsList[math.random(1, #AnimalsList)]
end

local function weightedChoice()

    local total = 0
    for _, entry in ipairs(entries) do
        total += entry.weight
    end

    local r = math.random() * total
    local cumulative = 0

    for _, entry in ipairs(entries) do
        cumulative += entry.weight
        if r <= cumulative then
            return entry.value
        end
    end


    return entries[#entries].value
end

local function spawnMobs()
	if throttle() then
		local cf = CFrame.new(randomPosition())
		local v = math.random(30, 70) -- Vary speed for more interesting behavior
		local size = weightedChoice()
        local types = RandomAnimals()

        local hitbox = Instance.new("Part")
        local HitboxSize = Animals[types].Size * size
		hitbox.Size = HitboxSize

		hitbox.CFrame = cf
		hitbox.Anchored = true
		hitbox.CanCollide = true
        hitbox.CollisionGroup = "NPC"
		hitbox.CanQuery = true
		hitbox.CanTouch = true
		hitbox.Transparency = 1
		hitbox.Parent = workspace.NPC_Hitboxes
        
        local e = world:entity()

        -- Base components
		world:set(e, Size, HitboxSize.Magnitude)
		world:set(e, Velocity, v)
		world:set(e, Transform, { new = cf, old = cf })
        world:set(e, Hitbox, hitbox)

		world:add(e, Mob)
        hitbox:SetAttribute("MobType", types)
        hitbox:SetAttribute("MobSize", size)

        world:set(e, cts.Wander, {
            center   = cf.Position,
            radius   = 25,
            nextMove = 0,
        })

        world:set(e, cts.Locomotion, {
            dir   = Vector3.zero,
            speed = 0,
        })

        local chaseWeight = randRange(0, 1)
        local fleeWeight  = randRange(0, 1)
        local circleWeight = randRange(0, 1)
        local jumpWeight  = randRange(0, 1)
        local detectRange = randRange(20, 40)
        local loseSight   = detectRange + randRange(15, 20)

        hitbox:SetAttribute("DetectRange", detectRange)
        hitbox:SetAttribute("LoseSightRange", loseSight)

        world:set(e, cts.Traits, {
            baseSpeedMul  = randRange(0.3, .5),
            chaseWeight   = chaseWeight,
            fleeWeight    = fleeWeight,
            circleWeight  = circleWeight,
            jumpWeight    = jumpWeight,
            fleeDistance  = randRange(5, 10),
            preferDistance = randRange(1, 5),

            detectRange    = detectRange,
            loseSightRange = loseSight,
        })

        world:set(e, cts.AIState, {
            state = "wander",
            t     = 0,
            dur   = randRange(2, 5),
            circleSign = (math.random(0, 1) == 0) and -1 or 1,
        })

        count += 1
        Countvalue.Value = count
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