----------------------------------------------------
-- Basic tactic entity, can hold from 1 to 4 aircraft
----------------------------------------------------  
----          AbstractCAP_Handler_Object      FighterEntity_FSM
----                  ↓                               ↓
----              CapElement <------------------------
----------------------------------------------------  
CapElement = utils.inheritFromMany(AbstractCAP_Handler_Object, FighterEntity_FSM)

CapElement.FSM_Enum = {
  FSM_Element_GroupEmul = 0,
  FSM_Element_Start = 1,
  FSM_Element_FlyFormation = 2,
  FSM_Element_FlySeparatly = 4,
  FSM_Element_Pump = 8,
  FSM_Element_Intercept = 16,
  FSM_Element_Attack = 32,
  FSM_Element_Crank = 64,
  FSM_Element_FlyParallel = 125,
  
  --tactics enums
  FSM_Element_SkateGrinder = 1024,
  FSM_Element_SkateOffsetGrinder = 1025,
  FSM_Element_ShortSkateGrinder = 1026,
  FSM_Element_Bracket = 1027,
  FSM_Element_Banzai = 1028,
  FSM_Element_Delouse = 1029,
  FSM_Element_Skate = 1030,
  FSM_Element_SkateOffset = 1031,
  FSM_Element_ShortSkate = 1032,
  FSM_Element_WVR = 2048,
  FSM_Element_Defending = 4096,
  }

function CapElement:create(planes) 
  local instance = {}
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.id = utils.getGeneralID()
  instance.name = "Element-" .. tostring(instance.id)
  --controlled aircraft
  instance.planes = planes
  instance.point = {x = 0, y = 0, z = 0}
  instance.bestMissile = {MaxRange = 0, MAR = 0}
  
  --relative pos to target
  instance.sideOfElement = nil
  
  --update linkage
  for _, plane in pairs(instance.planes) do 
    plane:registerElement(instance)
  end
  
  instance.FSM_stack = FSM_Stack:create()
  instance.FSM_stack:push(AbstractState:create())
  instance.FSM_args = {}
  
  --group i belong to
  instance.myGroup = nil
  --second element for tactics
  instance.secondElement = nil
  
  instance:update()--update missile and position
  return instance
end

function CapElement:isExist() 
  --delete dead planes, return false if no planes controlled
  local newTbl = {}
  
  for _, plane in pairs(self.planes) do 
    if plane:isExist() then 
      newTbl[#newTbl+1] = plane
    end
  end
  
  self.planes = newTbl
  return #self.planes ~= 0
end

function CapElement:getName() 
  return self.name
  end

function CapElement:getID() 
  return self.id
  end

function CapElement:getPoint() 
  return self.point
end

--update point and missile at same time(1 iteration instead of 2)
function CapElement:update() 
  
  local missile = {MaxRange = 0, MAR = 0}
  local pos = {}
  
  for _, plane in pairs(self.planes) do 
    --update plane missile in air
    plane:updateOurMissile()
    pos[#pos+1] = plane:getPoint()
    
    local planeMissile = plane:getBestMissile()
    if planeMissile.MaxRange > missile.MaxRange then 
      missile = planeMissile
    end
  end
  
  self.point = mist.getAvgPoint(pos)
  self.bestMissile = missile
end

--missile with best range in element
function CapElement:getBestMissile() 
  return self.bestMissile
  end

function CapElement:registerGroup(capGroup) 
  self.myGroup = capGroup
  end

--return true if any of aircraft has RWR indication of any of contacts
--in listContacts
function CapElement:isSpikedBy(listContacts) 
  
  for _, plane in pairs(self.planes) do 
    for __, nails in pairs(plane:getNails()) do 
      --listContacts is array of Target, nails is Raw DCS Object
      --so explicitly compare by ID
      for ___, contact in pairs(listContacts) do 
        --getNails return raw dcs detection Table
        if contact:getID() == nails.object:getID() then 
          return true
        end
      end
    end 
  end
  
  return false
end

--return self.planes sorted by amount of missiles
function CapElement:sortByAmmo() 
  
  --aliases
  local IR, ARH, SARH = Weapon.GuidanceType.IR, Weapon.GuidanceType.RADAR_ACTIVE, Weapon.GuidanceType.RADAR_SEMI_ACTIVE    
  
  local p = {}
  for _, plane in pairs(self.planes) do 
    p[#p+1] = plane
  end
  
  table.sort(p, function(e1, e2) 
      local res1, res2 = e1:getAmmo(), e2:getAmmo()
      return res1[IR] + res1[SARH] + res1[ARH] > res2[IR] + res2[SARH] + res2[ARH]
    end)
  return p
end



function CapElement:setSecondElement(element) 
  self.secondElement = element
  end

function CapElement:getSecondElement() 
  return self.secondElement
end

function CapElement:callPlanes() 
  for _, plane in pairs(self.planes) do 
    plane:callFSM()
  end
end

function CapElement:callFSM() 
  self.FSM_stack:run(self.FSM_args)

  self:callPlanes()
  self.FSM_args = {}
end


