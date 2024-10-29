
--BASIC ABC for future use
---@class AbstractCAP_Handler_Object
---@field id number
---@field name string
AbstractCAP_Handler_Object = {}

---@return number
function AbstractCAP_Handler_Object:getID()
  return self.id
end

---@return string
function AbstractCAP_Handler_Object:getName()
  return self.name
end

---@return string
function AbstractCAP_Handler_Object:getDebugStr(settings) 
  return ""
  end

-------------------------------------------------------------------
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject     
-------------------------------------------------------------------
---@class AbstractDCSObject: AbstractCAP_Handler_Object
---@field dcsObject table
AbstractDCSObject = utils.inheritFrom(AbstractCAP_Handler_Object)

---@return Vec3
function AbstractDCSObject:getPoint()
  return self.dcsObject:getPoint()
end

---@return Vec3
function AbstractDCSObject:getVelocity()
  return self.dcsObject:getVelocity()
end

---@return Position
function AbstractDCSObject:getPosition()
  return self.dcsObject:getPosition()
end

---@return Controller
function AbstractDCSObject:getController() 
  return self.dcsObject:getController()
end

---@return boolean
function AbstractDCSObject:isExist()
  --double check cause dcs can fail to report in some cases
  if self.dcsObject then
    return self.dcsObject:isExist()
  else
    return false
  end
end