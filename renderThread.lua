--- Render thread guard
local THREAD_RUNNING = true
local cpml = require("libraries.cpml")

local mat4 = cpml.mat4
local vec3 = require("libraries.cpml.modules.vec3")
local vec4 = require("libraries.cpml.modules.vec4")
local R3D = require("R3D")

math.randomseed(os.time())

local lightDir = vec3.new(0.3,0.3,0.3):normalize()

local function getAverageZ(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
        sum = sum + v.z
    end
    return sum / #t
end

local function multiplyColor(color, scalar)
    return {color[1]*scalar,color[2]*scalar,color[3]*scalar}
end

---Model store 
-- holds models for calculations
---@type {[string]:obj}
local models = {}

---Material store
-- holds materials
---@type {[string]:table}
local materials = {}

---Model synchronisation
-- Acts on the calls from the model channel
local function syncModels()
    local function add(modelId, model,mtl)
        models[modelId] = model
        materials[modelId] = mtl
    end
    local function remove (modelId)
        models[modelId] = nil
        materials[modelId] = nil
    end
    local function update(modelId, model,mtl)
        local m = models[modelId]
        for k,v in pairs(model) do m[k] = v end
        if mtl then
            materials[modelId] = mtl
        end
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
        actions[call.action](call.modelId,call.model,call.mtl)
    end
end

---Input synchronization
-- Get the latest matrix and clear the queue
---@return R3D.InputChannelCall
local function syncInput()
-- idea: memo/cache when things are not moving
    local channel = R3D.inputChannel
    local input = channel:pop()
    for i=1, channel:getCount() do
        input = channel:pop()
    end
    return input
end

local output = {}


---@type mat4
local projection = cpml.mat4.from_perspective(60,400/240,0.3,100)
projection[6] = projection[6] * -1 -- invert Y axis

---@type mat4
local VPMatrix = mat4.identity()

local projectSettings = {0,0,400,240}

---Checks for backface culling
---@param v vec3 vertex
---@param p vec3 plane
---@param n vec3 normal
---@return boolean
local function cullBackFace(v,p,n)
    return v:sub(p):dot(n) > 0
end

---Returns collection on vertices from vertex indices
---@param outVerts vec3[] converted vertices
---@param indices any
---@return table
local function getVertsFromIndices(outVerts,indices)
    local verts = {}
    for i = 1, #indices do
        verts[i] = outVerts[indices[i].v]
    end
    return verts
end

---Unpacks projected vertices into numbers for drawing
---@param t vec3[]
---@return table
local function unpackVerts(t)
    local r = {}
    for i, vert in ipairs(t) do
        r[i * 2 - 1] = vert.x
        r[i * 2] = vert.y
    end
    return r
end

---Add a drawing call to the output table
---@param color table
---@param verts table
local function polygon(color,verts)
    local zindex = getAverageZ(verts)
    table.insert(output,{color=color,polygon=unpackVerts(verts),zindex = zindex})
end

--- Render thread loop
while THREAD_RUNNING do
    syncModels()
    ---@type R3D.InputChannelCall
    local input = R3D.inputChannel:performAtomic(syncInput)

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
                    local diff = math.max(n:dot(lightDir),0.4)
                    local matlib = materials[modelId]
                    local c = matlib and matlib[face.mtl] or nil
                    c = multiplyColor(c and c or {0.8,0.8,0.8},diff*0.7)
                    local verts = getVertsFromIndices(outVerts,face)
                    polygon(c, verts)
                end
            end
        end
        table.sort(output,function(a, b) return a.zindex > b.zindex end)
        R3D.outputChannel:push(output)
    end
end
