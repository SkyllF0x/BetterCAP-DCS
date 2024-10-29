----------------------------------------------------
-- abstract mainloop class
----------------------------------------------------
----       AbstractCAP_Handler_Object
----                  ↓                           
----           AbstractMainloop
----------------------------------------------------
AbstractMainloop = utils.inheritFrom(AbstractCAP_Handler_Object)
AbstractMainloop.coalition = {}
AbstractMainloop.coalition.RED = 1
AbstractMainloop.coalition.BLUE = 2

function AbstractMainloop:create(coalition) 
  local instance = {}
  
  instance.id = utils.getGeneralID()
  instance.name = "Handler-" .. tostring(instance.id)
  instance.coalition = coalition
  instance.pollTime = 5
  instance.logger = CapLogger:create()
  instance.detector = DetectionHandler:create(instance.coalition)
  
  --active and alive CapGroup instance
  instance.groups = {}
  
  --radar and capGroup classes, by default Detecton cheks is ENABLED
  instance.radarClass = RadarWrapperWithChecks
  instance.groupClass = CapGroupWithChecks
  
  --groups await for activation
  instance.deferredGroups = {}
  
  --count how many error each group count
  instance.groupErrors = {}
  instance.detectorErrors = 0
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function AbstractMainloop:getDebugSettings()  
  return self.logger:getSettings()
end

function AbstractMainloop:setDebugSettings(settingTable)  
  self.logger.settings = settingTable
end

function AbstractMainloop:checkObjectCoalition(dcsObject) 
  return dcsObject:getCoalition() == self.coalition
  end

function AbstractMainloop:addAwacs(awacsUnit) 
  if not self:checkObjectCoalition(awacsUnit) then 
    utils.printToSim(awacsUnit:getName() .. " AWACS WITH WRONG COALITION")
    return
   elseif not (awacsUnit:hasAttribute('AWACS')) then 
    utils.printToSim(awacsUnit:getName() .. " IS NOT A AWACS")
    return
  end
  
  self.detector:addRadar(self.radarClass:create(awacsUnit))
end

function AbstractMainloop:addRadar(radar) 
  if not self:checkObjectCoalition(radar) then 
    utils.printToSim(radar:getName() .. " RADAR WITH WRONG COALITION")
    return
  elseif not (radar:hasAttribute('SAM SR') or radar:hasAttribute('EWR') or radar:hasAttribute("Armed ships")) then 
    utils.printToSim(radar:getName() .. " IS NOT A RADAR")
    return
  end
  
  self.detector:addRadar(self.radarClass:create(radar))
end

--add ALL EW from coalition
function AbstractMainloop:addEWs() 
  for _, group in pairs(coalition.getGroups(self.coalition, Group.Category.GROUND)) do 
    
    for _, unit in pairs(group:getUnits()) do 
      if unit:hasAttribute("EWR") then 
          self.detector:addRadar(self.radarClass:create(unit))
      end
    end
  end
  
end

function AbstractMainloop:deleteGroup(group) 
  --remove from groupErrors and groups
  self.groups[group:getID()] = nil
  self.groupErrors[group:getID()] = nil
end

function AbstractMainloop:callGroupInProtected(capGroup) 
  local function protectedWrapper(group) 
    group:update()
    if group:isExist() then 
      group:setFSM_Arg("contacts", self.detector:getHostileTargets())
      group:setFSM_Arg("radars", self.detector:getRadars())
      
      group:callFSM()
      
      if group:getAutonomous() then 
        self.detector:addFighterGroup(group)
      end
    else
      self:deleteGroup(group)
    end
  end
  
  local result, _error = xpcall(function() protectedWrapper(capGroup) end, debug.traceback)
  if not result then 
    self.groupErrors[capGroup:getID()] = self.groupErrors[capGroup:getID()] + 1
    
    GlobalLogger:create():error("AiHandler: " .. tostring(self.groupErrors[capGroup:getID()]) 
      .. " error during processing group: "..  capGroup:getName() .. "\nTraceback: \n" .. _error)
  else
    --update successful, clear counter
    self.groupErrors[capGroup:getID()] = 0
  end
end

function AbstractMainloop:checkGroupErrors() 
  for id, group in pairs(self.groups) do 
    if self.groupErrors[id] > 3 then 
      GlobalLogger:create():warning(group:getName() .. " 3 errors, excluded")
      self.groups[id] = nil
      self.groupErrors[id] = nil
    end
  end
  
end

function AbstractMainloop:updateDetectorInProtected() 
  local result, _err = xpcall(
    function()
      self.detector:update()
    end, 
    debug.traceback)
  
  if not result then 
    self.detectorErrors = self.detectorErrors + 1
    GlobalLogger:create():error("AiHandler: error during detector update, traceback: \n" .. debug.traceback)
  else
    self.detectorErrors = 0
  end
  
  if self.detectorErrors > 3 then 
    error("AiHandler: detector has more 3 errors")
  end
end

--check if group ready and if so, activate it
function AbstractMainloop:checkAwaitedGroups() 
  
  for id, container in pairs(self.deferredGroups) do 
    if container:isActive() then 
      self:spawnGroup(container)
      self.deferredGroups[id] = nil
    end
  end
end


function AbstractMainloop:spawnGroup(container)
  local result, _err = xpcall(function()
      local planes = {}
      for _, plane in pairs(container:activate()) do
        planes[#planes+1] = CapPlane:create(plane)
      end
      --check if we got some planes
      if #planes == 0 then 
        GlobalLogger:create():info(container:getName() .. " all dead, nothing to spawn")
        return
      end 
      
      --remove first wp, cause it's a spawn point
      local group = self.groupClass:create(planes, container:getOriginalName(), GroupRoute:create(mist.getGroupRoute(container:getOriginalName())))
      --move settings
      container:setSettings(group)
      self.groups[group:getID()] = group
      self.groupErrors[group:getID()] = 0
      
      GlobalLogger:create():info(group:getName() .. " activated with: " .. tostring(group:getOriginalSize()) .. " planes")
    end, debug.traceback)

  if not result then 
    GlobalLogger:create():error(container:getName() .. " Error during creation, traceback: \n" .. _err)
  end
end

function AbstractMainloop:mainloop() 
  
end

function AbstractMainloop:mainloopWrapper() 
  local status, errorCode = xpcall(function() self:mainloop() end, debug.traceback)
  
  if not status then 
    --something goes wrong
    self:setDebugSettings(CapLogger.settingsPrefab.onlyLog)
    env.info("AI HANDLER CRITICAL ERROR: " .. errorCode .. "\n SCRIPT DUMP")
    self.logger:printHandlerStatus(self)
    return 
  end
  
  return timer.getTime() + self.pollTime
end

function AbstractMainloop:start() 
  
end
----------------------------------------------------
-- Main loop class for ai Handling
----------------------------------------------------
----       AbstractCAP_Handler_Object
----                  ↓                           
----           AbstractMainloop
----                  ↓                           
----              AiHandler
----------------------------------------------------

AiHandler = utils.inheritFrom(AbstractMainloop)
AiHandler.coalition = AbstractMainloop.coalition

function AiHandler:addGroup(group) 

  if not rawget(utils.PlanesTypes, group:getUnit(1):getTypeName()) then
    local msg = "GROUP: " .. group:getName() .. " SKIPPED, NOT SUPPORTED TYPE: " .. group:getUnit(1):getTypeName()
    utils.printToSim(msg)
    GlobalLogger:create():error(msg)
    return
  end
  
  local groupTbl = mist.getGroupTable(group:getName())
  if not groupTbl then 
    utils.printToSim("GROUP: " .. group:getName() .. " NOT FINDED BY MIST")
    GlobalLogger:create():error("GROUP: " .. group:getName() .. " NOT FINDED BY MIST")
    return
  end

  if groupTbl.uncontrolled then 
    --group spawn with disabled ai
    local cont = AiDeferredContainer:create(group, groupTbl)
    self.deferredGroups[cont:getID()] = cont
  else
    local cont = TimeDeferredContainer:create(group, groupTbl)
    self.deferredGroups[cont:getID()] = cont
  end
end

function AiHandler:addCapGroupByName(name) 
  local group = Group.getByName(name)
  
  if not group then 
    utils.printToSim("CAN'T FIND GROUP WITH NAME: " .. name)
    return 
  elseif not self:checkObjectCoalition(group) then
    utils.printToSim("GROUP: " .. group:getName() .. " NOT BELONG TO MY COALITION")
    return 
  end
  
  self:addGroup(group)
end

function AiHandler:addCapGroupsByPrefix(prefix) 
  for _, group in pairs(utils.getItemsByPrefix(coalition.getGroups(self.coalition, 0), prefix)) do 
    self:addGroup(group)
    end
  end

--return ALL groups, active and avaited
--should used for setting options via methods
function AiHandler:getCapGroups() 
  local result = {}
  
  for _, aliveGroup in pairs(self.groups) do  
    result[#result + 1] = aliveGroup
  end
  
  for _, awaitedGroup in pairs(self.deferredGroups) do 
    result[#result + 1] = awaitedGroup
  end
  
  return utils.chainContainer:create(result)
end

function AiHandler:getCapGroupByName(groupName) 
  
  for _, group in pairs(self:getCapGroups()) do 

    if string.find(group:getName(), groupName) then 
      return group
    end
  end
end


function AiHandler:mainloop() 
  --check not active group and activate if ready
  self:checkAwaitedGroups()
 
  --update targets
  self:updateDetectorInProtected()
  
  --update groups
  for _, group in pairs(self.groups) do 
    self:callGroupInProtected(group)
  end
  
  self:checkGroupErrors()
  pcall(function() self.logger:printHandlerStatus(self) end)
end


function AiHandler:start() 
  timer.scheduleFunction(AiHandler.mainloopWrapper, self, timer.getTime()+1)
end

----------------------------------------------------
-- Main loop class for GciCap Module
----------------------------------------------------
----       AbstractCAP_Handler_Object
----                  ↓                           
----           AbstractMainloop
----                  ↓                           
----             GciCapHandler
----------------------------------------------------

GciCapHandler = utils.inheritFrom(AbstractMainloop)
GciCapHandler.coalition = AbstractMainloop.coalition

function GciCapHandler:create(coalition, groupLimit) 
  local instance = self:super():create(coalition)

  --replace groupClass
  instance.groupClass = CapGroupRouteWithChecks
  
  instance.squadrones = {}
  instance.objectives = {}
  instance.airborneGroupLimit = groupLimit or 4 --how many groups can be in air at one time
  instance.minimumGroupSize = 2 
  
  --counters for current val
  instance.airborneCount = 0
  
  --settings:
  
  --will only spawn groups with size 2 or 4, when request > 3 then 4, else 2
  instance.onlyEvenGroups = false
  --if container return less then requested, will deactivate group and start searching againg
  instance.discardDamagedGroups = true
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function GciCapHandler:setAirborneLimit(newVal)
  self.airborneGroupLimit = newVal
  end

function GciCapHandler:allowSignletonGroups(val)
  if val then 
    self.minimumGroupSize = 1
  else
    self.minimumGroupSize = 2
  end
end

function GciCapHandler:setForceEvenGroup(val) 
  self.onlyEvenGroups = val
end

function GciCapHandler:setDiscardDamaged(val) 
  self.discardDamagedGroups = val
end

function GciCapHandler:addSquadron(sqn, generateObj, objRadius) 
  if not self:checkObjectCoalition(sqn) then
    utils.printToSim(sqn:getName() .. " SQN WITH WRONG COALITION(try change original group side)")
    return
  elseif self.squadrones[sqn:getID()] then
    GlobalLogger:create():debug(sqn:getName() .. " already in handler" )
  end
  
  self.squadrones[sqn:getID()] = sqn
  --add sqn to all objectives
  for _, objective in pairs(self.objectives) do 
    objective:addSquadron(sqn)
  end
  
  if not generateObj then
    return
  end

  --add objective 
  self:addObjective(sqn:generateObjective(objRadius))
end

--if you make priority changes in objectives AFTER adding to class, call this
function GciCapHandler:sortObjectives() 
  table.sort(self.objectives, function(item1, item2) return item1:getPriority() > item2:getPriority() end)
end

function GciCapHandler:addObjective(obj) 
  --push sqn to objective
  for _, sqn in pairs(self.squadrones) do 
    obj:addSquadron(sqn)
  end

  --check if we already have it
  for _, objective in pairs(self.objectives) do 
    if obj == objective then 
      GlobalLogger:create():debug(obj:getName() .. " already in handler" )
      return
    end
  end

  self.objectives[#self.objectives + 1] = obj
  self:sortObjectives()
end

function GciCapHandler:deleteObjective(obj)
  
  for i = 1, #self.objectives do 
    if obj == self.objectives[i] then 
      table.remove(self.objectives, i)
      return
    end
  end
end

function GciCapHandler:wipeObjectives()
  
  self.objectives = {}
end

function GciCapHandler:getSquadrones() 
  local resultArr = {}
  
  for _, sqn in pairs(self.squadrones) do 
    resultArr[#resultArr+1] = sqn
  end
  
  return utils.chainContainer:create(resultArr)
end

function GciCapHandler:getObjectives() 
  local resultArr = {}
  
  for _, sqn in pairs(self.objectives) do 
    resultArr[#resultArr+1] = sqn
  end
  return utils.chainContainer:create(resultArr)
end


function GciCapHandler:deleteGroup(group) 
  --decrement counter
  self.airborneCount = self.airborneCount - 1
  self:super().deleteGroup(self, group)
end

--not use route from prototype(group will create route on it's own using objective)
function GciCapHandler:spawnGroup(container) 
  local result, _err = xpcall(function()
      local planes = {}
      for _, plane in pairs(container:activate()) do
        planes[#planes+1] = CapPlane:create(plane)
      end
      
      --check if we don't get any planes
      if #planes == 0 then 
        GlobalLogger:create():info(container:getName() .. " all dead, nothing to spawn")
        --remove planes from objective
        container:getObjective():addCapPlanes(-container:getOriginalSize())
        return
      elseif self.discardDamagedGroups and #planes ~= container:getOriginalSize() then
        GlobalLogger:create():info(container:getName() .. " damaged, discard")
        
        --remove planes from objective
        container:getObjective():addCapPlanes(-container:getOriginalSize())
        --return remaining to sqn
        container:getSquadron():returnAircrafts(#planes)
        --delete planes
        for _, plane in pairs(planes) do 
          plane:getObject():destroy()
        end
        
        return
      end 
      
      local group = self.groupClass:create(planes, container:getObjective(), container:getSquadron())
      --maybe some planes was destroyed during creation, remove delta
      container:getObjective():addCapPlanes(group:getOriginalSize() - container:getOriginalSize())
      
      --move settings
      container:setSettings(group)
      self.groups[group:getID()] = group
      self.groupErrors[group:getID()] = 0
      
      GlobalLogger:create():info(group:getName() .. " is activated with " .. tostring(group:getOriginalSize() .. " planes"))
    end, debug.traceback)

  if not result then 
    GlobalLogger:create():error(container:getName() .. " Error during creation, traceback: \n" .. mist.utils.serialize("", _err))
  end
end


function GciCapHandler:getMinSize() 
  
  if not self.onlyEvenGroups then 
    return self.minimumGroupSize
  end 
  
  --if request even group, can't be below 2
  return 2
end

--request can exceed group maximum capability(4), so will spawn multiply groups
function GciCapHandler:createNewGroupsFromSqn(sqn, objective, aircraftCount, requestReady) 
  
  while aircraftCount >= self:getMinSize() and self.airborneCount < self.airborneGroupLimit and sqn:getCounter() > 0 do 
    local amountToSpawn = math.min(aircraftCount, 4, sqn:getCounter())
    local cont = {}
    
    if requestReady then 
      cont = sqn:getReadyGroup(amountToSpawn, objective)
      GlobalLogger:create():info("Request ready group: " .. cont:getName() .. " with size " .. tostring(cont:getOriginalSize()))
    else
      cont = sqn:getGroup(amountToSpawn, objective)
      GlobalLogger:create():info("Request standart group: " .. cont:getName() .. " with size " .. tostring(cont:getOriginalSize()))
    end
    
    aircraftCount = aircraftCount - amountToSpawn
    self.airborneCount = self.airborneCount + 1
    
    self.deferredGroups[cont:getID()] = cont
  end
end

function GciCapHandler:spawnAircraftsForObjective(objective, aircraftNeeded, requestReady) 
  
  local minSize = self:getMinSize()
  local roundTo = 1
  if self.onlyEvenGroups then 
    roundTo = 2
  end
  
  --NO CHECK FOR aircraftNeeded < minSize
  local sqnCandidates = {}
  if requestReady then 
    for sqn in objective:getSquadrons() do 
      
      if sqn:getReadyCount() >= minSize then 
      
        --round to closest LOWEST odd val
        local request = math.floor(math.min(sqn:getReadyCount(), aircraftNeeded) / roundTo) * roundTo
        self:createNewGroupsFromSqn(sqn, objective, request, requestReady) 
        aircraftNeeded = aircraftNeeded - request
      end
    end
  else
    for sqn in objective:getSquadrons() do 
      
      if sqn:getCounter() >= minSize then 
      
        --round to closest LOWEST odd val
        local request = math.floor(math.min(sqn:getCounter(), aircraftNeeded) / roundTo) * roundTo
        self:createNewGroupsFromSqn(sqn, objective, request, requestReady) 
        aircraftNeeded = aircraftNeeded - request
      end
    end
  end

  if requestReady then
    self:spawnAircraftsForObjective(objective, aircraftNeeded, false) 
  end
end

--return array with groups which can be retasked for given objective sorted by range
function GciCapHandler:getGroupsForRetask(objective)
  local result = {}
  local TTG_lookUp = {}
  
  local function insertToList(item, TTG) 
    for i = 1, #result do 
      if TTG_lookUp[result[i]:getID()] > TTG then 
        table.insert(result, i, item)
        TTG_lookUp[item:getID()] = TTG
        return
      end
    end
    
    result[#result + 1] = item
    TTG_lookUp[item:getID()] = TTG
  end
  
  local objPos = objective:getPoint()
  for _, group in pairs(self.groups) do 
    local TTG = mist.utils.get2DDist(objective:getPoint(), group:getPoint()) / 300 --time to reach target with speed of 300m/s
    if group:canRetask() and TTG <= 600 then 
      insertToList(group, TTG)
    end
  end
  
  return result
end

--try to relocate one of group or spawn new if can
function GciCapHandler:addGciForObjective(objective, aircraftNeeded) 

  local minSize = self:getMinSize()

  --firstly try to relocate(group can change task and ETA at 300m/s less then 10min)
  for _, group in pairs(self:getGroupsForRetask(objective)) do 
    group:setNewObjective(objective)
    
    aircraftNeeded = aircraftNeeded - group:getOriginalSize()
    if aircraftNeeded < minSize then 
      --we done here
      return
    end
    --else continue add until satisfy requirement or no groups left
  end
  
  --no groups can take this task, try spawn new
  if self.airborneGroupLimit - self.airborneCount < 1 then 
    return
  end
  
  --need planes ASAP, request ready planes
  self:spawnAircraftsForObjective(objective, aircraftNeeded, true)
end

--check objectives for gci and spawn if needed
function GciCapHandler:checkGci() 
  
  local minSize = self:getMinSize()
  
  for _, objective in pairs(self.objectives) do 
    local gciNeeded = objective:getGciRequest()
    
    if gciNeeded >= minSize then 
      self:addGciForObjective(objective, gciNeeded)
    end
  end
end


function GciCapHandler:checkCap() 
  if self.airborneGroupLimit - self.airborneCount < 1 then 
    return
  end
  
  local minSize = self:getMinSize()
  
  for _, objective in pairs(self.objectives) do 
    local capNeeded = objective:getCapRequest()
    
    --no check for airborneGroupLimit because createNewGroupsFromSqn() won't spawn group if counter full
    if capNeeded >= minSize then 
      --don't need planes now, request non ready group
      self:spawnAircraftsForObjective(objective, capNeeded, false) 
    end
  end
end

function GciCapHandler:mainloop() 
  --update targets
  self:updateDetectorInProtected()
  
 --update objectives
  local targets = self.detector:getHostileTargets()
  for _, objective in pairs(self.objectives) do 
    objective:update(targets)
  end
  
  --update sqn's
  for _, squadron in pairs(self.squadrones) do 
    squadron:update()
  end
  
  --check objectives for gci and spawn if needed
  self:checkGci()
  --check objectives for cap and spawn if needed
  self:checkCap()
  
  --check not active group and activate if ready
  self:checkAwaitedGroups()
  
  --update groups
  for _, group in pairs(self.groups) do 
    self:callGroupInProtected(group)
  end
  
  self:checkGroupErrors()
  pcall(function() self.logger:printGciCapStatus(self) end)
end

function GciCapHandler:start() 
  timer.scheduleFunction(GciCapHandler.mainloopWrapper, self, timer.getTime()+1)
end