--- Render thread guard
local THREAD_RUNNING = true
local cpml = require("cpml")
local mat4 = cpml.mat4
local vec3 = cpml.vec3
local R3D = require("R3D")

---Model synchronisation
-- Acts on the calls from the model channel
local function syncModels()
    local function add(modelId, model)
        R3D.models[modelId] = model
    end
    local function remove (modelId)
        R3D.models[modelId] = nil
    end
    local function update(modelId, model)
        local m = R3D.models[modelId]
        for k,v in pairs(model) do m[k] = v end
    end
    local function setMatrix(modelId, model)
        R3D.models[modelId].matrix = model.matrix
    end

    local actions = {
        add,
        remove,
        update,
        setMatrix
    }

    local channel = R3D.modelChannel
    local count = channel:getCount()

    
    for i = 1, count do
        ---@type R3D.ModelChannelCall
        local call = channel:pop()
        actions[call.action](call.modelId,call.model)
    end
end

---Input synchronization
-- Get the latest matrix and clear the queue
---@return mat4
local function syncInput()
-- idea: memo/cache when things are not moving
    local channel = R3D.inputChannel
    local vp = channel:pop()
    for i=1, channel:getCount() do
        vp = channel:pop()
    end
    return vp
end

local output = {}
local function draw(...)
    table.insert(output,{...})
end

---@type mat4
local projection = cpml.mat4.from_perspective(60,400/240,0.3,100)
projection[6] = projection[6] * -1 -- invert Y axis

---@type mat4
local VPMatrix

--- Render thread loop
while THREAD_RUNNING do
    syncModels()
    VPMatrix = R3D.inputChannel:performAtomic(syncInput)
    -- ...do the calculations
    R3D.outputChannel:push(output)
end