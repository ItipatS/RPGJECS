# JECS RPG Template – Scalable Mob AI & Networking Demo

This repository is a **Roblox RPG template** built on top of **JECS** (an ECS architecture for Luau).  
The core goal is to show how far I can push:

- **Server-authoritative gameplay**
- **Cheap, scalable mob AI**
- **Minimal replication bandwidth**
- **Smooth visual interpolation on the client**

The current demo runs **~150 server-driven mobs** with behavior logic and pathing, using **~80 KB/s of network intake** on the client, while all visual motion is **client-side interpolated**.
# Demo Place
https://www.roblox.com/games/104444037041931/RPGJECS-DEMO
---
## Demo Video

[![Watch the video](https://img.youtube.com/vi/eprIcdV42WM/0.jpg)](https://youtu.be/eprIcdV42WM)

##  Highlights

- **JECS-based architecture** – all gameplay is data-driven via components and systems.
- **Server-authoritative mobs** – AI, movement, and ground checks are done on the server.
- **Hitbox-as-authority design** – physics & replication use invisible hitbox parts; visuals are client-side clones.
- **Client interpolation layer** – smooth 60 Hz rendering from lower-frequency server updates.
- **Scales to 150+ mobs** with pathing/behavior while staying lightweight on network usage.

---

## Overview

### Server: Mob Spawning

**File:** `ServerScriptService/systems/SpawnMob.luau`

Responsibilities:

- Spawn invisible **hitbox parts** inside `workspace.NPC_Hitboxes`.
- Randomize:
  - spawn position in a radius
  - base speed
  - size (weighted by `entries`)
  - behavior traits (chase/flee/circle weights, detection ranges, preferred distance, etc.)
- Create ECS entities and attach:
  - `Transform` → `{ new = cf, old = cf }`
  - `Velocity` → scalar speed baseline
  - `Size` → hitbox magnitude
  - `Hitbox` → reference to the physical part
  - `Mob`, `Wander`, `Locomotion`, `Traits`, `AIState`

This system basically seeds the ECS world with a cloud of mobs, each having slightly different movement style and AI behavior.

---

### Server: Mob Brain (AI)

**File:** `ServerScriptService/systems/mob_brain.luau`

Responsibilities:

- Query **players**: `Character + Player` components.
- Query **mobs with brains**: `Mob + Transform + Velocity + Wander + Traits + AIState + Hitbox`.
- For each mob:
  - Find **closest player** in detection range.
  - Decide state: `wander`, `chase`, `circle`, `flee` based on:
    - distance to player
    - `Traits` weights (`chaseWeight`, `fleeWeight`, `circleWeight`)
    - `fleeDistance`, `preferDistance`, `detectRange`, `loseSightRange`
  - Update `AIState`:
    - `state` (string)
    - `t` (elapsed time in this state)
    - `dur` (how long to stay)
    - `circleSign` (clockwise/counter-clockwise circling)
  - Compute desired **Locomotion**:
    - `dir` – normalized horizontal movement direction.
    - `speed` – based on `Velocity` and `Traits.baseSpeedMul`.

The system runs at **8 Hz** (`BRAIN_HZ`), not every frame, to keep CPU and network usage low. Each step updates high-level decisions, which are then executed by the movement system.

---

### Server: Mob Movement & Grounding

**File:** `ServerScriptService/systems/mob_move.luau`

Responsibilities:

- Query moving mobs: `Mob + Transform + Locomotion + Hitbox`.
- For each mob:
  - Take `Locomotion.dir` and `Locomotion.speed`.
  - Compute a **desired position** using simple kinematic step:  
    `desiredPos = pos + dir * speed * dt`.
  - Perform **raycasts**:
    1. **Forward ray** – check walls/obstacles ahead.
    2. **Downward ray** – snap to ground, stay on navmesh-like surface.
  - Handle edges: if no ground under the new pos, cancel the move.
  - Keep the mob facing its movement direction (CFrame look vector).
  - Write back `Transform.new` and update the **Hitbox** `CFrame` (only when moved more than `MIN_REPL_DELTA`).

The movement system runs at **20 Hz** (`MOVE_HZ`). This keeps movement smooth enough while avoiding excessive replication updates.

---

### Client: Visual Sync & Entity Linking

**File:** `StarterPlayer/StarterPlayerScripts/systems/syncMobs.luau`

Responsibilities:

- Maintain a `workspace.Mobs` folder of visual models.
- For each **hitbox** created in `workspace.NPC_Hitboxes`:
  - Read attributes:
    - `MobType` – which base mesh from `ReplicatedStorage.Animals` to clone.
    - `MobSize` – scale factor.
  - Clone the **Animal** mesh, create a `Model`, and `PivotTo` hitbox CFrame.
  - Register an ECS entity mapped to this hitbox:
    - `Transform`, `Model`, `Size`, `Hitbox`, `Mob`.

Important: the server replicates only the minimal **hitbox** parts. The client handles spawning and rendering the visible mob models.

---

### Client: Smooth Interpolation

**File:** `StarterPlayer/StarterPlayerScripts/systems/move.luau`

Responsibilities:

- Query `Mob + Model + Transform + Hitbox` entities.
- Maintain a small `Smooth` state per entity:

  ```lua
  type Smooth = {
      prev: CFrame,
      next: CFrame,
      rendered: CFrame,
      alpha: number,
      span: number,
  }
