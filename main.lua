local baton  = require("libraries.baton")
local cpml   = require("libraries.cpml")
local Timer  = require("libraries.timer")
local R3D    = require("R3D")
local Camera = require("camera")
local obj_loader = require("libraries.obj_loader")

local function dumpTable(table, depth)
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

---Purges mat4 table so it can be transferred over a channel
---@param mat mat4
---@return mat4
local function purgeMat4(mat)
    local result = {}
    for i = 1, 16 do
        result[i] = mat[i]
    end

    return result
end

local input = baton.new(
{
    controls = {
        left      = { 'key:a', 'axis:leftx-', 'button:dpleft'  },
        right     = { 'key:d', 'axis:leftx+', 'button:dpright' },
        up        = { 'key:w', 'axis:lefty-', 'button:dpup'    },
        down      = { 'key:s', 'axis:lefty+', 'button:dpdown'  },

        lookleft  = { 'key:left',   'axis:rightx-' },
        lookright = { 'key:right',  'axis:rightx+' },
        lookup    = { 'key:up',     'axis:righty-' },
        lookdown  = { 'key:down',   'axis:righty+' },
        action    = { 'key:x',      'button:a'     },
        quit      = { 'key:escape', 'button:start' },

        next = { 'key:e', 'button:rightshoulder' },
        prev = { 'key:q', 'button:leftshoulder'  }
    },
    pairs = {
        move = { 'left', 'right', 'up', 'down' },
        look = { 'lookleft','lookright', 'lookup', 'lookdown'}
    },
    joystick = love.joystick.getJoysticks()[1],
})

local camera = Camera.new(cpml.vec3.new(0,3,0))
camera.pitch = -20

local renderThread  = nil
local current_model = nil

local models_list = {}
local model_index = 1

function love.load()
    love.window.setMode(400,240)

    renderThread = love.thread.newThread("renderThread.lua")
    renderThread:start()

    local models_list_dir = love.filesystem.getDirectoryItems("models")
    if #models_list_dir == 0 then assert(false, "No models found") end

    for index = 1, #models_list_dir do
        if models_list_dir[index]:sub(-4) == ".obj" then
            table.insert(models_list, ("models/%s"):format(models_list_dir[index]))
        end
    end

    current_model = obj_loader.load(models_list[model_index])
    R3D.modelChannel:push({ action = "add", modelId = "polonez", model = current_model})
end


local n,o
---Calculates simplified view frustum with just the near plane
---@return { near: { [0]: R3D.vec3, [1]: R3D.vec3 } }
local function getNearPlaneFrustum()
    local r = {}

    n = camera.front
    n = { x = n.x, y = n.y, z = n.z }

    o = camera:getNearPoint(0.3)
    o = {x = o.x, y = o.y, z = o.z}

    r.near = { o, n }

    return r
end


function love.update(dt)
    input:update()

    local dx, dy = input:get('move')
    local lx, ly = input:get('look')

    camera:update(dt, dx, dy, lx,ly)

    local mat = purgeMat4(camera:getViewMatrix())
    local frustum = getNearPlaneFrustum()

    local threadInput = { mat = mat, frustum = frustum }
    R3D.inputChannel:push(threadInput)

    if input:pressed("next") or input:pressed("prev") then
        if input:pressed("next") then
            model_index = model_index + 1
            if model_index > #models_list then model_index = 1 end
        elseif input:pressed("prev") then
            model_index = model_index - 1
            if model_index < 1 then model_index = #models_list end
        end

        R3D.modelChannel:push({ action = "remove", modelId = "polonez", model = current_model})
        current_model = obj_loader.load(models_list[model_index])
        R3D.modelChannel:push({ action = "add", modelId = "polonez", model = current_model})
    end

    if input:pressed("quit") then
        love.event.quit()
    end
end

---Pull the draw calls from the R3D output channel
---@return R3D.OutputChannelCall
local function getCalls()
    local channel = R3D.outputChannel
    local count = channel:getCount()

    local calls
    for _ = 1, count do
        calls = channel:pop()
    end

    return calls
end

local info =
[[
FPS: %d
Model: %s
]]

function love.draw(screen)
    if screen == "bottom" then return end

    local calls = R3D.outputChannel:performAtomic(getCalls)

    if calls then
        for _, call in ipairs(calls) do
            love.graphics.setColor(call.color)
            love.graphics.polygon("fill",unpack(call.polygon))
        end
    end

    love.graphics.setColor(1,1,1,1)
    love.graphics.print(info:format(love.timer.getFPS(), models_list[model_index]))
end
