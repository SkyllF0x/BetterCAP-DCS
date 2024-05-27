
----------------------------------------------------
-- Abstract fighter aircraft with FSM
----------------------------------------------------  
FighterEntity_FSM = {}


function FighterEntity_FSM:setFSM_Arg(name, val) 
  self.FSM_args[name] = val
  end

--FSM_state is valid object, add it to stack and call it
function FighterEntity_FSM:setFSM(FSM_state) 
  self.FSM_stack:push(FSM_state)
  self.FSM_stack:run(self.FSM_args)
end

function FighterEntity_FSM:setFSM_NoCall(FSM_state) 
  self.FSM_stack:push(FSM_state)
  end

function FighterEntity_FSM:clearFSM()
  self.FSM_stack:clear()
  end

function FighterEntity_FSM:callFSM() 
  self.FSM_stack:run(self.FSM_args)--run current state
  
  --vipe args
  self.FSM_args = {}
end

function FighterEntity_FSM:popFSM() 
  self.FSM_stack:pop()
  --calls new state
  self.FSM_stack:run(self.FSM_args)
end

function FighterEntity_FSM:popFSM_NoCall() 
  self.FSM_stack:pop()
end

--return enumerator of current FSM state
function FighterEntity_FSM:getCurrentFSM() 
  return self.FSM_stack:getStateEnumerator()
end

----------------------------------------------------
-- Single fighter aircraft
----------------------------------------------------  
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper    FighterEntity_FSM
----                  ↓                ↓
----              CapPlane <-----------
----------------------------------------------------


CapPlane = utils.inheritFromMany(DCS_Wrapper, FighterEntity_FSM)
CapPlane.options = {
  ThreatReaction = 1,
  ROE = 2,
  RDR = 4,
  ECM = 8,
  AttackRange = 16,
  BurnerUse = 32
  }

function CapPlane:create(PlaneGroup) 
  --call consructor explicitly
  local instance = DCS_Wrapper:create(PlaneGroup:getUnit(1))--we get a group with only 1 unit
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.groupID = PlaneGroup:getID()
  --override controller field, we need group level controller
  instance.controller = PlaneGroup:getController()

  instance.waitAfterLiftOff = 60 --default time
  if PlaneGroup:getUnit(1):inAir() then 
    --plane in Air, will wait 5sec so it can properly configure
    instance.waitAfterLiftOff = 5
  end
  
  instance.isAirborne = false
  instance.liftOffTime = nil
  
  --set to true when aircraft land and turn off it engines, so it can be deactivated
  instance.shutdown = false
  
  --missile with most range
  instance.bestMissile = {MaxRange = 0, MAR = 0}
  --last lauched missile
  instance.ourMissile = nil
  --all missile which guided to us
  instance.threatMissiles = {}
  
  instance.myGroup = nil --CapGroup i belong to
  instance.myElement = nil --CapElement i belong to
  
  --overriden options(external caller can set custon option i.e. use radar instead of default for fsm state)
  instance.overridenOptions = {}
  --implement FighterEntity FSM field
  instance.FSM_stack = FSM_Stack:create()
  --initialize with stub FSM
  instance.FSM_stack:push(FSM_Start:create(instance))
  instance.FSM_args = {
    waypoint = nil, --new waypoint for FlyToPoint
    newTarget = nil --new target for Attack states
    } --dictionary with args for FSM
  
  instance.target = nil --target object which we attack
  
  EventHandler:create():registerObject(instance)
  return instance
end

function CapPlane:getGroupID() 
  return self.groupID
  end

function CapPlane:getController() 
  return self.controller
  end

--return true if group in air and ready for tasking
---or group was airbirne when spawned, or after 60 sec from inAir (in return true when aircraft finishes it's departure routines????)
---so ai can execute all it's take off routines
function CapPlane:inAir()
  --return true if we already in air
  if self.isAirborne then 
    return true
  end
  
  --check if group in air, then set timer
  if not self.dcsObject:inAir() then 
    return false
  elseif not self.liftOffTime then
    --set timer
    self.liftOffTime = timer.getAbsTime()
  elseif timer.getAbsTime() - self.liftOffTime >= self.waitAfterLiftOff then  
    --set flag for future early exit
    self.isAirborne = true
    return true
  end

  return false
end

function CapPlane:isExist() 
  if self.dcsObject and self.dcsObject:isExist() then
    return true
  end
  
  --delete target to remove targeted flag
  self:resetTarget()
  EventHandler:create():removeObject(self)
  return false
end


function CapPlane:engineOffEvent(event) 
  if event.initiator == self.dcsObject then
    self.shutdown = true
  end
end

function CapPlane:shotEvent(event) 
  if event.initiator == self.dcsObject then
    self.ourMissile = MissileWrapper:create(event.weapon)
  elseif event.weapon:getTarget() == self.dcsObject then
    self.threatMissiles[#self.threatMissiles+1] = MissileWrapper:create(event.weapon)
  end
end

function CapPlane:getFuel() 
  
  if not self:isExist() then
    return 0
  end
  return self.dcsObject:getFuel()
end

--return true if support ourMissile no more needed
--also missile if so
function CapPlane:canDropMissile() 
  return not self.ourMissile
end

--update best missile to passed msl or missile in air if it has more range
function CapPlane:updateBestMissile(msl)   
  --if have missile in air, also check it for
  if self.ourMissile and utils.WeaponTypes[self.ourMissile:getTypeName()].MaxRange >= self.bestMissile.MaxRange then 
    self.bestMissile = utils.WeaponTypes[self.ourMissile:getTypeName()]
    return
  end
  
  self.bestMissile = msl
end

--check status and delete if no need to support it
function CapPlane:updateOurMissile() 
  if not self.ourMissile then 
    return
  elseif self.ourMissile:isTrashed() or self.ourMissile:isActive() then 
    GlobalLogger:create():info(self:getName() .. " missile done")
    self.ourMissile = nil
  end
end

--yeah this is shit, but we it makes 2 job at once, and it would be called only once on each update
function CapPlane:getAmmo()
  
  local resultAmmo = {
    [Weapon.GuidanceType.IR] = 0, --IR
    [Weapon.GuidanceType.RADAR_ACTIVE] = 0, --ARH
    [Weapon.GuidanceType.RADAR_SEMI_ACTIVE] = 0  --SARH
    }
  if not self:isExist() then
    return resultAmmo
  end
  
  local ammoTable = self.dcsObject:getAmmo()
  if not ammoTable then 
    return resultAmmo
  end
  
  local bestMissile = {MaxRange = 0, MAR = 0}
  --populate with data, also update bestMissile
  for idx, ammo in pairs(ammoTable) do 
    --get all ammo
    if ammo.desc and resultAmmo[ammo.desc.guidance]  then
      resultAmmo[ammo.desc.guidance] = resultAmmo[ammo.desc.guidance] + ammo.count
      
      --update best missile
      if utils.WeaponTypes[ammo.desc.typeName].MaxRange > bestMissile.MaxRange then 
        bestMissile = utils.WeaponTypes[ammo.desc.typeName]
      end
    end
  end
  
  self:updateBestMissile(bestMissile)
  return resultAmmo
end

--return missile with most range(including missile in air)
function CapPlane:getBestMissile() 

  return self.bestMissile
end

function CapPlane:getDetectedTargets()
  if not self:isExist() then 
    return {}
    end
  
  --all detection except DLink
  return self:getController():getDetectedTargets(Controller.Detection.VISUAL, 
      Controller.Detection.OPTIC, Controller.Detection.RADAR, 
      Controller.Detection.IRST, Controller.Detection.RWR)
end

function CapPlane:getNails()
  --return array with targets detected by RWR wrapped in DCS_Wrapper
  return self:getController():getDetectedTargets(16)
end

function CapPlane:registerGroup(capGroup) 
  self.myGroup = capGroup
end

function CapPlane:registerElement(capElement) 
  self.myElement = capElement
end

function CapPlane:setTarget(target) 
  --delete old target if present
  if self.target then 
    self:resetTarget()
    end
  
  --set targeted flag, indicate we attack it
  target:setTargeted(true)
  self.target = target
end

function CapPlane:resetTarget() 
  --set targeted flag, indicate we drop it
  if not self.target then 
    return
    end
  self.target:setTargeted(false)
  self.target = nil
end

function CapPlane:getAoA() 
  --sometimes return nil(?)
  return mist.getAoA(self.dcsObject) or 0
  end

--optionTbl is packed option from utils or nil if you want to delete IT
--optionName is CapPlane.options
function CapPlane:setOption(optionName, optionTbl) 
  self.overridenOptions[optionName] = optionTbl
  
  if not optionTbl then 
    --set default options for FSM
    self.FSM_stack:getCurrentState():setOptions()
    return
  end
  
  --push option to DCS AI, overriden option for new FSM states
  --now need override current setting
  self:getController():setOption(unpack(optionTbl))
end

function CapPlane:resetOptions() 
  self.overridenOptions = {}
  --set default options for FSM
  self.FSM_stack:getCurrentState():setOptions()
  end

function CapPlane:callFSM() 
  self.FSM_stack:run(self.FSM_args)--run current state
  
  --check if need to reapply task
  self.FSM_stack:getCurrentState():checkTask()
  
  --vipe args
  self.FSM_args = {}
  end

----------------------------------------------------
-- end CapPlane
----------------------------------------------------