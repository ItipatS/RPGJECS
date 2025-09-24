local ReplicatedStorage = game:GetService("ReplicatedStorage")
local blink = require(ReplicatedStorage.net)
local std = ReplicatedStorage.std
local ref = require(std.ref)
local world = require(std.world)
local cts = require(std.components)
local spawned = {}

local pool = {}

local MobsFolder = Instance.new("Folder")
MobsFolder.Name = "Mobs"
MobsFolder.Parent = workspace

local function tweenMob(mob: Model, size: number)
	if not mob.PrimaryPart then return end

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
	local tween = game:GetService("TweenService"):Create(mob.PrimaryPart, tweenInfo, {Size = Vector3.new(1,1,1) * size})
	tween:Play()
	
end

local function syncMobs()
	for _, id, cf, Size in blink.SpawnMob.Iter() do
		if not spawned[id] then

			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
			part.Anchored = true
			part.CastShadow = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local model = Instance.new("Model")
			model.PrimaryPart = part
			part.Parent = model
			model.Name = "Mob-" .. tostring(id)
			model.PrimaryPart.CFrame = cf
			model.Parent = MobsFolder
			part.Size = Vector3.new(.1,.1,.1)
			tweenMob(model, Size)

			local e = ref("server-" .. tostring(id))
			world:set(e, cts.Transform, { new = cf, old = cf })
			world:set(e, cts.Model, model)
			world:add(e, cts.Mob)

			spawned[id] = true
		end
	end
end

local scheduler = require(std.scheduler)
scheduler.SYSTEM(syncMobs)

return 0

