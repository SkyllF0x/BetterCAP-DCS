----------------------------------------------------
-- deferred group(unit that will be activated later, 
-- i.e. late activation flag or with disable AI)
-- will be wrapped here and at start() will be spawned
-- and returned as valid group object 
-- or nil if we can't spawn(i.e. Carrier was sunk)
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----------------------------------------------------
--metatable for registering calls to capGroup and save it
local MT = {__index = function(tbl, key) 
      --search in table and in parent class
      local item = rawget(tbl, key) or tbl:super()[key]
      if item then 
        --item is class method/arg
        return item
      end
      
      --item is capGroupSetting call
      tbl[key] = function(tbl2, ...)
        tbl2.groupSettings[key] = {...}
      end
      return tbl[key]
    end
  }

AbstractDeferredContainer = utils.inheritFrom(AbstractCAP_Handler_Object)
setmetatable(AbstractDeferredContainer, MT) 
  

--will spawn/activate aircraft group
--group will be returned as multiply groups, each contain 1 unit 
--from original group(order presumed)
function AbstractDeferredContainer:create(name) 
  local instance = {}
  
  instance.name = "Container-" .. name
  
  --if we try to set setting to group which not activated, they will be stored here
  -- "name of func" = 'array of args'
  -- and will be called during creation
  instance.groupSettings = {}
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function AbstractDeferredContainer:activate() 
  
end


--return true when we can activate group
function AbstractDeferredContainer:isActive() 

end

--call all methods from groupSettings
function AbstractDeferredContainer:setSettings(capGroup)
  local counter = 0
  
  for funcName, funcArgs in pairs(self.groupSettings) do 
    capGroup[funcName](capGroup, unpack(funcArgs))
    counter = counter + 1
  end
  GlobalLogger:create():debug(capGroup:getName() .. " succesfully transfered " .. tostring(counter) .. " settings calls")
end

function AbstractDeferredContainer:getDebugStr(settings) 
  return utils.getMargin(2) .. self.name
  end
----------------------------------------------------
-- end of AbstractDeferredContainer
----------------------------------------------------


----------------------------------------------------
-- deferred group is invisible in 3d
-- spawn new group on activate()
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----          TimeDeferredContainer
----------------------------------------------------

TimeDeferredContainer = utils.inheritFrom(AbstractDeferredContainer)

--will spawn/activate aircraft group
--group will be returned as multiply groups, each contain 1 unit 
--from original group(order presumed)
function TimeDeferredContainer:create(awaitedGroup, groupTable) 
  local instance = self:super():create(awaitedGroup:getName())
  instance.groupName = awaitedGroup:getName()
  instance.group = awaitedGroup
  instance.groupTable = groupTable
  instance.id = awaitedGroup:getID()

  --save original coalition
  instance.country = awaitedGroup:getUnit(1):getCountry()
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--original group name
function TimeDeferredContainer:getOriginalName() 
  return self.groupName
end

--use controller for detection active groups or not
function TimeDeferredContainer:isActive() 
  return self.group:getController():hasTask()
  end

--return our true if our airbase is valid and we can spawn
function TimeDeferredContainer:checkForAirbase() 
  local airport, hasAirportSpawn = nil, false
  if self.groupTable.route.points[1].type == "TakeOff" 
    or self.groupTable.route.points[1].type == "TakeOffParking" 
    or self.groupTable.route.points[1].type == "TakeOffParkingHot" then 
   
    hasAirportSpawn = true
   
    --group start from ground
    if self.groupTable.route.points[1].airdromeId then 
      --we takeoff from airfield
      airport = AirbaseWrapper:create(self.groupTable.route.points[1].airdromeId)

    elseif self.groupTable.route.points[1].linkUnit then 
      --we takeoff from ship
      airport = CarrierWrapper:create(self.groupTable.route.points[1].linkUnit)
    end
  end 
  
  if airport then 
    return airport:isAvail()
  end
  
  return not hasAirportSpawn
end


--generate valid spawn table
function TimeDeferredContainer:getSpawnTable(unit, unitNbr) 
--[[
  local spawnTable = {
    hidden = self.groupTable.hidden,
    name = unit.name .. "-BC-" ..tostring(unitNbr),
    x = unit.x,
    y = unit.y,
    task = "CAP",
    route = self.groupTable.route,
    units = {
      [1] = {
        name = unit.name .. "-BC-" ..tostring(unitNbr),
        type = unit.type,
        x = unit.x,
        y = unit.y,
        alt = unit.alt,
        alt_type = unit.alt_type,
        speed = unit.speed,
        payload = unit.payload,
        callsign = unit.callsign,
        heading = unit.heading
        }
      }
    }--]]
    
  local spawnTable = mist.utils.deepCopy(self.groupTable)
  spawnTable.task = "CAP"
  spawnTable.uncontrolled = nil
  spawnTable.lateActivation = nil
  spawnTable.start_time = nil
  spawnTable.units = {}
  spawnTable.units[1] = unit
  spawnTable.units[1].name = unit.name .. "-BC-" ..tostring(unitNbr)
  return spawnTable
 end


--activate group and return array where each unit in individual group or nil
function TimeDeferredContainer:activate() 
  --deactivate original group
  self.group:destroy()
  
  --firstly decide what spawn we use
  if not self:checkForAirbase() then 
    --cant spawn here
    GlobalLogger:create():warning(self.groupTable.name .. " CANT SPAWN, FIELD UNAVAIL")
    return {}
  end
  
  local result = {}
  --create our own table
  for unitNbr, unit in pairs(self.groupTable.units) do 
    result[unitNbr] = coalition.addGroup(self.country, Group.Category.AIRPLANE, self:getSpawnTable(unit, unitNbr))
  end
  return result
end
----------------------------------------------------
-- end of DeferredContainer
----------------------------------------------------


----------------------------------------------------
-- deferred group is in 3d, but no AI
-- spawn new group on activate(), 
-- but also checks is original units still alive
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----          TimeDeferredContainer
----                  ↓
----          AiDeferredContainer
----------------------------------------------------

AiDeferredContainer = utils.inheritFrom(TimeDeferredContainer)

function AiDeferredContainer:activate()
  
  --firstly decide what spawn we use
  if not self:checkForAirbase() then 
    --cant spawn here
    GlobalLogger:create():warning(self.groupTable.name .. " CANT SPAWN, FIELD UNAVAIL")
    return {}
  end
  
  --table with units
  local units = {}
  for _, unit in pairs(self.group:getUnits()) do 
      units[unit:getID()] = unit
    end
  
  local result = {}
  --create our own table
  for unitNbr, unit in pairs(self.groupTable.units) do 
    --check if unit still alive
    local _dcsUnit = units[tostring(unit.unitId)]
    if _dcsUnit and _dcsUnit:isExist() then --also check we processing current unit
      _dcsUnit:destroy()
      result[unitNbr] = coalition.addGroup(self.country, Group.Category.AIRPLANE, self:getSpawnTable(unit, unitNbr))
    end
  end
  return result
end

----------------------------------------------------
-- Abstract class for container which used by CapSquadron
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----        AbstractSquadronContainer
----------------------------------------------------

AbstractSquadronContainer = utils.inheritFrom(AbstractDeferredContainer)

function AbstractSquadronContainer:create(squadron, objective, numberOfAircraftToSpawn, activateTime)
  local id = utils.getGeneralID()
  local instance = self:super():create(squadron:getName())
  instance.id = id
  
  instance.sqn = squadron
  instance.objective = objective
  instance.amountToSpawn = numberOfAircraftToSpawn
  instance.activateTime = activateTime
  
  --add planes to objective
  instance.objective:addCapPlanes(instance.amountToSpawn)
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function AbstractSquadronContainer:isActive() 
  return timer.getAbsTime() >= self.activateTime 
end 

function AbstractSquadronContainer:setSettings(group) 
  --transfer settings from squadron to spawned group
  group:setBingo(self.sqn.squadronBingo)
  group:setRTBWhen(self.sqn.rtbAmmo)
  group:setDeactivateWhen(self.sqn.deactivateWhen)
  group:setPriorities(
    self.sqn.priorityForTypes[AbstractTarget.TypeModifier.FIGHTER], 
    self.sqn.priorityForTypes[AbstractTarget.TypeModifier.ATTACKER], 
    self.sqn.priorityForTypes[AbstractTarget.TypeModifier.HELI]
  )
  group:setTactics(self.sqn.preferredTactics)
  group:setGoLiveThreshold(self.sqn.goLiveThreshold)
  group:setALR(self.sqn.alr)
end

function AbstractSquadronContainer:getObjective() 
  return self.objective
end

function AbstractSquadronContainer:getSquadron() 
  return self.sqn
end

function AbstractSquadronContainer:getOriginalSize() 
  return self.amountToSpawn
end

function AbstractSquadronContainer:getDebugStr(settings) 
  return utils.getMargin(2) .. self.name .. " will be active in: " .. tostring(self.activateTime - timer.getAbsTime())
  end

----------------------------------------------------
-- for Airspawn cases
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----        AbstractSquadronContainer
----                  ↓
----             AirContainer
----------------------------------------------------

AirContainer = utils.inheritFrom(AbstractSquadronContainer)

function AirContainer:create(squadron, objective, numberOfAircraftToSpawn, activateTime)
  --or will get error, cause super() firstly return AbstractSquadronContainer and only then AbstractDeferredContainer
  return setmetatable(self:super():create(squadron, objective, numberOfAircraftToSpawn, activateTime), {__index = self, __eq = utils.compareTables})
end

function AirContainer:activate() 
  local result = {}
 
  local spawnTable = mist.utils.deepCopy(self.sqn:getPrototypeTable())
 
  local groupID = utils.getUnitID()
  spawnTable.groupId = nil --DCS will create new
  spawnTable.units[1].unitId = nil
  
  --shift pos, so each unit has different pos
  local randomShift = mist.random(10000) --if multiply groups spawn simultaniously, this should redure chance of collition(i hope)
  local groupPos = {x = spawnTable.units[1].x + randomShift, z = spawnTable.units[1].y + randomShift, y = spawnTable.units[1].alt}
  local shiftVec = mist.projectPoint({x = 0, y = 0, z = 0}, 500, (spawnTable.units[1].heading or 0) + math.pi / 2) --will spawn in 500m LAB
  
  --create our own table
  for i = 1, self.amountToSpawn do 
    
    spawnTable.name = self.sqn:getName() .. "-group-" .. tostring(groupID) .. "-" .. tostring(i) --name for group
    spawnTable.units[1].name = self.sqn:getName() .. "-unit-" .. tostring(groupID) .. "-" .. tostring(i)
    --modify position
    spawnTable.x = groupPos.x
    spawnTable.y = groupPos.y
    spawnTable.units[1].x = groupPos.x
    spawnTable.units[1].y = groupPos.z
    spawnTable.route.points[1].x = groupPos.x
    spawnTable.route.points[1].y = groupPos.z
    
    result[i] = coalition.addGroup(self.sqn:getCountry(), Group.Category.AIRPLANE, spawnTable)
    
    --shift pos
    groupPos = mist.vec.add(groupPos, shiftVec)
  end
  
  
  return result
end

----------------------------------------------------
-- for spawn on airbases in hot states(hot part/RWY)
-- will NOT spawn if airbase not avail
--- if amount of free parking < group size will use spawn on RWY
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----        AbstractSquadronContainer
----                  ↓
----             AirContainer
----                  ↓
----             HotContainer
----------------------------------------------------

HotContainer = utils.inheritFrom(AirContainer)

--no spawn if spawn field unavail
function HotContainer:activate() 
  if not self.sqn:getAirbase():isAvail() then 
    --cant spawn here
    GlobalLogger:create():warning(self:getName() .. " CANT SPAWN, FIELD UNAVAIL")
    return {}
  end
 
  local spawnTable = mist.utils.deepCopy(self.sqn:getPrototypeTable())
  if self.amountToSpawn > self.sqn:getAirbase():howManyParkingAvail() then 
    --use spawn from RWY
    spawnTable.route.points[1].type = "TakeOff"
    spawnTable.route.points[1].action = "From Runway"

    local pos = self.sqn:getHomeWP()
    spawnTable.route.points[1].x = pos.x
    spawnTable.route.points[1].y = pos.y
    spawnTable.route.points[1].alt = pos.alt 
  end
 
  local groupID = utils.getUnitID()
  spawnTable.groupId = nil --DCS will create new
  spawnTable.units[1].unitId = nil
  
  local result = {}
  --create our own table
  for i = 1, self.amountToSpawn do 

    spawnTable.name = self.sqn:getName() .. "-group-" .. tostring(groupID) .. "-" .. tostring(i) --name for group
    spawnTable.units[1].name = self.sqn:getName() .. "-unit-" .. tostring(groupID) .. "-" .. tostring(i)
    
    result[#result + 1] = coalition.addGroup(self.sqn:getCountry(), Group.Category.AIRPLANE, spawnTable)
  end
  
  return result
end

----------------------------------------------------
-- for spawn on airbases in cold state, when time come
-- will use aircraft from squadron.airplanes and push task to him
-- delete planes from squadron.airplanes
----------------------------------------------------
----         AbstractCAP_Handler_Object
----                  ↓
----        AbstractDeferredContainer
----                  ↓
----        AbstractSquadronContainer
----                  ↓
----             AirContainer
----                  ↓
----             HotContainer
----                  ↓
----            ColdContainer
----------------------------------------------------

ColdContainer = utils.inheritFrom(HotContainer)

function ColdContainer:activate() 
  if not self.sqn:getAirbase():isAvail() then 
    --cant spawn here
    GlobalLogger:create():warning(self:getName() .. " CANT SPAWN, FIELD UNAVAIL")
    return {}
  end
  
 local result = {}
 
  --create our own table
  for _, plane in pairs(self.sqn:getPlanes(self.amountToSpawn)) do 
    --check if plane dead already(i.e. bombed on RWY)
    if plane and plane:isExist() then
      
      --start aircraft
      plane:getController():setCommand({ 
        id = 'Start', 
        params = { 
        } 
      })
      result[#result + 1] = plane
    end
  end
  
  return result
end

