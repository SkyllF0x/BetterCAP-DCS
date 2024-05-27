----------------------------------------------------
-- FSM State for CapPlane
----------------------------------------------------
----             AbstractState
----                  ↓
----           AbstractPlane_FSM
----------------------------------------------------

AbstractPlane_FSM = utils.inheritFrom(AbstractState)
AbstractPlane_FSM.enumerators = {
  AbstractPlane_FSM = 1,
  FSM_WithDefence = 2,
  FSM_FlyToPoint = 4,
  FSM_FixAoa = 8,
  FSM_Formation = 16,
  FSM_Defence = 32,
  FSM_ForcedAttack = 64,
  FSM_Attack = 128,
  FSM_WVR = 256,
  FSM_FlyOrbit = 512,
  FSM_PlaneRTB = 1024,
  } 

function AbstractPlane_FSM:create(handledObj) 
  local instance = self:super():create(handledObj)

  instance.name = "AbstractPlane_FSM"
  instance.enumerator = AbstractPlane_FSM.enumerators.AbstractPlane_FSM
  instance.task = {}
  instance.AoA_time = nil
  instance.options = {}
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end
--check if we got AoA stuck bug(aircraft just fly at high Aoa and can't accelerate)
function AbstractPlane_FSM:checkAoA() 
  --~16 deg aoa
  if self.object:getAoA() > 0.28 then 
    if not self.AoA_time then
      --set timer
      self.AoA_time = timer.getAbsTime()
    elseif timer.getAbsTime() - self.AoA_time >=  15 then
      --more then 15 sec on high AoA need recover
      return true
    end
  else
    --AoA is good, reset time
    self.AoA_time = nil
  end
  return false
end

function AbstractPlane_FSM:checkMissile(missile) 
  --if missile closer then 20000m then return true, but ignore FOX2
  if missile:getGuidance() ~= 2 and mist.utils.get3DDist(self.object:getPoint(), missile:getPoint()) < 20000 then 
    return true
  end
  return false
end

function AbstractPlane_FSM:checkForDefencive() 
  --check for any threat missiles in close range, and update missile table(delete dead)
  local aliveMsl, hasThreat = {}, false
  
  for i, missile in pairs(self.object.threatMissiles) do 
    --check if missile still valid
    if not missile:isTrashed() then 
      --missile still valid 
      if self:checkMissile(missile) then 
        hasThreat = true
      end
      
      aliveMsl[#aliveMsl+1] = missile
    end
  end
  
  --update missile list
  self.object.threatMissiles = aliveMsl
  return hasThreat
end

--set current task to controlled object
function AbstractPlane_FSM:pushTask() 
  if not self.object:getController() then 
    return
  end
  
  self.object:getController():setTask(self.task)
end

--check if AI for some reason don't have a task and reapply it
function AbstractPlane_FSM:checkTask()
  if not self.object:getController():hasTask() then 
    GlobalLogger:create():debug(self.object:getName() .. " no task, reapply")
    self:pushTask()
    end
  end
  

function AbstractPlane_FSM:setOptions() 
  if not self.object:getController() then 
    return
  end

  for name, option in pairs(self.options) do 
    --try to find option in overridedOptions
    self.object:getController():setOption(unpack(self.object.overridenOptions[name] or option))
  end
end

function AbstractPlane_FSM:setup() 
  --reset timer
  self.AoA_time = nil
  self:setOptions()
  self:pushTask()--need call after setOptions() 
end
----------------------------------------------------
-- end of AbstractPlane_FSM
----------------------------------------------------

----------------------------------------------------
-- Starting state, just does nothing and wait when
-- will be changes
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----              FSM_Start
----------------------------------------------------
FSM_Start = utils.inheritFrom(AbstractPlane_FSM)

function FSM_Start:setup() 
  --no op
  end

function FSM_Start:checkTask() 
  --no op
  end

----------------------------------------------------
-- helper class with defence checking(should we start defending or not)
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----           FSM_WithDefence
----------------------------------------------------
FSM_WithDefence = utils.inheritFrom(AbstractPlane_FSM)

--check if we have missile inbound and autoapply FSM_Defence
--return true if so
function FSM_WithDefence:defend() 
  if not self:checkForDefencive() then 
    --no threat
    return false
  end
  
  --update state
  self.object:setFSM(FSM_Defence:create(self.object))
  return true
end
----------------------------------------------------
-- end of FSM_WithDefence
----------------------------------------------------

----------------------------------------------------
-- Standart fly to point behaviour, can be used for 
-- flying route or during intercept
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----            FSM_FlyToPoint
----------------------------------------------------

FSM_FlyToPoint = utils.inheritFrom(FSM_WithDefence)

--WP_table - valid WP from mist.fixedWing.buildWP
function FSM_FlyToPoint:create(handledObj, WP_table) 
  local instance = self:super():create(handledObj)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})

  instance.task = { 
  id = 'Mission', 
    params = { 
      airborne = true,
      route = { 
        points = { 
          [1] = WP_table
        } 
      }, 
    }
  }
  instance.options = {
    [CapPlane.options.ROE] = utils.tasks.command.ROE.Hold,
    [CapPlane.options.ThreatReaction] = utils.tasks.command.React_Threat.Evade_Fire,
    [CapPlane.options.RDR] = utils.tasks.command.RDR_Using.Silent,
    [CapPlane.options.ECM] = utils.tasks.command.ECM_Using.Silent,
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.Off,
    }
  
  instance.name = "FSM_FlyToPoint"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_FlyToPoint
  return instance
end

--valid option in key 'waypoint' and wp returned from mist.buildWP
function FSM_FlyToPoint:run(arg) 
  --1)check if we need defence
  if self:defend() then 
    return
  end

  --2)check if new point avail
  if arg.waypoint then 
    --update task
    self.task.params.route.points[1] = arg.waypoint
    self:pushTask()
    return
  end
  
  --3)check for AoA
  if self:checkAoA() then 
    --we stuck at high AoA
    --fly at current heading
    local p = mist.vec.add(self.object:getPoint(), mist.vec.scalar_mult(self.object:getVelocity(), 200))
    self.object:setFSM(FSM_FixAoa:create(self.object, mist.fixedWing.buildWP(p, nil, 600)))
  end
end
----------------------------------------------------
-- end of FlyToPoint
----------------------------------------------------


----------------------------------------------------
-- AoA fix behaviour, allow use of burner and go dive
-- should reset after 15 sec
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----             FSM_FlyToPoint
----                  ↓
----              FSM_FixAoa
----------------------------------------------------

FSM_FixAoa = utils.inheritFrom(FSM_FlyToPoint)

--WP_table - valid WP from mist.fixedWing.buildWP
function FSM_FixAoa:create(handledObject, WP_table) 
  
  --change altitude so we start descend
  local wp = mist.utils.deepCopy(WP_table)
  wp.alt = 100
  
  local instance = self:super():create(handledObject, wp)
  instance.name = "Fix AoA"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_FixAoa
  
  instance.options = {
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.On,
    }
  --set current time in timer
  self.AoA_time = timer.getAbsTime()
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_FixAoa:setup() 
  --only option apply, AoA timer needed
  self:setOptions()
  self:pushTask()
  end


--WP_table - valid WP from mist.fixedWing.buildWP
function FSM_FixAoa:run(arg) 
  --1)check if we need defence
  if self:defend() then 
    return
  end
  
  --check if 15 sec elapsed in this state, if so resume old state
  if timer.getAbsTime() - self.AoA_time >= 15 then 
    --update state
    self.object:popFSM()
    return
  end
  
  --3)check if new point avail
  if arg.waypoint then 
    --update task
    self.task.params.route.points[1] = mist.utils.deepCopy(arg.waypoint)
    self.task.params.route.points[1].alt = 100
    self:pushTask()
    return
  end
    
end
----------------------------------------------------
-- end of FSM_FixAoa
----------------------------------------------------

----------------------------------------------------
-- Just follow Wedge formation
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----            FSM_Formation
----------------------------------------------------

FSM_Formation = utils.inheritFrom(FSM_WithDefence)

--idToFollow is GroupID what we need to follow, formation - Vec3
--Arg does nothing
function FSM_Formation:create(handledObj, idToFollow, formation) 
  local instance = self:super():create(handledObj)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.task = {
  id = 'Follow',
    params = {
      groupId = idToFollow,
      pos = formation or {x= -200, y = 0, z = 200},
      lastWptIndexFlag = false
    }    
  }
  
  instance.options = {
    [CapPlane.options.ROE] = utils.tasks.command.ROE.Hold,
    [CapPlane.options.ThreatReaction] = utils.tasks.command.React_Threat.Evade_Fire,
    [CapPlane.options.RDR] = utils.tasks.command.RDR_Using.Silent,
    [CapPlane.options.ECM] = utils.tasks.command.ECM_Using.Silent,
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.Off,
    }
  
  instance.name = "FSM_Formation"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_Formation
  return instance
end


--Arg does nothing
function FSM_Formation:run(arg) 
  --1)check if we need defence
  if self:defend() then 
    return
  end
  
  --2)check for AoA stuck 
  if not self:checkAoA() then 
    return 
  end
  
  --we stuck at high AoA, point in flont of us, 660m/s
  local p = mist.fixedWing.buildWP(mist.vec.add(self.object:getPoint(), mist.vec.scalar_mult(self.object:getVelocity(), 1000)), nil, 660)
  self.object:setFSM(FSM_FixAoa:create(self.object, p))
end

----------------------------------------------------
-- end of FSM_Formation
----------------------------------------------------

----------------------------------------------------
-- Defence behavior: fly at max speed with ECM
-- away from missiles
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----             FSM_Defence
----------------------------------------------------

FSM_Defence = utils.inheritFrom(AbstractPlane_FSM)

--Arg does nothing
function FSM_Defence:create(handledObj) 
  local instance = self:super():create(handledObj)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  instance.name = "FSM_Defence"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_Defence
  
  instance.options = {
    [CapPlane.options.ThreatReaction] = utils.tasks.command.React_Threat.Evade_Fire,
    [CapPlane.options.ECM] = utils.tasks.command.ECM_Using.On,
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.On,
    }

  instance.task = nil
  return instance
end


function FSM_Defence:setup() 
  --only setOptions() task set on each tun()
  self:setOptions()
  end

function FSM_Defence:getMissilePumpPoint() 
  --find missiles mean point
  local pos = {}
  for i, missile in pairs(self.object.threatMissiles) do 
    pos[i] = missile:getPoint()
  end
  
  --vector from missiles to us
  return mist.vec.add(self.object:getPoint(), mist.vec.sub(self.object:getPoint(), mist.getAvgPoint(pos)))
end

function FSM_Defence:run(arg) 
  --check if threat is no more
  if not self:checkForDefencive() then 
    self.object:popFSM()--return to previous state
    return
  end
  
  --continue defending, update point
  --utils.drawDebugCircle({point = self:getMissilePumpPoint()})
  self.task = { 
  id = 'Mission', 
    params = { 
      route = { 
        points = { 
          [1] = mist.fixedWing.buildWP(self:getMissilePumpPoint(), "turningpoint", 600, 1000, "BARO"),
        } 
      }, 
    }
  }
  
  --push new point
  self:pushTask()
end
----------------------------------------------------
-- end of FSM_Defence
----------------------------------------------------

----------------------------------------------------
-- Attack specified unit, no defencive
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----           FSM_WithDefence(not used basically, but needed in derived)
----                  ↓
----           FSM_ForcedAttack
----------------------------------------------------

FSM_ForcedAttack = utils.inheritFrom(FSM_WithDefence)

--Arg in key 'newTarget' and should be new target unit ID

function FSM_ForcedAttack:create(handledObj, targetId) 
  local instance = self:super():create(handledObj)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.task = { 
    id = 'AttackUnit', 
    params = { 
      unitId = targetId, 
   } 
  }
  
  instance.options = {
    [CapPlane.options.ROE] = utils.tasks.command.ROE.OnlyAssigned,
    [CapPlane.options.ThreatReaction] = utils.tasks.command.React_Threat.Evade_Fire,
    [CapPlane.options.RDR] = utils.tasks.command.RDR_Using.On,
    [CapPlane.options.ECM] = utils.tasks.command.ECM_Using.On,
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.On,
    [CapPlane.options.AttackRange] = utils.tasks.command.AA_Attack_Range.Max_Range
    }
  
  instance.name = "FSM_ForcedAttack"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_ForcedAttack
  return instance
end


--check if current target is still valid
function FSM_ForcedAttack:isTargetValid() 
  return self.object.target and self.object.target:isExist()
end

--reset target/delete our missile
function FSM_ForcedAttack:teardown() 
  self.object.ourMissile = nil
  self.object:resetTarget()
  end

--Arg in key 'newTarget' and should be new target unit ID
function FSM_ForcedAttack:run(arg) 
  --1)no defence check

  --2)no AoA check
  
  --3)check if new target avail
  if arg.newTarget then 
    --update task
    self.task.params.unitId = arg.newTarget
    self:pushTask()
    return
  end
  
  --4) check if target still alive
  if self:isTargetValid() then
    --target alive, just continue
    return
  end
  
  --target dead, return to previous state
  --reset target, and plane status
  self.object:popFSM()
end

----------------------------------------------------
-- end of FSM_ForcedAttack
----------------------------------------------------

----------------------------------------------------
-- Attack specified unit, go defencive if have missile inbound
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----           FSM_ForcedAttack
----                  ↓
----              FSM_Attack
----------------------------------------------------

FSM_Attack = utils.inheritFrom(FSM_ForcedAttack)

--Arg in key 'newTarget' and should be new target unit ID

function FSM_Attack:create(handledObj, targetId) 
  local instance = self:super():create(handledObj, targetId)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "FSM_Attack"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_Attack
  GlobalLogger:create():debug(handledObj:getName() .. " new target: " .. tostring(targetId))
  return instance
end

--setup() same
--teardown() same
--isTargetValid() same

--Arg in key 'newTarget' and should be new target unit ID
function FSM_Attack:run(arg) 
  --1)check if we need defence
  if self:defend() then 
    --we defending so target no more targeted
    self.object:resetTarget()
    return
  end

  --other same
  self:super().run(self, arg)
end
----------------------------------------------------
-- end of FSM_Attack
----------------------------------------------------


----------------------------------------------------
-- Attack anything in 30km radius using default logic
-- will be used in WVR conditions
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----               FSM_WVR
----------------------------------------------------

FSM_WVR = utils.inheritFrom(AbstractPlane_FSM)
--Arg does nothing

function FSM_WVR:create(handledObj)
  local instance = self:super():create(handledObj)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.task = { 
    id = 'EngageTargets', 
    params = { 
      maxDist = 30000, 
      targetTypes = {"Air"}, --attack only air
    } 
  }
  
  instance.options = {
    [CapPlane.options.ROE] = utils.tasks.command.ROE.Free,
    [CapPlane.options.ThreatReaction] = utils.tasks.command.React_Threat.Evade_Fire,
    [CapPlane.options.RDR] = utils.tasks.command.RDR_Using.On,
    [CapPlane.options.ECM] = utils.tasks.command.ECM_Using.On,
    [CapPlane.options.BurnerUse] = utils.tasks.command.Burner_Use.On,
    [CapPlane.options.AttackRange] = utils.tasks.command.AA_Attack_Range.Max_Range
    }
  
  instance.name = "FSM_WVR"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_WVR
  return instance
end

function FSM_WVR:run(arg) 
  --does nothing
end
----------------------------------------------------
-- end of FSM_WVR
----------------------------------------------------

----------------------------------------------------
-- fly at orbit behaviour, separate state, cause need 
-- different task
----------------------------------------------------  
----          AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----            FSM_FlyToPoint
----                  ↓
----            FSM_FlyOrbit
----------------------------------------------------

--arg does nothing
FSM_FlyOrbit = utils.inheritFrom(FSM_FlyToPoint)

--orbit task is ready to push in controller task
function FSM_FlyOrbit:create(handledObj, orbitTask) 
  local instance = self:super():create(handledObj)
  
  --just change task, other is same
  instance.task = orbitTask
  instance.name = "FSM_FlyOrbit"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_FlyOrbit
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--run behaviour same, except we don't want arg be processed
function FSM_FlyOrbit:run(arg) 
  self:super().run(self, {})--instead of arg send empty tbl
end


----------------------------------------------------
-- fly to Airbase state, same as FSM_FlyOrbit
-- but override checkTask() cause hasTask() return false
-- also has different task for this
-- when group flies toward airbase
----------------------------------------------------  
----           AbstractPlane_FSM
----                  ↓
----            FSM_WithDefence
----                  ↓
----            FSM_FlyToPoint
----                  ↓
----             FSM_PlaneRTB
----------------------------------------------------

FSM_PlaneRTB = utils.inheritFrom(FSM_FlyToPoint)

function FSM_PlaneRTB:create(handledObj, WP_table)
  local instance = self:super():create(handledObj, WP_table)
 
  --we need our target WP as NOT nbr 2, so add current pos as WP
  local pos = handledObj:getPoint()
  instance.task.params.route.points[2] = mist.utils.deepCopy(WP_table)
  instance.task.params.route.points[1] = {
    ["alt"] = pos.y,
    ["x"] =  pos.x,
    ["action"] = "Turning Point",
    ["alt_type"] = "BARO",
    ["speed"] = 200,
    ["form"] = "Turning Point",
    ["type"] = "Turning Point",
    ["y"] =  pos.z,
  }
  instance.name = "FSM_PlaneRTB"
  instance.enumerator = AbstractPlane_FSM.enumerators.FSM_PlaneRTB
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_PlaneRTB:checkTask() 
  
end--]]

function FSM_PlaneRTB:run(arg) 
  --no checks, just let AI do his shit
  end