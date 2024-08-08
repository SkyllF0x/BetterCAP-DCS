---@meta CapSquadronMeta

---@class DCSWaypoint
---@field x number
---@field y number
---@field alt number

---@class GroupTable
---@field task string
---@field uncontrolled boolean
---@field lateActivation boolean
---@field start_time integer
---@field units table
---@field route {["points"]: DCSWaypoint[]}