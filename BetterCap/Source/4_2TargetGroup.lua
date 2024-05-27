----------------------------------------------------    
-- Target group, multiply targets consistered as single entity
----------------------------------------------------  
----            AbstractTarget    AbstractCAP_Handler_Object
----                  ↓                       ↓
----             TargetGroup  <----------------
----------------------------------------------------  
TargetGroup = utils.inheritFromMany(AbstractTarget, AbstractCAP_Handler_Object)

--list of Target instances
function TargetGroup:create(targets, groupRange) 
  local instance = {}
  local points = {}
  
  instance.targetCount = 0
  instance.targets = {}
  for i, target in pairs(targets) do 
    instance.targetCount = instance.targetCount + 1
    instance.targets[target:getID()] = target
    points[#points + 1] = target:getPoint()
  end
  instance.currentROE = AbstractTarget.ROE.Bandit
  instance.typeModifier = targets[1]:getTypeModifier()
  instance.targeted = false--is this group intercepted by CapGroup
  --SEE UTILS PlanesTypes AND WeaponTypes
  instance.highestThreat = {MaxRange = 0, MAR = 0} --most dangerous missile we can expect from this group
  instance.point = mist.getAvgPoint(points)
  
  instance.id = utils.getGeneralID()
  instance.name = "TargetGroup-" .. tostring(instance.id)
  --distance from first plane in group we should consider as part of group
  --if distance is more we should move to other group
  instance.groupRange = groupRange or 30000 
  
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  return instance
end

--getID() inherited
--getName() inherited
--getTypeModifier() inherited

function TargetGroup:getCount()
  return self.targetCount
end

function TargetGroup:getHighestThreat() 
  return self.highestThreat
  end

function TargetGroup:getPoint() 
  return self.point
  end

function TargetGroup:getTargets() 
  return self.targets
  end

function TargetGroup:getLead() 
  local idx, lead = next(self.targets)
  return lead
  end

--return lowest AA(absolute) of all planes in degrees to given point
function TargetGroup:getAA(point) 
  local AA = 360
  
  for _, target in pairs(self.targets) do 
    local a = target:getAA(point) 
    if a < AA then 
      AA = a
      end
    end
    
  return AA
end

function TargetGroup:hasHostile() 
  --if atleast 1 aircraft has shooter flag
  for _, target in pairs(self.targets) do 
    if target:isShooter() then 
      return true
      end
    end
    return false
end

function TargetGroup:setROE(newROE) 
  --not only set self.currentROE but update ROE on all targets
  self.currentROE = newROE
  
  for _, target in pairs(self.targets) do 
    target:setROE(newROE)
    end
  end

function TargetGroup:update() 
  --calls update on respective targets and delete if target dead
  --also update counter
  --update highestThreat and point
  self.targetCount = 0
  local points = {}
  
  for i, target in pairs(self.targets) do 
    target:update()--update target
    
    if not target:isExist() then 
      --delete it
      self.targets[target:getID()] = nil
    else
      --target alive, increment counter and add to point table
      self.targetCount = self.targetCount  + 1 
      points[#points+1] = target:getPoint() 
      
      if utils.PlanesTypes[target:getTypeName()].Missile.MAR > self.highestThreat.MAR then 
        --update missile
        self.highestThreat = utils.PlanesTypes[target:getTypeName()].Missile
      end
    end
  end
  
  if self.targetCount < 1 then 
    return
    end
  
  --typeModifier of first plane
  local id, lead = next(self.targets)
  self.typeModifier = lead:getTypeModifier()
  self.point = mist.getAvgPoint(points)
end

function TargetGroup:deleteTarget(target) 
  self.targets[target:getID()] = nil
  end

--scan if target should be excluded, and return table with excluded targets
--EXCLUDED IF:
--distance from first plane > self.groupRange
--typeModifier different from first plane
function TargetGroup:getExcluded() 
  local excluded, leadPos = {}, self:getLead():getPoint()
  
  for i, target in pairs(self.targets) do 

    if mist.utils.get3DDist(target:getPoint(), leadPos) > self.groupRange
      or target:getTypeModifier() ~= self.typeModifier then 
      self.targetCount = self.targetCount - 1
  
      GlobalLogger:create():debug(self:getName() .. " " .. target:getName() .. " EXCLUDED")      
      --self.targets[target:getID()] = nil --delete target
      excluded[#excluded+1] = target
    end
  end
    
  --delete excluded
  for i, target in pairs(excluded) do 
    self:deleteTarget(target)
    end
  
  return excluded
end

--trying add target, if it inside groupRange and same typeModifier, if so
-- then add it, set ROE same as group ROE and return true
-- if target can't be accepted, return false
function TargetGroup:tryAdd(target) 

  if mist.utils.get3DDist(target:getPoint(), self:getLead():getPoint()) > self.groupRange
    or target:getTypeModifier() ~= self.typeModifier then 
      --target rejected
      return false
    end
  
  GlobalLogger:create():debug(self:getName() .. " " .. target:getName() .. " Accepted")
  
  --set ROE
  target:setROE(self:getROE())
  self.targets[target:getID()] = target
  self.targetCount = self.targetCount + 1
  
  return true
end

function TargetGroup:hasSeen(container) 
  if self.targets[container:getTarget():getID()] then 
    self.targets[container:getTarget():getID()]:hasSeen(container)
    return true
  end
  
  return false
end

--return true if we have any targets
function TargetGroup:isExist() 
  return self.targetCount > 0
  end

--move all contact from group to this group
function TargetGroup:mergeWith(group) 
  
  for _, target in pairs(group.targets) do 
    self.targets[target:getID()] = target
    --remove from group
    group.targets[target:getID()] = nil
  end
  
  group.targetCount = 0
  self:updatePoint()
  end

function TargetGroup:updatePoint() 
  local pos = {}
  
  for _, target in pairs(self.targets) do 
    pos[#pos + 1] = target:getPoint()
  end
  
  if #pos == 0 then 
    return --no update, group dead
  end
  
  self.point = mist.getAvgPoint(pos)
end

function TargetGroup:getDebugStr(settings) 
  local m = ""
  local GROUP_MARGIN = 2
  local TARGET_MARGIN = 6
  
  if settings.showTargetGroupDebug then
      
      m = m .. utils.getMargin(GROUP_MARGIN) .. self:getName() .. " |ROE: " .. AbstractTarget.names.ROE[self:getROE()]
      if settings.expandedTargetDebug then 
        m = m .. " |TypeMod: " .. AbstractTarget.names.typeModifier[self:getTypeModifier()] .. " |Targeted: " 
        .. tostring(self:getTargeted())
      end
    end
    
    m = m .. " |Strength: " .. tostring(self:getCount())
    
    if settings.showTargetDebug then 
      for __, target in pairs(self:getTargets()) do 
        m = m .. "\n" .. utils.getMargin(TARGET_MARGIN) .. target:getName() .. " |ROE: " 
          .. AbstractTarget.names.ROE[target:getROE()] .. " |Type: " .. target:getTypeName()
        
        if settings.expandedTargetDebug then 
          m = m .. " |Targeted: " .. tostring(target:getTargeted()) .. " |Control: " .. tostring(Target.names.ControlType[target.controlType])
        end
      end
    end
  
  return m
end
