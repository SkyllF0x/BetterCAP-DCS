----------------------------------------------------
-- Container for detected object, wrapper around default detection table
-- https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
----------------------------------------------------    
---@class TargetContainer
---@field private dcsObject table
---@field private detector AbstractDCSObject
---@field private typeKnown boolean
---@field private rangeKnown boolean
TargetContainer = {}

---@param dcsDetectionTable DCSDetectionTable
---@param detectorObject AbstractDCSObject
---@return TargetContainer
function TargetContainer:create(dcsDetectionTable, detectorObject)   
  local instance = {}

  instance.dcsObject = dcsDetectionTable.object
  instance.detector = detectorObject
  instance.typeKnown = dcsDetectionTable.type

  --dcsController can know distance from RWR, so check if target detected by some ranging sensors
  instance.rangeKnown = detectorObject:getController():isTargetDetected(instance.dcsObject,
     Controller.Detection.RADAR, Controller.Detection.IRST)
  return setmetatable(instance, {__index = self})
end

---@return table
function TargetContainer:getTarget() 
  return self.dcsObject
end

---@return AbstractDCSObject
function TargetContainer:getDetector()
  return self.detector
end

---@return boolean
function TargetContainer:isTypeKnown() 
  return self.typeKnown
end

---@return boolean
function TargetContainer:isRangeKnown() 
  return self.rangeKnown
  end
----------------------------------------------------    
-- End of TargetContainer
----------------------------------------------------    

----------------------------------------------------    
-- AbstractTarget object
----------------------------------------------------    
---@class AbstractTarget
---@field protected currentROE AbstractTarget.ROE
---@field protected typeModifier AbstractTarget.TypeModifier
---@field protected targeted boolean
AbstractTarget = {}
---@enum AbstractTarget.ROE
AbstractTarget.ROE = {
  Bandit = 1,  --target outside border, will not be attacket until shot to friendlies
  Hostile = 2 --valid target
}
---@enum AbstractTarget.TypeModifier
AbstractTarget.TypeModifier = {
  FIGHTER = 1,
  ATTACKER = 2,
  HELI = 3
}

AbstractTarget.names = {}
AbstractTarget.names.ROE = {
  [AbstractTarget.ROE.Bandit] = "BANDIT",
  [AbstractTarget.ROE.Hostile] = "HOSTILE",
}
AbstractTarget.names.typeModifier = {
  [AbstractTarget.TypeModifier.FIGHTER] = "FIGHTER",
  [AbstractTarget.TypeModifier.ATTACKER] = "ATTACKER",
  [AbstractTarget.TypeModifier.HELI] = "HELI"
}

---update ROE for target
---@param roeEnum AbstractTarget.ROE
function AbstractTarget:setROE(roeEnum) 
  self.currentROE = roeEnum
end

---@return AbstractTarget.ROE
function AbstractTarget:getROE() 
  return self.currentROE 
end

---@return boolean
function AbstractTarget:getTargeted() 
  return self.targeted
end

--flag mean target attacked by fighter
function AbstractTarget:setTargeted(newVal) 
  self.targeted = newVal
end

--type of target( FIGHTER or ATTACKER )used for priority calc
---@return AbstractTarget.TypeModifier
function AbstractTarget:getTypeModifier() 
  return self.typeModifier
end
----------------------------------------------------    
-- end of AbstractTarget
----------------------------------------------------  

----------------------------------------------------    
-- Target object, hide real object properties
-- uses it's own calculations for determining position
-- We have 3 types of 'control':
-- 1)Type1: radar contact, most accurate provide data directly from dcsObject
-- 2)Type2: no radar but we have NAILS, estimate position by Bearing and signal power
-- 3)Type3: no contact extrapolate for given time(standart 45 sec) then in should be deleted
----------------------------------------------------  
----            AbstractTarget    ObjectWithEvent
----                  ↓                  ↓
----               Target  <-------------    
----------------------------------------------------  
---@class Target: AbstractTarget, ObjectWithEvent
---@field private holdTime number how long keep extrapolate contact until drop
---@field private point Vec3 calculated point
---@field private position Position calculated data for getPosition()
---@field private velocity Vec3 calculated velocity
---@field private deltaVelocity Vec3 
---@field private lastSeen {['L1']: number, ["L2"]: number, ["L3"]: number} 
---@field private seenBy TargetContainer[] all containers contains this target in current detection frame
---@field private controllType Target.ControlType
---@field private shooter boolean
Target = utils.inheritFromMany(AbstractTarget, ObjectWithEvent)

---@enum Target.ControlType
Target.ControlType = {
LEVEL1 = 1,
LEVEL2 = 2,
LEVEL3 = 3
}

--for message forming
Target.names = {}
Target.names.ControlType = {
  [Target.ControlType.LEVEL1] = "L1",
  [Target.ControlType.LEVEL2] = "L2",
  [Target.ControlType.LEVEL3] = "L3"
  }

  ---@param targetContainer TargetContainer
  ---@param extrapolateTime number
  ---@return Target
function Target:create(targetContainer, extrapolateTime) 
  local instance = ObjectWithEvent:create(targetContainer:getTarget())--call explicitly
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  ---@cast instance Target
  
  local zeroVec = {x = 0, y = 0, z = 0}
  
  instance.holdTime = extrapolateTime or 45
  instance.point = zeroVec --calculated pont
  instance.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = zeroVec}
  instance.velocity = zeroVec
  instance.deltaVelocity = zeroVec
  instance.lastSeen = {L1 = 0, L2 = 0, L3 = timer.getAbsTime()} --when target was last seen in different control types(L3 always assumed)
  instance.seenBy = {targetContainer} --table contains all container with this target
  instance.controlType = Target.ControlType.LEVEL3
  
  instance.currentROE = AbstractTarget.ROE.Bandit
  instance.targeted = false
  instance.shooter = false --flag shows this target shoot at object belonging to our coalition
  instance.typeName = "Unknown" --leave unknown so it will be populate by updateTypes() in first run if type known
  instance.typeKnown = false --leave false so it will be populate by updateTypes() in first run if type known
  instance.typeModifier = AbstractTarget.TypeModifier.ATTACKER
  
  if targetContainer:isTypeKnown() then 
    --just set real typename
    instance:updateType()
  end
  
  --register this guy in eventHander so we can track his shots
  EventHandler:create():registerObject(instance)
  return instance
end

---@return string
function Target:getDebugStr() 
  return self:getName() .. " targeted: " .. tostring(self.targeted) .. " | ROE: " .. AbstractTarget.names.ROE[self.currentROE] .. " | Type: " .. self:getTypeName() 
    .. " | TypeMod: " .. AbstractTarget.names.typeModifier[self.typeModifier] .. " | Control: " .. Target.names.ControlType[self.controlType] .. "\n" 
  end

function Target:engineOffEvent(event) 
  --not interested in this
end

---@param event ShotEvent
function Target:shotEvent(event) 
  local t = event.weapon:getTarget()
    
    if t and event.initiator == self.dcsObject and event.weapon:getDesc().category == Weapon.Category.MISSILE then 
      local coal = t:getCoalition()
      if coal ~= self.dcsObject:getCoalition() and coal ~= 0 then --if it no friendly fire or attack neutral so it attack us(thankfull dcs not model multunational war)
        self.shooter = true
      end
    end
  end
  
---@return boolean
function Target:isExist() 
  --we can magically know target alive or not
  if self.dcsObject and self.dcsObject:isExist() and not self:isOutages() then 
    return true
  end
    
  EventHandler:create():removeObject(self)--we dead or contact lost deregister us
  return false
end

---@return boolean
function Target:isShooter() 
  return self.shooter
  end

  ---@return Vec3
function Target:getPoint() 
  return self.point
end

---@return Position
function Target:getPosition() 
  return self.position
end

---@return Vec3
function Target:getVelocity() 
  return self.velocity
end

---@return number
function Target:getSpeed() 
  --small helper
  return mist.vec.mag(self.velocity)
end

--return AOB for point
---@param point Vec3
---@return number
function Target:getAA(point) 
  local targetVel = self.velocity
  
  if mist.vec.mag(targetVel) == 0 then 
    --zero vec, velocity unknown, assume fly away from point
    return 180 
  end
  
  
  local fromTgtToPoint = mist.vec.getUnitVec(mist.vec.sub(point, self:getPoint()))
  --acos from tgt velocity and vector from tgt to point
  return math.abs(math.deg(math.acos(mist.vec.dp(mist.vec.getUnitVec(targetVel), fromTgtToPoint))))
  end

--this object was detected
---@param targetContainer TargetContainer
function Target:hasSeen(targetContainer)
  self.seenBy[#self.seenBy+1] = targetContainer
end

function Target:flushSeen()
  self.seenBy = {}
end

function Target:updateLEVEL1() 
  --just update all field with 'true' data
  self.point = self.dcsObject:getPoint()
  self.position = self.dcsObject:getPosition()
  self.deltaVelocity = mist.vec.sub(self.dcsObject:getVelocity(), self.velocity)
  self.velocity = self.dcsObject:getVelocity()
  
  --update timing
  local currentTime = timer.getAbsTime()
  self.lastSeen = {L1 = currentTime, L2 = currentTime, L3 = currentTime}
  self.controlType = Target.ControlType.LEVEL1
  
  self:flushSeen()
end

function Target:updateLEVEL2() 
  --guess position on bearing and signal strength
  --first find closest detector(for accuracy)
  local closestDet = {range = -1, detector = {}}
  
  for _, detect in pairs(self.seenBy) do 
    local range = mist.utils.get2DDist(self.dcsObject:getPoint(), detect:getDetector():getPoint())
    if range > closestDet.range then 
      closestDet.range = range
      closestDet.detector = detect
    end
  end
  
  --rounded distance to ~5 km till 100km and ~10 after
  local mult = 10^(math.floor(math.log(closestDet.range, 10))-2)
  closestDet.range = utils.round(closestDet.range/mult, 5)*mult
  
  --use real object pos to determine bearing
  local LOS = mist.vec.getUnitVec(mist.vec.sub(self.dcsObject:getPoint(), closestDet.detector:getDetector():getPoint()))
  
  --update data
  local zeroVec = {x = 0, y = 0, z = 0}
  self.point = mist.vec.add(closestDet.detector:getDetector():getPoint(), mist.vec.scalar_mult(LOS, closestDet.range))
  self.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = self.point}
  --self.velocity = zeroVec --velocity, leave last known
  self.deltaVelocity = zeroVec
  
  --update timing 2 and 3
  local currentTime = timer.getAbsTime()
  self.lastSeen.L2 = currentTime
  self.lastSeen.L3 = currentTime
  self.controlType = Target.ControlType.LEVEL2
  
  self:flushSeen()
end

function Target:updateLEVEL3() 
  --dumb extrapolate with last known velocity
  --update data
  local zeroVec = {x = 0, y = 0, z = 0}
  self.point = mist.vec.add(self.point, mist.vec.scalar_mult(self.velocity, timer.getAbsTime() - self.lastSeen.L3))
  self.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = self.point}
  --self.velocity = zeroVec --velocity, leave last known
  self.deltaVelocity = zeroVec
  
  --update controlType
  self.controlType = Target.ControlType.LEVEL3
  --update timer
  self.lastSeen.L3 = timer.getAbsTime()
end

--update type of target
function Target:updateType() 
  if self.typeKnown then 
    return
  end
  
  local typeKnown = false
  for _, container in pairs(self.seenBy) do 
    if container:isTypeKnown() then 
      typeKnown = true
      break
      end
    end
  
  if not typeKnown then 
    --don't find a container with known type
    return
    end
  
  local obj = self.dcsObject
  self.typeName = obj:getTypeName()
  self.typeKnown = true
  
  if obj:hasAttribute("Fighters") or obj:hasAttribute("Interceptors") or obj:hasAttribute("Multirole fighters") then 
    self.typeModifier = AbstractTarget.TypeModifier.FIGHTER
  elseif obj:hasAttribute("Helicopters") then
    self.typeModifier = AbstractTarget.TypeModifier.HELI
  end
end

---@return boolean
function Target:isOutages() 
  return timer.getAbsTime() - self.lastSeen.L2 >= self.holdTime and timer.getAbsTime() - self.lastSeen.L1 >= self.holdTime
  end

--update track
function Target:update() 
  --if we don't have any containers which see us, we go to extrapolate
  if #self.seenBy == 0 then 
    self:updateLEVEL3()
    return 
  end
  
  --we have atleast 1 container trying to update type
  self:updateType()
  
  --try find container with level1 detection and also find that detector which know our type
  for _, container in pairs(self.seenBy) do     
    if container:isRangeKnown() then 
      --range known in this container just update LEVEL1
      self:updateLEVEL1()
      return
    end
  end
  
  --no LEVEL1 but still detected, go L2
  self:updateLEVEL2()
  return
end