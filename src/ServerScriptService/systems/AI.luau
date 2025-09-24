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
local StateMachine = cts.StateMachine
local ChaseTarget = cts.ChaseTarget
local Patrol = cts.Patrol
local Wander = cts.Wander
local Aggressive = cts.Aggressive
local Flee = cts.Flee
local Timer = cts.Timer
local Player = cts.Player
local Character = cts.Character
local Mob = cts.Mob
local PendingMovements = cts.PendingMovements

--[[ Data store for movements
local SystemData = world:entity()
world:set(SystemData, PendingMovements, {})
]]
local SystemData = world:query(PendingMovements):cached()

-- Utility functions
local function getPlayerPositions(): {Vector3}
    local targets = {}
    for _, character in world:query(Character):with(Player) do
        local pp = character.PrimaryPart :: Part
        if pp then
            targets[#targets + 1] = pp.Position
        end
    end
    return targets
end

local function findClosestPlayer(position: Vector3, targets: {Vector3}): (Vector3?, number)
    if #targets == 0 then return nil, math.huge end
    
    local closest = nil
    local closestDist = math.huge
    
    for _, target in targets do
        local dist = (target - position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = target
        end
    end
    
    return closest, closestDist
end

-- ===== BEHAVIOR SYSTEMS =====

-- Chase Behavior System
local function chaseSystem(dt: number)
    local targets = getPlayerPositions()
    local movements = world:get(SystemData, PendingMovements)
    
    for entity, transform, velocity, chase in world:query(Transform, Velocity, ChaseTarget):with(Mob) do
        local position = transform.new.Position
        local closest, distance = findClosestPlayer(position, targets)
        
        if closest then
            if distance <= chase.range then
                -- Start/continue chasing
                chase.target = 1  -- Could store actual player entity
                
                -- Calculate movement
                local direction = (closest - position).Unit
                local speed = velocity
                local movement = direction * speed * dt
                
                -- Don't get too close
                if distance > 3 then
                    transform.new = CFrame.new(position + movement, direction)
                    movements[#movements + 1] = { id = entity, dp = movement }
                end
                
            elseif distance > chase.loseRange then
                -- Lost target
                chase.target = nil
            end
        else
            chase.target = nil
        end
    end
    
    world:set(SystemData, PendingMovements, movements)
end

-- Patrol Behavior System
local function patrolSystem(dt: number)
    local movements = world:get(SystemData, PendingMovements)
    
    for entity, transform, velocity, patrol, timer in world:query(Transform, Velocity, Patrol, Timer):with(Mob) do
        local position = transform.new.Position
        
        -- Count down wait timer
        timer.remaining -= dt
        
        if timer.remaining <= 0 then
            -- Move to next patrol point
            local targetPoint = patrol.points[patrol.current]
            local direction = (targetPoint - position)
            local distance = direction.Magnitude
            
            if distance < 2 then
                -- Reached point, move to next
                patrol.current = (patrol.current % #patrol.points) + 1
                timer.remaining = patrol.wait  -- Wait at point
            else
                -- Move toward point
                direction = direction / distance
                local speed = velocity
                local movement = direction * speed * dt
                
                transform.new = CFrame.new(position + movement, direction)
                movements[#movements + 1] = { id = entity, dp = movement }
            end
        end
    end
    
    world:set(SystemData, PendingMovements, movements)
end

-- Wander Behavior System  
local function wanderSystem(dt: number)
    local movements = world:get(SystemData, PendingMovements)
    
    for entity, transform, velocity, wander, timer in world:query(Transform, Velocity, Wander, Timer):with(Mob) do
        local position = transform.new.Position
        
        timer.remaining -= dt
        
        if timer.remaining <= 0 then
            -- Choose new random direction
            local angle = math.random() * math.pi * 2
            local distance = math.random() * wander.radius
            local target = wander.center + Vector3.new(
                math.cos(angle) * distance,
                0, 
                math.sin(angle) * distance
            )
            
            local direction = (target - position)
            if direction.Magnitude > 1 then
                direction = direction.Unit
                local speed = velocity * 0.5  -- Slower wandering
                local movement = direction * speed * dt
                
                transform.new = CFrame.new(position + movement, direction)
                movements[#movements + 1] = { id = entity, dp = movement }
            end
            
            timer.remaining = math.random(2, 5)  -- Next wander
        end
    end
    
    world:set(SystemData, PendingMovements, movements)
end

-- State Machine System
local function stateMachineSystem(dt: number)
    for entity, stateMachine in world:query(StateMachine):with(Mob) do
        local currentState = stateMachine.current
        local stateData = stateMachine.states[currentState]
        
        -- Example state transitions
        if currentState == "idle" then
            local targets = getPlayerPositions()
            local position = world:get(entity, Transform).new.Position
            local closest, distance = findClosestPlayer(position, targets)
            
            if closest and distance < 15 then
                -- Switch to chase
                stateMachine.current = "chase"
                
                -- Add chase component
                world:set(entity, ChaseTarget, {
                    range = 15,
                    loseRange = 25,
                    target = nil
                })
                
                -- Remove wander if it exists
                world:remove(entity, Wander)
                world:remove(entity, Timer)
            end
            
        elseif currentState == "chase" then
            local chase = world:get(entity, ChaseTarget)
            if not chase or not chase.target then
                -- Lost target, go back to wandering
                stateMachine.current = "wander"
                
                world:remove(entity, ChaseTarget)
                world:set(entity, Wander, {
                    center = world:get(entity, Transform).new.Position,
                    radius = 20,
                    nextMove = 0
                })
                world:set(entity, Timer, { remaining = 1 })
            end
        end
    end
end

--[[ Register all systems
scheduler.SYSTEM(stateMachineSystem, phases.AIBehavior)
scheduler.SYSTEM(chaseSystem, phases.AIBehavior)
scheduler.SYSTEM(patrolSystem, phases.AIBehavior)
scheduler.SYSTEM(wanderSystem, phases.AIBehavior)
]]

return 0