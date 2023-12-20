local baton  = require"baton"
local cpml   = require"cpml"
local Timer  = require"timer"
local R3D    = require"R3D"
local Camera = require"Camera"
local obj_loader = require "obj_loader"

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

---Purges mat4 table so it can be transferred over a channel
---@param mat mat4
---@return table
function purgeMat4(mat)
    local result = {}
    for i = 1, 16 do
        result[i] = mat[i]
    end
    return result
end

local input = baton.new {
	controls = {
		left = {'key:a', 'axis:leftx-', 'button:dpleft' },
		right = { 'key:d', 'axis:leftx+', 'button:dpright' },
		up = { 'key:w', 'axis:lefty-', 'button:dpup' },
		down = { 'key:s', 'axis:lefty+', 'button:dpdown' },
        lookleft = {'key:left', 'axis:rightx-' },
		lookright = { 'key:right', 'axis:rightx+' },
		lookup = { 'key:up', 'axis:righty-'},
		lookdown = { 'key:down', 'axis:righty+'},
		action = { 'key:x', 'button:a' },
        quit = { 'key:escape','button:start'}
	},
	pairs = {
		move = { 'left', 'right', 'up', 'down' },
        look = { 'lookleft','lookright', 'lookup', 'lookdown'}
	},
	joystick = love.joystick.getJoysticks()[1],
}

local camera
local renderThread
local polonez
local ploaded = false

function love.load()
    love.window.setMode(400,240)
    camera = Camera.new(cpml.vec3.new(0,3,0))
    camera.pitch = -20
    renderThread = love.thread.newThread("renderThread.lua")
    renderThread:start()
    polonez=obj_loader.load"polonez.obj"
end


local n,o
---Calculates simplified view frustum with just the near plane
---@return { near:{[0]:R3D.vec3, [1]:R3D.vec3} }
local function getNearPlaneFrustum()
    local r = {}
    n = camera.front
    n = {x=n.x, y=n.y, z=n.z}
    o = camera:getNearPoint(0.3)
    o = {x=o.x, y=o.y, z=o.z}
    r.near = { o, n }
    return r
end


function love.update(dt)
    input:update()

    local x,y = input:get'move'
    local lx,ly = input:get'look'
    camera:update(dt,x,y,lx,ly)
    ---@type mat4
    local mat = purgeMat4(camera:getViewMatrix())
    local frustum = getNearPlaneFrustum()
    ---@type R3D.InputChannelCall
    local threadInput = { mat=mat, frustum=frustum }
    R3D.inputChannel:push(threadInput)
    if input:pressed"action" and not ploaded then
        R3D.modelChannel:push({action="add", modelId="polonez", model=polonez, mtl={black={0.2,0.2,0.2},white={0.8,0.8,0.8},body={0.2,0.8,0.5}, red={0.457,0.09,0}, orange={0.8,0.159,0}}})
    end
    if input:pressed"quit" then
        love.event.quit()
    end
end

---Pull the draw calls from the R3D output channel
---@return R3D.OutputChannelCall
local function getCalls()
    local channel = R3D.outputChannel
    local count = channel:getCount()

    local calls
    for i = 1, count do
        calls = channel:pop()
    end
    return calls
end

local callCache
function love.draw(screen)
    if screen == "bottom" then return end
    local calls = R3D.outputChannel:performAtomic(getCalls)
    calls = calls or callCache
    if calls then
        callCache = calls
        for i, call in ipairs(calls) do
            love.graphics.setColor(call.color)
            love.graphics.polygon("fill",unpack(call.polygon))
        end      
    end
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(love.timer.getFPS())
end

