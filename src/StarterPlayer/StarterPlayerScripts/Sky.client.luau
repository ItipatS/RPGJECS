
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Sky = Lighting:WaitForChild("Sky") :: Sky

local TOTAL_TIME = 600-- 5 minutes in seconds
local ROTATION_SPEED = 360 / TOTAL_TIME -- 1.2 degrees per second

RunService.RenderStepped:Connect(function(dt)
	local ori = Sky.SkyboxOrientation
	Sky.SkyboxOrientation = Vector3.new(
    ori.X,
    (ori.Y + ROTATION_SPEED * dt) % 360,
    ori.Z)
end)
