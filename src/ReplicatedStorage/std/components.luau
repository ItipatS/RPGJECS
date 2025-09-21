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
} =
	{
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
	}

for name, component in components :: {[string]: jecs.Entity} do 
	world:set(component, jecs.Name, name)
end

return table.freeze(components)
