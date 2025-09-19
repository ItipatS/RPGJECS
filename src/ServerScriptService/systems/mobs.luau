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

local characters = world
	:query(Character)
	:with(Player)
	:cached()


local moving_mobs = world
	:query(Transform, Velocity)
	:with(Mob)
	:cached()
	

local lastupdate = 0
local function mobsMove(dt: number)
	lastupdate += dt
	if lastupdate < 0.064 then return end -- 30hz
	lastupdate = 0

	local targets = {}

	for _, character in characters do
		table.insert(targets, (character.PrimaryPart :: Part).Position)
	end

	for mob, transform, v in moving_mobs do
		local cf = transform.new
		local p = cf.Position

		local target
		local closest

		for _, pos in targets do
			local distance = (p - pos).Magnitude
			if not target or distance < closest then
				target = pos
				closest = distance
			end
		end

		if not target then
			continue
		end

		local moving = CFrame.new(p + (target - p).Unit * dt * v)
		transform.new = moving
		blink.UpdateTransform.FireAll(mob, moving)
	end
end

local throttle = interval(1)

local function spawnMobs()
	if throttle() then
		local p = Vector3.new(math.random(0, 200), 20, math.random(0, 200))
		local cf = CFrame.new(p)
		local v = 50

		local e = world:entity()
		world:set(e, Velocity, v)
		world:set(e, Transform, { new = cf })
		world:add(e, Mob)

		blink.SpawnMob.FireAll(e, cf, v)
	end
end

local scheduler = require(std.scheduler)

scheduler.SYSTEM(spawnMobs)
scheduler.SYSTEM(mobsMove)

return 0