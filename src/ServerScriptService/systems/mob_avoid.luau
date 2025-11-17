--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std       = ReplicatedStorage.std
local world     = require(std.world)
local cts       = require(std.components)
local scheduler = require(std.scheduler)
local phases    = require(std.phases)

local Mob        = cts.Mob
local Transform  = cts.Transform
local Locomotion = cts.Locomotion
local Size       = cts.Size

-- mobs we want to steer (need locomotion)
local moving = world
    :query(Transform, Locomotion, Size)
    :with(Mob)
    :cached()

-- neighbors pool (all mobs with positions + size)
local neighbors = world
    :query(Transform, Size)
    :with(Mob)
    :cached()

local EPS = 1e-4

-- Tunables:
-- Size is HitboxSize.Magnitude, so it's "overall scale".
--  radiusFactor converts that into a collision radius in studs.
local RADIUS_FACTOR       = 0.25  -- tweak: bigger -> they avoid from farther away
local SEPARATION_STRENGTH = 8     -- how aggressively to push

local SEP_HZ   = 10
local SEP_TICK = 1 / SEP_HZ
local sepAcc   = 0

local function separationStep(dt: number)
    for e, transform, loco, sizeSelf in moving do
        local pos = transform.new.Position
        local baseDir = loco.dir

        local selfRadius = (sizeSelf or 0) * RADIUS_FACTOR
        local separation = Vector3.zero

        for other, otherTransform, sizeOther in neighbors do
            if other == e then
                continue
            end

            local otherPos = otherTransform.new.Position
            local offset = pos - otherPos
            local dist = offset.Magnitude
            if dist < EPS then
                continue
            end

            local otherRadius = (sizeOther or 0) * RADIUS_FACTOR
            local targetDist = selfRadius + otherRadius

            if dist < targetDist and targetDist > EPS then
                -- how deep we are inside each other's "bubble"
                local penetration = targetDist - dist
                local pushStrength = penetration / targetDist -- [0..1]

                separation += offset.Unit * pushStrength
            end
        end

        if separation.Magnitude > EPS then
            local sepDir = separation.Unit

            -- blend separation into current direction
            local combined = baseDir + sepDir * (SEPARATION_STRENGTH * dt)
            if combined.Magnitude > EPS then
                combined = combined.Unit
            end

            loco.dir = combined
            world:set(e, Locomotion, loco)
        end
    end
end

local function sepWrapper(dt: number)
    sepAcc += dt
    if sepAcc < SEP_TICK then return end

    local step_dt = sepAcc
    sepAcc = 0
    separationStep(step_dt)
end

-- Runs after AIBehavior (brain), before AIMovement (movement)
scheduler.SYSTEM(sepWrapper, phases.AIStateMachine)

return 0
