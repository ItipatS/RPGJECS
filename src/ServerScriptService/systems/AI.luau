--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.std.world)
local cts = require(ReplicatedStorage.std.components)

local Transform = cts.Transform
local Velocity = cts.Velocity
local Size = cts.Size
local Player = cts.Player
local Character = cts.Character
local Mob = cts.Mob
local Knockback = cts.Knockback

-- ===== Behavior Constants =====
local STOP_RADIUS = 5
local RESUME_RADIUS = 12
local EPS = 1e-4

local halted: {[number]: boolean} = {}
local targets: {Vector3} = table.create(16)

local characters = world:query(Character):with(Player):cached()
local moving_mobs = world:query(Transform, Velocity, Size):with(Mob):cached()

local function getClosestTarget(position: Vector3): (Vector3?, number)
    if #targets == 0 then return nil, math.huge end
    
    local closestPos: Vector3? = nil
    local closestDistSq = math.huge
    
    for i = 1, #targets do
        local target = targets[i]
        local distSq = (target - position).Magnitude ^ 2
        if distSq < closestDistSq then
            closestDistSq = distSq
            closestPos = target
        end
    end
    
    return closestPos, math.sqrt(closestDistSq)
end

local function behaviorSystem(dt: number): {Vector3}
    -- Collect player target positions
    table.clear(targets)
    for _, character in characters do
        local pp = character.PrimaryPart :: Part
        if pp then
            targets[#targets + 1] = pp.Position
        end
    end

    if #targets == 0 then
        return {}
    end

    local movements = {}

    for mob, transform, speed, size in moving_mobs do
        -- Skip if being knocked back
        if world:has(mob, Knockback) then
            continue
        end
        
        local cf = transform.new
        local position = cf.Position
        local stopRadius = math.max(STOP_RADIUS, size * 2)

        local closestPos, closestDist = getClosestTarget(position)
        if not closestPos then continue end

        local isHalted = halted[mob] or false

        -- Hysteresis logic
        if isHalted then
            if closestDist > RESUME_RADIUS then
                halted[mob] = false
                isHalted = false
            end
        else
            if closestDist < stopRadius then
                halted[mob] = true
                isHalted = true
            end
        end

        if isHalted then continue end

        -- Calculate movement
        local direction = (closestPos - position)
        local distance = direction.Magnitude

        if distance < EPS then continue end
        
        direction = direction / distance

        local stepMax = math.max(0, distance - stopRadius)
        local step = math.min(speed * dt, stepMax)

        if step <= EPS then continue end

        local delta = direction * step
        local newPos = position + delta

        -- Update transform
        transform.new = CFrame.new(newPos, cf.LookVector)
        
        -- Store movement for networking
        movements[#movements + 1] = { id = mob, dp = delta }
    end

    return movements
end

return {
    behaviorSystem = behaviorSystem
}