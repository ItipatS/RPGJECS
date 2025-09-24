local ReplicatedStorage = game:GetService("ReplicatedStorage")
local std = ReplicatedStorage.std
-- Mailbox.lua (singleton)
local world = require(std.world)
local C     = require(std.components)

local M = { sys = nil, bufByComp = {} }  -- one global mailbox

local function ensureSYS(comp)
    if M.sys then return M.sys end
    for e in world:query(comp):cached() do
        M.sys = e;
        return e
    end
    -- (optional) create it:
    local e = world:entity()
    M.sys = e
    return e
end

function M.getBuf(comp)
    local buf = M.bufByComp[comp]
    if buf then return buf end
    local sys = ensureSYS(comp)
    buf = world:get(sys, comp)

    if not buf then
        buf = table.create(128);
        world:set(sys, comp, buf)
    end

    M.bufByComp[comp] = buf
    return buf
end

function M.push(comp, item)
    local b = M.getBuf(comp)
    b[#b+1] = item
end

function M.drain(comp, fn)
    local b = M.getBuf(comp)
    for i=1,#b do
        fn(b[i])
    end
    table.clear(b)
end

function M.invalidate()  -- for hot-reload
    M.sys = nil
    table.clear(M.bufByComp)
end

return M
