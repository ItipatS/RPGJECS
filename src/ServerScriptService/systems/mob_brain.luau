-- ServerScriptService/systems/mob_brain.luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std       = ReplicatedStorage.std
local world     = require(std.world)
local cts       = require(std.components)
local scheduler = require(std.scheduler)
local phases    = require(std.phases)

local Mob         = cts.Mob
local Transform   = cts.Transform
local Velocity    = cts.Velocity
local Wander      = cts.Wander
local Traits      = cts.Traits
local AIState     = cts.AIState
local Locomotion  = cts.Locomotion
local Hitbox      = cts.Hitbox
local Character   = cts.Character
local Player      = cts.Player

-- players to react to
local characters = world
    :query(Character)
    :with(Player)
    :cached()

-- mobs with brains
local mobs = world
    :query(Transform, Velocity, Wander, Traits, AIState, Hitbox)
    :with(Mob)
    :cached()

local EPS = 1e-4

local function randRange(min: number, max: number): number
    return min + (max - min) * math.random()
end

local function getClosestPlayer(pos: Vector3, maxRange: number?): (Vector3?, number)
    local limit = maxRange or math.huge
    local bestPos: Vector3? = nil
    local bestDist = limit

    for _, char in characters do
        local model = char :: Model
        local root = model.PrimaryPart
        if root then
            local d = (root.Position - pos).Magnitude
            if d < bestDist and d <= limit then
                bestDist = d
                bestPos = root.Position
            end
        end
    end

    return bestPos, bestDist
end

local function pickNewState(
    hasPlayer: boolean,
    dist: number,
    traits: any
): (string, number, number)
    -- returns: state, duration, circleSign
    -- default state
    local state = "wander"
    local dur = 0
    local circleSign = (math.random(0, 1) == 0) and -1 or 1

    if not hasPlayer then
        -- no player: mostly wander, sometimes idle-ish wander
        state = "wander"
        dur   = math.random(2, 5)
        return state, dur, circleSign
    end

    -- player exists → pick based on distance + weights
    local fleeWeight  = traits.fleeWeight or 0
    local chaseWeight = traits.chaseWeight or 0
    local circleWeight = traits.circleWeight or 0

    local fleeDist = traits.fleeDistance or 12
    local preferDist = traits.preferDistance or 20

    -- if very close + likes fleeing → flee
    if dist < fleeDist and fleeWeight > 0 then
        state = "flee"
        dur   = math.random(1, 3)
        return state, dur, circleSign
    end

    -- mid-range: circle or chase or wander
    if dist > 4 then
        local total = 1 + chaseWeight + fleeWeight + circleWeight
        local r = math.random() * total
        local acc = 1

        if r < acc then
            state = "wander"
        else
            acc += chaseWeight
            if r < acc then
                state = "chase"
            else
                acc += circleWeight
                if r < acc then
                    state = "circle"
                else
                    state = "flee"
                end
            end
        end
    else
        -- extremely close but not strongly fleeing → either flee or wander
        if fleeWeight > 0.5 and math.random() < fleeWeight then
            state = "flee"
        else
            state = "wander"
        end
    end

    -- durations per state
    if state == "chase" then
        dur = randRange(0.5, 1.2)
    elseif state == "circle" then
        dur = math.random(5, 10)
    elseif state == "flee" then
        dur = math.random(1, 3)
    else -- wander
        dur = math.random(2, 6)
    end

    return state, dur, circleSign
end

local function updateWanderDir(
    wander: { center: Vector3, radius: number, nextMove: number },
    pos: Vector3,
    speed: number,
    dt: number,
    locoPrev: { dir: Vector3, speed: number }?
): (Vector3, number)
    wander.nextMove -= dt
    local dir = Vector3.zero
    local finalSpeed = speed * 0.5

    if wander.nextMove <= 0 then
        local angle = math.random() * math.pi * 2
        local target = wander.center + Vector3.new(
            math.cos(angle) * wander.radius,
            0,
            math.sin(angle) * wander.radius
        )
        local toTarget = target - pos
        toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
        if toTarget.Magnitude > 1e-4 then
            dir = toTarget.Unit
        end
        wander.nextMove = math.random(2, 5)
    elseif locoPrev then
        dir = locoPrev.dir
        finalSpeed = locoPrev.speed
    end

    return dir, finalSpeed
end


local function mobBrainStep(dt: number)
    for e, transform, baseSpeed, wander, traits, ai, hitbox in mobs do
        local pos = transform.new.Position
        ai.t += dt

        local detectRange    = traits.detectRange or 40
        local loseSightRange = traits.loseSightRange or (detectRange + 15)

        local playerPos, dist = getClosestPlayer(pos, detectRange)
        local hasPlayer = (playerPos ~= nil)

        if hasPlayer and dist > loseSightRange then
            hasPlayer = false
            playerPos = nil
        end

        if hasPlayer then
            hitbox:SetAttribute("HasTarget", true)
            hitbox:SetAttribute("TargetPos", playerPos)
        else
            hitbox:SetAttribute("HasTarget", false)
            hitbox:SetAttribute("TargetPos", nil)
        end

        -- state expiry → pick a new one
        if ai.t >= ai.dur then
            local state, dur, circleSign = pickNewState(hasPlayer, dist, traits)
            ai.state = state
            ai.t     = 0
            ai.dur   = dur
            ai.circleSign = circleSign
        end

        local locoPrev = world:get(e, Locomotion)
        local dir = Vector3.zero
        local speed = (baseSpeed or 30) * (traits.baseSpeedMul or 1)

         if ai.state == "chase" and playerPos then
            local toPlayer = playerPos - pos
            toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
            if toPlayer.Magnitude > EPS then
                dir = toPlayer.Unit
            end
            
        elseif ai.state == "flee" and playerPos then
            local away = pos - playerPos
            away = Vector3.new(away.X, 0, away.Z)
            if away.Magnitude > EPS then
                dir = away.Unit
            end

        elseif ai.state == "circle" and playerPos then
            local toPlayer = playerPos - pos
            toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
            local dist2 = toPlayer.Magnitude
            if dist2 > EPS then
                toPlayer = toPlayer.Unit
                -- tangent: perpendicular on XZ plane
                local up = Vector3.new(0, 1, 0)
                local tangent = up:Cross(toPlayer) * (ai.circleSign or 1)
                tangent = Vector3.new(tangent.X, 0, tangent.Z)
                if tangent.Magnitude > EPS then
                    dir = tangent.Unit
                end

                -- small radial correction to stay near preferDistance
                local prefer = traits.preferDistance or 20
                local delta = dist2 - prefer
                if math.abs(delta) > 2 then
                    -- pull in or push out slightly
                    local radial = (delta > 0) and toPlayer or -toPlayer
                    dir = (dir + radial * 0.3).Unit
                end
            end

        else
            -- wander as fallback / default
            local d, s = updateWanderDir(wander, pos, speed, dt ,locoPrev)
            dir = d
            speed = s
        end

        if dir.Magnitude <= EPS then
            speed = 0
            dir = Vector3.zero
        end

        if hitbox then
            hitbox:SetAttribute("MobState", ai.state)
        end

        world:set(e, Locomotion, {
            dir   = dir,
            speed = speed,
        })
        world:set(e, AIState, ai)
    end
end

-- throttle + phase
local BRAIN_HZ = 8
local BRAIN_TICK = 1 / BRAIN_HZ
local acc = 0

local function brainWrapper(dt: number)
    acc += dt
    if acc < BRAIN_TICK then return end

    local step_dt = acc
    acc = 0
    mobBrainStep(step_dt)
end

scheduler.SYSTEM(brainWrapper, phases.AIBehavior)

return 0
