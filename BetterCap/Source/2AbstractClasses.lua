
--BASIC ABC for future use

AbstractCAP_Handler_Object = {}

function AbstractCAP_Handler_Object:getID()
  return self.id
end

function AbstractCAP_Handler_Object:getName()
  return self.name
end

function AbstractCAP_Handler_Object:getDebugStr(settings) 
  return ""
  end

-------------------------------------------------------------------
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject     
-------------------------------------------------------------------

AbstractDCSObject = utils.inheritFrom(AbstractCAP_Handler_Object)

function AbstractDCSObject:getPoint()
  return self.dcsObject:getPoint()
end

function AbstractDCSObject:getVelocity()
  return self.dcsObject:getVelocity()
end

function AbstractDCSObject:getPosition()
  return self.dcsObject:getPosition()
end

function AbstractDCSObject:getController() 
  return self.dcsObject:getController()
end

function AbstractDCSObject:isExist()
  --double check cause dcs can fail to report in some cases
  if self.dcsObject then
    return self.dcsObject:isExist()
  else
    return false
  end
end