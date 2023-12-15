function dumpTable(table, depth)
    if (depth > 200) then
      print("Error: Depth > 200 in dumpTable()")
      return
    end
    for k,v in pairs(table) do
      if (type(v) == "table") then
        print(string.rep("  ", depth)..k..":")
        dumpTable(v, depth+1)
      else
        print(string.rep("  ", depth)..k..": ",v)
      end
    end
end
--- Render thread guard
local THREAD_RUNNING = true
local cpml = require("cpml")
local mat4 = cpml.mat4
local vec3 = require("cpml.modules.vec3")
local vec4 = require("cpml.modules.vec4")
local R3D = require("R3D")

math.randomseed(os.time())

---Model store 
-- holds models for calculations
---@type {[string]:obj}
local models = {}

---Model synchronisation
-- Acts on the calls from the model channel
local function syncModels()
    local function add(modelId, model)
        models[modelId] = model
    end
    local function remove (modelId)
        models[modelId] = nil
    end
    local function update(modelId, model)
        local m = models[modelId]
        for k,v in pairs(model) do m[k] = v end
    end
    local function setMatrix(modelId, model)
        models[modelId].matrix = model.matrix
    end

    local actions = {
        add=add,
        remove=remove,
        update=update,
        setMatrix=setMatrix
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


---@type mat4
local projection = cpml.mat4.from_perspective(60,400/240,0.3,100)
projection[6] = projection[6] * -1 -- invert Y axis

---@type mat4
local VPMatrix = mat4.identity()

local projectSettings = {0,0,400,240}

local function cullBackFace(v,p,n)
    return v:sub(p):dot(n) > 0
end

local function getVertsFromIndices(outVerts,indices)
    local verts = {}
    for i = 1, #indices do 
        verts[i] = outVerts[indices[i].v]
    end
    return verts
end

local function unpackVerts(t)
    local r = {}
    for i, vert in ipairs(t) do
        r[i * 2 - 1] = vert.x
        r[i * 2] = vert.y
    end
    return r
end

local function polygon(color,verts)
    table.insert(output,{color=color,polygon=unpackVerts(verts)})
end

--- Render thread loop
while THREAD_RUNNING do
    syncModels()
    ---@type R3D.InputChannelCall
    local input = R3D.inputChannel:performAtomic(syncInput)
    --print(dumpTable(input,3))
    if input and input.mat and input.frustum then
        VPMatrix = mat4.mul(VPMatrix, projection, mat4.new(input.mat))
        output = {}
        for modelId, model in pairs(models) do
            local outVerts = {}
            for i, v in ipairs(model.v) do
                outVerts[i] = mat4.project(v,VPMatrix,projectSettings)
            end
            for _, face in pairs(model.f) do
                local v = vec3.new(model.v[face[1].v])
                local n = vec3.new(model.vn[face[1].vn])
                local p = input.frustum.near[1]
                if not cullBackFace(v,p,n) then
                
                    --local diff = math.max(n:dot(lightDir),0.4)
                    local c = {math.random(),math.random(),math.random()}
                    local verts = getVertsFromIndices(outVerts,face)
                    polygon(c, verts)
                end
            end
        end
        R3D.outputChannel:push(output)
    end
end