local cpml   = require"cpml"
---constants
local YAW         = -90.0;
local PITCH       =  0.0;
local SPEED       =  2.5;
local SENSITIVITY =  0.1;
local ZOOM        =  45.0;

---@class Camera
---@field pos cpml.vec3 position
---@field front cpml.vec3 front vector
---@field up cpml.vec3 up vector
---@field worldUp cpml.vec3 world up vector
---@field yaw number yaw rotation
---@field pitch number pitch rotation
local Camera = {
    up
}
Camera.new = function(pos, yaw, pitch)
    local self = {}
    self.pos = pos or cpml.vec3.new(0,1,0)
    self.yaw = yaw or YAW
    self.pitch = pitch or PITCH
    self.worldUp = cpml.vec3.new(0,1,0)
    self.front = cpml.vec3.new(0,0,-1)
    self = setmetatable(self,Camera)
    self:updateCameraVectors()
    return self
end

Camera.__index = Camera

local tempViewMat = cpml.mat4.new({0,0,0,0,0,0,0,0,0})
function Camera:getViewMatrix()
    return cpml.mat4.look_at(tempViewMat, self.pos, self.pos:add(self.front), self.up)
end
function Camera:getNearPoint(near)
    return self.pos + self.front:scale(near)
end

function Camera:updateCameraVectors()
    local front = cpml.vec3.new(
        math.cos(math.rad(self.yaw))*math.cos(math.rad(self.pitch)),
        math.sin(math.rad(self.pitch)),
        math.sin(math.rad(self.yaw))*math.cos(math.rad(self.pitch))
    )
    self.front = front:normalize()
    self.right = (self.front:cross(self.worldUp)):normalize()
    self.up = (self.right:cross(self.front)):normalize()
    
end

function Camera:update(dt,moveX, moveY, rotX, rotY)
    -- movement
    self.pos = self.pos:add(self.front:scale(-SPEED*moveY*dt))
    self.pos = self.pos:add(self.right:scale(SPEED*moveX*dt))
    -- rotation
    self.yaw = self.yaw + rotX
    self.pitch = cpml.utils.clamp(self.pitch - rotY,-89,89)


    self:updateCameraVectors()
end

function Camera:draw2D()
    local f = self.pos:add(self.front:scale(3))
    love.graphics.setColor(1,0,1)
    love.graphics.circle("fill",self.pos.x, self.pos.z, 3)
    love.graphics.setColor(1,1,1)
    love.graphics.line(self.pos.x, self.pos.z, f.x, f.z)
end


return Camera