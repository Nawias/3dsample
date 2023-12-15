--#region Type aliases

---@alias R3D.ModelChannelCall { action: "add"|"remove"|"update"|"setMatrix", modelId: string, model: table }
---@alias R3D.InputChannelCall mat4
---@alias R3D.OutputChannelCall table
--#endregion


---@class R3D 
--- Top-level namespace object
local R3D = {}

--- Model channel 
-- Handles model adding, removing and modification
---@type love.Channel
R3D.modelChannel = love.thread.getChannel("r3d_model")

--- Input channel 
-- Transports matrices for calculations
---@type love.Channel
R3D.inputChannel = love.thread.getChannel("r3d_input")
--- Output channel 
-- Transports arrays of draw calls
---@type love.Channel
R3D.outputChannel = love.thread.getChannel("r3d_output")

---Model store 
-- holds models for calculations
----------
-- **ONLY ON THE THREAD**
---@type table
R3D.models = {}

return R3D