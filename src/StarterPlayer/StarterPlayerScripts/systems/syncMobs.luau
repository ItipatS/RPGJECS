--StarterPlayer/StarterPlayerScripts/systems/syncMobs.luau May move to replicated later
--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
local ref = require(std.ref)
local world = require(std.world)
local cts = require(std.components)

local MobsFolder = Instance.new("Folder")
MobsFolder.Name = "Mobs"
MobsFolder.Parent = workspace

local ReplicatedAnimals = ReplicatedStorage:WaitForChild("Animals")
local Animals = {} :: {[string]: BasePart}

for _ , child in pairs(ReplicatedAnimals:GetChildren()) do
	if child:IsA("BasePart") then
		if Animals[child.Name] == nil then
			Animals[child.Name] = child
		end
	end
end

warn("Animals ", Animals)

local function spawnVisualForHitbox(hitbox: BasePart)

	local mobType = hitbox:GetAttribute("MobType")
	local size = hitbox:GetAttribute("MobSize") or 1
	if not mobType or not Animals[mobType] then
		return
	end

	local part = Animals[mobType]:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false

	local model = Instance.new("Model")
	model.Name = `Mob-{mobType}`
	model.PrimaryPart = part
	part.Parent = model
	model.Parent = MobsFolder

	model:PivotTo(hitbox.CFrame)
	part.Size *= size

	local e = ref(hitbox)
	world:set(e, cts.Transform, { new = hitbox.CFrame, old = hitbox.CFrame })
	world:set(e, cts.Model, model)
	world:set(e, cts.Size, part.Size.Magnitude)
	world:set(e, cts.Hitbox, hitbox)
	world:add(e, cts.Mob)

end

local NPC_Hitboxes = workspace:WaitForChild("NPC_Hitboxes")

NPC_Hitboxes.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		spawnVisualForHitbox(child)
	end
end)

for _, child in ipairs(NPC_Hitboxes:GetChildren()) do
	if child:IsA("BasePart") then
		spawnVisualForHitbox(child)
	end
end

return 0

