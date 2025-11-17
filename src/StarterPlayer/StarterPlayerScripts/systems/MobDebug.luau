--!strict
local RunService = game:GetService("RunService")

local NPC_HITBOXES = workspace:WaitForChild("NPC_Hitboxes")

type Visual = {
    range: BasePart?,
    ray: BasePart?,
    gui: BillboardGui,
    label: TextLabel,
}

local VISUALS: {[BasePart]: Visual} = {}

local function makeBillboard(hitbox: BasePart): Visual
    local gui = Instance.new("BillboardGui")
    gui.Name = "MobStateBillboard"
    gui.Size = UDim2.fromScale(4, 1)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.StudsOffset = Vector3.new(0, hitbox.Size.Y + hitbox.Size.Y/2, 0)
    gui.Adornee = hitbox
    gui.Parent = hitbox  -- auto-cleanup when hitbox is destroyed
    gui.MaxDistance = 100

    local label = Instance.new("TextLabel")
    label.Name = "StateLabel"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.35
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = "..."
    label.Parent = gui

    return { gui = gui, label = label }
end

local function stateColor(state: string): Color3
    if state == "chase" then
        return Color3.fromRGB(255, 80, 80)      -- red
    elseif state == "flee" then
        return Color3.fromRGB(80, 160, 255)     -- blue
    elseif state == "circle" then
        return Color3.fromRGB(255, 200, 80)     -- yellow
    elseif state == "wander" then
        return Color3.fromRGB(80, 255, 120)     -- green
    else
        return Color3.fromRGB(180, 180, 180)    -- gray / unknown
    end
end

local function createRangePart(range: number): BasePart
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(range*2, range*2, range*2)
    p.Color = Color3.fromRGB(0, 180, 255)
    p.Material = Enum.Material.ForceField
    p.Transparency = 0.85
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Anchored = true
    p.CastShadow = false
    p.Name = "DetectRangeVisual"
    p.Parent = workspace.Terrain
    return p
end

local function createRayPart(): BasePart
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 1)
    p.Color = Color3.fromRGB(255, 80, 80)
    p.Material = Enum.Material.Neon
    p.Transparency = 0.2
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Anchored = true
    p.Name = "VisionRay"
    p.Parent = workspace.Terrain
    return p
end

local function getVisual(hitbox: BasePart): Visual
    local v = VISUALS[hitbox]
    if not v then
        v = { range = nil, ray = nil }
        VISUALS[hitbox] = v
    end
    return v
end


local function updateStateVisual(hitbox: BasePart)
    local v = getVisual(hitbox)
    local stateAttr = hitbox:GetAttribute("MobState")
    if typeof(stateAttr) ~= "string" then
        return
    end

    if not v.gui then
        local Billboard = makeBillboard(hitbox)
        v.gui = Billboard.gui
        v.label = Billboard.label
    end

    v.label.Text = stateAttr
    v.label.BackgroundColor3 = stateColor(stateAttr)
end

local function updateRangeVisual(hitbox: BasePart)
    local v = getVisual(hitbox)
    local rangeAttr = hitbox:GetAttribute("DetectRange")
    if typeof(rangeAttr) ~= "number" or rangeAttr <= 0 then
        if v.range then
            v.range:Destroy()
            v.range = nil
        end
        return
    end

    if not v.range then
        v.range = createRangePart(rangeAttr)
    end
    v.range.Size = Vector3.new(rangeAttr*2, rangeAttr*2, rangeAttr*2)
end

local function updateRayVisual(hitbox: BasePart)
    local v = getVisual(hitbox)

    local hasTarget = hitbox:GetAttribute("HasTarget")
    local targetPos = hitbox:GetAttribute("TargetPos")

    if hasTarget ~= true or typeof(targetPos) ~= "Vector3" then
        if v.ray then
            v.ray.Transparency = 1
        end
        return
    end

    if not v.ray then
        v.ray = createRayPart()
    end

    local origin = hitbox.Position
    local toTarget = targetPos - origin
    local dist = toTarget.Magnitude
    if dist < 0.1 then
        v.ray.Transparency = 1
        return
    end

    local dir = toTarget.Unit
    v.ray.Transparency = 0.2
    v.ray.Size = Vector3.new(0.1, 0.1, dist)
    v.ray.CFrame = CFrame.new(origin + dir * (dist * 0.5), targetPos)
end

-- listen for new hitboxes
NPC_HITBOXES.ChildAdded:Connect(function(child)
    if not child:IsA("BasePart") then return end

    task.defer(function()
        updateRangeVisual(child)
        updateRayVisual(child)
        updateStateVisual(child)
    end)

    child.AttributeChanged:Connect(function(attr)
        if attr == "DetectRange" then
            updateRangeVisual(child)
        elseif attr == "HasTarget" or attr == "TargetPos" then
            updateRayVisual(child)
        elseif attr == "MobState" then
            updateStateVisual(child)
        end
    end)
end)

-- cleanup + follow hitboxes
RunService.RenderStepped:Connect(function()
    for hitbox, v in pairs(VISUALS) do
        if hitbox.Parent == nil then
            if v.range then v.range:Destroy() end
            if v.ray then v.ray:Destroy() end
            VISUALS[hitbox] = nil

            v.gui:Destroy()
            VISUALS[hitbox] = nil
        else
            if v.range then
                v.range.CFrame = hitbox.CFrame
            end
            -- ray visual is updated in AttributeChanged + here for motion
            if v.ray then
                updateRayVisual(hitbox)
            end
        end
    end
end)

return 0