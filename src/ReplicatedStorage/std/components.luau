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
	Velocity: Entity<number>,
	Previous: Entity,
	Size: Entity<number>,

	--Physics)
	Gravity: Entity<{ velocity: number, grounded: boolean }>,
    Knockback: Entity<{ force: Vector3, remaining: number }>,
    Collider: Entity<{ radius: number }>,
    Grounded: Entity,

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
	PendingMovements: Entity<{ [number]:{ id:number, dp: Vector3 } }>,
	PendingStateChanges: Entity<{ [number]:{ id:number,  state: string } }>,
} = {
		Character = world:component(),
		Mob = world:component(),
		Model = world:component(),
		Player = world:component(),
		Target = world:component(),
		Transform = world:component(),
		Velocity = world:component(),
		Previous = world:component(),
		Size = world:component(),

		Gravity = world:component(),
		Knockback = world:component(),
		Collider = world:component(),
		Grounded = world:component(),

		StateMachine = world:component(),
		ChaseTarget = world:component(),
		Patrol = world:component(),
		Wander = world:component(),
		Aggressive = world:component(),
		Flee = world:component(),
		Timer = world:component(),
		Cooldown = world:component(),
		PendingMovements = world:component(),
		PendingStateChanges = world:component(),
	}

for name, component in components :: {[string]: jecs.Entity} do 
	world:set(component, jecs.Name, name)
end

return table.freeze(components)
