--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = ReplicatedStorage.std
local world = require(std.world)
local ref = require(std.ref)

local cts = require(std.components)
local Model = cts.Model
local Transform = cts.Transform

-- Query: entities that have a Roblox model and a Transform
local moved_models = world:query(Model, Transform):cached()

-- Track which entities received a transform change this network tick
local updated_models: {[number]: true} = {}

-- --- timing (30 Hz presentation) ---
local TICK_HZ = 30
local TICK = 1 / TICK_HZ
local last = 0

-- Small epsilon to ignore noise
local EPS = 1e-4

-- Helper: ensure a Transform component exists with a .new CFrame
local function ensureTransform(e: number): {new: CFrame}
    local t = world:get(e, Transform)
    if t == nil then
        -- initialize with identity if missing (should be rare)
        t = { new = CFrame.new() }
        world:set(e, Transform, t)
    elseif t.new == nil then
        -- normalize shape if someone set Transform = CFrame by mistake
        t = { new = (t :: any) :: CFrame }
        world:set(e, Transform, t)
    end
    return t :: {new: CFrame}
end

-- --- Network handlers (register once) ---

-- Delta updates: [{ id: number, dp: Vector3 }, ...]
blink.UpdateTransformDelta.On(function(payload)
    for _, entry in payload do
        local e = ref("server-" .. tostring(entry.id))
        local t = ensureTransform(e)
        -- Shift position by delta while preserving rotation
        t.new = t.new + entry.dp
        updated_models[e] = true
    end
end)


-- 30 Hz presentation: push ECS Transform -> Roblox Model.PrimaryPart.CFrame
local function present(dt: number)
    last += dt
    if last < TICK then return end
    last = 0

    for e, model, transform in moved_models do
        if updated_models[e] then
            updated_models[e] = nil
            local m = model :: Model
            local t = transform :: {new: CFrame}
            if m and m.PrimaryPart and t and t.new then
                m.PrimaryPart.CFrame = t.new
            end
        end
    end
end

-- If you want a very light fairness/yield step you can keep this; otherwise remove it.
local i = 0
local function processed(n: number)
    i += 1
    if i > n then
        i = 0
        return true
    end
    return false
end

local scheduler = require(std.scheduler)
scheduler.SYSTEM(processed)  -- optional; safe to remove
scheduler.SYSTEM(present)

return 0
