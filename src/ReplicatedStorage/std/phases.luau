local std = game:GetService("ReplicatedStorage").std
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local scheduler = require(std.scheduler)
local PHASE = scheduler.PHASE

-- ===== Phase Creation with Validation =====
local phases = {}

local function createPhase(name: string, config: { after: any?, event: RBXScriptSignal? }?)
    if phases[name] then
        warn(`Phase '{name}' already exists! Skipping...`)
        return phases[name]
    end
    
    local phase = PHASE(config or {})
    phases[name] = phase
    
    if _G.__DEV__ then  -- Only in development
        print(`✓ Created phase: {name}`)
    end
    
    return phase
end

-- ===== Core Phases (Never Change) =====
phases.Heartbeat = scheduler.phases.Heartbeat
phases.PreSimulation = scheduler.phases.PreSimulation  
phases.PreAnimation = scheduler.phases.PreAnimation
phases.PreRender = scheduler.phases.PreRender

-- ===== Player Events =====
createPhase("PlayerAdded", { event = Players.PlayerAdded })
createPhase("PlayerRemoved", { event = Players.PlayerRemoving })

-- ===== Game Phases (Dependency Chain) =====
-- This order is the contract - changing it breaks everything
createPhase("EarlyUpdate", { after = phases.PreSimulation })
createPhase("Input", { after = phases.EarlyUpdate })
createPhase("GameLogic", { after = phases.Input })

-- Physics chain (order matters!)
createPhase("Physics", { after = phases.GameLogic })
createPhase("PhysicsKnockback", { after = phases.Physics })
createPhase("PhysicsGravity", { after = phases.PhysicsKnockback })
createPhase("PhysicsTerrain", { after = phases.PhysicsGravity })
createPhase("PhysicsCollision", { after = phases.PhysicsTerrain })

-- AI chain (can run in parallel within same phase)
createPhase("AIBehavior", { after = phases.PhysicsCollision })
createPhase("AIStateMachine", { after = phases.AIBehavior })
createPhase("AIMovement", { after = phases.AIStateMachine })  -- Chase/Patrol/Wander run here
createPhase("AICombat", { after = phases.AIMovement })

-- Game Systems
createPhase("Combat", { after = phases.AICombat })
createPhase("Health", { after = phases.Combat })
createPhase("Inventory", { after = phases.Health })
createPhase("Economy", { after = phases.Inventory })

-- Networking (order matters for batching)
createPhase("NetworkDelta", { after = phases.Economy })
createPhase("NetworkReliable", { after = phases.NetworkDelta })

-- Cleanup
createPhase("Cleanup", { after = phases.NetworkReliable })
createPhase("LateUpdate", { after = phases.Cleanup })

-- Independent chains (run on Heartbeat)
createPhase("WorldManagement", { after = phases.Heartbeat })
createPhase("Spawning", { after = phases.WorldManagement })
createPhase("Environment", { after = phases.WorldManagement })  -- Weather, day/night

-- Client-only phases
if RunService:IsClient() then
    createPhase("ClientInput", { after = phases.PreRender })
    createPhase("ClientUI", { after = phases.ClientInput })
    createPhase("ClientEffects", { after = phases.ClientUI })
    createPhase("ClientSound", { after = phases.ClientEffects })
    createPhase("ClientRendering", { after = phases.ClientSound })
end

-- Debug phase (always last)
createPhase("Debug", { after = phases.LateUpdate })

-- Freeze to prevent accidental modification
table.freeze(phases)

-- ===== Validation & Documentation =====
if _G.__DEV__ then
    print("=== Phase Execution Order ===")
    print("PreSimulation → EarlyUpdate → Input → GameLogic")
    print("→ Physics → PhysicsKnockback → PhysicsGravity → PhysicsTerrain → PhysicsCollision")
    print("→ AIBehavior → AIStateMachine → AIMovement → AICombat") 
    print("→ Combat → Health → Inventory → Economy")
    print("→ NetworkDelta → NetworkReliable → Cleanup → LateUpdate → Debug")
    print("\nHeartbeat Branch: WorldManagement → Spawning/Environment")
    print("PreRender Branch (Client): ClientInput → ClientUI → ClientEffects → ClientSound → ClientRendering")
    print("========================")
end

return phases