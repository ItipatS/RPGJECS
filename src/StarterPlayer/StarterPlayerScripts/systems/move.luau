--StarterPlayer/StarterPlayerScripts/systems/move.luau
--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
local world = require(std.world)
local scheduler = require(std.scheduler)

local cts = require(std.components)
local Model = cts.Model
local Transform = cts.Transform
local Hitbox = cts.Hitbox

local moved_mobs = world:query(Model, Transform,Hitbox):with(cts.Mob):cached()

-- ---------- Smooth interpolation state ----------
-- For each entity we keep a small state machine:
-- prev -> next over 'span' seconds, with alpha advancing each frame.
type Smooth = {
    prev: CFrame,
    next: CFrame,
    rendered: CFrame,  -- last frame’s output
    alpha: number,     -- [0..1]
    span: number,      -- seconds to complete the blend
}

local smooth: { [number]: Smooth } = {}

-- Pick a blend time ~ network period (12 Hz ~= 0.083s).
-- A bit longer is nicer; tweak to taste.
local TARGET_SPAN = 0.10   -- 100 ms
local MIN_SPAN    = 1/120  -- never 0; avoids huge alpha steps
local MAX_SPAN    = 0.25   -- don't smear too long

local function beginBlend(e: number, serverCF: CFrame)
    local s = smooth[e]
    if not s then
        -- first time: start at server pose (no pop)
        s = {
            prev = serverCF,
            next = serverCF,
            rendered = serverCF,
            alpha = 1,
            span = TARGET_SPAN,
        }
        smooth[e] = s
        return
    end

    -- Start new blend FROM what we actually rendered last frame (no rewind)
    local start = s.rendered
    s.prev = start
    s.next = serverCF

    -- Optional: dynamic span based on travel distance (longer jump = slightly longer smoothing)
    local dist = (s.next.Position - s.prev.Position).Magnitude
    local span = TARGET_SPAN
    if dist > 10 then
        span = math.clamp(TARGET_SPAN * 1.5, MIN_SPAN, MAX_SPAN)
    end

    s.span  = math.clamp(span, MIN_SPAN, MAX_SPAN)
    s.alpha = 0
end

local function stepBlend(e: number, dt: number): CFrame?
    local s = smooth[e]
    if not s then return nil end
    -- advance
    if s.alpha < 1 then
        -- normalize dt by span, clamp so big hitches don’t overshoot badly
        local da = math.clamp(dt / s.span, 0, 0.5)
        s.alpha = math.min(1, s.alpha + da)
    end
    -- CFrame:Lerp blends pos+rot (slerp-like)
    local out = s.prev:Lerp(s.next, s.alpha)
    s.rendered = out
    return out
end

-- ---------- 60 Hz presentation ----------
local RENDER_HZ = 60
local RENDER_DT = 1 / RENDER_HZ
local acc = 0

local function present(dt: number)
	acc += dt
	if acc < RENDER_DT then return end
	acc = 0
	for e, model, transform, hitbox in moved_mobs do
		if model.PrimaryPart and hitbox then
			-- target from Roblox replication
			local serverCF = hitbox.CFrame
			transform.new = serverCF

			-- drive smoothing
			beginBlend(e, serverCF)
			local cf = stepBlend(e, RENDER_DT)
			if cf then
				model:PivotTo(cf)
			end
		end
	end
end

scheduler.SYSTEM(present)

return 0
