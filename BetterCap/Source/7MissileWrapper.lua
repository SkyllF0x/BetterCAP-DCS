----------------------------------------------------
-- Wrapper around A/A Missile
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----            MissileWrapper
----------------------------------------------------

MissileWrapper = utils.inheritFrom(DCS_Wrapper)

function MissileWrapper:create(dcsObject) 
  --firstly check if this weapon have target(where it guiding to), if no target -> we not interested in this
  if not dcsObject:getTarget() then 
    return nil
  end

  local descTable = dcsObject:getDesc()
  --check guidance, we interested only in IR/SARH/ARH
  if descTable.guidance ~= 2 and descTable.guidance ~= 3 and descTable.guidance ~= 4 then 
    return nil
  end
  local instance = {}
  --missile doesn't have id, populate all values
  instance.dcsObject = dcsObject
  instance.name = "Missile"
  instance.typeName = dcsObject:getTypeName()
  instance.guidance = descTable.guidance
  instance.target = dcsObject:getTarget()
  instance.id = utils.getGeneralID()
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function MissileWrapper:getGuidance() 
  --guidance types:https://wiki.hoggitworld.com/view/DCS_Class_Weapon
  return self.guidance
end

function MissileWrapper:getClosingSpeed() 
  local speed = mist.vec.mag(self:getVelocity())
  return speed - mist.vec.dp(mist.vec.getUnitVec(mist.vec.sub(self.target:getPoint(), self:getPoint())), 
    self.target:getVelocity())
end

--return time to Hit
function MissileWrapper:getTTI()
  return mist.utils.get3DDist(self:getPoint(), self.target:getPoint()) / self:getClosingSpeed()
  end

--checks is missile still a factor, will return true if it dead or closingSpeed < 100 m/s
function MissileWrapper:isTrashed() 
  if not self.target:isExist() or not self:isExist() then --if target dead we also not interested
    return true
  end
  
  if self:getClosingSpeed() < 100 then 
    GlobalLogger:create():info("missile trashed, target: " .. self.target:getName() .. " closing: " .. tostring(self:getClosingSpeed()))
    return true
  end
  
  return false
end

--missile pittbull or Fox2, so no more support needed
--pittbull assumed when missile in ~ 18000m from target
function MissileWrapper:isActive() 
  return self:getGuidance() == Weapon.GuidanceType.IR 
    or (self:getGuidance() == Weapon.GuidanceType.RADAR_ACTIVE and mist.utils.get3DDist(self:getPoint(), self.target:getPoint()) < 18000)
  end
----------------------------------------------------
-- end of MissileWrapper
----------------------------------------------------
