JECS Server-Authoritative RPG Framework

A deterministic, server-authoritative RPG framework built entirely on JECS (a high-performance Lua ECS for Roblox).
This project provides the foundation for building action-RPG or MMO-style games with:

Fully server-simulated hitboxes

Server-controlled AI with behavior states

Kinematic physics

Deterministic execution order using phases

Client interpolation for smooth rendering

Lightweight, efficient replication

Zero external frameworks

This framework does not yet include combat, inventory, or full MMO persistence — instead, it focuses on delivering a robust simulation core for developers who want total control of their multiplayer game logic.

 Features
Server-Authoritative Simulation

All core logic runs on the server

No client-side physics or predictions

Deterministic order ensures sync across clients

JECS Architecture

Entities, components, and systems follow JECS conventions

High performance, minimal allocations

Clear separation of data (components) and logic (systems)

 AI Behavior System

Includes basic but extendable AI:

Wander

Patrol

Avoid collisions / crowding

Chase

Circle target

Idle / decision brain

Timer-driven logic

Each mob runs through a small behavior pipeline driven by components and phases.

Simple Kinematic Physics

Custom movement controller with:

Direction vectors

Speed modifiers

Soft collision avoidance

Controlled acceleration or instant velocity
No Roblox physics → 100% deterministic movement.

Server-Authoritative Hitboxes

Hitboxes simulated server-side

Clients only render visuals

Supports melee, ranged, AoE

Easily expandable for a future combat system

Deterministic Phases System

Custom phases.luau defines system execution order:

Movement phase

AI phase

Hitbox/update phase

Sync phase

Guaranteed identical updates each frame.

 Lightweight Sync + Client Interpolation

Server sends essential state only

Clients interpolate positions to avoid jitter

Scales smoothly as mob count increases

Debug Tools

MobDebug.luau can render:

Hitboxes

Velocity vectors

AI states

Target lines

Useful for diagnosing server-authoritative movement and decision-making.
