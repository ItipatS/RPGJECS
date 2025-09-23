--!optimize 2
--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
local world = require(std.world)
local cts = require(std.components)
local scheduler = require(std.scheduler)
local phases = require(std.phases)

local Transform = cts.Transform
local Velocity = cts.Velocity
local Size = cts.Size
local Gravity = cts.Gravity
local Knockback = cts.Knockback
local Collider = cts.Collider
local Grounded = cts.Grounded
local Mob = cts.Mob

-- ===== Physics Constants =====
local GRAVITY_FORCE = -196.2  -- Roblox gravity
local TERMINAL_VELOCITY = -200
local GROUND_CHECK_DISTANCE = 0.5
local MOB_HEIGHT = 4

-- ===== Spatial Grid for Collision =====
local GRID_SIZE = 16
local spatialGrid: {[string]: {number}} = {}

local function clearSpatialGrid()
    for key in spatialGrid do
        spatialGrid[key] = nil
    end
end

local function addToGrid(entity: number, position: Vector3)
    local x, z = math.floor(position.X / GRID_SIZE), math.floor(position.Z / GRID_SIZE)
    local key = x .. "," .. z
    
    if not spatialGrid[key] then
        spatialGrid[key] = {}
    end
    
    table.insert(spatialGrid[key], entity)
end

local function getNearbyEntities(position: Vector3): {number}
    local x, z = math.floor(position.X / GRID_SIZE), math.floor(position.Z / GRID_SIZE)
    local nearby = {}
    
    -- Check 3x3 grid around position
    for dx = -1, 1 do
        for dz = -1, 1 do
            local key = (x + dx) .. "," .. (z + dz)
            if spatialGrid[key] then
                for _, entity in spatialGrid[key] do
                    table.insert(nearby, entity)
                end
            end
        end
    end
    
    return nearby
end

-- ===== Gravity System =====
local gravity_entities = world:query(Transform, Gravity):cached()

local function gravitySystem(dt: number)
    for entity, transform, gravity in gravity_entities do
        local position = transform.new.Position
        
        -- Apply gravity if not grounded
        if not gravity.grounded then
            gravity.velocity = math.max(gravity.velocity + GRAVITY_FORCE * dt, TERMINAL_VELOCITY)
            
            -- Move down
            local newY = position.Y + gravity.velocity * dt
            
            -- Ground check (raycast to terrain)
            local rayOrigin = Vector3.new(position.X, newY + GROUND_CHECK_DISTANCE, position.Z)
            local rayDirection = Vector3.new(0, -GROUND_CHECK_DISTANCE * 2, 0)
            local raycast = workspace:Raycast(rayOrigin, rayDirection)
            
            if raycast and raycast.Instance == workspace.Terrain then
                -- Hit ground
                newY = raycast.Position.Y + MOB_HEIGHT / 2
                gravity.velocity = 0
                gravity.grounded = true
                world:add(entity, Grounded)
            else
                -- Still falling
                gravity.grounded = false
                world:remove(entity, Grounded)
            end
            
            -- Update position
            transform.new = CFrame.new(Vector3.new(position.X, newY, position.Z), transform.new.LookVector)
        end
    end
end

-- ===== Knockback System =====
local knockback_entities = world:query(Transform, Knockback):cached()

local function knockbackSystem(dt: number)
    for entity, transform, knockback in knockback_entities do
        -- Apply knockback movement
        local movement = knockback.force * dt
        transform.new = transform.new + movement
        
        -- Reduce remaining time
        knockback.remaining -= dt
        
        if knockback.remaining <= 0 then
            world:remove(entity, Knockback)
        end
    end
end

-- ===== Collision System =====
local collision_entities = world:query(Transform, Collider):with(Mob):cached()

local function collisionSystem(dt: number)
    clearSpatialGrid()
    
    -- Build spatial grid
    for entity, transform, collider in collision_entities do
        addToGrid(entity, transform.new.Position)
    end
    
    -- Check collisions
    for entity, transform, collider in collision_entities do
        local position = transform.new.Position
        local radius = collider.radius
        
        local nearby = getNearbyEntities(position)
        
        for _, otherEntity in nearby do
            if entity ~= otherEntity and world:has(otherEntity, Collider) then
                local otherTransform = world:get(otherEntity, Transform)
                local otherCollider = world:get(otherEntity, Collider)
                
                if otherTransform and otherCollider then
                    local otherPos = otherTransform.new.Position
                    local distance = (position - otherPos).Magnitude
                    local minDistance = radius + otherCollider.radius
                    
                    if distance < minDistance and distance > 0 then
                        -- Collision! Push apart
                        local pushDirection = (position - otherPos).Unit
                        local pushAmount = (minDistance - distance) * 0.5
                        
                        -- Move both entities apart
                        local newPos = position + pushDirection * pushAmount
                        transform.new = CFrame.new(newPos, transform.new.LookVector)
                        
                        local otherNewPos = otherPos - pushDirection * pushAmount  
                        otherTransform.new = CFrame.new(otherNewPos, otherTransform.new.LookVector)
                    end
                end
            end
        end
    end
end

-- ===== Terrain Collision System =====
local function terrainCollisionSystem(dt: number)
    for entity, transform in world:query(Transform):with(Mob) do
        local position = transform.new.Position
        
        -- Check if position is inside terrain
        local region = Region3.new(
            position - Vector3.new(1, 1, 1),
            position + Vector3.new(1, 1, 1)
        )
        
        local material, occupancy = workspace.Terrain:ReadVoxels(region, 4)
        local size = material.Size
        
        -- Simple terrain collision - if any voxel is occupied, push up
        for x = 1, size.X do
            for y = 1, size.Y do
                for z = 1, size.Z do
                    if occupancy[x][y][z] > 0 then
                        -- Push mob above terrain
                        local newY = position.Y + 2
                        transform.new = CFrame.new(Vector3.new(position.X, newY, position.Z), transform.new.LookVector)
                        break
                    end
                end
            end
        end
    end
end

--[[scheduler.SYSTEM(knockbackSystem, phases.Physics)
scheduler.SYSTEM(gravitySystem, phases.Physics)
scheduler.SYSTEM(terrainCollisionSystem, phases.Physics)
scheduler.SYSTEM(collisionSystem, phases.Physics)]]

return {}