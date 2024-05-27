
----------------------------------------------------
----           Wraps around DCS object
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----------------------------------------------------
DCS_Wrapper = utils.inheritFrom(AbstractDCSObject)

function DCS_Wrapper:create(dcsObject) 
  local instance = {}
  instance.dcsObject = dcsObject
  instance.typeName = dcsObject:getTypeName()
  instance.name = dcsObject:getName()
  instance.id = dcsObject:getID()
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function DCS_Wrapper:getTypeName() 
  return self.typeName
end

function DCS_Wrapper:getObject()
  return self.dcsObject
end

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

ObjectWithEvent = utils.inheritFrom(DCS_Wrapper)

--to detect shots
function ObjectWithEvent:shotEvent(event) 
  
end


--will be used to detect shutdown of aircraft
function ObjectWithEvent:engineOffEvent(event) 
  
end

----------------------------------------------------
-- end of ObjectWithEvent
----------------------------------------------------    
