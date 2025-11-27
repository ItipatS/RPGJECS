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

## Features
- ~**150 active server-driven mobs** (wander / chase / circle / flee)
- **Dynamic behaviors per mob** based on weighted traits (personality-like stats)
- **Server-authoritative AI and movement**
- **Raycast-based movement:** ground snapping, edge detection, wall checks
- **Hitbox-driven replication:** invisible server hitboxes, visual models rendered on client
- **Client-side interpolation** running at 60 FPS
- Tunable gameplay parameters via ECS components

## Architecture
- **JECS ECS model** with components such as `Transform`, `Traits`, `Locomotion`, `AIState`, `Hitbox`
- **Clear system separation**:
  - AI System → selects behavior state
  - Movement System → handles kinematic motion + raycasts
  - Sync System → spawns client models
  - Interpolation System → smooths movement visually
- **Native engine networking**
  - Server replicates only hitbox CFrames
  - No per-frame RemoteEvent spam
- **Tick rates**
  - AI: **8 Hz**  
  - Movement: **20 Hz**  
  - Rendering: **60 Hz**  

## Benefits
- Clean, scalable ECS architecture
- Efficient use of Roblox physics and replication
- Smooth client visuals with minimal bandwidth
- Extensible foundation (e.g., plug in pathfinding)
- Strong demonstration of engineering and performance awareness (I thought)
