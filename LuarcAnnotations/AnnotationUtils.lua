---meta Names

---basic DCS event
---@class Event
---@field id integer

---@class ShotEvent: Event
---@field weapon table
---@field time number
---@field initiator table

---@class Vec2
---@field x number
---@field y number

---@class Vec3: Vec2
---@field z number

---@class Position
---@field x Vec3
---@field y Vec3
---@field z Vec3
---@field p Vec3


---@class DCSDetectionTable
---@field object table
---@field visible boolean
---@field type boolean
---@field distance boolean