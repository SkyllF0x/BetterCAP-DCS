----------------------------------------------------
-- Route for CapGroup as array of points
----------------------------------------------------  
GroupRoute = {}

--groupR is points from group task(mist.getGroupPoints)
function GroupRoute:create(groupR) 
  local instance = {}
  
  instance.waypoints = groupR or {
    {x = 0,
     y = 0,
     alt = 0,
     type = "Turning Point",
     action = "Turning Point",
     speed = 200
      }
    }--just stp
  instance.currentWpNumber = 1
  
  --find home point: or first WP with type 'Landing' from end
  --if no Landing point then first point of route
  instance.homeBase = nil
  instance.airbaseFinded = false
  for i = #instance.waypoints, 1, -1 do 
    if instance.waypoints[i].airdromeId then
      --find airfield, check if it still avail
      local airfield = AirbaseWrapper:create(instance.waypoints[i].airdromeId) 
      
      if airfield and airfield:isAvail() then 
        instance.homeBase = mist.utils.deepCopy(instance.waypoints[i])
        instance.airbaseFinded = true
        break
      end
    end
    
    if instance.waypoints[i].helipadId then 
      --find carrier
      local carrier = CarrierWrapper:create(instance.waypoints[i].helipadId)
      
      if carrier and carrier:isAvail() then 
        instance.homeBase = mist.utils.deepCopy(instance.waypoints[i])
        instance.airbaseFinded = true
        break
      end
    end
  end
  --if we have airbase, set type of wp to landing
  if instance.airbaseFinded then 
    instance.homeBase.type = "Land"
    instance.homeBase.action = "Landing"
  end
  
  return setmetatable(instance, {__index = self})
end

function GroupRoute:getWaypoint(wpNbr) 
  return self.waypoints[wpNbr]
  end

function GroupRoute:getWaypointNumber() 
  return self.currentWpNumber
end

--return true if group fly toward home, or past last WP
function GroupRoute:isReachEnd() 
  if self:getCurrentWaypoint().type == "Land" or self.currentWpNumber > #self.waypoints then 
    return true
  end
  return false
end

--return currentWaypoint, if reach end of Route(self.currentWpNumber > number of waypoints)
--should return homeBase
function GroupRoute:getCurrentWaypoint() 
  if self.currentWpNumber > #self.waypoints then 
    return self:getHomeBase()
  end
  return self.waypoints[self.currentWpNumber]
end


function GroupRoute:setHomePoint(point) 
  --reset flag, cause it point, not airfield
  self.airbaseFinded = false
  self.homeBase = mist.fixedWing.buildWP(point, "turningpoint", 200)
  end

function GroupRoute:getHomeBase() 
  return self.homeBase or self.waypoints[1] or mist.fixedWing.buildWP({x = 0, y = 0})
  end

function GroupRoute:hasAirfield() 
  return self.airbaseFinded
end

--return distance from current LEG
function GroupRoute:distanceToLeg(point)
  if #self.waypoints < 2 then 
    --to close
    return 0
  end
  
  local w2 = self.waypoints[self.currentWpNumber+1] or self.waypoints[1]
  
  return utils.distance2Line({self.waypoints[self.currentWpNumber], w2}, point) 
end

--CapGroup pass current position and if it close then 7.5km to WP it return true indicae new WP avail
function GroupRoute:checkWpChange(point) 
  local currentWP = self.waypoints[self.currentWpNumber] or self.waypoints[1]
  
  if mist.utils.get2DDist(currentWP, point) < 7500 then 
    self.currentWpNumber = self.currentWpNumber + 1
    return true
  end
  return false
end

----------------------------------------------------
-- end of GroupRoute
----------------------------------------------------  

----------------------------------------------------
-- Abstract Wrapper for different trigger condition
----------------------------------------------------
AbstractWpCondition = {}

function AbstractWpCondition:start() 
  
  end

function AbstractWpCondition:getResult() 
  
  end

----------------------------------------------------
-- Time condition, return true when mission time more 
-- then specified
----------------------------------------------------

TimeCondition = utils.inheritFrom(AbstractWpCondition)

function TimeCondition:create(targetTime)
  local instance = {}
  instance.time = targetTime
  
  return setmetatable(instance, {__index = self})
end


function TimeCondition:getResult() 
  return timer.getAbsTime() > self.time
end

----------------------------------------------------
-- duration condition, return true when passed specified time
----------------------------------------------------

DurationCondition = utils.inheritFrom(AbstractWpCondition)

function DurationCondition:create(duration) 
  local instance = {}
  instance.duration = duration
  instance.startTime = 0
  return setmetatable(instance, {__index = self})
end
  
function DurationCondition:start() 
  
  self.startTime = timer.getAbsTime()
  end
  
function DurationCondition:getResult() 
  return timer.getAbsTime() - self.startTime > self.duration
end

----------------------------------------------------
-- flag condition, return true when flag value equals
-- Only bool values supported
----------------------------------------------------

FlagCondition = utils.inheritFrom(AbstractWpCondition)

function FlagCondition:create(flag, val) 
  local instance = {}
  instance.flag = flag
  instance.val = val
  return setmetatable(instance, {__index = self})
  end

function FlagCondition:getResult() 
  return (trigger.misc.getUserFlag(self.flag) ~= 0) == self.val
end

----------------------------------------------------
-- lua condition, return true when code evaluate to true
----------------------------------------------------

LuaCondition = utils.inheritFrom(AbstractWpCondition)

--YOUR CODE ADDED IS BOOL, ADDED AFTER RETURN keyword
function LuaCondition:create(luaCode) 
  local instance = {}
  
  local func, err = loadstring(luaCode)
  if err then 
    trigger.action.outText("WARNING: Error in LUA condition for Orbit task in Group\n error: " .. err)
    env.warning("WARNING: Error in LUA condition for Orbit task in Group\n error: " .. err)
    return nil
  end
  instance.func = func
  return setmetatable(instance, {__index = self})
end

function LuaCondition:getResult() 
  return self.func()
end

----------------------------------------------------
-- random condition on probability in precentage
----------------------------------------------------
RandomCondition = utils.inheritFrom(AbstractWpCondition)

function RandomCondition:create(percentage) 
  local instance = {}
  
  instance.result = percentage > mist.random(100)
  return setmetatable(instance, {__index = self})
end

function RandomCondition:getResult() 
  return self.result
end


----------------------------------------------------
-- small helper for creation conditions
----------------------------------------------------
ConditionFactory = {}
ConditionFactory.conditions = {
  ['time'] = TimeCondition,
  ['condition'] = LuaCondition,
  ['duration'] = DurationCondition,
  ['probability'] = RandomCondition,
  }

--arg is array 'condition ' or 'stopCondition' from ControlledTask.params
function ConditionFactory:getConditions(condionsList) 
  if not condionsList then 
    return {}
    end
  
  local result = {}
  
  for name, val in pairs(condionsList) do 
    --if it flag condition it can have userFlagValue
    if name == "userFlag" then 
      if condionsList["userFlagValue"] then 
        result[#result+1] = FlagCondition:create(val, condionsList["userFlagValue"])
      else
        result[#result+1] = FlagCondition:create(val, false)
      end
    else
      result[#result+1] = ConditionFactory.conditions[name]:create(val)
    end
  end
  
  return result
end

----------------------------------------------------
-- Represent Orbit task for CapGroup with pre and post conditions
----------------------------------------------------  
----          AbstractCAP_Handler_Object
----                  ↓                           
----              OrbitTask
----------------------------------------------------

OrbitTask = utils.inheritFrom(AbstractCAP_Handler_Object)

function OrbitTask:create(point, speed, alt, preConditions, postConditions) 
  local instance = {}
  instance.id = utils.getGeneralID()
  instance.name = "Zone-" .. tostring(instance.id)
  instance.point = mist.utils.makeVec3(point)
  
  --this zone will be active if any of this conditions will be true
  instance.preConditions = preConditions or {}
  --this zone will be stopped if any of this return true
  instance.postConditions = postConditions or {}
  
  instance.task = { 
     id = 'Orbit', 
     params = { 
       pattern = "Circle",
       altitudeEdited = true,
       point = mist.utils.makeVec2(point),
       speed = speed,
       altitude = alt or 2000
     } 
    }
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

function OrbitTask:getTask() 
  return self.task
end

--position of task
function OrbitTask:getPoint() 
  return self.point
end

function OrbitTask:checkPreCondition() 
  --if no conditions supplied, always return true
  --so zone always triggered
  if #self.preConditions == 0 then 
    return true
  end

  for _, condition in pairs(self.preConditions) do 
    if condition:getResult() then
      return true
      end
    end
    return false
  end
  
function OrbitTask:checkExitCondition() 
  --if no conditions supplied, always return false
  --so zone never exit

  for _, condition in pairs(self.postConditions) do 
    if condition:getResult() then
      return true
      end
    end
    return false
  end

----------------------------------------------------
-- Represent RaceTrack task for CapGroup with pre and post conditions
----------------------------------------------------  
----          AbstractCAP_Handler_Object
----                  ↓                           
----              OrbitTask
----                  ↓                           
----            RaceTrackTask
----------------------------------------------------

RaceTrackTask = utils.inheritFrom(OrbitTask)

function RaceTrackTask:create(point1, point2,  speed, alt, preConditions, postConditions) 
  local instance = self:super():create(point1, speed, alt, preConditions, postConditions)
  
  --to make it RaceTrack change type and add second point
  instance.task.params.pattern = "Race-Track"
  instance.task.params.point2 = mist.utils.makeVec2(point2)
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


----------------------------------------------------
-- Single fighter group
----------------------------------------------------  
----          AbstractCAP_Handler_Object  FighterEntity_FSM
----                  ↓                           ↓
----              CapGroup <----------------------
----------------------------------------------------

CapGroup = utils.inheritFromMany(AbstractCAP_Handler_Object, FighterEntity_FSM)
CapGroup.DeactivateWhen = {}
CapGroup.DeactivateWhen.InAir = 1
CapGroup.DeactivateWhen.OnLand = 2
CapGroup.DeactivateWhen.OnShutdown = 3

CapGroup.RTBWhen = {}
CapGroup.RTBWhen.NoAmmo = 1
CapGroup.RTBWhen.IROnly = 2
CapGroup.RTBWhen.NoARH = 3

CapGroup.AmmoState = {}
--just indicate most valuable ammo(it can be 1 ARH and nothing more)
CapGroup.AmmoState.NoAmmo = 1
CapGroup.AmmoState.IrOnly = 2
CapGroup.AmmoState.SARH = 3
CapGroup.AmmoState.ARH = 4

--acceptable level of risk
CapGroup.ALR = {}
--standart, skate tactics, press into MAR only if Fox1 environment
--and targetGroup cold to fighter
CapGroup.ALR.Normal = 1 
--will prefer Banzai/Bracket, press into MAR if Fox1 or target cold to fighter
-- or numerical advantage 2:1
CapGroup.ALR.High = 2 

CapGroup.FSM_Enum = {
  FSM_GroupStart = 1,
  FSM_Rejoin = 2,
  FSM_GroupRTB = 4,
  FSM_FlyRoute = 8,
  FSM_Deactivate = 16,
  FSM_Commit = 32,
  FSM_Engaged = 64,
  FSM_Pump = 128,
  FSM_PatrolZone = 256
  }

CapGroup.tactics = {}
CapGroup.tactics.Skate = 1
CapGroup.tactics.SkateGrinder = 2
CapGroup.tactics.SkateOffset = 3
CapGroup.tactics.SkateOffsetGrinder = 4
CapGroup.tactics.ShortSkate = 5
CapGroup.tactics.ShortSkateGrinder = 6
CapGroup.tactics.Bracket = 7
CapGroup.tactics.Banzai = 8

function CapGroup:create(planes, originalName, route) 
  local instance = {}
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.elements = {CapElement:create(planes)}
  instance.countPlanes = #planes
  
  instance.id = utils.getGroupID()
  instance.name = originalName or ("CapGroup-"..tostring(instance.id))
  instance.typeName = planes[1]:getTypeName()
  
  instance.point = planes[1]:getPoint() or {x = 0, y = 0, z = 0} --mean point of group is here, now just pos of lead
  
  instance.route = route or GroupRoute:create()
  
  instance.rtbWhen = CapGroup.RTBWhen.NoAmmo
  instance.bingoFuel = 0.3
  instance.deactivateWhen = CapGroup.DeactivateWhen.OnShutdown
    
  instance.ammoState = nil
    
  instance.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = 1,
    [AbstractTarget.TypeModifier.ATTACKER] = 0.5,
    [AbstractTarget.TypeModifier.HELI] = 0.1
  }
  --minimum amount of radars covers this group to NOT use own radar
  instance.goLiveThreshold = 2
  --additional zones for targeting, target in this groups
  --will be attacked even if distance > commitRange
  instance.commitZones = {}
  instance.commitRange = 110000
  instance.missile = utils.PlanesTypes[instance.typeName].Missile--missile with most range
  instance.radarRange = utils.PlanesTypes[instance.typeName].RadarRange
  instance.autonomous = false --is this group used as radar for detection
  instance.alr = CapGroup.ALR.Normal
  instance.preferableTactics = {}
  instance.target = nil
  
  instance.FSM_stack = FSM_Stack:create()
  --initialize with stub FSM
  instance.FSM_stack:push(FSM_GroupStart:create(instance))
  instance.FSM_args = {
    contacts = {}, --targetGroups from detectionHandler
    radars = {} --radars from detection handler for updateAutonomous
    } --dictionary with args for FSM
  
  --holds
  instance.patrolZones = {}
  --should group disengage when target too far from group route leg(distance > commitRange), this should prevent chasing all the way to enemy field
  instance.checkRouteDist = true
  
  --classes used for RTB and Deactivate(this version used basic, version with tasks used decorated)
  instance.rtbClass = FSM_GroupRTB
  instance.deactivateClass = FSM_Deactivate

  instance.elements[1]:registerGroup(instance)
  for _, plane in pairs(instance.elements[1].planes) do 
    plane:registerGroup(instance)
  end
  
  instance:updateAmmo()
  return instance
end

--setters
function CapGroup:setRTBWhen(val)
  self.rtbWhen = val
  end

function CapGroup:setBingo(val) 
  self.bingoFuel = val
  end

function CapGroup:setDeactivateWhen(val) 
  self.deactivateWhen = val
end

function CapGroup:setPriorities(modifierFighter, modifierAttacker, modifierHeli) 
  self.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = modifierFighter or self.priorityForTypes[AbstractTarget.TypeModifier.FIGHTER],
    [AbstractTarget.TypeModifier.ATTACKER] = modifierAttacker or self.priorityForTypes[AbstractTarget.TypeModifier.ATTACKER],
    [AbstractTarget.TypeModifier.HELI] = modifierHeli or self.priorityForTypes[AbstractTarget.TypeModifier.HELI]
    }
  end

function CapGroup:setCheckDistanceToRoute(val) 
  self.checkRouteDist = val
  end

function CapGroup:addCommitZone(zone) 
  self.commitZones[zone:getID()] = zone
end

function CapGroup:deleteCommitZone(zone) 
  self.commitZones[zone:getID()] = nil
end

function CapGroup:setCommitRange(val) 
  self.commitRange = val
end

function CapGroup:setALR(val) 
  self.alr = val
  end

function CapGroup:setTactics(tacticList) 
  self.preferableTactics = tacticList
  end

function CapGroup:setGoLiveThreshold(val) 
  self.goLiveThreshold = val
end

function CapGroup:addCommitZoneByTriggerZoneName(triggerZoneName) 
  local trig_zone = trigger.misc.getZone(triggerZoneName)
  self:addCommitZone(CircleZone:create(trig_zone.point, trig_zone.radius))
end

function CapGroup:addCommitZoneByGroupName(groupName) 
  local points = mist.getGroupPoints(groupName)
  
  if points then
    self:addCommitZone(ShapeZone:create(points))
  end
end

function CapGroup:addPatrolZone(wpIndex, zone) 
  if not self.patrolZones[wpIndex] then 
    self.patrolZones[wpIndex] = {}
  end
  self.patrolZones[wpIndex][zone:getID()] = zone
end

function CapGroup:removePatrolZone(zone) 
  for _, wp in pairs(self.patrolZones) do 
    wp[zone:getID()] = nil
  end
  
end


--try to create OrbitZome for 
function CapGroup:createPatrolZoneFromTask(waypointID, taskFromWaypoint) 

  local waypoint, waypoint2 = self.route:getWaypoint(waypointID), self.route:getWaypoint(waypointID + 1)
  
  if taskFromWaypoint.id == "Orbit" then --not wrapped
    local param = taskFromWaypoint.params
    local alt = param.altitude or 6000
    local speed = param.speed or 200
    
    if taskFromWaypoint.params.pattern == "Circle" or not waypoint2 then 
      self:addPatrolZone(waypointID, OrbitTask:create({x = waypoint.x, y = waypoint.y}, speed, alt))
    else
      self:addPatrolZone(waypointID, RaceTrackTask:create({x = waypoint.x, y = waypoint.y}, {x = waypoint2.x, y = waypoint2.y}, speed, alt))
    end
  elseif taskFromWaypoint.id == "ControlledTask" and taskFromWaypoint.params.task.id == "Orbit"  then
    --wrapped orbit
    local param = taskFromWaypoint.params.task.params
    local alt = param.altitude or 6000
    local speed = param.speed or 200
    
    if taskFromWaypoint.params.task.params.pattern == "Circle" or not waypoint2 then 
      self:addPatrolZone(waypointID, OrbitTask:create({x = waypoint.x, y = waypoint.y}, speed, alt, 
          ConditionFactory:getConditions(taskFromWaypoint.params.condition), ConditionFactory:getConditions(taskFromWaypoint.params.stopCondition)))
    else
       self:addPatrolZone(waypointID, RaceTrackTask:create({x = waypoint.x, y = waypoint.y}, {x = waypoint2.x, y = waypoint2.y}, speed, alt,
           ConditionFactory:getConditions(taskFromWaypoint.params.condition), ConditionFactory:getConditions(taskFromWaypoint.params.stopCondition)))  
    end
  end
end


--add all orbit task from original group route
function CapGroup:addPatrolZonesFromTask() 
  local route = mist.getGroupRoute(self:getName(), true)
  
  if not route then 
    return
  end
  
  for nbr, point in ipairs(route) do 
    --looks all task wrapped in ComboTask
    if point.task.params then 
      for ii, task in pairs(point.task.params.tasks) do 
        self:createPatrolZoneFromTask(nbr, task)
      end
    end
  end
end


--set home base as this point
function CapGroup:setHomePoint(point)
  self.route:setHomePoint(point)
end

function CapGroup:setAutonomous(val) 
  self.autonomous = val
  
  for _, plane in self:planes() do 
    if self.autonomous then
      plane:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On)
    else
      plane:setOption(CapPlane.options.RDR, nil)
    end
  end
end


--iterator
function CapGroup:planes() 
  local nbr = 0
  return coroutine.wrap(
    function()
      for _, elem in pairs(self.elements) do 
        for __, plane in pairs(elem.planes) do 
          nbr = nbr + 1
          coroutine.yield(nbr, plane)
          end
        end
    end
    )
  end

function CapGroup:getID() 
  return self.id
end

function CapGroup:getName() 
  return self.name
end

function CapGroup:getLead() 
  --first plane in first element
  return self.elements[1].planes[1]
  end

function CapGroup:getPoint() 
  --return position of lead
  --return self:getLead():getPoint()
  
  --New: return mean pos of all elements
  return self.point
end

function CapGroup:getTypeName() 
  return self.typeName
  end

--missile with most range in group, including missiles in air
function CapGroup:getBestMissile() 
  return self.missile
  end


--update ammoState
--update missile
function CapGroup:updateAmmo() 
  --aliases
  local IR, ARH, SARH = Weapon.GuidanceType.IR, Weapon.GuidanceType.RADAR_ACTIVE, Weapon.GuidanceType.RADAR_SEMI_ACTIVE
  local generalAmmo = {
      [IR] = 0,
      [ARH] = 0,
      [SARH] = 0,
    }
    
  self.missile = {MaxRange = 0, MAR = 0}
  for _, plane in self:planes() do
    local ammo = plane:getAmmo()
    generalAmmo[SARH] = generalAmmo[SARH] + ammo[SARH]
    generalAmmo[ARH] = generalAmmo[ARH] + ammo[ARH]
    generalAmmo[IR] = generalAmmo[IR] + ammo[IR]
    
    --update missile
    local m = plane:getBestMissile()
    if m.MaxRange > self.missile.MaxRange then 
      self.missile = m
    end
  end
  
  if generalAmmo[SARH] == 0 
    and generalAmmo[ARH] == 0
    and generalAmmo[IR] == 0 then 
    --we are empty
    self.ammoState = CapGroup.AmmoState.NoAmmo
  elseif generalAmmo[ARH] > 0 then
    self.ammoState = CapGroup.AmmoState.ARH
  elseif generalAmmo[SARH] > 0 then
    self.ammoState = CapGroup.AmmoState.SARH
  else
    self.ammoState = CapGroup.AmmoState.IrOnly
  end
end

--delete dead planes
--update ammo state
--update .countPlanes
--update linkage
function CapGroup:update() 
  local aliveElems = {}
  self.countPlanes = 0
  
  local elemPos = {}
  
  for _, elem in pairs(self.elements) do 
    if elem:isExist() then 
      aliveElems[#aliveElems+1] = elem
      self.countPlanes = self.countPlanes + #elem.planes
      
      elem:update()
      
      elemPos[#elemPos + 1] = elem:getPoint()
    else
      --element dead, verify target was cleared if present
      if elem:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then 
        
        elem:popFSM_NoCall()
      end
    end
  end
  
  self.elements = aliveElems
  self.point = mist.getAvgPoint(elemPos)
  self:updateElementsLink()
  self:updateAmmo()
  end

function CapGroup:updateElementsLink() 
  
  if self.countPlanes == 0 then 
    --group dead
    return
  end
  
  if #self.elements == 1 then 
    --remove link
    self.elements[1]:setSecondElement(nil)
    return
  end
  
  self.elements[1]:setSecondElement(self.elements[2])
  self.elements[2]:setSecondElement(self.elements[1])  
end

--return false if no more controlled element
function CapGroup:isExist() 
  if self.countPlanes > 0 then 
    return true
  end
  
  if self.target then 
    self.target:setTargeted(false)
    end
  
  return false
end

--return lowest fuel in group
function CapGroup:getFuel() 
  local fuel = 100
  
  for _, plane in self:planes() do 
    if plane:getFuel() < fuel then 
      fuel = plane:getFuel()
    end
  end
  return fuel
end

--check if group should change autonomous state and change it
function CapGroup:updateAutonomous(radars) 
  --we check if point ahead of us is covered by radar
  local point = mist.vec.add(
    self:getPoint(),
    mist.vec.scalar_mult(mist.vec.getUnitVec(self:getLead():getVelocity()), self.radarRange*0.75))
  local radarsCounter = 0
  for _, radar in pairs(radars) do
    if radar:inZone(point) then 
      radarsCounter = radarsCounter + 1
    end
  end
  
  if radarsCounter >= self.goLiveThreshold and self.autonomous then 
    self:setAutonomous(false)
  elseif radarsCounter < self.goLiveThreshold and not self.autonomous then
    self:setAutonomous(true)
  end
end



--call elements FSM
function CapGroup:callElements()
  for _, element in pairs(self.elements) do
    element:callFSM()
  end
end

function CapGroup:callFSM() 
  self.FSM_stack:run(self.FSM_args)
  
  self:callElements()
  self.FSM_args = {
    radars = {},
    contacts = {}
    }
end

--check if entire group in air
function CapGroup:isAirborne() 
  --ask all planes, so they can setup their timers
  local inAir = true
  
  for _, plane in self:planes() do 
    if not plane:inAir() then 
      inAir = false
      end
    end
    
    return inAir
  end
  
--check if entire group is landed
function CapGroup:isLanded()
  for _, plane in self:planes() do 
    if plane:getObject():inAir() then 
      return false
      end
    end
    return true
  end
  
function CapGroup:isEngineOff() 
 for _, plane in self:planes() do 
    if not plane.shutdown then 
      return false
      end
    end
    return true
 end 
  
--return true if group should be deactivated
-- criteria is:
--  1)deactivateWhen == CapGroup.DeactivateWhen.InAir then if group in 10000m from homeBase
--  2)deactivateWhen == CapGroup.DeactivateWhen.OnLand or onShutdown but group don't have a airfield -> same rules as above
--  3)deactivateWhen == CapGroup.DeactivateWhen.OnLand deactivate when isLanded() return true
--  4)deactivateWhen == CapGroup.DeactivateWhen.OnShutdown deactivate when all planes .shutdown flag is true
function CapGroup:shouldDeactivate() 
  if self.route:hasAirfield() then 
    if self.deactivateWhen == CapGroup.DeactivateWhen.OnLand then 
      return self:isLanded()
    elseif self.deactivateWhen == CapGroup.DeactivateWhen.OnShutdown then
      return self:isEngineOff()
    end
  end
  
  return mist.utils.get2DDist(self:getPoint(), self.route:getHomeBase()) < 10000 
end

--maximum distance from lead to wingman
function CapGroup:getMaxDistanceToLead() 
  if self.countPlanes == 1 then 
    --no  wingmans
    return 0
  end
  
  local leadPos = self:getPoint()
  local maxRange = 0
  
  for _, plane in self:planes() do 
    local range = mist.utils.get3DDist(leadPos, plane:getPoint())
    
    if range > maxRange then 
      maxRange = range
      end
    end
  
  return maxRange
end

function CapGroup:needRTB() 
  return self.ammoState <= self.rtbWhen or self:getFuel() < self.bingoFuel
  end


--move all airplanes to first element
function CapGroup:mergeElements() 
  if not self.elements[2] then  
    --only 1 element
    return
  end
  
  --has second element, clear target if in wrapper state
  if self.elements[2]:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then 
    
    --manually clear target, or stack will unwind and it can try to reach dead target
    --self.elements[2].FSM_Stack:getCurrentState().target:setTargeted(false) this shit will also throw
    local res, err = pcall(function() self.elements[2]:popFSM_NoCall() end)--need to catch, cause it can try to call a target, which now deleted
    if not res then 
      GlobalLogger:create():warning(self:getName() .. " error during merging " .. tostring(err))
    end
 end
  
  for _, plane in pairs(self.elements[2].planes) do 
    self.elements[1].planes[#self.elements[1].planes+1] = plane
    plane:registerElement(self.elements[1])
  end
  --delete element
  self.elements[2] = nil
  --delete link
  self.elements[1]:setSecondElement(nil)

  GlobalLogger:create():info(self:getName() .. "mergeElements, now elements is: " .. self.elements[1]:getName())
end

--split first element to 2 elements
--if 2 planes then 2 singletons
--or pair and 1/2
function CapGroup:splitElement() 
  if self.elements[2] or self.countPlanes == 1 then  
    --has second element or we singleton
    return
  end
  
  if self.countPlanes == 2 then 
    self.elements[2] = CapElement:create({self.elements[1].planes[2]})
    
    --remove plane
    self.elements[1].planes[2] = nil
    --update linkage
    self.elements[2]:registerGroup(self)
    self:updateElementsLink()
    
    --copy first state of first element
    local copiedState = mist.utils.deepCopy(self.elements[1].FSM_stack.data[1])
    copiedState.object = self.elements[2]--replace object state refers to
    copiedState.id = utils.getGeneralID()
    self.elements[2]:clearFSM()
    self.elements[2]:setFSM_NoCall(copiedState)

    GlobalLogger:create():info(self:getName() .. " Split elements, now elements is: " 
    .. self.elements[1]:getName() .. " | " .. self.elements[2]:getName())
    return
  end
  
  if self.countPlanes == 4 then 
    self.elements[2] = CapElement:create({self.elements[1].planes[3], self.elements[1].planes[4]})
    --delete from first elem
    self.elements[1].planes[3] = nil
    self.elements[1].planes[4] = nil
  else
    self.elements[2] = CapElement:create({self.elements[1].planes[3]})
    --delete from first elem
    self.elements[1].planes[3] = nil
  end
  
  --update linkage
  self.elements[2]:registerGroup(self)
  self:updateElementsLink()
  
  --copy first state of first element
  local copiedState = mist.utils.deepCopy(self.elements[1].FSM_stack.data[1])
  copiedState.object = self.elements[2]--replace object state refers to
  copiedState.id = utils.getGeneralID()
  self.elements[2]:clearFSM()
  self.elements[2]:setFSM_NoCall(copiedState)

  GlobalLogger:create():info(self:getName() .. " Split elements, now elements is: " 
    .. self.elements[1]:getName() .. " | " .. self.elements[2]:getName())
end



--check all zones if target inside any of this
function CapGroup:checkInZones(target) 
  for _, zone in pairs(self.commitZones) do 
    if zone:isInZone(target:getPoint()) then 
      return true
      end
    end
    
    return false
  end


--calculate 'weight' for current target
function CapGroup:getTargetPriority(target, count, targetTypeMod, targetedMult, range, aspect) 
  local MAR = target:getHighestThreat().MAR
  return (count * (50000 * (MAR / range)^2) * targetedMult - (MAR * (aspect / 180))) * targetTypeMod
end

--lowest aspect from target to each element, this prevent from exit from engage, when target 
--chasing second element and became to far from mean pos(i.e. in bracket), using low aspect will mean target is hot
--and result in higher commit range
function CapGroup:getAspectFromElements(target) 
  local a1 = target:getAA(self.elements[1]:getPoint())
  
  if not self.elements[2] then 
    return a1
  end
  
  return math.min(a1, target:getAA(self.elements[2]:getPoint()))
end

--added 08.01.24: check for target status, exclude dead targets
function CapGroup:calculateTargetsPriority(targets) 
  local result = {}
  local ourPos = self:getPoint()
  
  for _, target in pairs(targets) do 
    
    if target:isExist() then
      local typeModifier = self.priorityForTypes[target:getTypeModifier()]
      local count, range = target:getCount(), mist.utils.get2DDist(ourPos, target:getPoint())
      
      --lowest aspect from target to each element, this prevent from exit from engage, when target 
      --chasing second element and became to far from mean pos(i.e. in bracket)
      local aspect = self:getAspectFromElements(target)
      
      local targetedMult = 1.0
      if target:getTargeted() then 
        targetedMult = 0.5
      end
      
      result[#result+1] = {
        target = target,
        priority = self:getTargetPriority(target, count, typeModifier, targetedMult, range, aspect),
        range = range,
        aspect = aspect
      }
    end
  end
  
  return result
end

--calculate commit distance for target, use this logic for dropping targets
--lower aspect -> much more range to start commit
--TO DO: option to allow group chase target all the way
function CapGroup:calculateCommitRange(target, aspect) 
  --OLD: CR seem to high against targets with hi range missiles
  --[[return self.commitRange 
    - 0.75*math.abs(self.commitRange - math.max(self.missile.MaxRange*0.8, targetRange))*(target:getAA(self:getPoint())/180)--]]
  
  --commit range was set to value which is below our missile maximum range
  if self.commitRange < self.missile.MaxRange then
    return self.commitRange
  end
  
  local targetRange, targetPos = target:getHighestThreat().MaxRange*0.75, target:getPoint()
  --new: go attack if inside maxRange(when target cold, or at calc commit range)
  local attackRange = self.missile.MaxRange*0.8
  local rangeDelta = self.commitRange - attackRange

  return math.max(self.missile.MaxRange, attackRange + rangeDelta * (1 - aspect/180))
end

--check targetCandidates return target if it can be accepted, or return nil
--if target with most priority inside CommitRange then return it
--or return target with most priority and if it inside one of commitZones
--if finded target is ourTarget then return in if it inside commitRange + 20km
function CapGroup:checkTargets(targetCandidates) 
  local emptyTable = {
      target = nil,
      priority = -math.huge,
      range = -10,
      commitRange = -10, --calculated commit range for target
      aspect = 180       --lowest aspect by getAspectFromElements()
    }

  local resultTarget = mist.utils.deepCopy(emptyTable)
  
  --get target with most priority
  for _, targetTbl in pairs(self:calculateTargetsPriority(targetCandidates)) do 
    if targetTbl.priority > resultTarget.priority then 
      resultTarget = targetTbl
    end
  end
  
  if not resultTarget.target then 
    return emptyTable
  end
  
  --option for route check:
  -- target will be returned if option off
  -- or distance from target to current leg < commitRange OR dist to target less then 20nm(to prevent disengaging in combat)
  local inRouteArea = not self.checkRouteDist or (resultTarget.range < 40000 or
    self.route:distanceToLeg(resultTarget.target:getPoint()) < self.commitRange)
  
  --return target if it inside one of commit Zones or inside commitRange and to close to route(if option set)
  local commitRange = self:calculateCommitRange(resultTarget.target, resultTarget.aspect)
  
  if (resultTarget.range < commitRange and inRouteArea)
    or self:checkInZones(resultTarget.target) then
    
    resultTarget.commitRange = commitRange
    return resultTarget
  end
  
  return emptyTable
end


function CapGroup:getAutonomous()
  return self.autonomous
end

--default checks, just return all detectedTargets
function CapGroup:getDetectedTargets() 
  
  local result = {}
  local nbr = 1
  
  for _, plane in self:planes() do 
    for __, contact in pairs(plane:getDetectedTargets()) do 
      --return only alive and aircraft
      if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") then
        result[nbr] = TargetContainer:create(contact, plane)
        nbr = nbr + 1
        end
      end
    end
    
    return result
  end

function CapGroup:getDebugStr(settings) 

  local MARGIN_GROUP = 2
  local MARGIN_GROUP_FSM = 6
  local MARGIN_ELEMENT = 4
  local MARGIN_ELEMENT_FSM = 8
  local MARGIN_PLANES = 8
  local MARGIN_PLANES_FSM = 12
  
  local showTargetTernary = function(obj) 
    if obj.target then 
      return obj.target:getName() 
    else 
      return "nil"
    end 
  end
  local m = ""
  
  if settings.showGroupsDebug then 
      m = m .. utils.getMargin(MARGIN_GROUP) .. self:getName() .. " |Fuel: " .. tostring(utils.round(self:getFuel(), 2)) 
        .. " |Strength: " .. tostring(self.countPlanes) 
        .. " |Autonom: " .. tostring(self:getAutonomous()) .. " |Target: " .. showTargetTernary(self)
        .. "\n    State: " .. self.FSM_stack:getCurrentState().name .. "\n"
      
      if settings.showFsmStack then
        m = m .. FSM_Stack.printStack(self.FSM_stack, MARGIN_GROUP_FSM)
      end
    end
    
  if settings.showElementsDebug then 
    for _, element in pairs(self.elements) do 
      m = m .. "\n"
      m = m .. utils.getMargin(MARGIN_ELEMENT) .. element:getName() .. " |Strength: " .. tostring(#element.planes) 
        .. " |State: " .. element.FSM_stack:getCurrentState().name .. "\n"
      
      if settings.showFsmStack then 
        if element:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then 
          --print inner stack
          local wrapperState = element.FSM_stack:getCurrentState()
          for _, innerElem in pairs(wrapperState.elements) do 
            m = m .. "\n" .. utils.getMargin(MARGIN_ELEMENT_FSM) .. "Inner elem: " .. innerElem:getName() .. "\n"
            m = m .. FSM_Stack.printStack(innerElem.FSM_stack, MARGIN_ELEMENT_FSM)
          end
        else
          m = m .. FSM_Stack.printStack(element.FSM_stack, MARGIN_ELEMENT_FSM)
        end
        
      end
        
      if settings.showPlanesDebug then 
        m = m .. "\n"
        m = m .. utils.getMargin(MARGIN_PLANES) .. "PLANES: \n"
        for __, plane in pairs(element.planes) do 
          m = m .. utils.getMargin(MARGIN_PLANES+2) .. plane:getName() .. " |Target: " .. showTargetTernary(plane) 
            .. " |State: " .. plane.FSM_stack:getCurrentState().name .. "\n"
          
          if settings.showFsmStack then 
            m = m .. FSM_Stack.printStack(plane.FSM_stack, MARGIN_PLANES_FSM)
          end
        end--plane fsm
      end--end of planes debug
    end--element debug cycle
  end--end of element debug
  
  return m
end

--will be used in derived
function CapGroup:calculateAOB(point, plane) 
  
  local fromTgtToPoint = mist.vec.getUnitVec(mist.vec.sub(point, plane:getPoint()))
  --acos from tgt velocity and vector from tgt to point
  return math.abs(math.deg(math.acos(mist.vec.dp(mist.vec.getUnitVec(plane:getVelocity()), fromTgtToPoint))))
  end

--only return targets which in forward hemisphere and inside radar range and clear LOS
--of if target inside 20Nm(think AI very good at assuming where target)
function CapGroup:getDetectedTargetsWithChecks() 
  

  local result, ourPos = {}, self:getPoint()
  local nbr = 1
  
  for _, plane in self:planes() do 
    for __, contact in pairs(plane:getDetectedTargets()) do 
      
      if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air")
        and land.isVisible(contact.object:getPoint(), ourPos) --CHECK LOS
        and mist.utils.get3DDist(contact.object:getPoint(), ourPos) < self.radarRange
        and self:calculateAOB(contact.object:getPoint(), plane) < 90 then --target in front of aircraft
          
        result[nbr] = TargetContainer:create(contact, plane)
        nbr = nbr + 1
        end
      end
    end
    
    return result
end

----------------------------------------------------
-- Single fighter group, with custom route and task
--- used by squadrons anf GciCap module
----------------------------------------------------  
----          AbstractCAP_Handler_Object  FighterEntity_FSM
----                  ↓                           ↓
----              CapGroup <----------------------
----                  ↓
----             CapGroupRoute
----------------------------------------------------

CapGroupRoute = utils.inheritFrom(CapGroup)

function CapGroupRoute:create(planes, objective, squadron) 
  
  local points = {}
  local objPoint = mist.vec.add(objective:getPoint(), {x = 20000, y = 0, z = 0})
  --if objective north point closer then 50km, then add second WP 35km to EAST
  --so group can climb to altitude
  if mist.utils.get2DDist(objPoint, squadron:getPoint()) < 50000 then 
    points = { 
      mist.fixedWing.buildWP(mist.vec.add(objective:getPoint(), {x = 0, y = 0, z = 35000}), "turningpoint", squadron.speed, squadron.alt, squadron.alt_type),
      mist.fixedWing.buildWP(objPoint, "turningpoint", squadron.speed, squadron.alt, squadron.alt_type),
      squadron:getHomeWP()}
  else
    --else just fly to objectives
    points = {
      squadron:getHomeWP(), 
      mist.fixedWing.buildWP(objPoint, "turningpoint", squadron.speed, squadron.alt, squadron.alt_type), 
      squadron:getHomeWP()}
  end
  
  
  local instance = self:super():create(planes, squadron:getName() .. "-group-" .. tostring(utils.getGeneralID()) , GroupRoute:create(points))
  instance.sqn = squadron
  instance.objective = objective
  instance.originalSize = #planes
  
  --add objective zone to zones
  instance.commitZones[objective:getGciZone():getID()] = objective:getGciZone()
  --add patrol zone over objective
  local PatrolArea = RaceTrackTask:create(objPoint, objective:getPoint(), squadron.speed, squadron.alt)
  instance.patrolZones[#points - 1] = {[PatrolArea:getID()] = PatrolArea}
  
  --time when task was set, group can't be retasked until it patrol at current task random(5min, 15min) 
  instance.canBeRetasked = timer.getAbsTime() + mist.random(300, 900)
  
  --use decorated version, which will handle work with squadron and objective
  instance.rtbClass = FSM_GroupRTB_Route
  instance.deactivateClass = FSM_Deactivate_Route
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--will remove group from objective if we dead
function CapGroupRoute:update() 
  --call parent class explicitly or will get overflow with super
  CapGroup.update(self)
  
  if not self:isExist() 
    and self:getCurrentFSM() ~= CapGroup.FSM_Enum.FSM_GroupRTB
    and self:getCurrentFSM() ~= CapGroup.FSM_Enum.FSM_Deactivate then 
    --in RTB group automatically delete planes
    --Deactivate called only from RTB
    --delete only when group dies
    self.objective:addCapPlanes(-self.originalSize)
  end
end

--can be retasked if enough time passed and group in FlyRoute or PatrolZone or Rejoin state
function CapGroupRoute:canRetask() 

  return timer.getAbsTime() >= self.canBeRetasked and 
    (self:getCurrentFSM() == CapGroup.FSM_Enum.FSM_FlyRoute or
     self:getCurrentFSM() == CapGroup.FSM_Enum.FSM_Rejoin or
     self:getCurrentFSM() == CapGroup.FSM_Enum.FSM_PatrolZone)
end

function CapGroupRoute:getOriginalSize() 
  return self.originalSize
end

function CapGroupRoute:setNewObjective(objective) 
  GlobalLogger:create():info(self:getName() .. " switch objective to: " .. objective:getName())
  
  --firstly delete our group from current objective
  self.objective:addCapPlanes(-self.originalSize)
  
  self.objective = objective
  self.objective:addCapPlanes(self.originalSize)
  
  local objPoint = mist.vec.add(objective:getPoint(), {x = 20000, y = 0, z = 0})
  
  --update zones
  self.patrolZones = {}
  self.commitZones = {}
  self:addPatrolZone(1, RaceTrackTask:create(objPoint, objective:getPoint(), self.sqn.speed, self.sqn.alt))
  self:addCommitZone(objective:getGciZone())
  
  --update timer
  self.canBeRetasked = timer.getAbsTime() + mist.random(300, 900)
  
  --create new Route, first point is objective, speed 300m/s(cause we retasking) second point home base
  self.route = GroupRoute:create({mist.fixedWing.buildWP(objPoint, "turningpoint", 300,  self.sqn.alt, self.sqn.alt_type), self.sqn:getHomeWP()})
  
  --if we already flying to route call setup(), it will reapply route to planes
  if self:getCurrentFSM() == CapGroup.FSM_Enum.FSM_FlyRoute then 
    self.FSM_stack:getCurrentState():setup()
  elseif self:getCurrentFSM() == CapGroup.FSM_Enum.FSM_PatrolZone then
    --we in patrol zone, return to fly route
    self:popFSM_NoCall()
  end
  --if we in rejoin, setup will be called during transition to FlyRoute
end


function CapGroupRoute:getDebugStr(settings) 
  local message = CapGroup.getDebugStr(self, settings)
  
  local idx = string.find(message, "\n") or 0
  message = string.sub(message, 1, idx) .. utils.getMargin(4) .. "Objective: " .. self.objective:getName() .. string.sub(message, idx)
  
  return message
end

----------------------------------------------------
-- Single fighter group, with detection checks
----------------------------------------------------  
----          AbstractCAP_Handler_Object  FighterEntity_FSM
----                  ↓                           ↓
----              CapGroup <----------------------

----                  ↓
----          CapGroupWithChecks
----------------------------------------------------

CapGroupWithChecks = utils.inheritFrom(CapGroup)

--only return targets which in forward hemisphere and inside radar range and clear LOS
--of if target inside 20Nm(think AI very good at assuming where target)
function CapGroupWithChecks:getDetectedTargets() 
  
  return self:getDetectedTargetsWithChecks()
end


----------------------------------------------------
-- group with route, but using detection cheks
----------------------------------------------------  
----          AbstractCAP_Handler_Object  FighterEntity_FSM
----                  ↓                           ↓
----              CapGroup <----------------------
----                  ↓
----             CapGroupRoute
----                  ↓
----          CapGroupWithChecks
----------------------------------------------------

CapGroupRouteWithChecks = utils.inheritFrom(CapGroupRoute)

--declare consructor or will get problems with super() (my iheritance is shit)
function CapGroupRouteWithChecks:create(planes, objective, sqn)
  return setmetatable(self:super():create(planes, objective, sqn), {__index = self, __eq = utils.compareTables})
end

function CapGroupRouteWithChecks:getDetectedTargets() 
  
  return self:getDetectedTargetsWithChecks()
end