
ZeroVec = {x = 0, y = 0, z = 0}

do 
 CoalitionObject = {}
 CoalitionObject.neutral = 0
 CoalitionObject.red = 1
 CoalitionObject.blue = 2
 
 function CoalitionObject:create() 
   return setmetatable({}, {__index = self})
   end
 
 function CoalitionObject:getCoalition() 
    return self.red
  end
  
  function CoalitionObject:getCountry() 
    return 0
  end
end


do 
  Controller = {}
  Controller.Detection = {  
  VISUAL = 1,
  OPTIC  = 2,
  RADAR  = 4,
  IRST   = 8,
  RWR    = 16,
  DLINK  = 32
}
  function Controller:create() 
   return setmetatable({}, {__index = self})
  end
  
  function Controller:setTask(task) 
    
  end
  
  function Controller:resetTask() 
  end
  
  function Controller:pushTask(task) 
  end
  
  function Controller:popTask()
  end
  
  function Controller:hasTask()
    return false
  end
  
  function Controller:setCommand(command) 
    
  end
  
  function Controller:setOption(optionID, optionVal) 
    
  end
  
  function Controller:setOnOff(value) 
    
  end
  
  function Controller:setAltitude(altitude, keep, altType) 
  
  end

  function Controller:setSpeed(speed, keep) 
  end
  
  function Controller:knowTarget(object, typ, distance) 
    
  end
  
  function Controller:isTargetDetected(target, ...) 
    return false
  end
  
  function Controller:getDetectedTargets(...) 
    return {}
  end
end

do
Object = {}
Object.Category = {
  UNIT   = 1,
  WEAPON = 2,
  STATIC = 3,
  BASE   = 4,
  SCENERY= 5,
  Cargo  = 6,
  }

function Object:create() 
  return setmetatable({}, {__index = self})
end

function Object:isExist() 
  return true
end

function Object:destroy() 
  
end

function Object:getCategory() 
  return Object.Category.UNIT
end

function Object:getTypeName() 
  return "F-14A"
end

function Object:getDesc() 
  return {}
end

function Object:hasAttribute(attribute) 
  return false
end

function Object:getName() 
  return "Name"
end

function Object:getPoint()
  return ZeroVec
end

function Object:getPosition() 
  return {p = ZeroVec,
          x = ZeroVec,
          y = ZeroVec,
          z = ZeroVec}
end

function Object:getVelocity() 
  return ZeroVec
end

function Object:inAir() 
  return false
  end

end



do 
  Group = setmetatable({}, {__index = Object})
  Group.Category = {
  AIRPLANE      = 0,
  HELICOPTER    = 1,
  GROUND        = 2,
  SHIP          = 3,
  TRAIN         = 4
}
  
  function Group:create() 
   return setmetatable({}, {__index = self})
  end
  
  function Group:activate() 
    
  end
  
  function Group:getUnit(id) 
    return Unit:create()
  end
  
  function Group:getID() 
    return 10
  end
  
  function Group:getUnits() 
    return {}
  end
  
  function Group:getSize() 
    return 0
  end
  
  function Group:getInitialSize() 
    return 0 
  end
  
  function Group:getController() 
    return Controller:create()
  end
  
  function Group:getCoalition() 
    return 0
  end
  
  function Group:getCoalition() 
    return 1
  end
  
  function Group:getCountry()
    return 1
  end
  

  function Group.getByName(name) 
    return Group:create()
  end
end


do 
  Unit = setmetatable({}, {__index = function(tbl, idx) 
        return Object[idx] or CoalitionObject[idx]
        end})
  Unit.Category = {
  AIRPLANE      = 0,
  HELICOPTER    = 1,
  GROUND_UNIT   = 2,
  SHIP          = 3,
  STRUCTURE     = 4
}
  Unit.SensorType = {
  OPTIC     = 0,
  RADAR     = 1,
  IRST      = 2,
  RWR       = 3
}
  
  
  function Unit:create() 
   return setmetatable({}, {__index = self})
  end
  
  function Unit:isActive() 
    return true
  end
  
  function Unit:getPlayerName() 
    return ""
  end
  
  function Unit:getID()
    return 0
  end
    
  function Unit:getNumber() 
    return 0
  end
  
  function Unit:getObjectID() 
    return 0
  end
  
  function Unit:getController() 
    return Controller:create()
  end
  
  function Unit:getGroup() 
    return Group
  end
  
  function Unit:getFuel() 
    return 1
  end
  
  function Unit:getLife() 
    return 1 
  end
  
  function Unit:getLife0() 
    return 1 
  end
  
  function Unit:getAmmo() 
    return {}
  end
  
  function Unit:getSensors() 
    return {}
  end
  
  function Unit:hasSensors(sensorType, subCategory)
    return false
  end
  
  function Unit:getRadar() 
    return false, nil
  end
  
  function Unit:getDrawArgumentValue(arg) 
    return 0
  end
  
  function Unit:getNearestCargos() 
    return {}
  end
  
  function Unit:enableEmission(setting) 
    
  end
  
end


do 
  Airbase = setmetatable({}, {__index = function(tbl, idx) 
        return Object[idx] or CoalitionObject[idx]
        end})
  Airbase.Category = {
  AIRDROME = 0,
  HELIPAD = 1, 
  SHIP = 2}

  function Airbase:create() 
   return setmetatable({}, {__index = self})
  end

  function Airbase:getID() 
    return 1
  end

  function Airbase:getParking(isAvail) 
    return {}
  end
  
  function Airbase:getRunways() 
    return {}
  end
  
  function Airbase:getTechObjectPos(objectType) 
    return ZeroVec
  end
  
  function Airbase:getRadioSilentMode() 
    return false
  end
  
  function Airbase:setRadioSilentMode(value) 
    
  end
  
  function Airbase:autoCapture(val) 
    
  end 
  
  function Airbase:autoCaptureIsOn() 
    return false
  end
  
  function Airbase:setCoalition(colition) 
    
  end
  
  function Airbase:getWarehouse() 
    return {}
  end
  
  function Airbase.getByName(name) 
    return Airbase
  end
  
  function Airbase.getDescByName(name) 
    return {} 
  end
end


do 
  Weapon = setmetatable({}, {__index = function(tbl, idx) 
        return Object[idx] or CoalitionObject[idx]
        end})
  Weapon.Category = {
  SHELL     = 0,
  MISSILE   = 1,
  ROCKET    = 2,
  BOMB      = 3}
  Weapon.GuidanceType = {
  INS                  = 1,
  IR                   = 2,
  RADAR_ACTIVE         = 3,
  RADAR_SEMI_ACTIVE    = 4,
  RADAR_PASSIVE        = 5,
  TV                   = 6,
  LASER                = 7,
  TELE                 = 8}

  Weapon.MissileCategory = {
  AAM         = 1,
  SAM         = 2,
  BM          = 3,
  ANTI_SHIP   = 4,
  CRUISE      = 5,
  OTHER       = 6}

  function Weapon:create() 
   return setmetatable({}, {__index = self})
  end

  function Weapon:getLauncher() 
    return Unit
  end
  
  function Weapon:getTarget() 
    return Object
  end
end
