----------------------------------------------------
-- Abstract zone object
----------------------------------------------------  
----        AbstractCAP_Handler_Object  
----                  ↓                           
----             AbstractZone 
----------------------------------------------------  

AbstractZone = utils.inheritFrom(AbstractCAP_Handler_Object)

function AbstractZone:create() 
  local instance = {}
  instance.id = utils.getGeneralID()
  instance.name = "AbstractZone-" .. tostring(instance.id)
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--distance to border of zone, if inside zone return -1
function AbstractZone:getDistance(point) 
  return -1
  end

function AbstractZone:isInZone(point) 
  return true
end

----------------------------------------------------
-- 2D Circle zone object(really it's cylinder)
----------------------------------------------------  
----        AbstractCAP_Handler_Object  
----                  ↓                           
----             AbstractZone 
----                  ↓                           
----             CircleZone 
----------------------------------------------------  

CircleZone = utils.inheritFrom(AbstractZone)

function CircleZone:create(centerPoint, radius) 
  local instance = self:super():create()
  instance.name = "CircleZone-" .. tostring(instance.id)
  
  instance.point = mist.utils.makeVec2(centerPoint)
  instance.radius = radius
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


function CircleZone:getDistance(point) 
  local range = mist.utils.get2DDist(self.point, point)
  
  if range < self.radius then 
    return -1
  end
  
  return range - self.radius
end

function CircleZone:isInZone(point) 
  return self:getDistance(point) == -1
end

function CircleZone.makeFromTriggerZone(triggerZoneName) 
  local zone = trigger.misc.getZone(triggerZoneName)
  
  return CircleZone:create(zone.point, zone.radius)
end

----------------------------------------------------
-- zone with any shape
----------------------------------------------------  
----        AbstractCAP_Handler_Object  
----                  ↓                           
----             AbstractZone 
----                  ↓                           
----               ShapeZone 
----------------------------------------------------

ShapeZone = utils.inheritFrom(AbstractZone)

--points is array with vertexes(VEC2) of shape
function ShapeZone:create(points) 
  local instance = self:super():create()
  instance.name = "ShapeZone-" .. tostring(instance.id)
  
  instance.points = points
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function ShapeZone:getDistance(point) 
  
  point = mist.utils.makeVec2(point)
  
  if mist.pointInPolygon(point, self.points) then 
    return -1
  end
  
  local range = 9999999
  for i = 1, #self.points do 
    --create segment
    --distance from point to segment
    local dist = utils.distance2Line({self.points[i], self.points[i+1] or self.points[1]}, point)

    if dist < range then 
      range = dist
      end
    end
    
    return range
  end
  
function ShapeZone:isInZone(point) 
  return mist.pointInPolygon(point, self.points)
  end
  
function ShapeZone.makeFromGroupRoute(groupName) 
  return ShapeZone:create(mist.getGroupPoints(groupName))
end
  
----------------------------------------------------
---- Manages detection for coalition
----------------------------------------------------  
----        AbstractCAP_Handler_Object  
----                  ↓                           
----           DetectionHandler 
----------------------------------------------------
DetectionHandler = utils.inheritFrom(AbstractCAP_Handler_Object)

function DetectionHandler:create(coalitionEnum) 
  local instance = {}
  instance.id = utils.getGeneralID()
  instance.name = "Detector-" ..tostring(instance.id)
  instance.coalition = coalitionEnum
  
  --DIFFERNT ARRAYS DOUE POSSIBLE ID COLLITION
  --dict with all radars
  instance.radars = {}
  --dict with all CapGroup acting as radar
  instance.airborneRadars = {}
  
  --how far should target fly away from border to stop consisdered hostile
  --i.e. Hostile group leave border and will become Bandit only after this distance from border
  --this to prevent abusing war around border
  instance.borderZone = 30000
  --how long we should hold lost target
  instance.trackHoldTime = 45

  
  --airspace border, all contacts outside this will firstly classify as Bandits
  --and only after crossing/shooting at us will consisdered hostile
  --will switch to Bandit if distance from border > self.borderZone
  instance.border = AbstractZone:create() --by default any target is hostile
  
  --all detected targetGroups
  instance.targets = {}
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

function DetectionHandler:setTrackHoldTime(newTime) 
  self.trackHoldTime = newTime
end

function DetectionHandler:addRadar(radar)
  self.radars[radar:getID()] = radar
end

function DetectionHandler:deleteRadar(radar) 
  self.radars[radar:getID()] = nil
  end

function DetectionHandler:addFighterGroup(group)
  self.airborneRadars[group:getID()] = group
end

function DetectionHandler:deleteFighterGroup(group) 
  self.airborneRadars[group:getID()] = nil
  end

function DetectionHandler:setBorderZone(newRange) 
  self.borderZone = newRange
  end

function DetectionHandler:addBorder(border) 
  self.border = border
end

--return all group radats
function DetectionHandler:getRadars() 
  return self.radars
  end

--return all targets
function DetectionHandler:getTargets() 

  return self.targets
end

--return all HostileTargets
function DetectionHandler:getHostileTargets() 
  local result = {}
  
  for id, target in pairs(self.targets) do 
    if target:getROE() == AbstractTarget.ROE.Hostile then 
      result[id] = target
    end
  end
  
  return result
 end
  
--delete dead radars
--delete capGroup if it dead or not autonomous 
function DetectionHandler:updateRadars() 
  
  for _, groundRadar in pairs(self.radars) do 
    if not groundRadar:isExist() then 
      GlobalLogger:create():debug("Ground radar: " .. groundRadar:getName() .. " dead")
      self.radars[groundRadar:getID()] = nil
    end
  end
    
  for _, airGroup in pairs(self.airborneRadars) do 
    if not airGroup:isExist() or not airGroup:getAutonomous() then
      GlobalLogger:create():debug("Airborne radar: " .. airGroup:getName() .. " dead")
      self.airborneRadars[airGroup:getID()] = nil
    end
  end
end

function DetectionHandler:getDebugStr() 
  local radarsCounter, capGroupCounter = 0, 0
  
  for _, groundRadar in pairs(self.radars) do 
    radarsCounter = radarsCounter + 1
  end
  
  for _, radar in pairs(self.airborneRadars) do
    capGroupCounter = capGroupCounter + 1
  end
  
  return "RADARS: " .. tostring(radarsCounter) .. " | CapGroups as Detector: " .. tostring(capGroupCounter)
end

--return targets from all radars
function DetectionHandler:askRadars() 
  local contacts = {}
  
  for _, radar in pairs(self:getRadars()) do 
    for __, target in pairs(radar:getDetectedTargets()) do 
      contacts[#contacts+1] = target
    end
  end
  
  for _, radar in pairs(self.airborneRadars) do 
    for __, target in pairs(radar:getDetectedTargets()) do 
      contacts[#contacts+1] = target
    end
  end
  
  return contacts
  end

--try update existed targets with containers from contacts
--containers which wasn't accepted
function DetectionHandler:updateExisted(contacts) 
  local notAccepted = {}
  
  for _, contact in pairs(contacts) do 
    local wasAccepted = false
    for __, target in pairs(self:getTargets()) do
      
      if target:hasSeen(contact) then 
        wasAccepted = true
        break
      end
    end
    
    if not wasAccepted then 
      notAccepted[#notAccepted+1] = contact
    end
  end
  
  return notAccepted
  end


--return array with targets created from containers
function DetectionHandler:createTargets(containers) 
  local tgt = {}
  for _, cont in pairs(containers) do
    if tgt[cont:getTarget():getID()]  then 
      --target exist, push container
      tgt[cont:getTarget():getID()]:hasSeen(cont)
    else
      --create new target
      tgt[cont:getTarget():getID()] = Target:create(cont, self.trackHoldTime)
    end
  end
  
  return tgt
end

--tries add target to existed targetGroup
function DetectionHandler:tryAdd(target) 
  --update to calculate position
  target:update()
  
  for _, group in pairs(self:getTargets()) do 
    if group:tryAdd(target) then 
      --added succesfully
      return true
    end
  end
  
  return false
end

--merge targetGroups if needed
function DetectionHandler:mergeGroups() 
  --groups will be merged if: distance between < 15000m and groups have same ROE and same typeModifier
  
  local seenGroups = {}
  
  for _, target1 in pairs(self:getTargets()) do 
    for __, target2 in pairs(self:getTargets()) do 
     
      if not utils.itemInTable(seenGroups, target1:getID())                                                       --check if we already process this group
        and target1 ~= target2                                                                                     --check we process different targets
        and mist.utils.get2DDist(target1:getPoint(), target2:getPoint()) < 15000                                  --check if distance below 15000
        and target1:getROE() == target2:getROE() and target1:getTypeModifier() == target2:getTypeModifier() then --check ROE and modifier same

        GlobalLogger:create():debug("MERGE GROUPS: " .. target1:getID() .. " " .. target2:getID())
        seenGroups[#seenGroups+1] = target1:getID()
        
        target1:mergeWith(target2)
        self.targets[target2:getID()] = nil --delete second group
        end
      end
    end
  end

function DetectionHandler:updateTargets() 
  
  local exluded = {}
  --update all groups
  for _, group in pairs(self:getTargets()) do 
    group:update()
    
    if group:isExist() then
      
      for i, excluded in pairs(group:getExcluded()) do 
        if not self:tryAdd(excluded) then
          --create new group
          local newGroup = TargetGroup:create({excluded})
          --call update here
          newGroup:update()
          self.targets[newGroup:getID()] = newGroup       
          
          --update calculate new group point, cause we exclude one of points
          group:updatePoint()
        end
      end
    else
      --group dead delete it
      self.targets[group:getID()] = nil
    end
  end

end

function DetectionHandler:updateROE() 
  for _, group in pairs(self:getTargets()) do 
    
    local dist = self.border:getDistance(group:getPoint())
    --group inside border or inside borderZone and has guy who shot on us
    if dist == -1 or (dist < self.borderZone and group:hasHostile()) then 
      --update group ROE
      group:setROE(AbstractTarget.ROE.Hostile)
      
      --group outside border zone and set to hostile
    elseif dist > self.borderZone and group:getROE() == AbstractTarget.ROE.Hostile then 
      group:setROE(AbstractTarget.ROE.Bandit)
    end
    end
  end

function DetectionHandler:update() 
  self:updateRadars()
  
  --get all targets
  local contacts = self:askRadars()
  
  --this contacts not accepted, convert them to targets, and add to groups or create new
  for _, target in pairs(self:createTargets(self:updateExisted(contacts))) do 
    if not self:tryAdd(target) then
      --create new group
      local group = TargetGroup:create({target})
      self.targets[group:getID()] = group
    end
  end
  
  self:updateTargets()
  self:updateROE()
  --try to merge groups
  self:mergeGroups()
  end

