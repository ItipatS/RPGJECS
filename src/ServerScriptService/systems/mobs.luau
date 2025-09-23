--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(game:GetService("ServerScriptService").net)
local jecs = require(ReplicatedStorage.ecs)
local __ = jecs.Wildcard
local std = ReplicatedStorage.std
local ref = require(std.ref)
local interval = require(std.interval)

local world = require(std.world)
local cts = require(std.components)

local Mob = cts.Mob
local Transform = cts.Transform
local Velocity = cts.Velocity
local Player = cts.Player
local Character = cts.Character
local Size = cts.Size
local PendingMovements = cts.PendingMovements

-- Data store for movements
local SystemData = world:entity()
world:set(SystemData, PendingMovements, {})

local movements = world:get(SystemData, PendingMovements)
-- ===== Tunables =====
local TICK_HZ = 30
local TICK = 1 / TICK_HZ

local RESUME_RADIUS = 12     -- resume movement when farther than this (hysteresis)
local EPS = 1e-4             -- don't send tiny deltas

local STOP_RADIUS = 5
local lastPositions: {[number]: Vector3} = {}
local halted: {[number]: boolean} = {}

local targets: {Vector3} = table.create(16)

local characters = world
	:query(Character)
	:with(Player)
	:cached()

local moving_mobs = world
	:query(Transform, Velocity, Size)
	:with(Mob)
	:cached()

local last_accum = 0

-- Optimized distance calculation (avoids sqrt when possible)
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

local function mobsMove(dt: number)
	last_accum += dt

	if last_accum < TICK then return end -- 30hz

	local step_dt = last_accum
	last_accum = 0

	-- Collect player target positions
	table.clear(targets)
	for _, character in characters do
		local pp = (character.PrimaryPart :: Part)
		if pp then
			targets[#targets + 1] = pp.Position
		end
	end

	if #targets == 0 then
		return
	end

	table.clear(movements)
	for mob, transform, speed, size in moving_mobs do
		local cf = transform.new
		local position = cf.Position
		

		local stopRadius = math.max(STOP_RADIUS, size * 2)  -- Larger mobs stop farther out
		-- Find closest player
		local closestPos, closestDist = getClosestTarget(position)
		if not closestPos then
			continue
		end

		local isHalted = halted[mob] or false

		-- Hysteresis logic to prevent jittering
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

		if isHalted then
			-- Stay put; no delta to send
			continue
		end

		-- Move toward target, but don't overshoot past STOP_RADIUS
		local dir = (closestPos - position)
		local dist = dir.Magnitude

		if dist < EPS then
			continue
		end
		
		dir = dir / dist

		-- How far we're allowed to move this tick:
		-- 1) natural step = speed * dt
		-- 2) clamp so we never cross into STOP_RADIUS
		local stepMax = math.max(0, dist - stopRadius)
		local step = math.min(speed * step_dt, stepMax)

		if step <= EPS then
			-- Already close enough; nothing to do
			continue
		end

		local delta = dir * step
		local newPos = position + delta

		-- Update Transform
		transform.new = CFrame.new(newPos, cf.LookVector)

		-- Batch delta (skip near-zero)
		if delta.Magnitude > EPS then
			movements[#movements+1] = { id = mob, dp = delta }
			world:set(SystemData, PendingMovements, movements)
		end

		local lastPos = lastPositions[mob]
		if lastPos and (position - lastPos).Magnitude < 0.1 and not isHalted then
			-- Mob hasn't moved much - might be stuck
			-- Force unhalt or add small random offset
			halted[mob] = false
		end
		lastPositions[mob] = position

	end
--[[
	for e, pendingMovements in world:query(PendingMovements) do
		print("id", e, pendingMovements)
	end]]

end

local throttle = interval(1)
local function spawnMobs()
	if throttle() then
		-- Spawn in a more interesting pattern
		local angle = math.random() * math.pi * 2
		local radius = math.random(50, 150)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local p = Vector3.new(x, 20, z)
		local cf = CFrame.new(p)
		local v = math.random(30, 70) -- Vary speed for more interesting behavior
		local size = math.random(1,5)
		local e = world:entity()

		world:set(e, Size, size)
		world:set(e, Velocity, v)
		world:set(e, Transform, { new = cf })
		world:add(e, Mob)

		blink.SpawnMob.FireAll(e, cf, size)
	end
end

local scheduler = require(std.scheduler)

scheduler.SYSTEM(spawnMobs)
scheduler.SYSTEM(mobsMove)

return 0