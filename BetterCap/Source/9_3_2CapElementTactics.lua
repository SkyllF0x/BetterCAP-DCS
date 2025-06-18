
----------------------------------------------------
---- interface for tactics
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----------------------------------------------------
FSM_Element_Tactic = utils.inheritFrom(FSM_Element_AbstractCombat)

function FSM_Element_Tactic:create(handledObject) 
  local instance = self:super():create(handledObject)
  
  --when last parameter update was made
  instance.updateTimeStamp = -math.huge
  instance.distance2Target = 0
  instance.distance2Mar = 0
  instance.aspect = 0
  
  --speed and alt during tactic
  instance.speed = 300 --0.9M good amound of enegry with reasonable fuel consumpsion
  instance.alt = 7500 --~25000ft
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_Tactic:compareAlrAndPreferred(capGroup, alrEnum, tacticEnum) 
  local score = 0
  if capGroup.alr == alrEnum then 
    score = score + 1
  end
  
  if utils.itemInTable(capGroup.preferableTactics, tacticEnum) then 
    score = score + 1
  end
  
  return score
  end


function FSM_Element_Tactic:getWeight(capGroup) 
  return 0
end

function FSM_Element_Tactic:isOtherElementInTrouble() 
  return self.object:getSecondElement() and 
    self.object:getSecondElement():getCurrentFSM() >= CapElement.FSM_Enum.FSM_Element_WVR
  end

function FSM_Element_Tactic:update() 
  --update if more than 1 sec elapsed
  local currentTime = math.floor(timer.getAbsTime() + 0.5) --round to int
  if currentTime == self.updateTimeStamp then 
    return
  end
  
  local range = math.huge
  --smallest ditance between plane and target
  for _, plane in pairs(self.object.planes) do
    
    for _, target in pairs(self:getTargetGroup():getTargets()) do 
      local range2Target = mist.utils.get3DDist(plane:getPoint(), target:getPoint())
      
      if range2Target < range then 
        range = range2Target
      end
    end
  end
  
  self.distance2Target = range
  --Use target alt for MAR calc
  self.distance2Mar = range - utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MAR
  self.aspect = self:getTargetGroup():getAA(self.object:getPoint())
  self:updateSpeedAlt()
  
  self.updateTimeStamp = currentTime
end

function FSM_Element_Tactic:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  elseif self.alt - targetAlt > 2000 then
    --we too high, set target alt, or 1000meters
    self.alt = math.max(targetAlt, 1000)
  elseif self.alt - targetAlt < -2000 then
    --we too low,  set target alt, or 10000 meters
    self.alt = math.min(10000, targetAlt)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--check if we can drop missile and turn cold
-- return true if: pitbull/no Missile/ missile trashed
-- false if any aircraft has missile to support
function FSM_Element_Tactic:checkOurMissiles() 
  for _, plane in pairs(self.object.planes) do 
    if not plane:canDropMissile() then 
      return false
      end 
    end
    return true
  end

--check if all element is defending against missiles
function FSM_Element_Tactic:inDefending() 
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      return false
      end
    end

  return true
end

--check if we to close to enemy
function FSM_Element_Tactic:inWVR() 
  return self.distance2Target < 15001
end

--check if all element is defending against missiles
--set state to FSM_Element_Defending and return true to indicate change
function FSM_Element_Tactic:isDefending() 
  if not self:inDefending() then 
    return false
  end
  --set proper Defend state
  if self.object.myGroup.alr == CapGroup.ALR.Normal then 
    self.object:setFSM(FSM_Element_Defending:create(self.object, self))
  else
    self.object:setFSM(FSM_Element_DefendingHigh:create(self.object, self))
  end
  return true
end
  

--check if we to close to enemy and should switch to WVR
function FSM_Element_Tactic:isWVR() 
  if not self:inWVR() then
    --we ok
    return false
  end
  
  self.object:setFSM(FSM_Element_WVR:create(self.object))
  return true
end

--return lowest distance from plane to target
function FSM_Element_Tactic:distanceToTarget() 
  return self.distance2Target
end

--distance to MAR of targetGroup highest threat, return negative if inside mar
function FSM_Element_Tactic:distanceToMar() 
  if self.object.myGroup.alr == CapGroup.ALR.Normal then
    return self.distance2Mar
  end

  return self.distance2Target
end

function FSM_Element_Tactic:getAA() 
  return self.aspect
  end

--check for starting executing of coldOps tactic(like notchBack, Bracket or smth)
--for now just place holder, will return to force attack
--should return true if state was changed
function FSM_Element_Tactic:checkColdOps() 
  return false
end

--checks can this element execute current tactic, if no set new state and return true
function FSM_Element_Tactic:checkCondition() 
  return false
  end

--All functions below will be called from respective fsm states, when they active
--they check if state should change and change it, replace top item it stack
--and return true, to indicate that, so previous state can early return
function FSM_Element_Tactic:checkCrank() 
  return false
end

function FSM_Element_Tactic:checkFlyParallel() 
 return false
end

function FSM_Element_Tactic:checkIntercept() 
  return false
  end

function FSM_Element_Tactic:checkAttack() 
  return false
end

function FSM_Element_Tactic:checkPump() 
  return false
end

--check for continue attack for different ALR
function FSM_Element_Tactic:checkAttackNormal() 
  return false
end

function FSM_Element_Tactic:checkAttackHigh() 
  return false
end

--should be replaced by callbacks above, depend on what alr used
function FSM_Element_Tactic:ALR_check() 
end


----------------------------------------------------
---- Mixin for with methods for skateOffset
----------------------------------------------------  

SkateOffsetChecks = {}
SkateOffsetChecks.aspectThreshold = {}
SkateOffsetChecks.aspectThreshold.intercept = 60 --above this aspect group go intercept
SkateOffsetChecks.aspectThreshold.crank = 30 --below this aspect group go crank

function SkateOffsetChecks:setupForOffset() 
  self.object.sideOfElement = nil
  
  --clear FSM, task will be set on each run()
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    
    --set all needed options
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    plane:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On)
    plane:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On)
    --attack range/ROE will set plane Attack states
    
    --set first task in stack(no call cause task will be changed after)
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
  --
  --go to flyParallel other magic will happen in states check
  self.object:setFSM(FSM_Element_FlyParallel:create(self.object, self))
end

--find where(left or right) we should crank and return side enum for crank
function SkateOffsetChecks:directionOfCrank() 
  if self.object.sideOfElement then 
    
    return self.object.sideOfElement
  elseif self.object:getSecondElement() and self.object:getSecondElement().sideOfElement then
    
    --use side of second element
    self.object.sideOfElement = self.object:getSecondElement().sideOfElement
    return self.object.sideOfElement
  end
  
  local leadTarget, ourPos = self:getTargetGroup():getLead(), self.object:getPoint()
  local aspect = leadTarget:getAA(ourPos)
  
  local targetTrackLine = {mist.vec.add(leadTarget:getPoint(), leadTarget:getVelocity()), leadTarget:getPoint()}
  if aspect < 90 then 
    targetTrackLine = {leadTarget:getPoint(), mist.vec.add(leadTarget:getPoint(), leadTarget:getVelocity())}
  end

  local side = utils.sideOfLine(targetTrackLine, ourPos)
  if side == 1 then 
    self.object.sideOfElement = FSM_Element_Crank.DIR.Right 
  else
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
  end

  return self.object.sideOfElement
end



--check if aspect below minimum for intercept state, if so return back to flyParallel
function SkateOffsetChecks:interceptAspectCheck() 
  local aspect = self:getAA()
  
  if aspect < self.aspectThreshold.intercept then
    --go fly parallel
    self.object:popFSM()
    return true
  end
  
  return false
end

--check if aspect above minimum for crank state, if so return back to flyParallel
function SkateOffsetChecks:crankAspectCheck() 
  local aspect = self:getAA()
  
  if aspect > self.aspectThreshold.crank then
    --go fly parallel
    self.object:popFSM()
    return true
  end
  
  return false
end

--check if aspect exceed limits for flyParallel and set correct state for correction
function SkateOffsetChecks:flyParallelAspectCheck() 
  local aspect = self:getAA()
  
  if aspect > self.aspectThreshold.intercept then
    --go intercept
    self.object:setFSM(FSM_Element_Intercept:create(self.object, self))
    return true
  elseif aspect < self.aspectThreshold.crank then
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 60, self:directionOfCrank()))--no alt, will use tactic alt
    return true
  end
  
  return false
end



----------------------------------------------------
---- Skate Wall, two elements without separation
---- used when missiles range ~equals
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----------------------------------------------------
FSM_Element_Skate = utils.inheritFrom(FSM_Element_Tactic)


function FSM_Element_Skate:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "Skate"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Skate
  instance.abortAttackAspect = 90 --if target aspect below that we turn cold at MAR
  
  --set proper callback for attack check
  if instance.object.myGroup.alr == CapGroup.ALR.Normal then 
    instance.ALR_check = self.checkAttackNormal
  else
    instance.ALR_check = self.checkAttackHigh
  end

  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_Skate:setup() 
  --clear FSM, task will be set on each run()
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    
    --set all needed options
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    plane:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On)
    plane:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On)
    --attack range/ROE will set plane Attack states
    
    --set first task in stack(no call cause task will be changed after)
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
  --go to intercept other magic will happen in states check
  self.object:setFSM(FSM_Element_Intercept:create(self.object, self))
end

--return true if we should go to attack state
function FSM_Element_Skate:inRangeForAttack() 
  local distance = self:distanceToTarget()
  
  local ourMaxRange = utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange
  return distance < ourMaxRange 
end

--check if should go attack and return true if state change happened
function FSM_Element_Skate:isAttack() 
  if not self:inRangeForAttack() then 
    return false
  end
  
  self.object:setFSM(FSM_Element_Attack:create(self.object, self))
  return true
end

--will be used also for weight calc
--switch to skateOffset when enemy has more than 5NM MaxRange advantage
--of 1.25 range(which is greater)
function FSM_Element_Skate:checkRequrements(targetRange, ourRange) 
  local ratio = targetRange/ourRange
  
  return ratio < 1.25 or ourRange + 10000 > targetRange
end

function FSM_Element_Skate:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.Skate) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " Skate Score: " .. tostring(score))
  return score 
end

function FSM_Element_Skate:checkCondition() 
  if not self:checkRequrements(self:getTargetGroup():getHighestThreat().MaxRange, 
    self.object:getBestMissile().MaxRange) then 
    
      GlobalLogger:create():debug(debug.getinfo(1).name .. " " .. tostring(debug.getinfo(1).linedefined) .. " checkCondition() true")
    --switch tactic
    self.object:setFSM(FSM_Element_SkateOffset:create(self.object))
    return true
  end
  
  return false
end


--will work only if have second element, if so:
---1)we far enough from MAR -> Grinder
---2)not far go Bracket
----selection of coldState start after 60 sec in defend state
function FSM_Element_Skate:checkColdOps() 
  
  if not self.object:getSecondElement() or self.object.FSM_stack:getCurrentState():getTimer() < 60 then 
    return false
  elseif not (self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Pump 
    or self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Defending) then   
    --second element ok
    return false
  end
  
  local distance2Mar = self:distanceToMar()
  if distance2Mar > 10000 then 
    --far enough, can go grinder
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    
    local secondElem = self.object:getSecondElement()
    secondElem:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(secondElem))
    return true
  end

  --too close go Delouse
  self.object:setFSM_NoCall(FSM_Element_Delouse:create(self.object))
  local secondElem = self.object:getSecondElement()
  secondElem:setFSM_NoCall(FSM_Element_Delouse:create(secondElem))
  return true
end

--go pump if we to close
function FSM_Element_Skate:interceptCheck() 
  self:update()
  
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return 
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack()
end


--return back if we in WVR, Defending or to far from target
--call respective check for ALR
function FSM_Element_Skate:checkAttack() 
  self:update()
  if self:inWVR() or self:inDefending() then 
    --should go to WVR or Defend, set Pump to stack, so when defending/WVR will pop
    --Pump will be called
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    return true
  elseif self:distanceToTarget() > utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange + 7500
    and not (self.object:getSecondElement() 
      and self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_WVR) then
      
    GlobalLogger:create():info("distance to great")
    --to far to attack, return to intercept
    self.object:popFSM()
    return true
  end
  
  if self:ALR_check() then 
    --delete attack
    self.object:popFSM_NoCall()
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return false
end


--we fly cold and should stop PUMP
---1)second element in troble and we ~5nm From Mar
---2)we far enough from target 
function FSM_Element_Skate:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() or self:checkColdOps() then 
    --we switched to WVR or Defend
    return true
  end
  
  local dist2Mar = self:distanceToMar()
  if dist2Mar > 18500 then 
    --we far enough
    self.object:popFSM()
    return true
  elseif self:isOtherElementInTrouble() and dist2Mar > 10000 then
    --element defending/WVR and dist2Mar > 5NM
    self.object:popFSM()
    return true
  end
  
  return false
end

--if close to MAR:
---1)missile support no needed -> Pump()
---2)support needed then continue only if targetAA > 90 else -> Pump()
function FSM_Element_Skate:checkAttackNormal() 
  if self:distanceToMar() > 0 then 
    return false
  elseif (not self:checkOurMissiles() and self:getAA() > self.abortAttackAspect) then
    return false
  end

  return true
end

--return back to intercept if:
--1) defending -> replace attack, with defending
--2) WVR -> replace attack with WVR

--3) if distance < MAR - > continue only if FOX1 or aspect > 90 or numerical advantage 2.5:1
--4) other go pump
function FSM_Element_Skate:checkAttackHigh() 
  if self:distanceToMar() < 0 --we inside MAR and target hot on us or we don't have enough numerical advantage
    and (#self.object.planes/self:getTargetGroup():getCount() < 2 and self:getAA() < self.abortAttackAspect) then
    return true 
  end
  
  --continue
  return false
end



----------------------------------------------------
---- Skate with single side offset, used when
---- little disadvantage in launch range 
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate           SkateOffsetChecks
----                  ↓                           ↓   
----        FSM_Element_SkateOffset<--------------
----------------------------------------------------

FSM_Element_SkateOffset = utils.inheritFromMany(FSM_Element_Skate, SkateOffsetChecks)

function FSM_Element_SkateOffset:create(handledElem) 
  local instance = FSM_Element_Skate:create(handledElem)--call parent explicitly
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Skate Offset"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateOffset
  
  --use setup from skateOffset
  instance.setup = self.setupForOffset
  return instance
end

--will be used also for weight calc
--ratio enemy MaxRange/ourRange > 1.5 or difference between ranges > 10 NM
function FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange) 
  local ratio = targetRange/ourRange
  
  return ratio < 1.5 or ourRange + 20000 > targetRange
end


function FSM_Element_SkateOffset:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange) then 
    return 0
  end
  
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateOffset) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateOffset Score: " .. tostring(score))
  return score 
end

function FSM_Element_SkateOffset:checkCondition() 
  if not self:checkRequrements(self:getTargetGroup():getHighestThreat().MaxRange, 
    self.object:getBestMissile().MaxRange) then 
    
    --switch tactic
    self.object:setFSM(FSM_Element_ShortSkate:create(self.object))
    return true
  end
  
  return false
end


function FSM_Element_SkateOffset:interceptCheck() 
  self:update()
  
  --No MAR check cause target cold to us
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:interceptAspectCheck()
end

function FSM_Element_SkateOffset:checkCrank() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:crankAspectCheck()
end

function FSM_Element_SkateOffset:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:flyParallelAspectCheck()
end


--interceptAscectCheck() same
--crankAspectCheck() same
--FlyParallelAspectCheck() same
--checkPump() same
--checkAttack() same
--checkAttackNormal() same
--checkAttackHigh() same
--checkColdOps() same

----------------------------------------------------
---- Short Skate with offset, mostly same 
---- with FSM_Element_SkateOffset but allow usage 
---- with more disadvantage in missile range or with higher
---- ALR, will go attack when distance < MaxRange * 0.75
---- or MAR + 5NM
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate           SkateOffsetChecks
----                  ↓                           ↓   
----        FSM_Element_SkateOffset<--------------
----                  ↓
----         FSM_Element_ShortSkate
----------------------------------------------------
FSM_Element_ShortSkate = utils.inheritFrom(FSM_Element_SkateOffset)

function FSM_Element_ShortSkate:create(handledElem)
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Short Skate"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_ShortSkate

  return instance
end

--other same

--try being lower then target atleast 3000, or 1000m, but not higher then 5000
function FSM_Element_ShortSkate:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  else
    self.alt = math.min(math.max(targetAlt - 3000, 1000), 5000)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--MAR + 5nm
function FSM_Element_ShortSkate:inRangeForAttack() 
  --use target alt for MAR calc
  local MarMargin = utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MAR + 10000
  local ourRange = utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange
  return self:distanceToTarget() < math.min(MarMargin, ourRange)
end


function FSM_Element_ShortSkate:getWeight(capGroup) 

  local score = 2 --ALR always match, no condition
  if utils.itemInTable(capGroup.preferableTactics, CapGroup.tactics.ShortSkate) then 
    score = score + 1
  end
  
  GlobalLogger:create():debug(capGroup:getName() .. " ShortSkate Score: " .. tostring(score))
  return score
end

--no op, this tactic always true
function FSM_Element_ShortSkate:checkCondition() 
  return false
end


----------------------------------------------------
---- Skate Grinder, two elements in trail ~20nm
---- used when missiles range ~equals
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----       FSM_Element_SkateGrinder
----------------------------------------------------

FSM_Element_SkateGrinder = utils.inheritFrom(FSM_Element_Skate)


function FSM_Element_SkateGrinder:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "SkateGrinder"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateGrinder
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--function FSM_Element_SkateGrinder:setup() inherited
--run() not used
--function FSM_Element_SkateGrinder:isAttack() inherited

--new
--return true if this element far enough
function FSM_Element_SkateGrinder:isGoodSeparation() 
  --just check distance between elements, it looks loke it works, but need more testing
  return mist.utils.get2DDist(self.object:getPoint(), self.object:getSecondElement():getPoint()) > 13000
  
  --[[ old version check is element behind other
  return mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getPoint())
          - mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getSecondElement():getPoint()) > 13000--]]
end
  
--return true if this element far enough and beyound other element
function FSM_Element_SkateGrinder:isBeyondOtherElem() 
  
  return mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getPoint())
          - mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getSecondElement():getPoint()) > 13000--]]
end

--check if we should start separating during intercept
--if second element Attack or Intercept
--and we not far enough
function FSM_Element_SkateGrinder:needSeparate() 
  return self.object:getSecondElement() 
    and (self.object:getSecondElement():getCurrentFSM() > CapElement.FSM_Enum.FSM_Element_Pump
      and self.object:getSecondElement():getCurrentFSM() < CapElement.FSM_Enum.FSM_Element_WVR)
    and not self:isGoodSeparation() 
end

--check if we should start separating during intercept and return true if state was changed
function FSM_Element_SkateGrinder:isSeparating() 
  if not self:needSeparate() then 
    return false
  end
  
  self.object:setFSM(FSM_Element_Pump:create(self.object, self, 300))
  return true
end

--return true if can use grinder
-- can use grinder when:
---1)has second element(planes > 1)
---2)if group have more than > 2 planes(so atleast one element will be 2 planes) 
---3)if our missile range > 40000m(or use grinder don't help we can't help eachother)
function FSM_Element_SkateGrinder:checkForGrinder(numberPlanes, ourRange)
  if numberPlanes == 1 then 
    --no second element, return
    return false
  end
  
  if numberPlanes > 2 then 
    --atleast 1 element will have 2 planes, can split even if no range
    return true
  end
  
  --2 planes split only if distance allow
  return ourRange > 40000
end

--overriden: if can't continue tactic go to shortSkate
--if can't go grinder go to skate
function FSM_Element_SkateGrinder:checkCondition() 
  local targetRange = self:getTargetGroup():getHighestThreat().MaxRange
  local ourRange = self.object:getBestMissile().MaxRange
  
  --check for tactic
  if not FSM_Element_Skate:checkRequrements(targetRange, ourRange) then 
    GlobalLogger:create():debug(self.object:getName() .. " can't continue Skate")
    
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    return true
  elseif not self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then
    GlobalLogger:create():debug(self.object:getName() .. " can't continue Skate Grinder")
    
    self.object:setFSM_NoCall(FSM_Element_Skate:create(self.object))
    return true
  end
  
  return false
end

--overriden: also check grinder
function FSM_Element_SkateGrinder:checkRequrements(targetRange, ourRange, numberPlanes) 
  --call explicitly base class, cause we can't use super
  return self:checkForGrinder(numberPlanes, ourRange) and FSM_Element_Skate:checkRequrements(targetRange, ourRange)
end

function FSM_Element_SkateGrinder:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange, capGroup.countPlanes) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateGrinder) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateGrinder Score: " .. tostring(score))
  return score 
end

--add separation check
function FSM_Element_SkateGrinder:interceptCheck() 
  self:update()

  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating()
end

--will work only if have second element
--if both element defending/Pump and distance2Mar < 0 both elements then go Bracket
function FSM_Element_SkateGrinder:checkColdOps() 
  
  if self.object.FSM_stack:getCurrentState():getTimer() < 60 then 
    return false
  end
  
  local otherElem = self.object:getSecondElement()
  if not (otherElem:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Defending
    or otherElem:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Pump) then 
    --other element ok
    return false
  end
  
  --check if second element inside MAR + 5nm
  local MAR = utils.missileForAlt(self:getTargetGroup():getHighestThreat(), otherElem:getPoint().y).MAR + 10000
  for _, plane in pairs(otherElem.planes) do 
    for __, target in pairs(self:getTargetGroup():getTargets()) do 
      
      if mist.utils.get3DDist(plane:getPoint(), target:getPoint()) < MAR then 
        --second elem inside MAR
        GlobalLogger:create():info(self.object:getName() .. " go Cold Ops")
        
        self.object:setFSM_NoCall(FSM_Element_Delouse:create(self.object))
        otherElem:setFSM_NoCall(FSM_Element_Delouse:create(otherElem))
        return true
        end
      end
    end
    return false
end


--we fly cold and should stop PUMP
---1)second element WVR to help him
---1.5)second element defending then turn hot if distance > MAR + 5nm
---2)we separated
function FSM_Element_SkateGrinder:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() or self:checkColdOps() then 
    --we switched to WVR or Defend
    return true
  end
  
  local rangeCond = self:distanceToMar() > 10000
  --2 elements scenaries:
  if rangeCond and (self:isOtherElementInTrouble() or self:isBeyondOtherElem()) then
    self.object:popFSM()
    return true
  end
  
  return false
end

--function FSM_Element_SkateGrinder:checkAttack() same
--function FSM_Element_SkateGrinder:checkAttackNormal() same
--function FSM_Element_SkateGrinder:checkAttackHigh() same


----------------------------------------------------
---- Skate Grinder with single side offset, used when
---- little disadvantage in launch range 
---- two elements in trail ~20nm
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----------------------------------------------------
FSM_Element_SkateOffsetGrinder = utils.inheritFromMany(FSM_Element_SkateGrinder, SkateOffsetChecks)

function FSM_Element_SkateOffsetGrinder:create(handledElem) 
  local instance = FSM_Element_SkateGrinder:create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "SkateGrinderOffset"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateOffsetGrinder
  
  --use setup from skateOffset
  instance.setup = self.setupForOffset
  return instance
end

--function FSM_Element_SkateOffsetGrinder:setup() same
--checkCondition() same
--run() same
--inRangeForAttack() same
--isGoodSeparation() same
--needSeparate() same
--isSeparating() same
--directionOfCrank() same
--interceptAspectCheck()  same
--crankAspectCheck()  same
--flyParallelAspectCheck()  same

--overriden, also will check missile range, we don't use grinder when our MaxRange < 25NM
--cause elements can't help eachother
function FSM_Element_SkateOffsetGrinder:checkRequrements(targetRange, ourRange, numberPlanes) 
  return self:checkForGrinder(numberPlanes, ourRange) and FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange)
end

function FSM_Element_SkateOffsetGrinder:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange, capGroup.countPlanes) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateOffsetGrinder) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateOffset Grinder Score: " .. tostring(score))
  return score 
end

--overriden: if can't continue tactic go to shortSkate
--if can't go grinder go to skateOfsset
function FSM_Element_SkateOffsetGrinder:checkCondition() 
  local targetRange = self:getTargetGroup():getHighestThreat().MaxRange
  local ourRange = self.object:getBestMissile().MaxRange
  
  --check for tactic
  if not FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange) then 
    GlobalLogger:create():debug(self.object:getName() .. " can't continue SkateOffset")
    
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    return true
  elseif not self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then
    GlobalLogger:create():debug(self.object:getName() .. " can't continue SkateOffset Grinder")
    
    self.object:setFSM_NoCall(FSM_Element_SkateOffset:create(self.object))
    return true
  end
  
  return false
end



--added separation Checks 
function FSM_Element_SkateOffsetGrinder:interceptCheck()
  self:update()
  
  --no MAR check, target cold
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:interceptAspectCheck()
end

function FSM_Element_SkateOffsetGrinder:checkCrank() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:crankAspectCheck()
end

function FSM_Element_SkateOffsetGrinder:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:flyParallelAspectCheck()
end


--checkPump() same
--checkColdOps() same
--checkAttack() same
--checkAttackNormal() same
--checkAttackHigh() same


----------------------------------------------------
---- Short Skate with offset, mostly same 
---- with FSM_Element_SkateOffsetGrinder but allow usage 
---- with more disadvantage in missile range or with higher
---- ALR, will go attack when distance < MaxRange * 0.75
---- or MAR + 5NM
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----     FSM_Element_ShortSkateGrinder
----------------------------------------------------
FSM_Element_ShortSkateGrinder = utils.inheritFrom(FSM_Element_SkateOffsetGrinder)

function FSM_Element_ShortSkateGrinder:create(handledElem)
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "ShortSkateGrinder"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder
  return instance
end

--other same
--function FSM_Element_ShortSkateGrinder:inRangeForAttack() SAME

--use same version as standart shortSkate(), yes this ugly i know
FSM_Element_ShortSkateGrinder.updateSpeedAlt = FSM_Element_ShortSkate.updateSpeedAlt

function FSM_Element_ShortSkateGrinder:getWeight(capGroup) 
  
  if not self:checkForGrinder(capGroup.countPlanes, capGroup:getBestMissile().MaxRange) then 
    return 0
  end

  local score = 1 --ALR always match
  if utils.itemInTable(capGroup.preferableTactics, CapGroup.tactics.ShortSkateGrinder) then 
    score = score + 1
  end
  
  GlobalLogger:create():debug(capGroup:getName() .. " ShortSkateGrinder Score: " .. tostring(score))
  return score
end

--this tactic only require MaxRange > 40000 and second element avail
--or will used WALL version
function FSM_Element_ShortSkateGrinder:checkCondition() 
  local ourRange = self.object:getBestMissile().MaxRange
  if self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then 
    return false
  end
  
  --switch tactic
  self.object:setFSM_NoCall(FSM_Element_ShortSkate:create(self.object))
  return true
end



----------------------------------------------------
---- Short Skate with bracket, crank to different
---- directions, of target leaning to element, continue crank
---- if inside enemy MAR*1.25 go reverse bracket(crank 120 from target)
---- other element
---- at that time intercept and go to merge
---- if second element merge(WVR) then go attack
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----------------------------------------------------
FSM_Element_Bracket = utils.inheritFrom(FSM_Element_SkateOffsetGrinder)

function FSM_Element_Bracket:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Bracket"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Bracket
  
  instance.abortAttackAspect = 60 --if target aspect below that we turn cold at MAR, override this to lower aspect
  instance.ALR_check = self.checkAttackHigh --always use high, cause we want press if have aspect/numericat advantage
  return instance
end


--no second element or not count advantage 2:1 when no missile range advantage 1.75
function FSM_Element_Bracket:checkRequrements(hasSecondElem, missileRatio, aircraftRatio) 
  
  return hasSecondElem and (missileRatio > 1.75 or aircraftRatio >= 2) 
end

function FSM_Element_Bracket:getWeight(capGroup) 
  local hasElem = capGroup.countPlanes > 1 --when sigleton there's no second element
  local ratio = capGroup:getBestMissile().MaxRange / capGroup.target:getHighestThreat().MaxRange
  local aircraftRatio = capGroup.countPlanes/capGroup.target:getCount()
  
  if not self:checkRequrements(hasElem, ratio, aircraftRatio) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.High, CapGroup.tactics.Bracket) 
  GlobalLogger:create():debug(capGroup:getName() .. " Bracket Score: " .. tostring(score))
  return score
end

--no second element or not count advantage 2:1 when no missile range advantage 1.75
function FSM_Element_Bracket:checkCondition() 
  local ratio = self.object:getBestMissile().MaxRange / self:getTargetGroup():getHighestThreat().MaxRange
  local aircraftRatio = self.object.myGroup.countPlanes/self:getTargetGroup():getCount()

  if not self:checkRequrements(self.object:getSecondElement(), ratio, aircraftRatio) then 
   
    GlobalLogger:create():info(self.object:getName() .. " bracket can't continue, weapon ratio: " .. tostring(ratio) 
      .. " aircraft ratio: " .. tostring(aircraftRatio))
    
    self.object:setFSM_NoCall(FSM_Element_SkateOffsetGrinder:create(self.object))
    return true
  end
  return false
end


--run() same
--inRangeForAttack() not same, go attack only if target cold to us
--or if second element engaged in WVR
function FSM_Element_Bracket:inRangeForAttack() 
  return (self:getAA() > 60 
    and self:distanceToTarget() < utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange)
    or self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_WVR
end


--isGoodSeparation()  no used

--nothing to do
function FSM_Element_Bracket:checkColdOps() 
  return false
end


--overrided, elements should have different sides
--find where(left or right) we should crank and return side enum for crank
--we should crank to opposite direction from our element
function FSM_Element_Bracket:directionOfCrank() 
  if self.object.sideOfElement then 
    --side known
    return self.object.sideOfElement
  elseif not self.object:getSecondElement() then
    
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
    return self.object.sideOfElement
  end
 
  local ourPos = self.object:getPoint()
  local line = {self.object:getSecondElement():getPoint(), self:getTargetGroup():getPoint()}
  
  if utils.sideOfLine(line, ourPos) == 1 then 
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
    return self.object.sideOfElement
  end
  
  self.object.sideOfElement = FSM_Element_Crank.DIR.Right 
  return self.object.sideOfElement
end


--isSeparating() not used
--needSeparate() not used

--interceptAspectCheck() same
--crankAspectCheck() same
--flyParallelAspectCheck() same

--overriden, no exit if other element in trouble
function FSM_Element_Bracket:checkAttack() 
  self:update()
  
  if self:inWVR() or self:inDefending() then 
    --should go to WVR or Defend, set Pump to stack, so when defending/WVR will pop
    --Pump will be called
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    return true
  elseif self:isOtherElementInTrouble() then
    return false
  elseif self:distanceToTarget() > utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange + 7500 then
      
    GlobalLogger:create():info("distance to great")
    --to far to attack, return to intercept
    self.object:popFSM()
    return true
  end
  
  if self:ALR_check() then 
    self.object:popFSM_NoCall()
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return false
end




--decorators for orinal methods, will early exit if other element defending/WVR
function FSM_Element_Bracket:checkAttackNormal() 
  --CALL base explicitly cause my inheritance suck)
  return not self:isOtherElementInTrouble() and FSM_Element_Skate.checkAttackNormal(self) 
end

function FSM_Element_Bracket:checkAttackHigh() 
  --CALL base explicitly cause my inheritance suck)
  return not self:isOtherElementInTrouble() and FSM_Element_Skate.checkAttackHigh(self) 
end

--override:
-- remove 1 element scenarios, cause this tactic only for 2 elements
---stop pump if :
--- 1)AA > aspect threshold for ALR check, or 10nm from MAR, or secondElement in trouble
function FSM_Element_Bracket:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() then 
    --we switched to WVR or Defend
    return true
  end
  
  if self:getAA() > self.abortAttackAspect + 10 or self:distanceToMar() > 10000 or self:isOtherElementInTrouble() then
    self.object:popFSM()
    return true
  end
  
  return false
end

--same as previous except no check for separation
function FSM_Element_Bracket:interceptCheck() 
  self:update()
  
  --no MAR check, target cold
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:interceptAspectCheck()
end

function FSM_Element_Bracket:checkCrank()
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:crankAspectCheck()
end

--same as base, but no check for separate
function FSM_Element_Bracket:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:flyParallelAspectCheck()
end



----------------------------------------------------
---- Bracket for cold Ops situations, same as normal
---- but with only 1 condition: should be a second
---- element
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----                  ↓
----         FSM_Element_Delouse
----------------------------------------------------
FSM_Element_Delouse = utils.inheritFrom(FSM_Element_Bracket)

function FSM_Element_Delouse:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Delouse"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Delouse
  return instance
end

function FSM_Element_Delouse:checkCondition() 
  if not self.object:getSecondElement() then 
   
    GlobalLogger:create():info(self.object:getName() .. " can't continue delouse, no second element")
    
    self.object:setFSM(FSM_Element_ShortSkate:create(self.object))
    return true
  end
  return false
end

----------------------------------------------------
---- Banzai tactic, go bracket until enemy max range
---- then go notch until enemy Mar+3NM, then spiked element
---- go reverse notch, not spiked attack
---- if both spiked then go Bracket tactic
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----                  ↓
----          FSM_Element_Banzai
----------------------------------------------------
FSM_Element_Banzai = utils.inheritFrom(FSM_Element_Bracket)

function FSM_Element_Banzai:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Banzai"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Banzai
  return instance
end

function FSM_Element_Banzai:getWeight(capGroup) 
  local hasElem = capGroup.countPlanes > 1 --when sigleton there's no second element
  local ratio = capGroup:getBestMissile().MaxRange / capGroup.target:getHighestThreat().MaxRange
  local aircraftRatio = capGroup.countPlanes/capGroup.target:getCount()
  
  if not self:checkRequrements(hasElem, ratio, aircraftRatio) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.High, CapGroup.tactics.Banzai) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " Banzai Score: " .. tostring(score))
  return score 
end

--just try stay below target atleast at 3000m
function FSM_Element_Banzai:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  else
    self.alt = math.max(targetAlt - 3000, 1000)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--run() same
--checkCondition() same
--checkRequrements() same
--inRangeForAttack() no used
--isGoodSeparation()  no used
--needSeparate() 
--directionOfCrank() 
--checkAttack() same
--interceptAspectCheck() same, no check for banzai, cause aspect good for attack
--flyParallelAspectCheck() same

--notch until aspect > 70 
--or distance to MAR < 3nm -> then if spiked go pump
-- else go attack
function FSM_Element_Banzai:notchCheck() 
  self:update()
  if self:isOtherElementInTrouble() 
    or self:getAA() > 30 then 
    --other element in trouble/aspect to great go hot
    self.object:popFSM()
    return true
  elseif self:distanceToMar() > 8000 then 
    --still to far
    return false
  end
  
  if self:getAA() < 60 then 
    --assume we spiked, go pump
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump)) --no alt, use tactic alt
    return true
    end
  
  --not spiked go attack
  self.object:popFSM()
end

--add additional check for aspect, if in range and target cold, go attack
--else go notch
function FSM_Element_Banzai:isAttack() 
  local distance = self:distanceToTarget()
  local aspect = self:getAA()
  
  if distance < utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MaxRange and aspect < 30 then 
    --go notch
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 90, self:directionOfCrank(), self.notchCheck))  --no alt
    return true
  elseif distance < utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange or self:isOtherElementInTrouble() then
    
    self.object:setFSM(FSM_Element_Attack:create(self.object, self))
    return true
  end
  
  return false
end



----------------------------------------------------
---- WVR state, planes will execute FSM_WVR,
---- will return back when no enemy aircraft within 20000m
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----           FSM_Element_WVR
----------------------------------------------------
FSM_Element_WVR = utils.inheritFrom(FSM_Element_Tactic)

function FSM_Element_WVR:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "Element WVR"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_WVR
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_WVR:setup() 
  for _, plane in pairs(self.object.planes) do 
    plane:setFSM(FSM_WVR:create(plane))
  end
end

function FSM_Element_WVR:teardown() 
  for _, plane in pairs(self.object.planes) do 
    plane:popFSM()
  end
end

function FSM_Element_WVR:run(arg) 
  self:update()
  if self:inWVR() then 
    --still in WVR 
    return
  end
  
  self.object:popFSM()
end