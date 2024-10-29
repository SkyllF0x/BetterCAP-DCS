----------------------------------------------------
---- Start task, will wait until all aircraft airborne
-----and ready for tasking, also set each plane 
-----to hold as soon as it airborne
----------------------------------------------------  
----             AbstractState
----                  ↓
----          FSM_Element_Start
----------------------------------------------------

FSM_Element_Start = utils.inheritFrom(AbstractState)

function FSM_Element_Start:create(handledElem)
  local instance = self:super():create(handledElem)
  
  --check if all aircraft airborne on start
  instance.isInAir = true
  for _, plane in pairs(handledElem.planes) do 
    if not plane:getObject():inAir() then 
      instance.isInAir = false
    end
  end
  --orbit task for all aircraft
  instance.task = { 
     id = 'Orbit', 
     params = { 
       pattern = "Circle",
       point = mist.utils.makeVec2(handledElem:getPoint()),
       speed = 140,
       altitude = 1000
     } 
    }
  instance.numberPlanes = #handledElem.planes
  instance.name = "FSM_Element_Start"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Start
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end


--check if plane in Air and if so, push task
function FSM_Element_Start:run(arg) 

  if self.isInAir then 
    --already in air, just wait until group replace us
    return
  end

  local inAir = true
  
  for _, plane in pairs(self.object.planes) do 
    if not plane:getObject():inAir() then 
      inAir = false
    elseif plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.AbstractPlane_FSM then 

      plane:clearFSM()
      --restrict burner(yes by default in state it on, but
      --fuel consuption too great)
      plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off)
      plane:setFSM_NoCall(FSM_FlyOrbit:create(plane, self.task))
    end
  end
  
  self.isInAir = inAir
end

----------------------------------------------------
-- end of FSM_Element_Start
----------------------------------------------------

----------------------------------------------------
---- First plane assumed lead and will fly in passed
---- state, other planes in FSM_Formation
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_FlyFormation
----------------------------------------------------
FSM_Element_FlyFormation = utils.inheritFrom(AbstractState)

function FSM_Element_FlyFormation:create(handledElem, state, ...)
  local instance = self:super():create(handledElem)
  
  instance.state = state
  instance.stateArg = {...}
  instance.numberPlanes = #handledElem.planes
  instance.name = "FSM_Element_FlyFormation"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlyFormation
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_FlyFormation:setup() 
  --set wingmans to formation
  local leadID = self.object.planes[1]:getGroupID()
  
  for i = 2, #self.object.planes do 
    self.object.planes[i]:clearFSM()
    self.object.planes[i]:setFSM(FSM_Formation:create(self.object.planes[i], leadID, utils.tasks.formation.Cruise[i]))
  end
  
  --set lead to state
  self.object.planes[1]:clearFSM()
  self.object.planes[1]:setFSM(self.state:create(self.object.planes[1], unpack(self.stateArg)))
end

function FSM_Element_FlyFormation:teardown() 
  --disable burner override
  for _, plane in pairs(self.object.planes) do 
    plane:setOption(CapPlane.options.BurnerUse, nil)--restrict burner
  end
end

function FSM_Element_FlyFormation:run(arg) 
  --push argument to lead
  self.object.planes[1]:setFSM_Arg("waypoint", arg.waypoint)
  self.object.planes[1]:setFSM_Arg("newTarget", arg.newTarget)
  
  --check if someone dies 
  if #self.object.planes ~= self.numberPlanes then
    --someone dies, or has been moved from element,
    --reapply task
    self:setup()
    
    --update counter
    self.numberPlanes = #self.object.planes
  end
end



----------------------------------------------------
-- end of FSM_Element_FlyFormation
----------------------------------------------------

----------------------------------------------------
---- Group fly toward point, but as singletons
---- (all planes using passed state)
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_FlyFormation
----                  ↓
----        FSM_Element_FlySeparatly
----------------------------------------------------
FSM_Element_FlySeparatly = utils.inheritFrom(FSM_Element_FlyFormation)


function FSM_Element_FlySeparatly:create(handledElem, state, ...)
  local instance = self:super():create(handledElem, state, ...)
  
  instance.name = "FSM_Element_FlySeparatly"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlySeparatly
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_FlySeparatly:setup() 
  --set all planes to passed state
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    --restrict burner(yes by default in state it on, but
      --fuel consuption too great)
    plane:setFSM(self.state:create(plane, unpack(self.stateArg)))
  end
end

--teardown inherited

function FSM_Element_FlySeparatly:run(arg) 
  --push argument to planes
  for _, plane in pairs(self.object.planes) do 
    plane:setFSM_Arg("waypoint", arg.waypoint)
    plane:setFSM_Arg("newTarget", arg.newTarget)
  end
  --no need check if someone dies 
end

----------------------------------------------------
---- Abstract combat tactic with methods needed during combat
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----------------------------------------------------

FSM_Element_AbstractCombat = utils.inheritFrom(AbstractState)

  
--shortcut to get group target
function FSM_Element_AbstractCombat:getTargetGroup() 
  return self.object.myGroup.target
end  

function FSM_Element_AbstractCombat:logPrefix()
  return "Group: " .. self.object.myGroup:getName() .. " Element: " .. self.object:getName()
end

----------------------------------------------------
---- Abstract combat tactic with tactic inst
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----------------------------------------------------

FSM_Element_TacticWrapper = utils.inheritFrom(FSM_Element_AbstractCombat)

function FSM_Element_TacticWrapper:create(handledElem, tacticInst) 
  local instance = self:super():create(handledElem)
  
  --timestamp when tactic starts
  instance.startTime = 0
  instance.tactic = tacticInst
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_TacticWrapper:setup() 
  self.startTime = timer.getAbsTime()
end

function FSM_Element_TacticWrapper:getTimer() 
  return timer.getAbsTime() - self.startTime
end

----------------------------------------------------
---- Basic combat flying tactic(inmplement rejoin lead
---- by wingmans)
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----------------------------------------------------
FSM_Element_FlyPoint = utils.inheritFrom(FSM_Element_TacticWrapper)

--all planes set FlyToPoint
--Lead always fly to point, wingmans if in 5km
--fly to point or trying to intercept lead
function FSM_Element_FlyPoint:flyToPoint(point)
  local lead = self.object.planes[1]
  lead:setFSM_Arg("waypoint", point)

  --for other planes task will depend on distance from lead
  for i = 2, #self.object.planes do 
    local plane = self.object.planes[i]
    
    if mist.utils.get3DDist(plane:getPoint(), lead:getPoint()) > 7500 then 
      --we far away from lead, intercept our flightLead instead
      local leadIntercept = mist.fixedWing.buildWP(
        utils.getInterceptPoint(lead, plane, mist.vec.mag(lead:getVelocity())), 
          "turningpoint", 500, lead:getPoint().y, "BARO")
      plane:setFSM_Arg("waypoint", leadIntercept)

      GlobalLogger:create():drawPoint({pos = leadIntercept, text = plane:getName() .. " LEAD intercept point"})
    else
      --we close enough, set intercept point
      plane:setFSM_Arg("waypoint", point)
    end
  end
end
----------------------------------------------------
---- Basic intercept
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----                  ↓
----         FSM_Element_Intercept
----------------------------------------------------

FSM_Element_Intercept = utils.inheritFrom(FSM_Element_FlyPoint)

--tactic instance used to checkFor transition between states
function FSM_Element_Intercept:create(handledElem, tacticInst) 
  local instance = self:super():create(handledElem, tacticInst)
  instance.name = "FSM_Element_Intercept"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Intercept
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--FSM_Element_Intercept:setup() inherited

--create intercept point, intercept speed should be equals 
--to target speed + 75 but not below 300m/s
function FSM_Element_Intercept:getInterceptPoint() 
  local Speed = mist.vec.mag(self:getTargetGroup():getLead():getVelocity()) + 75
  if Speed < 300 then 
    Speed = 300
  end

  local point = mist.fixedWing.buildWP(
    utils.getInterceptPoint(self:getTargetGroup():getLead(), self.object.planes[1], Speed), 
      "turningpoint", Speed, self.tactic.alt)
  
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() 
      .. " intercept point speed/alt: " .. tostring(Speed) .. "/" .. tostring(self.tactic.alt)})
  return point
end

function FSM_Element_Intercept:run(arg)
  --check if we should stop
  if self.tactic:interceptCheck() then
    return
  end
  --set point for element
  self:flyToPoint(self:getInterceptPoint())
end


----------------------------------------------------
---- Fly away from target at given speed, tactic 
---- should replace this state at their own
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----                  ↓
----           FSM_Element_Pump
----------------------------------------------------

FSM_Element_Pump = utils.inheritFrom(FSM_Element_FlyPoint)

function FSM_Element_Pump:create(handledElem, tactic, speed)
  local instance = self:super():create(handledElem, tactic)
  instance.speed = speed
  instance.name = "FSM_Element_Pump"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Pump
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

--FSM_Element_Intercept:setup() inherited

function FSM_Element_Pump:run(arg)
  --check if we should stop
  if self.tactic:checkPump() then 
    return
  end
  
  --[[if we have second element, fly toward it, or just fly away
  local point = {}
  local element = self.object:getSecondElement()
  if element then 
    local elemPos = element:getPoint()
    local targetToElem = mist.vec.getUnitVec(mist.vec.sub(elemPos, self:getTargetGroup():getPoint()))
    point = mist.fixedWing.buildWP(
      mist.vec.add(elemPos, mist.vec.scalar_mult(targetToElem, 50000)), "turningpoint", self.speed, 7000, "BARO")
    
    GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT, to other elem: " .. tostring(element)})
  else
    local ourPos = self.object:getPoint()
    local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(ourPos, self:getTargetGroup():getPoint()))
    point = mist.fixedWing.buildWP(
      mist.vec.add(ourPos, mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", self.speed, 7000, "BARO")  
    
    GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT, to elem: " .. tostring(element)})
  end--]]
  
  local ourPos = self.object:getPoint()
  local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(ourPos, self:getTargetGroup():getPoint()))
  local point = mist.fixedWing.buildWP(
      mist.vec.add(ourPos, mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", self.speed, self.tactic.alt)  
    
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT speed/alt: " 
      .. tostring(self.speed) .. "/" .. tostring(self.tactic.alt)})
  
  --set point for element
  self:flyToPoint(point)
end

----------------------------------------------------
---- Attack state tactic 
---- should replace this state at their own
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----          FSM_Element_Attack
----------------------------------------------------

FSM_Element_Attack = utils.inheritFrom(FSM_Element_Intercept)

function FSM_Element_Attack:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.tactic = tactic
  instance.name = "FSM_Element_Attack"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Attack
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})  
end



function FSM_Element_Attack:getDataForPriorityCalc(target) 
  local speed = mist.vec.mag(target:getVelocity())
  local alt = target:getPoint().y
  --use this because getAA return absolute and in degrees
  local los = mist.vec.dp(mist.vec.getUnitVec(target:getPoint(), self.object:getPoint()), mist.vec.getUnitVec(target:getVelocity()))
  local range = mist.utils.get3DDist(target:getPoint(), self.object:getPoint())
  
  return target, speed, alt, los, range
end

function FSM_Element_Attack:calculatePriority(target, speed, alt, los, range)   
  local MAR, capGroup = utils.PlanesTypes[target:getTypeName()].Missile.MAR, self.object.myGroup
  local typeModifier = capGroup.priorityForTypes[target:getTypeModifier()]
  local targeted = 1
  
  if target.targeted then 
    targeted = 0.75 
  end
  
  return (((speed^2)/2 + 10*alt)*1.5 + 0.1*((80000*(los+1.5)*(capGroup:getBestMissile().MaxRange/range)^2)
      *(MAR/range)*targeted) + 2.5*MAR*(los+1))*typeModifier
end

function FSM_Element_Attack:prioritizeTargets(targets) 
  local result = {}
  for _, target in pairs(targets) do 
    result[#result+1] = {tgt = target, priority = self:calculatePriority(self:getDataForPriorityCalc(target))}
  end
  
  --IN DESCENDING ORDER YPU IDIOT
  table.sort(result, function(e1, e2) return e1.priority > e2.priority end)
  return result
end

--add target to plane without fsmAttack and wiothout target
function FSM_Element_Attack:tryAddTarget(plane, targetList) 
  
  if plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.FSM_Defence then 
    return 
    end
  
  for _, targetTbl in pairs(targetList) do 
    local target = targetTbl.tgt
    
    if not target:getTargeted() then 
      plane:setTarget(target)
      plane:setFSM(FSM_Attack:create(plane, target:getID()))
      return
      --set targeted target only is higher then non targeted target at high energy at our max range
    elseif targetTbl.priority/self:calculatePriority(
        target, 300, 8000, 1, self.object.myGroup:getBestMissile().MaxRange) >= 1.10 then
        
      --add targeted 
      GlobalLogger:create():debug(plane:getName() .. " add targeted: " .. target:getName())
      plane:setTarget(target)
      plane:setFSM(FSM_Attack:create(plane, target:getID()))
      return
    end
  end
end

--replace target in group
function FSM_Element_Attack:tryReplaceTarget(plane, targetList) 
  
  for _, targetTbl in pairs(targetList) do 
    local target = targetTbl.tgt
    
    --replace only if different target
    if target ~= plane.target then
    
      local ourPriority = self:calculatePriority(self:getDataForPriorityCalc(plane.target))
      local ratio = targetTbl.priority/ourPriority
      if ratio > 1.2 and not target:getTargeted() then 
        GlobalLogger:create():debug(plane:getName() ..  " change target, ratio: " .. tostring(ratio))
        plane:resetTarget()
        plane:setTarget(target)
        plane:setFSM_Arg("newTarget", target:getID())
        return
      end
    end
  end
end

function FSM_Element_Attack:setup() 
  --set attack states
  local targetSorted = self:prioritizeTargets(self:getTargetGroup():getTargets())
  
  for idx, plane in pairs(self.object:sortByAmmo()) do 
    self:tryAddTarget(plane, targetSorted)
  end
end


function FSM_Element_Attack:teardown() 
  GlobalLogger:create():debug(self.object:getName() .. " reset attack state")
  
   for idx, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      
      plane:resetTarget()--target deleted from plane and it will be automatically POPed from FSM
    end
  end
end

function FSM_Element_Attack:run(arg)

  if self.tactic:checkAttack() then 
    return
  end
  
  --intercept point 
  local interceptPoint = self:getInterceptPoint()

  local targetSorted = self:prioritizeTargets(self:getTargetGroup():getTargets())
  for idx, plane in pairs(self.object:sortByAmmo()) do 
    if not plane.target then 
      self:tryAddTarget(plane, targetSorted)
    else
      self:tryReplaceTarget(plane, targetSorted)
    end
    --if plane don't have target it just fly toward target
    plane:setFSM_Arg("waypoint", interceptPoint)
  end
end


----------------------------------------------------
---- Defend against missile, just call planes fsm
---- allow him to execute their defend behaviour
---- will maintain state until all planes clear
---- if plane exit from defend earlier
---- will set new WP for flying away from target
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Defending
----------------------------------------------------
FSM_Element_Defending = utils.inheritFrom(FSM_Element_TacticWrapper)

function FSM_Element_Defending:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.name = "Defending"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Defending
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--function FSM_Element_Defending:setup() inherited

--return true when ALL aircraft not defending
function FSM_Element_Defending:checkDefend() 
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.FSM_Defence then 
      return false
    end
  end
  
  return true
end

function FSM_Element_Defending:run(arg) 
  if self:checkDefend() then 
    --we stop defend, return to called
    self.object:popFSM()
    return
  elseif self.tactic:checkColdOps() then
    --we switch to cold ops
    return
  end
  
  local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(self:getTargetGroup():getPoint(), self.object:getPoint()))
  local point = mist.fixedWing.buildWP(
    mist.vec.add(self.object:getPoint(), mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", 600, 1000)
  
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " DEFEND POINT"})
  --set point for not defending plane
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      
      GlobalLogger:create():debug(plane:getName() .. " pumping")
      plane:setFSM_Arg("waypoint", point)
    end
  end
end

----------------------------------------------------
---- Defend against missile with HIGH ALR, will exit 
---- as soon as atleast 1 plane not defending
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Defending
----                  ↓
----       FSM_Element_DefendingHigh
----------------------------------------------------
FSM_Element_DefendingHigh = utils.inheritFrom(FSM_Element_Defending)

function FSM_Element_DefendingHigh:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.name = "DefendingHigh"
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--return as soon as atleast 1 plane not defending
function FSM_Element_DefendingHigh:checkDefend() 
  --will return true if alteast one plane not defending
  return not self.tactic:inDefending()
end
--run() same just override checkDefend()

----------------------------------------------------
---- Crank to given direction at given angle
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----          FSM_Element_Crank
----------------------------------------------------

FSM_Element_Crank = utils.inheritFrom(FSM_Element_Intercept)
FSM_Element_Crank.DIR = {}
FSM_Element_Crank.DIR.Left = -1
FSM_Element_Crank.DIR.Right = 1

FSM_Element_Crank.names = {}
FSM_Element_Crank.names[FSM_Element_Crank.DIR.Left] = "Left"
FSM_Element_Crank.names[FSM_Element_Crank.DIR.Right] = "Right"

--callback is function from tactic used for state checks, default is checkCrank
function FSM_Element_Crank:create(handledElem, tactic, angle, side,callback)
  local instance = self:super():create(handledElem, tactic)

  instance.callback = callback or tactic.checkCrank
  instance.angle = math.rad(angle) or math.rad(60)
  instance.side = side or FSM_Element_Crank.DIR.Left
  instance.name = "Crank " .. FSM_Element_Crank.names[instance.side]
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Crank
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--setup() not needed

function FSM_Element_Crank:getCrankPoint() 
  local ourPos = self.object:getPoint()
  local dirToTarget = mist.utils.makeVec2(mist.vec.getUnitVec(mist.vec.sub(self:getTargetGroup():getPoint(), ourPos)))
  local dirToCrankPoint = mist.utils.makeVec3(mist.vec.rotateVec2(dirToTarget, self.angle*self.side))

  return mist.vec.add(ourPos, mist.vec.scalar_mult(dirToCrankPoint, 50000))
end

function FSM_Element_Crank:run(arg) 
  if self.callback(self.tactic) then 
    return
  end
  
  local crankPoint = self:getCrankPoint()
  self:flyToPoint(mist.fixedWing.buildWP(crankPoint, "turningpoint", self.tactic.speed, self.tactic.alt))
  GlobalLogger:create():drawPoint({pos = crankPoint, text = self:getName() .. " point, speed/alt: " 
      .. tostring(self.tactic.speed) .. "/" .. tostring(self.tactic.alt)})
  end

----------------------------------------------------
---- Maintain lateral separation from target,
---- just fly parallel line
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----        FSM_Element_FlyParallel
----------------------------------------------------

FSM_Element_FlyParallel = utils.inheritFrom(FSM_Element_Intercept)


function FSM_Element_FlyParallel:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)

  instance.name = "Fly Parallel"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlyParallel
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end



function FSM_Element_FlyParallel:getTargetPoint() 
  local ourPos = self.object:getPoint()
  local lead = self:getTargetGroup():getLead()
  local aspect = lead:getAA(ourPos)
  if aspect > 90 then 
    --target cold, just use it velocity
    return mist.vec.add(ourPos, mist.vec.scalar_mult(lead:getVelocity(), 20000))
  else
    --target hot, use negative velocity
    local vel = lead:getVelocity()
    local negVelocity = {x = -vel.x, y = -vel.y, z = -vel.z}
    return mist.vec.add(ourPos, mist.vec.scalar_mult(negVelocity, 20000))
  end
end

function FSM_Element_FlyParallel:run(arg) 
  if self.tactic:checkFlyParallel() then 
    return
  end
  
  local point = self:getTargetPoint()
  GlobalLogger:create():drawPoint({pos = point, text = self:getName() .. " fly parallel point, speed/alt: " 
      .. tostring(self.tactic.speed) .. "/" .. tostring(self.tactic.altitude)})
  
  self:flyToPoint(mist.fixedWing.buildWP(point, "turningpoint", self.tactic.speed, self.tactic.alt))
end


----------------------------------------------------
---- Wrapper which simulate capGroup, allow execute
---- group level tactic inside element and on different
---- target
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_GroupEmul
----------------------------------------------------
FSM_Element_GroupEmul = utils.inheritFrom(AbstractState)

--groupTarget is bool determining this element attack grou target or different targtet
function FSM_Element_GroupEmul:create(elementToWrap, target, groupTarget) 
  local instance = self:super():create(elementToWrap)

  target:setTargeted(true)
  instance.target = target
  
  instance.elements = {}
  instance.elements[1] = CapElement:create({elementToWrap.planes[1]})
  --create elements from element
  if #elementToWrap.planes > 1 then 
    instance.elements[2] = CapElement:create({elementToWrap.planes[2]})
    
    --register elements to each other
    instance.elements[1]:setSecondElement(instance.elements[2])
    instance.elements[2]:setSecondElement(instance.elements[1])
  end
  
  for _, elem in pairs(instance.elements) do 
    elem:registerGroup(instance)
    elem.planes[1]:registerGroup(instance)
  end
  
  --copy some fields from group, so this instance can be used for tactic selection
  instance.preferableTactics = elementToWrap.myGroup.preferableTactics
  instance.countPlanes = #elementToWrap.planes
  instance.alr = elementToWrap.myGroup.alr
  instance.priorityForTypes = elementToWrap.myGroup.priorityForTypes
  
  instance.name = "Element Wrapper-" .. target:getName()
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_GroupEmul

  instance.attackGroupTarget = groupTarget or false
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_GroupEmul:getBestMissile() 
  return self.object:getBestMissile()
  end

function FSM_Element_GroupEmul:selectTactic() 
  local counter, tblWithWeights = 0, {}
  
  for enum, tactic in pairs(FSM_Engaged.tactics) do 
    local w = tactic:getWeight(self)
    tblWithWeights[enum] = w
    counter = counter + w
  end
  
  local stepSize = 100/counter
  local prevRange = 0
  local randomChoice = mist.random(100)
  
  for enum, weight in pairs(tblWithWeights) do 
    local newRange = prevRange + stepSize*weight
    if prevRange <= randomChoice and randomChoice <= newRange then 
      return FSM_Engaged.tactics[enum]
    end
    prevRange = newRange
  end
end

function FSM_Element_GroupEmul:setup() 
  
  local tactic = self:selectTactic()
  for _, elem in pairs(self.elements) do 
    
    elem:clearFSM()
    elem:setFSM(tactic:create(elem))
  end
end

function FSM_Element_GroupEmul:teardown() 
  --reset targeted 
  self.target:setTargeted(false)
  
  --return everything back, so element can be safely returned to group
  for _, plane in pairs(self.object.planes) do 
    --return links
    plane:registerElement(self.object)
    plane:registerGroup(self.object.myGroup)
    plane:clearFSM()
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
end

function FSM_Element_GroupEmul:update() 
  --update elements, delete dead
  self.countPlanes = 0
  
  local newElems = {}
  for _, elem in pairs(self.elements) do 
    
    if elem:isExist() then 
      newElems[#newElems + 1] = elem
      self.countPlanes = self.countPlanes + #elem.planes
      end
    end
    
  self.elements = newElems
  
  -- no check cause it will checked in update elements, and will be deleted
  --[[if #self.elements == 0 then 
    --dead
    return
    end--]]
  
  --update links
  if #self.elements == 1 then 
    self.elements[1]:setSecondElement(nil)
    return
  end
  
  self.elements[1]:setSecondElement(self.elements[2])
  self.elements[2]:setSecondElement(self.elements[1])
end

function FSM_Element_GroupEmul:callElements() 
  for _, elem in pairs(self.elements) do 
    elem:callFSM()
    end
end

function FSM_Element_GroupEmul:run(arg) 
  self:update() 

  if not self.target:isExist() then 
    GlobalLogger:create():debug(self.object:getName() .. " target dead")
    self.object:popFSM()
    return
  end

  --return if we should attack group target but target changes
  if self.attackGroupTarget then 
    
    if self.target ~= self.object.myGroup.target then 
      GlobalLogger:create():debug(self.object:getName() .. " group target chages")
      self.object:popFSM()
      return
    end
    --return here, no range check for group target
    self:callElements() 
    return
  end

  if arg.newTarget == self.object.myGroup.target then 
    --we recieve same target as our group, no need to split more
    GlobalLogger:create():debug(self.object:getName() .. " element have same target as group")
    self.object:popFSM()
    return
  end

  --update target
  if arg.newTarget and arg.newTarget ~= self.target then 
    
    GlobalLogger:create():debug(self.object:getName() .. " change target for split")
    self.target:setTargeted(false)
    
    self.target = arg.newTarget
    self.target:setTargeted(true)
    self.name = "Element Wrapper-" .. self.target:getName()
  end

  --distance more 20nm or MaxRange or Mar + 15000
  local rangeToTarget = mist.utils.get2DDist(self.object:getPoint(), self.target:getPoint()) 
  local ourRangeMargin = self.object:getBestMissile().MaxRange + 5000
  local targetRangeMargin = self.target:getHighestThreat().MAR + 15000

  if rangeToTarget > math.max(35000, math.min(ourRangeMargin, targetRangeMargin)) then 

    GlobalLogger:create():debug(self.object:getName() .. " return back to far")
    self.object:popFSM_NoCall()
    return
  elseif self.target:getTypeModifier() ~= AbstractTarget.TypeModifier.FIGHTER then
    GlobalLogger:create():debug(self.object:getName() .. " return back target not a factor")
    self.object:popFSM_NoCall()
    return
  end--]]
  
  --call elements
  self:callElements() 
end
