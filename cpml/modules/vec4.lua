--- A 4 component vector.
-- @module vec4

local modules = (...):gsub('%.[^%.]+$', '') .. "."
local precond = require(modules .. "_private_precond")
local private = require(modules .. "_private_utils")
local sqrt    = math.sqrt
local cos     = math.cos
local sin     = math.sin

---@class vec4
---@field x number 
---@field y number
---@field z number
---@field w number
local vec4    = {}
local vec4_mt = {}

---Private constructor.
---@param x number
---@param y number
---@param z number
---@param w number
---@return vec4
local function new(x, y, z, w)
	return setmetatable({
		x = x or 0,
		y = y or 0,
		z = z or 0,
		w = w or 1
	}, vec4_mt)
end

-- Do the check to see if JIT is enabled. If so use the optimized FFI structs.
local status, ffi
if type(jit) == "table" and jit.status() then
	status, ffi = pcall(require, "ffi")
	if status then
		ffi.cdef "typedef struct { double x, y, z, w;} cpml_vec4;"
		new = ffi.typeof("cpml_vec4")
	end
end

--- Constants
-- @table vec4
-- @field unit_x X axis of rotation
-- @field unit_y Y axis of rotation
-- @field unit_z Z axis of rotation
-- @field zero Empty vector
vec4.unit_x = new(1, 0, 0)
vec4.unit_y = new(0, 1, 0)
vec4.unit_z = new(0, 0, 1)
vec4.zero   = new(0, 0, 0)

--- The public constructor.
---@param x number|table X component or table `{x, y, z, w}` or `{x=x, y=y, z=z, w=w}` or scalar to fill the vector
---@param y number Y component
---@param z number Z component
---@param w number W component
---@return vec4 out
function vec4.new(x, y, z, w)
	-- number, number, number
	if x and y and z and w then
		precond.typeof(x, "number", "new: Wrong argument type for x")
		precond.typeof(y, "number", "new: Wrong argument type for y")
		precond.typeof(z, "number", "new: Wrong argument type for z")
		precond.typeof(w, "number", "new: Wrong argument type for w")

		return new(x, y, z, w)

	-- {x, y, z} or {x=x, y=y, z=z}
	elseif type(x) == "table" or type(x) == "cdata" then -- table in vanilla lua, cdata in luajit
		local xx, yy, zz, ww = x.x or x[1], x.y or x[2], x.z or x[3], x.w or x[4]
		precond.typeof(xx, "number", "new: Wrong argument type for x")
		precond.typeof(yy, "number", "new: Wrong argument type for y")
		precond.typeof(zz, "number", "new: Wrong argument type for z")
		precond.typeof(ww, "number", "new: Wrong argument type for w")

		return new(xx, yy, zz, ww)

	-- number
	elseif type(x) == "number" then
		return new(x, x, x, x)
	else
		return new()
	end
end

--- Clone a vector.
---@param a vec4 Vector to be cloned
---@return vec4 out
function vec4.clone(a)
	return new(a.x, a.y, a.z, a.w)
end

--- Add two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 out
function vec4.add(a, b)
	return new(
		a.x + b.x,
		a.y + b.y,
		a.z + b.z,
		a.w + b.w
	)
end

--- Subtract one vector from another.
-- Order: If a and b are positions, computes the direction and distance from b
-- to a.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 out
function vec4.sub(a, b)
	return new(
		a.x - b.x,
		a.y - b.y,
		a.z - b.z,
		a.w - b.w
	)
end

--- Multiply a vector by another vector.
-- Component-wise multiplication not matrix multiplication.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 out
function vec4.mul(a, b)
	return new(
		a.x * b.x,
		a.y * b.y,
		a.z * b.z,
		a.w * b.w
	)
end

--- Divide a vector by another.
-- Component-wise inv multiplication. Like a non-uniform scale().
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 out
function vec4.div(a, b)
	return new(
		a.x / b.x,
		a.y / b.y,
		a.z / b.z,
		a.w / b.w
	)
end

--- Scale a vector to unit length (1).
---@param a vec4 vector to normalize
---@return vec4 out
function vec4.normalize(a)
	if a:is_zero() then
		return new()
	end
	return a:scale(1 / a:len())
end

--- Scale a vector to unit length (1), and return the input length.
---@param a vec4 vector to normalize
---@return vec4 out
---@return number input vector length
function vec4.normalize_len(a)
	if a:is_zero() then
		return new(), 0
	end
	local len = a:len()
	return a:scale(1 / len), len
end

--- Trim a vector to a given length
---@param a vec4 vector to be trimmed
---@param len number Length to trim the vector to
---@return vec4 out
function vec4.trim(a, len)
	return a:normalize():scale(math.min(a:len(), len))
end


--- Get the dot product of two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return number dot
function vec4.dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

--- Get the length of a vector.
---@param a vec4 Vector to get the length of
---@return number len
function vec4.len(a)
	return sqrt(a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w)
end

--- Get the squared length of a vector.
---@param a vec4 Vector to get the squared length of
---@return number len
function vec4.len2(a)
	return a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w
end

--- Get the distance between two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return number dist
function vec4.dist(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	local dw = a.w - b.w
	return sqrt(dx * dx + dy * dy + dz * dz + dw * dw)
end

--- Get the squared distance between two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return number dist
function vec4.dist2(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	local dw = a.w - b.w
	return dx * dx + dy * dy + dz * dz + dw * dw
end

--- Scale a vector by a scalar.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 out
function vec4.scale(a, b)
	return new(
		a.x * b,
		a.y * b,
		a.z * b,
		a.w * b
	)
end

--- Lerp between two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@param s vec4 Step value
---@return vec4 out
function vec4.lerp(a, b, s)
	return a + (b - a) * s
end

-- Round all components to nearest int (or other precision).
---@param a vec4 Vector to round.
---@param precision number Digits after the decimal (round numebr if unspecified)
---@return vec4 out Rounded vector
function vec4.round(a, precision)
	return vec4.new(private.round(a.x, precision), private.round(a.y, precision), private.round(a.z, precision),private.round(a.w, precision))
end

--- Unpack a vector into individual components.
---@param a vec4 Vector to unpack
---@return number x
---@return number y
---@return number z
---@return number w
function vec4.unpack(a)
	return a.x, a.y, a.z, a.w
end

--- Return the component-wise minimum of two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 A vector where each component is the lesser value for that component between the two given vectors.
function vec4.component_min(a, b)
	return new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z),math.min(a.w, b.w))
end

--- Return the component-wise maximum of two vectors.
---@param a vec4 Left hand operand
---@param b vec4 Right hand operand
---@return vec4 A vector where each component is the lesser value for that component between the two given vectors.
function vec4.component_max(a, b)
	return new(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z),math.max(a.w, b.w))
end

---Negate x axis only of vector.
---@param a vec4 Vector to x-flip.
---@return vec4 out x-flipped vector
function vec4.flip_x(a)
	return vec4.new(-a.x, a.y, a.z, a.w)
end

---Negate y axis only of vector.
---@param a vec4 Vector to y-flip.
---@return vec4 out y-flipped vector
function vec4.flip_y(a)
	return vec4.new(a.x, -a.y, a.z, a.w)
end

-- Negate z axis only of vector.
---@param a vec4 Vector to z-flip.
---@return vec4 out z-flipped vector
function vec4.flip_z(a)
	return vec4.new(a.x, a.y, -a.z, a.w)
end

-- Negate z axis only of vector.
---@param a vec4 Vector to w-flip.
---@return vec4 out w-flipped vector
function vec4.flip_w(a)
	return vec4.new(a.x, a.y, a.z, -a.w)
end

---Convert vector from clipspace to NDC.
---@param a vec4 Vector convert.
---@return vec4 out converted vector
function vec4.clip_to_ndc(a)
	return vec4.new(a.x/a.w, a.y/a.w, a.z/a.w, 1/a.w)
end

---Convert vector from NDC to screen space.
---@param a vec4 Vector to w-flip.
---@return vec4 w-out converted vector
function vec4.ndc_to_screen(a,w,h)
	return vec4.new(w*(a.x+1)/2, h*(a.y+1)/2, (a.z+1)/2, a.w)
end

function vec4.angle_to(a, b)
	local v = a:normalize():dot(b:normalize())
	return math.acos(v)
end

--- Return a boolean showing if a table is or is not a vec4.
---@param a vec4 Vector to be tested
---@return boolean is_vec4
function vec4.is_vec4(a)
	if type(a) == "cdata" then
		return ffi.istype("cpml_vec4", a)
	end

	return
		type(a)   == "table"  and
		type(a.x) == "number" and
		type(a.y) == "number" and
		type(a.z) == "number" and
		type(a.w) == "number"
end

--- Return a boolean showing if a table is or is not a zero vec4.
---@param a vec4 Vector to be tested
---@return boolean is_zero
function vec4.is_zero(a)
	return a.x == 0 and a.y == 0 and a.z == 0 and a.w == 0
end

--- Return whether any component is NaN
---@param a vec4 Vector to be tested
---@return boolean if x,y, or z are nan
function vec4.has_nan(a)
	return private.is_nan(a.x) or
		private.is_nan(a.y) or
		private.is_nan(a.z) or
		private.is_nan(a.w)
end

--- Return a formatted string.
---@param a vec4 Vector to be turned into a string
---@return string formatted
function vec4.to_string(a)
	return string.format("(%+0.3f,%+0.3f,%+0.3f,%+0.3f)", a.x, a.y, a.z, a.w)
end

vec4_mt.__index    = vec4
vec4_mt.__tostring = vec4.to_string

function vec4_mt.__call(_, x, y, z)
	return vec4.new(x, y, z)
end

function vec4_mt.__unm(a)
	return new(-a.x, -a.y, -a.z)
end

function vec4_mt.__eq(a, b)
	if not vec4.is_vec4(a) or not vec4.is_vec4(b) then
		return false
	end
	return a.x == b.x and a.y == b.y and a.z == b.z
end

function vec4_mt.__add(a, b)
	precond.assert(vec4.is_vec4(a), "__add: Wrong argument type '%s' for left hand operand. (<cpml.vec4> expected)", type(a))
	precond.assert(vec4.is_vec4(b), "__add: Wrong argument type '%s' for right hand operand. (<cpml.vec4> expected)", type(b))
	return a:add(b)
end

function vec4_mt.__sub(a, b)
	precond.assert(vec4.is_vec4(a), "__sub: Wrong argument type '%s' for left hand operand. (<cpml.vec4> expected)", type(a))
	precond.assert(vec4.is_vec4(b), "__sub: Wrong argument type '%s' for right hand operand. (<cpml.vec4> expected)", type(b))
	return a:sub(b)
end

function vec4_mt.__mul(a, b)
	precond.assert(vec4.is_vec4(a), "__mul: Wrong argument type '%s' for left hand operand. (<cpml.vec4> expected)", type(a))
	precond.assert(vec4.is_vec4(b) or type(b) == "number", "__mul: Wrong argument type '%s' for right hand operand. (<cpml.vec4> or <number> expected)", type(b))

	if vec4.is_vec4(b) then
		return a:mul(b)
	end

	return a:scale(b)
end

function vec4_mt.__div(a, b)
	precond.assert(vec4.is_vec4(a), "__div: Wrong argument type '%s' for left hand operand. (<cpml.vec4> expected)", type(a))
	precond.assert(vec4.is_vec4(b) or type(b) == "number", "__div: Wrong argument type '%s' for right hand operand. (<cpml.vec4> or <number> expected)", type(b))

	if vec4.is_vec4(b) then
		return a:div(b)
	end

	return a:scale(1 / b)
end

if status then
	xpcall(function() -- Allow this to silently fail; assume failure means someone messed with package.loaded
		ffi.metatype(new, vec4_mt)
	end, function() end)
end

return setmetatable({}, vec4_mt)
