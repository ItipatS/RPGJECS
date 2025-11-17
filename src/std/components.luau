--ReplicatedStorage/std/components.luau

local jecs = require(game:GetService("ReplicatedStorage").ecs)
local world = require(script.Parent.world)

type Entity<T = nil> = jecs.Entity<T>
local components: {
	Character: Entity<Model>,
	Mob: Entity,
	Model: Entity<Model>,
	Player: Entity,
	Target: Entity,
	Transform: Entity<{ new: CFrame, old: CFrame }>,
	Speed: Entity<number>,
	Velocity: Entity<Vector3>,
	Previous: Entity,
	Size: Entity<number>,
	Hitbox: Entity<Part>,

	 -- Behavior Components
    StateMachine: Entity<{ current: string, states: {[string]: any} }>,
    ChaseTarget: Entity<{ target: number?, range: number, loseRange: number }>,
    Patrol: Entity<{ points: {Vector3}, current: number, wait: number }>,
	
    Wander: Entity<{ center: Vector3, radius: number, nextMove: number }>,
    Aggressive: Entity<{ attackRange: number, damage: number, cooldown: number }>,
    Flee: Entity<{ from: number?, fleeRange: number, speed: number }>,
    
    -- Timers/Conditions
    Timer: Entity<{ remaining: number }>,
    Cooldown: Entity<{ remaining: number }>,
	PendingStateChanges: Entity<{ [number]:{ id:number,  state: string } }>,

	--movement intent
	Locomotion: Entity<{ dir: Vector3, speed: number }>,

	 Traits: Entity<{
        baseSpeedMul: number,
        chaseWeight: number,
        fleeWeight: number,
        circleWeight: number,
        jumpWeight: number,
        fleeDistance: number,
        preferDistance: number,
    }>,

	AIState: Entity<{
        state: string,   -- "wander" | "chase" | "flee" | "circle"
        t: number,       -- time spent in state
        dur: number,     -- how long to stay in state (seconds)
        circleSign: number, -- +1 / -1 for circle direction
    }>,
} = {
		Character = world:component(),
		Mob = world:component(),
		Model = world:component(),
		Player = world:component(),
		Target = world:component(),
		Transform = world:component(),
		Speed = world:component(),
		Velocity = world:component(),
		Previous = world:component(),
		Size = world:component(),

		Hitbox = world:component(),

		StateMachine = world:component(),
		ChaseTarget = world:component(),
		Patrol = world:component(),
		Wander = world:component(),
		Aggressive = world:component(),
		Flee = world:component(),
		Timer = world:component(),
		Cooldown = world:component(),
		PendingStateChanges = world:component(),

		Locomotion = world:component(),

		Traits      = world:component(),
    	AIState     = world:component(),
	}

for name, component in components :: {[string]: jecs.Entity} do 
	world:set(component, jecs.Name, name)
end

return table.freeze(components)
