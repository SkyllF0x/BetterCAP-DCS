
----------------------------------------------------
----           Wraps around DCS object
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----------------------------------------------------
---@class DCS_Wrapper: AbstractDCSObject
---@field typeName string
---@field name string
---@field id number
DCS_Wrapper = utils.inheritFrom(AbstractDCSObject)

---@param dcsObject table
---@return DCS_Wrapper
function DCS_Wrapper:create(dcsObject) 
  local instance = {}
  ---@protected
  instance.dcsObject = dcsObject
  instance.typeName = dcsObject:getTypeName()
  instance.name = dcsObject:getName()
  instance.id = dcsObject:getID()
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

---@return string
function DCS_Wrapper:getTypeName() 
  return self.typeName
end

---@return table
function DCS_Wrapper:getObject()
  return self.dcsObject
end

---@return boolean
function DCS_Wrapper:hasAttribute(attr) 
  return self.dcsObject:hasAttribute(attr)
end

----------------------------------------------------
-- End of DCS_Wrapper
---------------------------------------------------

----------------------------------------------------
-- Wrapper with events, for use in EventHandler class
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----           ObjectWithEvent
----------------------------------------------------
---@class ObjectWithEvent: DCS_Wrapper
---@field create fun(self, dcsObject: table): ObjectWithEvent
ObjectWithEvent = utils.inheritFrom(DCS_Wrapper)

---to detect shots
---@param event Event
function ObjectWithEvent:shotEvent(event) 
  
end


---will be used to detect shutdown of aircraft
---@param event Event
function ObjectWithEvent:engineOffEvent(event) 
  
end

----------------------------------------------------
-- end of ObjectWithEvent
----------------------------------------------------    
