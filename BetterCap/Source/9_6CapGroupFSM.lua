------------------------------------------------
-- First state, wait until group take off
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupStart
----------------------------------------------------

FSM_GroupStart = utils.inheritFrom(AbstractState)

--arg does nothing
function FSM_GroupStart:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_GroupStart"
  instance.enumerator = CapGroup.FSM_Enum.FSM_GroupStart
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end


function FSM_GroupStart:setup() 
  --update point to skip first stpt
  self.object.route:checkWpChange(self.object:getPoint())
  
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM_NoCall(FSM_Element_Start:create(self.object.elements[1]))
  end--]]
--no teardown() 


function FSM_GroupStart:run(arg) 
  if not self.object:isAirborne() then
    --group still on ground
    return
  end
  
  GlobalLogger:create():debug(self.object:getName() .. " airborne, push to FlyRoute")
  self.object:setFSM(FSM_FlyRoute:create(self.object))
end




----------------------------------------------------
--- helper class, implement helpers for transition
--- checks
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----------------------------------------------------

FSM_GroupChecks = utils.inheritFrom(AbstractState)

function FSM_GroupChecks:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --minimum desired speed
  instance.targetSpeed = 0
  instance.burnerAllowed = false
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_GroupChecks:checkAttack(contacts) 
  local tgt = self.object:checkTargets(contacts)
  
  if not tgt.target then 
    return false
  end
  
  if tgt.range > tgt.commitRange then 
    GlobalLogger:create():debug(self.object:getName() .. " go commit on: " .. tgt.target:getName() .. " range: " 
      .. tostring(tgt.range) .. " CR: " .. tostring(tgt.commitRange))
    self.object:setFSM(FSM_Commit:create(self.object, tgt.target))
    return true
  end
  
  self.object:setFSM(FSM_Engaged:create(self.object, tgt.target))
  return true
end

function FSM_GroupChecks:setBurner(val) 
  --if value false, then return original values
  local command = nil
  if val then 
    command = utils.tasks.command.Burner_Use.On
  end
  
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, command)
  end
end

--if group flies to slow(commanded speed - actual > 50m/s(100kn))
-- then we allow usage of afterburner, and restrict it back when
-- speed is ~40kn from target speed
function FSM_GroupChecks:checkForBurner() 
  local deltaSpeed = self.targetSpeed - mist.vec.mag(self.object:getLead():getVelocity())
  
  if deltaSpeed < 20 and self.burnerAllowed then 
    self.burnerAllowed = false
    self:setBurner(false)
    GlobalLogger:create():debug(self.object:getName() .. " allow burner")
  elseif deltaSpeed > 50 and not self.burnerAllowed then 
    self.burnerAllowed = true
    self:setBurner(true)
    GlobalLogger:create():debug(self.object:getName() .. " restrict burner")
  end
end

function FSM_GroupChecks:setTargetSpeed(newSpeed) 
  self.targetSpeed = newSpeed or 0
end

--check for RTB/Attack and set correct state if so,
--return true if change state is occured
--also checks updateAutonomous
function FSM_GroupChecks:groupChecks(arg) 
  --firstly check for RTB
  if self.object:needRTB() then 
    --go RTB
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return true
  end
  
  if self:checkAttack(arg.contacts) then 
    return true
  end
  
  --check for autonomous
  self.object:updateAutonomous(arg.radars)
  --check for burner
  self:checkForBurner()
  return false
end

----------------------------------------------------
--- Rejoin state, first aircraft will orbit at current
--- position until all group is rejoined(this mean maxDist < 10000)
--- except Target detected or shouldRTB() returns true
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----              FSM_Rejoin
----------------------------------------------------

FSM_Rejoin = utils.inheritFrom(FSM_GroupChecks)

function FSM_Rejoin:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --no speed, DCS will set stallSpeed*1.5
  instance.task = { 
     id = 'Orbit', 
     params = { 
       pattern = "Circle",
       point = mist.utils.makeVec2(handledGroup:getPoint()),
       altitude = 6000,
       speed = 150
     } 
    }
  instance.name = "FSM_Rejoin"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Rejoin
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Rejoin:setup() 
  GlobalLogger:create():info(self.object:getName() .. " FSM_Rejoin:setup(), range to lead " .. tostring(self.object:getMaxDistanceToLead()))

  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyOrbit, self.task))
end

--no teardown()

--arg does nothing
function FSM_Rejoin:run(arg)
  --perform checks for transition
  if self:groupChecks(arg) then 
    return
  end
  
  --check for exit
  if self.object:getMaxDistanceToLead() > 20000 then 
    return
  end

  GlobalLogger:create():info(self.object:getName() .. " rejoin complete")
  --we close enough, return to prev state
  self.object:popFSM()
end



----------------------------------------------------
--- RTB state, when group just fly to home, 
--- and don't engage dua lack Ammo/Fuel, 
--- can transit to Deactivate if shouldDeactivate()
--- return true, mostly similar to FlyRoute
--- but no interrupt for attack of rejoin
--- Also prohibit use of afterburner
----------------------------------------------------
----             AbstractState
----                  ↓
----             FSM_GroupRTB
----------------------------------------------------
FSM_GroupRTB = utils.inheritFrom(AbstractState)

function FSM_GroupRTB:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --create task
  instance.waypoint = handledGroup.route:getHomeBase()
  instance.name = "FSM_GroupRTB"
  instance.enumerator = CapGroup.FSM_Enum.FSM_GroupRTB
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

function FSM_GroupRTB:setup() 
  self.object:setAutonomous(false)
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --prohibit AB using
  --allow infinite fuel, or can crash
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off)
    plane:getController():setCommand({ 
      id = 'SetUnlimitedFuel', 
      params = { 
        value = true 
      } 
    })
    end
  
  --if homeBase if airfield, fly as singletons, set FSM_PlaneRTB, if it just a point set FlyToPoint
  if self.object.route:hasAirfield() then 
    GlobalLogger:create():info(self.object:getName() .. " FSM_GroupRTB:setup(), RTB to airfield")

    self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_PlaneRTB, self.waypoint))
  else
    GlobalLogger:create():info(self.object:getName() .. " FSM_GroupRTB:setup(), RTB to WP")

    --create waypoint at wp position at altitude of 5000m, use standart fly in formation
    self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyToPoint, 
        mist.fixedWing.buildWP(self.waypoint, "turningpoint", 250, 5000, "BARO")))
  end
end

function FSM_GroupRTB:run(arg) 
  --no need to send argument
  
  --check for deactivate
  if not self.object:shouldDeactivate() then 
    return
  end
  
  self.object:setFSM(self.object.deactivateClass:create(self.object))
end

----------------------------------------------------
--- decorator for RTB for route version, will remove
--- planes from objective when start
----------------------------------------------------
----             AbstractState
----                  ↓
----             FSM_GroupRTB
----                  ↓
----           FSM_GroupRTB_Route
----------------------------------------------------

FSM_GroupRTB_Route = utils.inheritFrom(FSM_GroupRTB)

function FSM_GroupRTB_Route:setup() 
  --i think it's safe cause no transitions except to deativate so setup() will be called only once
  self.object.objective:addCapPlanes(-self.object:getOriginalSize())
  
  self:super().setup(self)
end

----------------------------------------------------
-- Flying route state, few transitions here:
-- 1) if shouldRTB() return true or when group very close to homeBase(distance < 20km) -> FSM_RTB
-- 2) if target detected within commitRange -> FSM_Engage
-- 3) if valid target detected withou commitRange -> FSM_Commit(just move towards target without executing combat tactics)
-- 4) if approach to PatrolZone -> FSM_PatrolZone
-- 5) if distance between planes > 20000 -> FSM_Rejoin
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----             FSM_FlyRoute
----------------------------------------------------

FSM_FlyRoute = utils.inheritFrom(FSM_GroupChecks) 

function FSM_FlyRoute:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_FlyRoute"
  instance.enumerator = CapGroup.FSM_Enum.FSM_FlyRoute
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


--check if we close enough to deactivate point and we fly toward it
--return true if so
function FSM_FlyRoute:checkBaseProximity() 
  return self.object.route:isReachEnd() and mist.utils.get2DDist(self.object:getPoint(), self.object.route:getHomeBase()) < 20000
end


function FSM_FlyRoute:setNextWP() 
  if self.object.route:isReachEnd() then 
    --we fly toward home, create WP at airfield position, but type of 'Turning point'
    self.object.elements[1]:setFSM_Arg("waypoint", mist.fixedWing.buildWP(self.object.route:getHomeBase(), "turningpoint", 200, 8000, "BARO"))
    
    --update target speed
    self:setTargetSpeed(200)
    GlobalLogger:create():drawPoint({point = self.object.route:getHomeBase(), text = self.object:getName() .. " Home Point"})
    return
  end
 
  --we just fly toward wp, set it
  self.object.elements[1]:setFSM_Arg("waypoint", self.object.route:getCurrentWaypoint())
  
  --update target speed
  self:setTargetSpeed(self.object.route:getCurrentWaypoint().speed)
  GlobalLogger:create():drawPoint({point = self.object.route:getCurrentWaypoint(), text = self.object:getName() .. " Next WP"})
end

function FSM_FlyRoute:setup()
  if self:checkPatrolZone() then 
    --prevent RTB when route very compact(i.e. hold placed right over airfield)
    return
  end
  
  --prepare elements
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --check we should change WP
  self.object.route:checkWpChange(self.object:getPoint())
  
  --if we fly toward home, but to far from it
  --we need to remove type = "Land", so checkTask not be broken
  --not set RTB here, cause we can't interrupt it for attack
  --even if fuel/ammo allows, also when plane execute
  --treir landing behaviour, Follow task don't work correctly
  --even if target plane flying straight
  if self.object.route:isReachEnd() then 
    --we fly toward home, create WP at airfield position, but type of 'Turning point'
    self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(
        self.object.elements[1], FSM_FlyToPoint, mist.fixedWing.buildWP(self.object.route:getHomeBase(), "turningpoint", 200, 8000, "BARO")))
    
    self:setTargetSpeed(200)
    
    GlobalLogger:create():info(self.object:getName() .. " FSM_FlyRoute:setup(), fly toward home")
    return
  end
  
  --we just fly toward wp, set it
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyToPoint, self.object.route:getCurrentWaypoint()))
  --update target speed
  self:setTargetSpeed(self.object.route:getCurrentWaypoint().speed)
end


 --check approach for any of patrols zones for current WP, and if so 
 --transit to FSM_PatrolZone and return true
function FSM_FlyRoute:checkPatrolZone() 
  local zones = self.object.patrolZones[self.object.route:getWaypointNumber()]
  if not zones then 
    return false
  end
  
  for _, zone in pairs(zones) do 
    
    if mist.utils.get2DDist(self.object:getPoint(), zone:getPoint()) < 15000 
      and zone:checkPreCondition() then 
      self.object:setFSM(FSM_PatrolZone:create(self.object, zone))
      return true
    end
  end
  
  return false
end

function FSM_FlyRoute:run(arg) 
  --Attack and RTB
  if self:groupChecks(arg) then 
    return
  end
  
  --to Rejoin
  if self.object:getMaxDistanceToLead() > 20000 then 
    --go to FSM_Rejoin
    self.object:setFSM(FSM_Rejoin:create(self.object))
    return
  end
  
  --transition to FSM_PatrolZone
  if self:checkPatrolZone() then 
    return
  end
  
  if self:checkBaseProximity() then 
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  elseif self.object.route:checkWpChange(self.object:getPoint()) then
    --time to change wp
    self:setNextWP()
  end
end
----------------------------------------------------
-- Deactivate state, delete all planes
----------------------------------------------------
----            AbstractState
----                  ↓
----            FSM_Deactivate
----------------------------------------------------

FSM_Deactivate = utils.inheritFrom(AbstractState)

function FSM_Deactivate:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_Deactivate"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Deactivate
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Deactivate:run(arg) 
  --delete all aircraft
  for _, plane in self.object:planes() do 
    plane:getObject():destroy()
  end
  
  --wipe elements
  self.object.elements = {}

  GlobalLogger:create():info(self.object:getName() .. " FSM_Deactivate:run() deactivate group")
  end

----------------------------------------------------
-- Deactivate state, for route version, also remove
-- remaining airplanes to squadron
----------------------------------------------------
----            AbstractState
----                  ↓
----           FSM_Deactivate
----                  ↓
----          FSM_Deactivate_Route
----------------------------------------------------

FSM_Deactivate_Route = utils.inheritFrom(FSM_Deactivate)

function FSM_Deactivate_Route:setup() 
  --return remaining aircraft to squadron
  GlobalLogger:create():info(self.object:getName() .. " FSM_Deactivate_Route:setup(), return planes: " .. tostring(self.object.countPlanes))
  self.object.sqn:returnAircrafts(self.object.countPlanes)
end

----------------------------------------------------
-- Commit, group move to intercept, but at lower speed
-- to save fuel and maintaining formation, at commitRange
-- will switch to Engage and start execute combat tactics
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----              FSM_Commit
----------------------------------------------------

FSM_Commit = utils.inheritFrom(FSM_GroupChecks)

function FSM_Commit:create(handledGroup, target) 
  local instance = self:super():create(handledGroup)
  
  --update target
  instance.object.target = target
  --Dont't set targeted, so it can be attacked by other groups
  --will set flag in FSM_engage
  --self.object.target:setTargeted(true)
  
  instance.name = "FSM_Commit"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Commit
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Commit:setup() 

  if not (self.object.target and self.object.target:isExist()) then 
    GlobalLogger:create():info(self.object:getName() .. " FSM_Commit:setup() no target")

    --no target, continue unwind
    self.object:popFSM()
    return
  end
  
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --set autonomous so radar will be enabled
  self.object:setAutonomous(true)
  
  --take lead target, speed during this state will be 290 this is ~0.85M
  self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_FlyToPoint, 
    self:getInterceptWaypoint(290)))

  --set new Target Speed(it's always same for this state)
  self:setTargetSpeed(290)
  end
  
function FSM_Commit:teardown() 
  self.object.target = nil
  end
  

function FSM_Commit:getInterceptWaypoint(speed) 
  local p = utils.getInterceptPoint(self.object.target:getLead(), self.object:getLead(), speed)
  return mist.fixedWing.buildWP(p, "turningpoint", speed, self.object.target:getPoint().y, "BARO")
end

--return true if state switch occured
function FSM_Commit:checkTargetStatus(contacts) 
  --check if target still avail
  local tgt = self.object:checkTargets(contacts)
  
  if not tgt.target then 
    --no target for commit
    self.object:popFSM()
    return true
  elseif tgt.target ~= self.object.target then 
    --update target
    self.object.target = tgt.target
  end
  
  --check for transition to Engaged
  if tgt.range < tgt.commitRange then 
      
    self.object:setFSM(FSM_Engaged:create(self.object, tgt.target))  
    return true
  end 
  return false
end
  
function FSM_Commit:run(arg) 
  --check for RTB
  if self.object:needRTB() then 
    self:teardown()--delete target
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  end
  
  if self:checkTargetStatus(arg.contacts) then 
    return
  end
  
  --update point for first plane
  self.object.elements[1]:setFSM_Arg("waypoint", self:getInterceptWaypoint(290))
end
----------------------------------------------------
-- Engage state, elements execute their combat tactics
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----             FSM_Engaged
----------------------------------------------------

FSM_Engaged = utils.inheritFrom(FSM_GroupChecks)
FSM_Engaged.tactics = {}
FSM_Engaged.tactics[CapGroup.tactics.Skate] = FSM_Element_Skate
FSM_Engaged.tactics[CapGroup.tactics.SkateGrinder] = FSM_Element_SkateGrinder
FSM_Engaged.tactics[CapGroup.tactics.SkateOffset] = FSM_Element_SkateOffset
FSM_Engaged.tactics[CapGroup.tactics.SkateOffsetGrinder] = FSM_Element_SkateOffsetGrinder
FSM_Engaged.tactics[CapGroup.tactics.ShortSkate] = FSM_Element_ShortSkate
FSM_Engaged.tactics[CapGroup.tactics.ShortSkateGrinder] = FSM_Element_ShortSkateGrinder
FSM_Engaged.tactics[CapGroup.tactics.Bracket] = FSM_Element_Bracket
FSM_Engaged.tactics[CapGroup.tactics.Banzai] = FSM_Element_Banzai


function FSM_Engaged:create(handledGroup, target) 
  local instance = self:super():create(handledGroup)

  target:setTargeted(true)
  handledGroup.target = target
  instance.name = "FSM_Engaged"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Engaged
  instance.tactic = nil
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Engaged:selectTactic() 
  local counter, tblWithWeights = 0, {}
  
  for enum, tactic in pairs(self.tactics) do 
    local w = tactic:getWeight(self.object)
    tblWithWeights[enum] = w
    counter = counter + w
  end
  
  local stepSize = 100/counter
  local prevRange = 0
  local randomChoice = mist.random(100)
  
  for enum, weight in pairs(tblWithWeights) do 
    local newRange = prevRange + stepSize*weight
    if prevRange <= randomChoice and randomChoice <= newRange then 

      return self.tactics[enum]
    end
    prevRange = newRange
  end
end

function FSM_Engaged:setup() 
  self.object:splitElement()
  --set autonomous so radar will be enabled
  self.object:setAutonomous(true)
  
  self.tactic = self:selectTactic()

  for _, elem in pairs(self.object.elements) do 
    elem:clearFSM()
    elem:setFSM(self.tactic:create(elem))
  end
end


function FSM_Engaged:teardown() 
  if not self.object.target then
    return
  end
  self.object.target:setTargeted(false)
  self.object.target = nil
  
  --clear element side
  for _, elem in pairs(self.object.elements) do 
    elem.sideOfElement = nil
  end
end

--if we reach RTB ammo or ~0.1 away from bingo go pump
--splitElement if no second elem
--if no target go back
function FSM_Engaged:run(arg) 
  if self.object.ammoState <= self.object.rtbWhen or self.object:getFuel() < (self.object.bingoFuel + 0.1) then 
    self.object:popFSM_NoCall()
    self.object:setFSM(FSM_Pump:create(self.object))
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, need RTB")
    return
    
  elseif not self.object.target:isExist() then
    --target dead, return
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, target dead")
    self.object:popFSM()
    return
  end
  
  self.object:splitElement()
  
  local tgt = self.object:checkTargets(arg.contacts)
  if not tgt.target then 
    --no target for commit
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, no more targets")
    self.object:popFSM()
    return
  
  elseif tgt.target == self.object.target then
    --return to prev state if range more then CommitRange + 10nm
    
    local commitRange = tgt.commitRange
    if commitRange + 18500 < tgt.range then
      
      GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: drop target, range: " .. tostring(tgt.range) .. " cr: " .. tostring(commitRange))
      self.object:popFSM()
      return
    end
  
  else
    local ourTgt = self.object.target
    local typeModifier = self.object.priorityForTypes[ourTgt:getTypeModifier()]
    local ourTargetPriority = self.object:getTargetPriority(ourTgt, ourTgt:getCount(), typeModifier, 1, 
        mist.utils.get2DDist(self.object:getPoint(), ourTgt:getPoint()), ourTgt:getAA(self.object:getPoint()))
    
    if tgt.priority/ourTargetPriority >= 1.1 then

      GlobalLogger:create():debug(self.object:getName() .. " FSM_Engaged: set new target for group: " .. tgt.target:getName())
      --update target
      self.object.target:setTargeted(false)
      tgt.target:setTargeted(true)
      self.object.target = tgt.target
    end
  end

  self:checkForSplit(arg.contacts)
  self:checkForRejoin(arg.contacts)
end

--check if any other groups to close to second element
--split group if so

function FSM_Engaged:checkForSplit(targets) 
  
  local element = self.object.elements[2]
  if not element or element:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then 
    --element dead or already splitted
    return
  end
  
  local closestTarget = self:findClosestTarget(targets) 
  if not (closestTarget.target and closestTarget.target ~= self.object.target) then 
    return
  end
  GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: Split elements")

  --split group, first element continue attack original target
  --no range check, should pop manually
  self.object.elements[1]:setFSM(FSM_Element_GroupEmul:create(self.object.elements[1], self.object.target, true))
  
  --second element goes on his own target
  self.object.elements[2]:setFSM(FSM_Element_GroupEmul:create(self.object.elements[2], closestTarget.target, false))
end



--target inside max(15NM, Min(MaxRANGE/MAR+7500)) get closest from this
--added 08.01.24: skip all target groups except fighters
function FSM_Engaged:findClosestTarget(targets) 
  local element = self.object.elements[2]
  local elemPos, elemRange = element:getPoint(), element:getBestMissile().MaxRange
  local lowestRangeTarget = {target = nil, range = math.huge}
  for _, target in pairs(targets) do 
    
    local range = mist.utils.get2DDist(target:getPoint(), elemPos)
    if range < math.max(27000, math.min(elemRange, target:getHighestThreat().MAR + 7500)) 
      and range < lowestRangeTarget.range 
      and target:getTypeModifier() == AbstractTarget.TypeModifier.FIGHTER then 
      
      lowestRangeTarget = {target = target, range = range}
    end
  end
  
  return lowestRangeTarget
end

function FSM_Engaged:checkForRejoin(targets) 
  if self.object.elements[1]:getCurrentFSM() ~= CapElement.FSM_Enum.FSM_Element_GroupEmul then 
    --elements not splitted
    return
    end
  
  --other element dead or return from split state, when first element also return to normal tactics
  local element = self.object.elements[2]
  if element and element:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then
    --element still in state update target    
    local closestTarget = self:findClosestTarget(targets).target
    self.object.elements[2]:setFSM_Arg('newTarget', closestTarget)
    return
  end
  
  GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: rejoin elements")
  self.object.elements[1]:popFSM_NoCall()
end

----------------------------------------------------
-- Group flying at max speed toward home base, 
-- trying to increate distance, called from engage
-- when NoAmmo/fuel approach bingo to break contact
-- if fuel below Bingo -> RTB
-- or no targets inside commit range or 20km from home base
----------------------------------------------------
----             AbstractState
----                  ↓
----               FSM_Pump 
----------------------------------------------------

FSM_Pump = utils.inheritFrom(AbstractState)

function FSM_Pump:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_Pump"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Pump
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Pump:setup() 
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --allow usage of afterburner
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    --set infinite fuel
    plane:getController():setCommand({ 
      id = 'SetUnlimitedFuel', 
      params = { 
        value = true 
      } 
    })
  end
  
  --convert to vec2 or it will use speed/alt from point
  local wp = mist.fixedWing.buildWP(mist.utils.makeVec2(self.object.route:getHomeBase()), "turningpoint", 500, 7000, "BARO")
  self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_FlyToPoint, wp))

  GlobalLogger:create():info(self.object:getName() .. " FSM_Pump:setup() done")
end
  
function FSM_Pump:teardown() 
  --restrict use of burner
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, nil)
  end
end
  
function FSM_Pump:run(arg) 

  local selfPos = self.object:getPoint()
  local hasTarget = false
  for _, contact in pairs(arg.contacts) do 
    if mist.utils.get2DDist(contact:getPoint(), selfPos) < self.object.commitRange then 
      hasTarget = true
      break
    end
  end
  
  if not hasTarget 
    or mist.utils.get2DDist(self.object:getPoint(), self.object.route:getHomeBase()) < 20000
    or self.object:getFuel() < self.object.bingoFuel then 
      
    --no targets nearby, or we close to home, or fuel low
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  end
end

----------------------------------------------------
-- Group flying in patrol zone, until 
--  1)postCondition() return true -> return back
--  2)groupChecks -> go respective state
--  3)distance > 20000 go rejoin
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----            FSM_PatrolZone 
----------------------------------------------------
FSM_PatrolZone = utils.inheritFrom(FSM_GroupChecks)

function FSM_PatrolZone:create(handledGroup, zone) 
  local instance = self:super():create(handledGroup)

  instance.zone = zone
  instance.name = "FSM_PatrolZone"
  instance.enumerator = CapGroup.FSM_Enum.FSM_PatrolZone
  --start exist conditons
  for _, cond in pairs(instance.zone.postConditions) do 
    cond:start()
    end
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_PatrolZone:setup() 
  GlobalLogger:create():info(self.object:getName() .. " FSM_PatrolZone:setup()")

  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyOrbit, self.zone:getTask()))
  --update speed
  self:setTargetSpeed(self.zone:getTask().params.speed or 0)
end

function FSM_PatrolZone:run(arg)

  if self:groupChecks(arg) then 
    return
  elseif self.zone:checkExitCondition() then 
    GlobalLogger:create():info(self.zone:getName() .. " Exit")
    self.object:removePatrolZone(self.zone)
    self.object:popFSM()
    return
  end
  
  if self.object:getMaxDistanceToLead() > 20000 then 
    --go to FSM_Rejoin
    self.object:setFSM(FSM_Rejoin:create(self.object))
    return
  end
end
