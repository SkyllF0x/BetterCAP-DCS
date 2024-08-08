----------------------------------------------------
-- CapObjective whick GciCapHandler will try to cover
---with groups
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            CapObjective
----------------------------------------------------

CapObjective = utils.inheritFrom(AbstractCAP_Handler_Object)

CapObjective.Priority = {}
CapObjective.Priority.Low = 1     --no CAP, only GCI with (amount of fighters in zone) * 1 + others * 0.25, minimum 2, maximum 4 will be requested
CapObjective.Priority.Normal = 2  --CAP 2 ship with ALR normal, GCI (amount of fighter) * 1 + others * 0.5, minimum 2
CapObjective.Priority.High = 3    --CAP 4 ship with ALR high, GCI (amount of fighter) * 1.5 + others * 0.75

CapObjective.PriorityModifiers = {
  [CapObjective.Priority.Low] = {fighter = 1, other = 0.25, capReq = 0},
  [CapObjective.Priority.Normal] = {fighter = 1, other = 0.5, capReq = 2},
  [CapObjective.Priority.High] = {fighter = 1.5, other = 0.75, capReq = 4}
  }


--gciZone is CircleZone or ShapeZone which will used for detection target, and also will passed to group
function CapObjective:create(point, gciZone, useForCap, useForGci, prior, customName)
  local instance = {}
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  instance.id = utils.getGeneralID()
  instance.name = customName or ("CapObjective-" .. tostring(instance.id))
  
  instance.point = mist.utils.makeVec3(point)
  instance.zone = gciZone
  instance.requestCap = useForCap or false
  instance.requestGci = useForGci or false
  
  --current prority stored here
  instance.priority = nil
  instance.modifierFighter = 1
  instance.modifierOther = 0.25
  --how many planes we need in cap
  instance.capRequestAmount = 2
  --maximum amount of GCI planes this objective will request
  instance.maxGciPlanes = 4
  --initialize priority field and callable
  instance:setPriority(prior or CapObjective.Priority.Low)
  
  --how many enemy aircraft in zone
  instance.threatsAircraft = 0
  --how many aircraft in zone
  instance.aircraftAssigned = 0
  
  --squadrons sorted by range
  instance.squadrons = {}
  
  GlobalLogger:create():drawPoint({point = point, text = instance.name})
  
  return instance
end

function CapObjective:setRequestCap(val) 
  self.requestCap = val
end

function CapObjective:setRequestGci(val) 
  self.requestGci = val
end

function CapObjective:setPriority(priority) 
  self.priority = priority
  
  self.modifierFighter = CapObjective.PriorityModifiers[priority].fighter
  self.modifierOther = CapObjective.PriorityModifiers[priority].other
  self.capRequestAmount = CapObjective.PriorityModifiers[priority].capReq
  
  if priority == CapObjective.Priority.Low then 
    self.maxGciPlanes = 4
  else
    --in other no limit
    self.maxGciPlanes = math.huge
  end
end

function CapObjective:setCountModifier(modifierForFighter, modifierForOthers) 
  self.modifierFighter = modifierForFighter or self.modifierFighter
  self.modifierOther = modifierForOthers or self.modifierOther
end

function CapObjective:addCapPlanes(val) 
  if val < 0 then 
    GlobalLogger:create():info("decrease " .. tostring(val) ..  " call " .. tostring(debug.getinfo(2).linedefined) .. " "
      .. tostring(debug.getinfo(3).linedefined) .. " "
      .. tostring(debug.getinfo(4).linedefined) .. " "
      .. tostring(debug.getinfo(5).linedefined) .. " ")
	end
  self.aircraftAssigned = self.aircraftAssigned + val
end

function CapObjective:addSquadron(sqn) 
  local rangeToSqn = mist.utils.get2DDist(self:getPoint(), sqn:getPoint()) 
  
  if rangeToSqn > sqn:getCombatRadius() then 
    return --to far, nothing added
  end
  
  --apply priority modifier
  rangeToSqn = rangeToSqn * sqn:getPriorityModifier()
  
  for i = 1, #self.squadrons do 
    if sqn == self.squadrons[i].squadron then 
      GlobalLogger:create():info(self:getName() .. " " .. sqn:getName() .. " already in list")
      return
    elseif rangeToSqn < self.squadrons[i].range then 
      GlobalLogger:create():info(self:getName() .. " " .. sqn:getName() .. " was added as nbr: " .. tostring(i))
      table.insert(self.squadrons, i, {squadron = sqn, range = rangeToSqn})
      return
    end
  end
  
  --add to end
  self.squadrons[#self.squadrons+1] = {squadron = sqn, range = rangeToSqn}
end

function CapObjective:removeSquadron(sqn) 
  for i = 1, #self.squadrons do 
    if self.squadrons[i].squadron == sqn then 
      table.remove(self.squadrons, i)
      return
    end
  end
end

--iterator which return only squadrons
function CapObjective:getSquadrons() 
  local nbr = 0
  return coroutine.wrap(
    function()
      for _, sqn in pairs(self.squadrons) do 
        coroutine.yield(sqn.squadron)
      end
    end
    )
end

function CapObjective:getPoint() 
  return self.point
end

--group use same zone for target search
function CapObjective:getGciZone() 
  return self.zone
end

function CapObjective:getPriority() 
  return self.priority
end

--calculate threatsAircraft
function CapObjective:calculateThreat(target)
  if target:getTypeModifier() ~= AbstractTarget.TypeModifier.FIGHTER then 
    return target:getCount() * self.modifierOther
  end
  
  return target:getCount() * self.modifierFighter
end


function CapObjective:update(targets) 
  
  self.threatsAircraft = 0
  
  for _, target in pairs(targets) do 
    if self.zone:isInZone(target:getPoint()) then 
      --count planes
      self.threatsAircraft = self.threatsAircraft + self:calculateThreat(target)
    end
  end
  
  if self.threatsAircraft > 1 then 
    self.threatsAircraft = math.floor(self.threatsAircraft)
  elseif self.threatsAircraft > 0 then
    self.threatsAircraft = 1
  end
end

function CapObjective:getGciRequest()
  --how many planes we need
  local delta = self.threatsAircraft - self.aircraftAssigned
  
  if not self.requestGci or self.threatsAircraft <= 0 then 
    return 0 --no threat
  end
  
  --if no groups assigned will request minimum 2
  -- else will reqest only delta to satisfy requirement
  local lowestGroupSize = 0
  if self.aircraftAssigned == 0 then 
    lowestGroupSize = 2
  end
  
  return math.max(lowestGroupSize, math.min(self.maxGciPlanes - self.aircraftAssigned, delta))
end

function CapObjective:getCapRequest() 
  if not self.requestCap or self.priority == CapObjective.Priority.Low then 
    return 0
  end
  
  return math.max(0, self.capRequestAmount - self.aircraftAssigned)
end

function CapObjective:getDebugStr()
  return self:getName() .. " | Threat aircraft: " .. tostring(self.threatsAircraft) 
    ..  " | Cap Request: " .. tostring(self:getCapRequest()) .. " | GCI Request: " .. tostring(self:getGciRequest()) 
    .. " | Assigned: " .. tostring(self.aircraftAssigned)
end

--create zone with Gci zone created from trigger zone
function CapObjective.makeFromTriggerZone(triggerZoneName, useForCap, useForGci, priority) 
  local zone =  trigger.misc.getZone(triggerZoneName)

  return CapObjective:create(zone.point, CircleZone.makeFromTriggerZone(triggerZoneName), useForCap, useForGci, priority, triggerZoneName)
end

--center is meanPoint
function CapObjective.makeFromGroupRoute(groupName, useForCap, useForGci, priority) 
  local points = mist.getGroupPoints(groupName)
  local meanPoint = mist.getAvgPoint(points)
  
  return CapObjective:create(meanPoint, ShapeZone:create(points), useForCap, useForGci, priority, groupName)
end