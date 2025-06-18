
---@meta "CapSquadronMeta"
----------------------------------------------------
-- CapSquadron FSM, standart waiting, with aircraft
---prepared
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            AbstractState
----                  ↓
----          CapSquadronReady
----------------------------------------------------

CapSquadronReady = utils.inheritFrom(AbstractState)

function CapSquadronReady:create(sqn) 
  local instance = self:super():create(sqn)
  
  instance.name = "CapSquadronReady"
  instance.enumerator = CapSquadronAir.FSM_Enum.CapSquadronReady
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--if readyCounter on handled object below readyAircraft setting start timer to preparing aircraft
function CapSquadronReady:run() 
  
  if self.object.aircraftCounter == self.object.readyCounter or self.object.readyAircraft == self.object.readyCounter then 
    --no planes avail or all planes in stock already prepared
    return
  end
  
  --avail count below required value and still have plane in stock
  if self.object.readyAircraft - self.object.readyCounter > 0 then 
    self.object.FSM_stack:push(CapSquadronWaiting:create(self.object))
  end
end

----------------------------------------------------
-- CapSquadron FSM, preparing aircraft, wait random time
---between preflightTime*0.75 and preflightTime*1.25
---when wait done return to CapSquadronReady
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            AbstractState
----                  ↓
----          CapSquadronWaiting
----------------------------------------------------
CapSquadronWaiting = utils.inheritFrom(AbstractState)

function CapSquadronWaiting:create(sqn) 
  local instance = self:super():create(sqn)
  
  instance.name = "CapSquadronWaiting"
  instance.enumerator = CapSquadronAir.FSM_Enum.CapSquadronWaiting
  
  instance.waitUntil = 0
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--setup random timer to wait
function CapSquadronWaiting:setup() 
  self.object.preflightTimeLeft = mist.random(self.object.preflightTime*0.75, self.object.preflightTime*1.25)
  self.waitUntil = timer.getAbsTime() + self.object.preflightTimeLeft
  
  GlobalLogger:create():debug(self.object:getName() .. " new aircraft will be ready in: " .. tostring(self.object.preflightTimeLeft))
end

function CapSquadronWaiting:run() 
  
  if self.waitUntil > timer.getAbsTime() then 
    --just update timer
    self.object.preflightTimeLeft = self.waitUntil - timer.getAbsTime()
    return
  end
  
  local planesReady = math.min(self.object.aircraftCounter, self.object.readyAircraft)
  GlobalLogger:create():debug(self.object:getName() .. " " .. tostring(planesReady) .. " now ready")
    
  self.object.readyCounter = planesReady
  self.object.FSM_stack:pop()
end

function CapSquadronWaiting:teardown() 
  self.object.preflightTimeLeft = 0
end

----------------------------------------------------
--CapSquadron, this for Airstart, this will always spawn
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            CapSquadronAir
----------------------------------------------------

---@class CapSquadronAir: AbstractCAP_Handler_Object
CapSquadronAir = utils.inheritFrom(AbstractCAP_Handler_Object)
CapSquadronAir.FSM_Enum = {
  CapSquadronReady = 101,
  CapSquadronWaiting = 102,
}

--range modifier for diffent priority(used in objective during sorting, so less priority -> higher mult -> higher distance -> will be used later)
CapSquadronAir.Priority = {}
CapSquadronAir.Priority.LOW = 1.25
CapSquadronAir.Priority.NORMAL = 1
CapSquadronAir.Priority.HIGH = 0.75

---@return CapSquadronAir
function CapSquadronAir:create(prototypeGroupName, aircraftReady, aircraftAvail, preflightTime, combatRadius, priority) 
  
  local instance = {}
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.id = utils.getGeneralID()
  instance.name = "CapSquadron-" .. prototypeGroupName
  
  --DON'T delete original group!!!
  local g = Group.getByName(prototypeGroupName)
  
  if not rawget(utils.PlanesTypes, g:getUnit(1):getTypeName()) then 
    utils.printToSim("Group: " .. prototypeGroupName .. " -> THIS AIRCRAFT TYPE NO SUPPORTED, SKIPPED, TYPE: " .. g:getUnit(1):getTypeName())
    return 
  end
  
  instance.coalition = g:getCoalition()
  instance.country = g:getUnit(1):getCountry()
  
  ---@type GroupTable
  ---@diagnostic disable-next-line: assign-type-mismatch 
  instance.prototypeTable = mist.getGroupTable(prototypeGroupName)--name check in caller, always return valid table
  instance.prototypeTable.task = "CAP"
  instance.prototypeTable.uncontrolled = nil
  instance.prototypeTable.lateActivation = nil
  instance.prototypeTable.start_time = nil
  instance.prototypeTable.units = {instance.prototypeTable.units[1]}--use only first unit!
  
  --flight parameters for groups
  instance.alt = 7500 --alt on route and in hold
  instance.alt_type = "BARO" --alt type
  instance.speed = 230 --speed on route and in hold in m/s 
  
  instance.priority = priority or CapSquadronAir.Priority.NORMAL
  instance.alr = CapGroup.ALR.Normal

  instance.combatRadius = combatRadius or 300000 --default 160nm
  --how many aircraft squdron have
  instance.aircraftCounter = aircraftAvail or 10
  --how many aircraft ready for takeoff squadron will hold
  instance.readyAircraft = aircraftReady or 2
  --how many aircraft ready now
  instance.readyCounter = instance.readyAircraft
  --how long takes to prepare aircraft(transition to readyAircraft)
  --it's mean time real time will be random(preflightTime*0.75, preflightTime*1.25)
  instance.preflightTime = preflightTime or 600
  
  --how many time left until new aircraft will be ready
  instance.preflightTimeLeft = 0
  
  --spawn point of squadron
  instance.point = {x = instance.prototypeTable.route.points[1].x,
    z = instance.prototypeTable.route.points[1].y,
    y = instance.prototypeTable.route.points[1].alt,
  }
  instance.homeWP = mist.fixedWing.buildWP(instance.point, "turningpoint", 230, 1000, "BARO")
  
  instance.FSM_stack = FSM_Stack:create()
  instance.FSM_stack:push(CapSquadronReady:create(instance))
  
  --settings which will be trasferred to groups
  instance.squadronBingo = 0.3
  instance.rtbAmmo = CapGroup.RTBWhen.NoAmmo
  instance.deactivateWhen = CapGroup.DeactivateWhen.InAir
  instance.preferredTactics = {}
  instance.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = 1,
    [AbstractTarget.TypeModifier.ATTACKER] = 0.5,
    [AbstractTarget.TypeModifier.HELI] = 0.1
  }
  instance.goLiveThreshold = 2
  
  return instance
end

--generate objective at sqn start point with CircleZone with radius R(default is 200km)
--objective by default request only GCI
function CapSquadronAir:generateObjective(R)
    local radius = R or 200000
    local pos = mist.utils.deepCopy(self:getPoint())--can corrupt point when creates
    return CapObjective:create(pos, CircleZone:create(pos, radius), false, true, nil, self:getName() .. "-home")
end

function CapSquadronAir:setALR(alr)
  GlobalLogger:create():info(self:getName() .. " setALR() " .. tostring(alr))
  self.alr = alr
end

function CapSquadronAir:setPriority(priority) 
  self.priority = priority
end

function CapSquadronAir:setSpeedAlt(speed, alt, alt_type) 
  self.alt = alt or self.alt --alt on route and in hold
  self.alt_type = alt_type or self.alt_type --alt type
  self.speed = speed or self.speed--speed on route and in hold in m/s 
end

function CapSquadronAir:setCombatRange(val) 
  self.combatRadius = val
end

function CapSquadronAir:setBingo(val) 
  self.squadronBingo = val
end

function CapSquadronAir:setRTBWhen(val)
  self.rtbAmmo = val
end

function CapSquadronAir:setDeactivateWhen(val) 
  self.deactivateWhen = val
end

function CapSquadronAir:setPriorities(modifierFighter, modifierAttacker, modifierHeli) 
  self.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = modifierFighter or self.priorityForTypes[AbstractTarget.TypeModifier.FIGHTER],
    [AbstractTarget.TypeModifier.ATTACKER] = modifierAttacker or self.priorityForTypes[AbstractTarget.TypeModifier.ATTACKER],
    [AbstractTarget.TypeModifier.HELI] = modifierHeli or self.priorityForTypes[AbstractTarget.TypeModifier.HELI]
    }
  end

function CapSquadronAir:setTactics(tacticList)
  self.preferredTactics = tacticList
end

function CapSquadronAir:setGoLiveThreshold(val)
  self.goLiveThreshold = val
end

function CapSquadronAir:getPriorityModifier() 
  return self.priority
end

--valid wp to spawn point
function CapSquadronAir:getHomeWP() 
  return self.homeWP
end

function CapSquadronAir:getCombatRadius() 
  return self.combatRadius
end

function CapSquadronAir:getPoint() 
  return self.point
end

function CapSquadronAir:getCountry() 
  return self.country
end

function CapSquadronAir:getCoalition() 
  return self.coalition
end

function CapSquadronAir:getReadyCount() 
  return self.readyCounter
end

function CapSquadronAir:getCounter() 
  return self.aircraftCounter
end

function CapSquadronAir:returnAircrafts(count) 
  self.aircraftCounter = self.aircraftCounter + count
end

function CapSquadronAir:update() 
  self.FSM_stack:run({})
end


function CapSquadronAir:spawnGroup(planesCount, objectiveForGroup, spawnTime) 
  self.aircraftCounter = self.aircraftCounter - planesCount
  self.readyCounter = math.min(self.readyCounter, self.aircraftCounter)
  
  return AirContainer:create(self, objectiveForGroup, planesCount, spawnTime)
end

--if has enough ready planes will return group which can instantly activated
function CapSquadronAir:getReadyGroup(planesCount, objectiveForGroup) 
  --if we have enough plane ready, then just spawn without delay
  if planesCount <= self.readyCounter then 
    --remove planes from ready
    self.readyCounter = self.readyCounter - planesCount
    return self:spawnGroup(planesCount, objectiveForGroup, timer.getAbsTime() - 10)  
  end
  
  --return standart group
  return self:getGroup(planesCount, objectiveForGroup)
end

function CapSquadronAir:getGroup(planesCount, objectiveForGroup)

  --don't use ready counter
  return self:spawnGroup(planesCount, objectiveForGroup, timer.getAbsTime() + mist.random(self.preflightTime * 0.75, self.preflightTime * 1.25))
end

function CapSquadronAir:getPrototypeTable() 
  return self.prototypeTable
end

function CapSquadronAir:getDebugStr() 
  local m = self:getName() .. " | ACF Total: " .. tostring(self:getCounter()) .. " | Ready: " .. tostring(self:getReadyCount())
  
  if self.FSM_stack:getStateEnumerator() == CapSquadronAir.FSM_Enum.CapSquadronWaiting then 
    m = m .. " | ACF ready in: " .. tostring(self.preflightTimeLeft)
  end
  
  return m
  end

----------------------------------------------------
--CapSquadron for start on airbases in hot states
-- (hot Park, on runway), will return avail planes 0
-- and no spawn if airbase/carrier captured or dead
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            CapSquadronAir
----                  ↓
----            CapSquadronHot
----------------------------------------------------

CapSquadronHot = utils.inheritFrom(CapSquadronAir)

function CapSquadronHot:create(prototypeGroupName, aircraftReady, aircraftAvail, preflightTime, combatRadius, priority) 
  local instance = self:super():create(prototypeGroupName, aircraftReady, aircraftAvail, preflightTime, combatRadius, priority)
  
  instance.carrierBased = false
  
  local homePoint = instance.prototypeTable.route.points[1]
  if homePoint.linkUnit then 
    instance.homeBase = CarrierWrapper:create(homePoint.linkUnit)
    instance.deactivateWhen = CapGroup.DeactivateWhen.OnLand
    instance.carrierBased = true
  elseif homePoint.airdromeId then
    --deactivate on shutdown cause we have airbase
    instance.deactivateWhen = CapGroup.DeactivateWhen.OnShutdown
    instance.homeBase = AirbaseWrapper:create(homePoint.airdromeId)
  else
    error("can't find airbase in group: " .. prototypeGroupName)
  end
  
  --set home point to type Landing
  instance.homeWP = mist.utils.deepCopy(instance.prototypeTable.route.points[1])
  instance.homeWP.type = "Land"
  instance.homeWP.action = "Landing"
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function CapSquadronHot:getAirbase() 
  return self.homeBase
end

function CapSquadronHot:getReadyCount() 
  if not self.homeBase:isAvail() then 
    return 0
  end
  
  return self.readyCounter
end

function CapSquadronHot:getCounter() 
  if not self.homeBase:isAvail() then 
    return 0
  end
  
  return self.aircraftCounter
end

--use different container
function CapSquadronHot:spawnGroup(planesCount, objectiveForGroup, spawnTime) 
  self.aircraftCounter = self.aircraftCounter - planesCount
  self.readyCounter = math.min(self.readyCounter, self.aircraftCounter)
  
  return HotContainer:create(self, objectiveForGroup, planesCount, spawnTime)
end

----------------------------------------------------
--CapSquadron for start in cold state, all aircraft will
---be spawned on startup and then just activates with
--- AI task start, or use RWY start if no parking avail
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            CapSquadronAir
----                  ↓
----            CapSquadronHot
----                  ↓
----           CapSquadronCold
----------------------------------------------------

CapSquadronCold = utils.inheritFrom(CapSquadronHot)

function CapSquadronCold:create(prototypeGroupName, aircraftReady, aircraftAvail, preflightTime, combatRadius, priority) 
  local instance = self:super():create(prototypeGroupName, aircraftReady, aircraftAvail, preflightTime, combatRadius, priority)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  instance.airplanes = {} --not active planes stored here
  
  --how many planes reserved for cold container but not taken yet
  instance.requestedCount = 0

  --set flag to disable ai on spawn
  instance.prototypeTable.uncontrolled = true
  instance:addNewPlanes()
    
  return instance
end

--return table with required amount of planes or all airplanes if don't have enough
function CapSquadronCold:getPlanes(amount) 
  --delete from requested
  self.requestedCount = math.max(self.requestedCount - amount, 0)
  
  local result = {}
  local len = #self.airplanes
  
  while amount > 0 and len > 0 do 
    
    result[#result + 1] = self.airplanes[len]:getGroup()
    self.airplanes[len] = nil --remove plane
    amount = amount - 1
    len = len - 1
  end
  
  return result
end

--fill all parking with aircraft or until all planes spawned
function CapSquadronCold:addNewPlanes() 
  local groupID = utils.getGroupID()
  
  for i = 1, math.min(self.homeBase:howManyParkingAvail(), self.aircraftCounter + self.requestedCount - #self.airplanes) do 
    self.prototypeTable.name = self:getName() .. "-group-" .. tostring(groupID) .. "-" .. tostring(i) --name for group
    self.prototypeTable.units[1].name = self:getName() .. "-unit-" .. tostring(groupID) .. "-" .. tostring(i)
    
    --add unit instead of group
    self.airplanes[#self.airplanes + 1] = coalition.addGroup(self.country, Group.Category.AIRPLANE, self.prototypeTable):getUnit(1)
  end
end

--use different containers
function CapSquadronCold:spawnGroup(planesCount, objectiveForGroup, spawnTime) 
  --spawn new aicraft
  self:addNewPlanes()
  
  self.aircraftCounter = self.aircraftCounter - planesCount
  self.readyCounter = math.min(self.readyCounter, self.aircraftCounter)
  
  --assume all parkings taken by our planes
  if planesCount > #self.airplanes then 
    --use rwy spawn, not enough planes
    return HotContainer:create(self, objectiveForGroup, planesCount, spawnTime)
  else
    --will use planes from self.airplanes
    --increment reserved planes counter
    self.requestedCount = self.requestedCount + planesCount
    return ColdContainer:create(self, objectiveForGroup, planesCount, spawnTime)
  end
end

function CapSquadronCold:updateCounters() 
  self.requestedCount = math.min(self.aircraftCounter + self.requestedCount, self.requestedCount)
  self.aircraftCounter = math.max(self.aircraftCounter, 0)
  self.readyCounter = math.min(self.aircraftCounter, self.readyCounter)
end

--added check for parkings and check aircraft status, if new slots avail fill it with planes(if we have)
function CapSquadronCold:update() 

  local newTbl = {}
  --check aircraft status, if dead or too damaged remove and decrement counter
  for i = #self.airplanes, 1, -1 do 
    if not self.airplanes[i] then
      --no acft, decrement
      self.aircraftCounter = self.aircraftCounter - 1
      self:updateCounters()
    elseif not self.airplanes[i]:isExist() or self.airplanes[i]:getLife()/self.airplanes[i]:getLife0() < 0.75 then 
      
      --too damaged, delete it to free parking
      --call in protected cause can throw if object don't exist(isExist() return false cause object to damaged, but plane still in 3D occupies parking)
      pcall(function() self.airplanes[i]:destroy() end) 
      self.aircraftCounter = self.aircraftCounter - 1
      self:updateCounters()
    else
      newTbl[#newTbl + 1] = self.airplanes[i]
    end
  end
  
  self.airplanes = newTbl
  --spawn new planes if able
  self:addNewPlanes()
  
  self:super().update(self)
end

--Overriden: added reserved counter
function CapSquadronCold:getDebugStr() 
  local m = self:getName() .. " | ACF Total: " .. tostring(self:getCounter()) .. " | Ready: " .. tostring(self:getReadyCount()) 
    .. " | Reserv: " .. tostring(self.requestedCount)
  
  if self.FSM_stack:getStateEnumerator() == CapSquadronAir.FSM_Enum.CapSquadronWaiting then 
    m = m .. " | ACF ready in: " .. tostring(self.preflightTimeLeft)
  end
  
  return m
  end

----------------------------------------------------
--CapSquadron 'factory' will return proper squadron type
---for given group
----------------------------------------------------

----------------------------------------------------
CapSquadron = {}
CapSquadron.Priority = CapSquadronAir.Priority

---@return CapSquadronAir
function CapSquadron:create(groupName, aircraftReady, aircraftTotal, preflightTime, combatRange, priority) 
  local firstPoint = mist.getGroupRoute(groupName)[1]
  
  if firstPoint.type == "Turning Point" then 
    
    GlobalLogger:create():debug(groupName .. " create squadron with spawn in AIR")
    return CapSquadronAir:create(groupName, aircraftReady, aircraftTotal, preflightTime, combatRange, priority)
  elseif firstPoint.type == "TakeOff" or firstPoint.type == "TakeOffParkingHot" then
    
    GlobalLogger:create():debug(groupName .. " create squadron with spawn in " .. firstPoint.type)
    return CapSquadronHot:create(groupName, aircraftReady, aircraftTotal, preflightTime, combatRange, priority)
  elseif firstPoint.type == "TakeOffParking" then
    
    GlobalLogger:create():debug(groupName .. " create squadron with COLD spawn")
    return CapSquadronCold:create(groupName, aircraftReady, aircraftTotal, preflightTime, combatRange, priority)
  else
    GlobalLogger:create():warning(groupName .. " UNSUPPORTED START TYPE")
  end
end