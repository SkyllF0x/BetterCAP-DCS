----------------------------------------------------
-- Logger for AiHandler
----------------------------------------------------
----       AbstractCAP_Handler_Object
----                  ↓                           
----              CapLogger
----------------------------------------------------
CapLogger = utils.inheritFrom(AbstractCAP_Handler_Object)
CapLogger.delimeter = "\n--------------------------------------------------------------------------------------------------------------------"
CapLogger.settingsPrefab = {}
CapLogger.settingsPrefab.allOn = {
  showMessagesInGame = true,  --output in game 
  showTargetGroupDebug = true,--show target groups status
  showTargetDebug = true,     --show individual target status
  expandedTargetDebug = true, --show additional target info(both group and individual target)
  showRadarStatus = true,     --display radar debug
  showGroupsDebug = true,     --Cap group general info
  showElementsDebug = true,   --Cap element general info
  showPlanesDebug = true,     --Cap plane general info
  showFsmStack = true,        --show fsm states
  showAwaitedGroups = true,   --show how many groups await activation
  showObjectivesDebug = true, --show objectives info
  showSquadronesDebug = true  --show squandrons info
}

CapLogger.settingsPrefab.onlyLog = {
  showMessagesInGame = false, --output in game 
  showTargetGroupDebug = true,--show target groups status
  showTargetDebug = true,     --show individual target status
  expandedTargetDebug = true, --show additional target info(both group and individual target)
  showRadarStatus = true,     --display radar debug
  showGroupsDebug = true,     --Cap group general info
  showElementsDebug = true,   --Cap element general info
  showPlanesDebug = true,     --Cap plane general info
  showFsmStack = true,        --show fsm states
  showAwaitedGroups = true,   --show how many groups await activation
  showObjectivesDebug = true, --show objectives info
  showSquadronesDebug = true  --show squandrons info
}

CapLogger.settingsPrefab.allOff = {
  showMessagesInGame = false,  --output in game 
  showTargetGroupDebug = false,--show target groups status
  showTargetDebug = false,     --show individual target status
  expandedTargetDebug = false, --show additional target info(both group and individual target)
  showRadarStatus = false,     --display radar debug
  showGroupsDebug = false,     --Cap group general info
  showElementsDebug = false,   --Cap element general info
  showPlanesDebug = false,     --Cap plane general info
  showFsmStack = false,        --show fsm states
  showAwaitedGroups = false,   --show how many groups await activation
  showObjectivesDebug = false, --show objectives info
  showSquadronesDebug = false  --show squandrons info
}

function CapLogger:create(settings) 
  local instance = {}
  instance.settings = settings or CapLogger.settingsPrefab.allOff
  
  instance.id = utils.getGeneralID()
  instance.name = "Logger-" .. tostring(instance.id)
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function CapLogger:getSettings() 
  return self.settings
end

function CapLogger:printToLog(message) 
  env.warning(message)
end

function CapLogger:printToSim(message) 
  if not self.settings.showMessagesInGame then
    return
  end
  
  trigger.action.outText(message, 5)
end


function CapLogger:printRadarsStatus(aiHandler) 
  if not self.settings.showRadarStatus then 
    return
    end
  
  local m = aiHandler.detector:getDebugStr()
  self:printToLog(m)
  self:printToSim(m)
end

function CapLogger:printTargetsStatus(aiHandler) 
  if not (self.settings.showTargetGroupDebug or self.settings.showTargetDebug) then 
    return
  end
  
  local m = ""
  
  for _, targetGroup in pairs(aiHandler.detector:getTargets()) do 
    m = m .. "\n\n"
    m = m .. targetGroup:getDebugStr(self.settings)
  end
  
  if string.len(m) == 0 then 
    return
  end
  
  m = "Detected Targets:" .. m
  
  self:printToLog(m)
  self:printToSim(m)
end



function CapLogger:printAwaitedGroups(aiHandler) 
  if not self.settings.showAwaitedGroups then return end
  
  local m = ""
  
  for _, awaited in pairs(aiHandler.deferredGroups) do 
    m = m .. "\n" .. awaited:getDebugStr(self.settings)
  end
  
  if string.len(m) == 0 then 
    return
  end
  
  m = "Not active groups: \n" .. m
  self:printToLog(m)
  self:printToSim(m)
end


function CapLogger:printObjectivesStatus(Handler) 
  if not self.settings.showObjectivesDebug then return end
  
  local m = ""
  for _, objective in pairs(Handler.objectives) do 
    m = m .. utils.getMargin(2) .. objective:getDebugStr() .. "\n"
  end
  
  if string.len(m) == 0 then 
    return
  end
  
  m = "Cap Objectives:\n" .. m
  self:printToLog(m)
  self:printToSim(m)
end

function CapLogger:printSqnStatus(Handler) 
  if not self.settings.showSquadronesDebug then return end
  
  local m = ""
  for _, sqn in pairs(Handler.squadrones) do 
    m = m .. utils.getMargin(2) ..  sqn:getDebugStr() .. "\n"
  end
  
  if string.len(m) == 0 then 
    return
  end
  
  m = "Cap Squadrones:\n" .. m
  self:printToLog(m)
  self:printToSim(m)
end

function CapLogger:printCapGroupStatus(aiHandler) 
  if not (self.settings.showGroupsDebug or self.settings.showElementsDebug or self.settings.showPlanesDebug) then 
    return
  end

  local m = ""
  for _, capGroup in pairs(aiHandler.groups) do 
    m = m .. "\n\n"
    m = m .. capGroup:getDebugStr(self.settings)
  end
  
  if string.len(m) == 0 then
    return
  end
  
  m = "Group status:" .. m
  
  self:printToLog(m)
  self:printToSim(m)
end

function CapLogger:printHandlerStatus(aiHandler) 

  self:printRadarsStatus(aiHandler)
  self:printTargetsStatus(aiHandler)
  self:printAwaitedGroups(aiHandler)
  self:printCapGroupStatus(aiHandler)
end

function CapLogger:printGciCapStatus(Handler) 

  self:printRadarsStatus(Handler)
  self:printTargetsStatus(Handler)
  self:printAwaitedGroups(Handler)
  self:printObjectivesStatus(Handler)
  self:printSqnStatus(Handler)
  self:printCapGroupStatus(Handler)
end

----------------------------------------------------
-- Global logger signleton
----------------------------------------------------
----       AbstractCAP_Handler_Object
----                  ↓                           
----             GlobalLogger
----------------------------------------------------
GlobalLogger = {}
GlobalLogger._instance = nil

GlobalLogger.LEVELS = {
  DEBUG = 1,
  INFO = 2, 
  WARNING = 4,
  ERROR = 8,
  NOTHING = 16,--nothing will be printed
  }

GlobalLogger.settingsPrefab = {}
GlobalLogger.settingsPrefab.allOn = {
  showPoints = true,                      --draw marks on F10 map
  outputInGame = true,                    --output messages to 3D
  outputInLog = true,                     --output messages to dcs.log
  level = GlobalLogger.LEVELS.DEBUG,      --lowest level of message,
  levelInGame = GlobalLogger.LEVELS.DEBUG,--lowest level to show message in game
}

GlobalLogger.settingsPrefab.standart = {
  showPoints = false,                     --draw marks on F10 map
  outputInGame = false,                   --output messages to 3D
  outputInLog = true,                     --output messages to dcs.log
  level = GlobalLogger.LEVELS.DEBUG,       --lowest level of message
  levelInGame = GlobalLogger.LEVELS.DEBUG,--lowest level to show message in game
}

GlobalLogger.settingsPrefab.allOff = {
  showPoints = true,                      --draw marks on F10 map
  outputInGame = true,                    --output messages to 3D
  outputInLog = true,                     --output messages to dcs.log
  level = GlobalLogger.LEVELS.NOTHING,    --lowest level of message
  levelInGame = GlobalLogger.LEVELS.DEBUG,--lowest level to show message in game
}

function GlobalLogger:create() 
  if self._instance then 
    return self._instance
  end
  
  local instance = {}
  setmetatable(instance, {__index = self})
  
  instance.settings = GlobalLogger.settingsPrefab.standart
  self._instance = instance
  return instance
end

function GlobalLogger:getSettings() 
  return self.settings
  end

function GlobalLogger:setNewSettings(newSettings) 
  self.settings = newSettings
  end

function GlobalLogger:printToLog(levelStr, message)
  if type(message) ~= "string" then 
    self:warning("ATTEMPT TO PRINT NON STRING")
    self:warning(mist.utils.serializeWithCycles("MESSAGE TYPE OF: " .. type(message), message))
    return
  end
  
  env.info("BetterCap logger: " .. levelStr .. message)
end

function GlobalLogger:printToSim(levelStr, message, level)
  if not self.settings.outputInGame or self.settings.levelInGame > level then 
    return
    end
  if type(message) ~= "string" then 
    self:warning("ATTEMPT TO PRINT NON STRING")
    self:warning(mist.utils.serializeWithCycles("MESSAGE TYPE OF: " .. type(message), message))
    return
  end
  
  trigger.action.outText("BetterCap logger: " .. levelStr .. message, 10)
end

function GlobalLogger:debug(message) 
  self:printToSim("DEBUG: ", message, GlobalLogger.LEVELS.DEBUG)

  if self.settings.level > GlobalLogger.LEVELS.DEBUG then 
    return
  end
  
  self:printToLog("DEBUG: ", message)
end

function GlobalLogger:info(message) 
  self:printToSim("INFO: ", message, GlobalLogger.LEVELS.INFO)

  if self.settings.level > GlobalLogger.LEVELS.INFO then 
    return
  end
  
  self:printToLog("INFO: ", message)
end

function GlobalLogger:warning(message) 
  self:printToSim("WARNING: ", message, GlobalLogger.LEVELS.WARNING)

  if self.settings.level > GlobalLogger.LEVELS.WARNING then 
    return
  end
  
  self:printToLog("WARNING: ", message)
end

function GlobalLogger:error(message) 
  self:printToSim("WARNING: ", message, GlobalLogger.LEVELS.WARNING)

  if self.settings.level > GlobalLogger.LEVELS.ERROR then 
    return
  end
  
  self:printToLog("ERROR: ", message)
end

function GlobalLogger:addToFile(message) 
  if _G["io"] and _G["os"] and _G['lfs'] and
    package.loaded["io"] and package.loaded["os"] and package.loaded["lfs"] then 
    --packages not sanitized
      local file = io.open("BetterCAP_DUMPS.txt", "a")
      if not file then 
        file = io.open("BetterCAP_DUMPS.txt", "w")
        if not file then return end
      end
      file:write( "-----------------" ..tostring(timer.getAbsTime()) .. "-----------------" )
      file:write(message)
      file:close()
  end
end

function GlobalLogger:drawPoint(data)
  if not self.settings.showPoints then 
    return
  end
  
  mist.marker.add(data)
end
