-- ServerScriptService/systems/mob_move.luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace    = game:GetService("Workspace")

local std       = ReplicatedStorage.std
local world     = require(std.world)
local cts       = require(std.components)
local scheduler = require(std.scheduler)
local phases    = require(std.phases)

local Mob        = cts.Mob
local Transform  = cts.Transform
local Locomotion = cts.Locomotion
local Hitbox     = cts.Hitbox

local moving_mobs = world
    :query(Transform, Locomotion, Hitbox)
    :with(Mob)
    :cached()

local MIN_REPL_DELTA = 0.05 

local EPS = 1e-4
local GROUND_CHECK_DIST = 30

local GROUND_ROOT = workspace:WaitForChild("Map")

local function makeRayParams(ignore: {Instance}): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { GROUND_ROOT, workspace.Terrain }
    return params
end

local function mobMoveStep(dt: number)
    for _e, transform, loco, hitbox in moving_mobs do
        local cf = transform.new
        local pos = cf.Position

        local dir = loco.dir
        local speed = loco.speed or 0

        -- horizontal only
        dir = Vector3.new(dir.X, 0, dir.Z)
        if dir.Magnitude > EPS and speed > 0 then
            dir = dir.Unit
        else
            dir = Vector3.zero
            speed = 0
        end

        local move = dir * speed * dt
        local desiredPos = pos + move

        local params = makeRayParams({ hitbox })

        -- 1) forward wall check (optional, but good to keep)
        if move.Magnitude > EPS then
            local forwardResult = Workspace:Raycast(
                pos + Vector3.new(0, hitbox.Size.Y * 0.5, 0),
                move,
                params
            )

            if forwardResult then
                local hitDist = (forwardResult.Position - pos).Magnitude
                if hitDist > 1 then
                    desiredPos = pos + dir * (hitDist - 1)
                else
                    desiredPos = pos -- blocked immediately
                end
            end
        end

        -- 2) Edge / ground check UNDER desiredPos
        local groundResult = Workspace:Raycast(
            desiredPos + Vector3.new(0, GROUND_CHECK_DIST * 0.5, 0),
            Vector3.new(0, -GROUND_CHECK_DIST, 0),
            params
        )

        local halfHeight = hitbox.Size.Y * 0.5
        local stepUpLimit = pos.Y + math.min(halfHeight, 3)

         if groundResult then
            local hitY = groundResult.Position.Y

            if hitY <= stepUpLimit then
                desiredPos = Vector3.new(
                    desiredPos.X,
                    hitY + halfHeight,
                    desiredPos.Z
                )
            else
                -- treat as ceiling, keep current Y
                desiredPos = Vector3.new(
                    desiredPos.X,
                    pos.Y,
                    desiredPos.Z
                )
            end
        else
            -- no ground under new step -> edge
            desiredPos = pos
        end

        pos = desiredPos

        -- 3) Facing direction (if idle, keep old forward)
        local forward = if dir.Magnitude > EPS
            then dir
            else cf.LookVector

        local oldPos = transform.new.Position
        local newCF = CFrame.new(pos, pos + forward)

        transform.new = newCF
        
        if (pos - oldPos).Magnitude > MIN_REPL_DELTA then
            hitbox.CFrame = newCF
        end
    end
end

local MOVE_HZ = 20          -- 20 Hz movement
local MOVE_TICK = 1 / MOVE_HZ
local moveAcc = 0

local function moveWrapper(dt: number)
    moveAcc += dt
    if moveAcc < MOVE_TICK then return end

    local step_dt = moveAcc
    moveAcc = 0
    mobMoveStep(step_dt)
end

scheduler.SYSTEM(moveWrapper, phases.AIMovement)
return 0
