---Better CAP version: 1.0.11 | Build time: 18.06.2025 0917Z---
env.info("Better CAP version: 1.0.11 | Build time: 18.06.2025 0917Z")
---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 0Utility.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

utils = {}
utils.generalID = 0 --used for internal purposes(i.e. zone ID or detector handler)
utils.unitID = 0   -- for DCS UNIT
utils.groupID = 0 --for DCS GROUP
TRACE_ENABLED = true

function utils.getGeneralID()
  utils.generalID = utils.generalID + 1
  return utils.generalID
end

function utils.getUnitID() 
  utils.unitID = utils.unitID + 1
  return utils.unitID
end

function utils.getGroupID() 
  utils.groupID = utils.groupID + 1
  return utils.groupID
  end

--helper for inheritance
function utils.inheritFrom(baseClass) 

  local newClass = {}
  --search for field in base classes
  setmetatable(newClass, {__index = baseClass})
  
  function newClass:super() 
    return baseClass
  end
  
  return newClass
end


function utils.inheritFromMany(...) 
  --Just copy all data to new class on first serch, it can help with perfomance 
  
    local function searchInParent(parents, key) 
      local val = nil
      
      --we search in all parents to verify there's no diamond problem(only method 'create'(constructor) is exeption)
      for _, parent in pairs(parents) do 
        if parent[key] and key ~= "create" then --constructor not inherited, need call explicitly
          if val then 
            error("Error during inheritance field: " .. key .. " has in more then 1 base class")
          else
            --update val
            val = parent[key]
          end
          
        end
      end
        return val
    end
    
    local baseClasses = {...}
    local newClass = {}

    setmetatable(newClass, {__index = function(tbl, key) 
          
          --search for field
          local val = searchInParent(baseClasses, key)
          --move new field for our class, so this function will call once for every field
          --env.info("register new field: " .. key)
          tbl[key] = val
          return val
        end})
    
    function newClass:super() 
      --return self, cause we copy all field
      return newClass
    end
    
    return newClass
  end
  
--
function utils.kmhToMs(speed)
  return speed/3.6
end

--knots to m/s
function utils.knToMs(speed)
  return speed / 1.944
end

--mach number to m/s
function utils.machToMs(speed) 
  return speed * 340
end

function utils.getMargin(margin)
  margin = margin or 2
  
  local m = ""
  for i = 1, margin do 
    m = m .. " "
  end
  return m
end 

--compare 2 tables(all instances will have ID)
function utils.compareTables(tbl1, tbl2)
  return tbl1:getID() == tbl2:getID()
end


function utils.itemInTable(tbl, item) 

  if item ~= nil then
    for _, t in pairs(tbl) do
      if type(t) ~= type(item) then
        t = tostring(t)
        item = tostring(item)
      end
      if t == item then
        return true
      end
    end
  end
  return false
end



function utils.concatTables(tbl1, tbl2) 
  
    if not tbl1 then
      return mist.utils.deepCopy(tbl2)
    end
    
    local tbl = mist.utils.deepCopy(tbl1)
    
    for i = 1, #tbl2 do
      tbl[#tbl + 1] = tbl2[i]
    end
  return tbl
end


function utils.removeFrom(tbl, item) 
    local t = {}
    local nbr = 1
    
    for i, table_item in pairs(tbl) do
      if not (table_item == item) then
        t[nbr] = table_item
        nbr = nbr + 1
      end
    end
    return t
  end
  
--return relative position point to line
-- -1 mean point Left side of line
--  0 = point on line
--  1 point on right side
function utils.sideOfLine(line, point) 
  local point1, point2 = mist.utils.makeVec2(line[1]), mist.utils.makeVec2(line[2])
  point = mist.utils.makeVec2(point)
  local D = (point.x - point1.x) * (point2.y - point1.y) - (point.y - point1.y) * (point2.x - point1.x)
  if D == 0 then 
    return 0
  elseif D > 0 then
    return 1
  end
  return -1
end

--return 2d distance to line segment from point, if closest point outside segment, then return closest segment point
function utils.distance2Line(line, point) 
  local vec1 = line[1]
  local vec2 = line[2]
  point = mist.utils.makeVec2(point)
  
  local point_Intercept = {x = 0, y = 0}
  local k = ((point.x - vec1.x) * (vec2.x - vec1.x) + (point.y - vec1.y)*(vec2.y - vec1.y))/
  (math.pow(vec2.x - vec1.x, 2) + math.pow(vec2.y - vec1.y, 2))
  
  point_Intercept.x, point_Intercept.y = vec1.x + k * (vec2.x - vec1.x), vec1.y + k * (vec2.y - vec1.y) 
  
  local x, y = {vec1.x, vec2.x}, {vec1.y, vec2.y}
  
  --sort point in ascend
  table.sort(x)
  table.sort(y)
  local x1, x2 = unpack(x)
  local y1, y2 = unpack(y)
  local x3, y3 = point_Intercept.x, point_Intercept.y
  
  
  local inSegment = x1 <= x3 and x2 >= x3 and y1 <= y3 and y2 >= y3
  if inSegment then 
    --in segment return distance
    return mist.utils.get2DDist(point_Intercept, point)
  end
  return math.min(mist.utils.get2DDist(vec1, point), mist.utils.get2DDist(vec2, point))
end
  
  

function utils.round(num, DecimalPlaces) 
  local mult = 10^(DecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end
  


function utils.getItemsByPrefix(itemList, prefix) 
    local result, idx = {}, 1
    
    for _, item in pairs(itemList) do 
      if string.find(item:getName(), prefix) then 
        result[idx] = item
        idx = idx + 1
      end
    end
    return result
  end
  

--2d intercept point 
function utils.getInterceptPoint(target, interceptor, interceptor_spd)
  
  local range = mist.utils.get3DDist(target:getPoint(), interceptor:getPoint())
  local relativeSpeed = interceptor_spd - mist.vec.dp(mist.vec.getUnitVec(mist.vec.sub(target:getPoint(), interceptor:getPoint())), 
    target:getVelocity())

  --if relative speed to small just go pure
  if relativeSpeed < 150 then 
    return mist.vec.add(target:getPoint(), mist.vec.scalar_mult(target:getVelocity(), 30))
  end 
  local time = range/relativeSpeed

  return mist.vec.add(target:getPoint(), mist.vec.scalar_mult(target:getVelocity(), time)), time
  --return mist.vec.add(target:getPoint(), mist.vec.scalar_mult(target:getVelocity(), 30))
end

--all missiles in WeaponTypes has ranges for 10000m, linear interpolate for given alt
function utils.missileForAlt(missile, alt)
  return {MaxRange = missile.MaxRange - missile.MaxRange / 2 * (1 - alt/10000), --Range will be halfed at 0
    MAR = missile.MAR - missile.MAR * 0.75 * (1 - alt/10000)} --MAR will be 0.75 at 0
end

--serialize message with cycles(no overflow if self reference)
function utils.prepareMessage_cycles(...) 
  local message = ""
  for _, val in pairs({...}) do 
    if type(val) == "string" then 
      message = message .. " " .. val 
    elseif type(val) == "table" then
      message = message .. " " .. mist.utils.serializeWithCycles("", val) 
    else
      message = message .. " " .. tostring(val)
    end
  end
  return message
end


--serialize message witout cycles(DANGER, can overflow)
function utils.prepareMessage(...) 
  local message = ""
  for _, val in pairs({...}) do 
    message = message .. mist.utils.serialize(val)
  end
  return message
end


function utils.printToSim(...) 
  trigger.action.outText(utils.prepareMessage_cycles(...), 10)
end


function utils.printToLog(...) 
    env.info(utils.prepareMessage_cycles(...))
end


function utils.drawDebugCircle(data) 
  mist.marker.add(data)
end


function utils.getInProcected(func, ...)
  local arg = {...}
  local res, val = pcall(function() return func(unpack(arg)) end)
  return val
end

---Container whick allow call methods on all it's elements and support chaincalls
utils.chainContainer = {}

function utils.chainContainer:create(arrayOfElements) 
  local instance = arrayOfElements
  local container = {
    __index = function(tbl, name)
      
      --tbl2 is our instance array
      tbl[name] = function(tbl2, ...) 
        for i = 1, #tbl2 do 
          tbl2[i][name](tbl2[i], ...)
        end
        return tbl2
      end
    return tbl[name]
    end
  }
    
  setmetatable(instance, container)
  return instance
end

--tasks for DCS
utils.tasks = {}

utils.tasks.EmptyTask = {
  ["id"] = "ComboTask",
  ["params"] =
  {
    ["tasks"] =
    {}, -- end of ["tasks"]
  }, -- end of ["params"]
}

--position relative to lead
utils.tasks.formation = {
  ["Cruise"] = {
    [1] = {["x"]=-150, ["y"]=0, ["z"] = 150},
    [2] = {["x"]=-150, ["y"]=0, ["z"] = -150},
    [3] = {["x"]=-300, ["y"]=0, ["z"] = 150},
    [4] = {["x"]=-450, ["y"]=0, ["z"] = 300},
  },
  ["Spread"] = {
    [1] = {["x"]=0, ["y"]=0, ["z"] = 2000},
    [2] = {["x"]=0, ["y"]=0, ["z"] = -2000},
    [3] = {["x"]=0, ["y"]=0, ["z"] = 4000},
    [4] = {["x"]=0, ["y"]=0, ["z"] = 6000},
  },
  ["Wedge"] = {
    [1] = {["x"]=-800, ["y"]=0, ["z"] = 800},
    [2] = {["x"]=-800, ["y"]=0, ["z"] = -800},
    [3] = {["x"]=-1600, ["y"]=0, ["z"] = 800},
    [4] = {["x"]=-2400, ["y"]=0, ["z"] = 1600},
  },
}
utils.tasks.mission = {
  ["id"] = "Mission",
  ["params"] = {
    ["airborne"] = true,
    ["route"] = {
      ["points"] = {
        [1] = {
          ["alt"] = 0,
          ["type"] = "Turning Point",
          ["action"] = "Turning Point",
          ["alt_type"] = "BARO",
          ["speed_locked"] = true,
          ["y"] = 0,
          ["x"] = 0,
          ["speed"] = 274,
        }
      }
    }
  }
}


utils.tasks.command = {
  ["ROE"] = {
    ["Hold"] = {0, 4},
    ["OnlyAssigned"] = {0, 2},
    ["Free"] = {0, 0},
  },
  ["React_Threat"] = {
    ["Passive_Defence"] = {1, 1},
    ["Evade_Fire"] = {1, 2},
    ["Go_Low_Alt"] = {1, 3},
  },
  ["RDR_Using"] = {
    ["Silent"] = {3, 1},
    ["On"] = {3, 3}
  },
  ["ECM_Using"] = {
    ["Silent"] = {13, 0},
    ["On"] = {13, 3}
  },
  ["AA_Attack_Range"] = {
    ["Max_Range"] = {18, 0},
    ["NEZ"] = {18, 1},
    ["Half_Way"] = {18, 2},
    ["By_Threat"] = {18, 3}
  },
  ["Burner_Use"] = {
    ["Off"] = {16, true},
    ["On"] = {16, false}
  },
}


utils.WeaponTypes = {  --USES TYPENAME from getAmmo() DESC
  ['default'] = {MaxRange = 47000, MAR = 26000}, --R-27 stub
  ["R-60"] = {MaxRange = 10000, MAR = 8000},
  ["P_60"] = {MaxRange = 10000, MAR = 8000},
  ["RS2US"] = {MaxRange = 8000, MAR = 5000},
  ["P_73"] = {MaxRange = 15000, MAR = 8000},
  ["R-3S"] = {MaxRange = 7000, MAR = 5000},
  ["R-3R"] = {MaxRange = 7000, MAR = 5000},
  ["R-13M"] = {MaxRange = 9000, MAR = 5000},
  ["R-13M1"] = {MaxRange = 9000, MAR = 5000},
  ["PL-5EII"] = {MaxRange = 10000, MAR = 5000},
  ["R_550"] = {MaxRange = 8000, MAR = 5000},
  ["GAR-8"] = {MaxRange = 8000, MAR = 5000},
  ["AIM-9L"] = {MaxRange = 10000, MAR = 6000},
  ["AIM-9P"] = {MaxRange = 9000, MAR = 5000},
  ["AIM-9P3"] = {MaxRange = 9000, MAR = 5000},
  ["AIM-9P5"] = {MaxRange = 10000, MAR = 5000},
  ["AIM-9J"] = {MaxRange = 9000, MAR = 5000},
  ["AIM-9JULI"] = {MaxRange = 9000, MAR = 5000},
  ["AIM_9"] = {MaxRange = 10000, MAR = 6000},
  ["AIM_9X"] = {MaxRange = 12000, MAR = 6000},
  --end of close range
  ["P_77"] = {MaxRange = 55000, MAR = 24000},
  ["P_40R"] = {MaxRange = 35000, MAR = 22000},
  ["P_40T"] = {MaxRange = 35000, MAR = 22000},
  ["P_33E"] = {MaxRange = 130000, MAR = 46000},
  ["P_27T"] = {MaxRange = 47000, MAR = 26000},
  ["P_27P"] = {MaxRange = 47000, MAR = 26000},
  ["P_27TE"] = {MaxRange = 70000, MAR = 35000},
  ["P_27PE"] = {MaxRange = 70000, MAR = 35000},
  ["P_24T"] = {MaxRange = 33000, MAR = 20000},
  ["P_24R"] = {MaxRange = 33000, MAR = 20000},
  ["weapons.missiles.SD-10"] = {MaxRange = 60000, MAR = 31000},
  ["Super_530D"] = {MaxRange = 40000, MAR = 20000},
  ["MICA_T"] = {MaxRange = 40000, MAR = 20000},
  ["MICA_R"] = {MaxRange = 45000, MAR = 22000},
  ["weapons.missiles.AIM_7"] = {MaxRange = 45000, MAR = 20000},
  ["weapons.missiles.HB-AIM-7E"] = {MaxRange = 45000, MAR = 20000},
  ["weapons.missiles.HB-AIM-7E-2"] = {MaxRange = 45000, MAR = 20000},
  ["weapons.missiles.AIM-7E"] = {MaxRange = 42000, MAR = 18000},
  ["weapons.missiles.AIM-7MH"] = {MaxRange = 45000, MAR = 20000},
  ["weapons.missiles.AIM-7F"] = {MaxRange = 42000, MAR = 18000},
  ["AIM_54C_Mk47"] = {MaxRange = 50000, MAR = 20000},
  ["AIM_54A_Mk60"] = {MaxRange = 50000, MAR = 20000},
  ["AIM_54A_Mk47"] = {MaxRange = 50000, MAR = 20000},
  ["weapons.missiles.AIM_120C"] = {MaxRange = 65000, MAR = 31000},
  ["weapons.missiles.AIM_120"] = {MaxRange = 55000, MAR = 27000},
  ["AIM_120C"] = {MaxRange = 65000, MAR = 31000},
  ["AIM_120"] = {MaxRange = 55000, MAR = 27000},
}

--return stub with R-60 when can't find missile in table
setmetatable(utils.WeaponTypes, {__index = function (self, key)
      GlobalLogger:create():debug("No missile in table: " .. key)
      return utils.WeaponTypes['default']
    end})

utils.PlanesTypes = {
  ['default'] = {Missile = utils.WeaponTypes["default"], RadarRange = 1000},
  ["AV8BNA"] = {Missile = utils.WeaponTypes["AIM_9"], RadarRange = 1000},--KEKW
  ["F-14A"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 150000},
  ["F-14A-135-GR"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 150000},
  ["F-14B"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 150000},
  ["F-15C"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["F-15E"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["F-15ESE"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["F-16A MLU"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 74000},
  ["F-16A"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 74000},
  ["F-16C bl.50"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 74000},
  ["F-16C bl.52d"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 74000},
  ["F-16C_50"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 74000},
  ["F-4E-45MC"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_7"], RadarRange = 50000},
  ["F-5E-3"] = {Missile = utils.WeaponTypes["AIM-9P5"], RadarRange = 15000},
  ["F-5E"] = {Missile = utils.WeaponTypes["AIM-9P5"], RadarRange = 15000},
  ["F/A-18A"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["F/A-18C"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["FA-18C_hornet"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_120C"], RadarRange = 90000},
  ["J-11A"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["JF-17"] = {Missile = utils.WeaponTypes["weapons.missiles.SD-10"], RadarRange = 70000},
  ["M-2000C"] = {Missile = utils.WeaponTypes["Super_530D"], RadarRange = 60000},
  ["Mirage 2000-5"] = {Missile = utils.WeaponTypes["MICA_R"], RadarRange = 60000},
  ["MiG-21Bis"] = {Missile = utils.WeaponTypes["R-60"], RadarRange = 10000},
  ["MiG-23MLD"] = {Missile = utils.WeaponTypes["P_24R"], RadarRange = 50000},
  ["MiG-25PD"] = {Missile = utils.WeaponTypes["P_40R"], RadarRange = 50000},
  ["MiG-29A"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["MiG-29G"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["MiG-29S"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["MiG-31"] = {Missile = utils.WeaponTypes["P_33E"], RadarRange = 150000},
  ["Su-27"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["Su-33"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 90000},
  ["Su-30"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 110000},
  ["Su-34"] = {Missile = utils.WeaponTypes["P_27PE"], RadarRange = 110000},
  ["Mirage-F1EE"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_7"], RadarRange = 50000},
  ["Mirage-F1CE"] = {Missile = utils.WeaponTypes["weapons.missiles.AIM_7"], RadarRange = 50000},

  --SU30 mod
  ["Su-30SM"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 120000},
  ["Su-30MKM"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 120000},
  ["Su-30MKI"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 120000},
  ["Su-30MKA"] = {Missile = utils.WeaponTypes["AIM_54A_Mk60"], RadarRange = 120000},
}

--return stub with R-60 when can't find aircraft in table
setmetatable(utils.PlanesTypes, {__index = function (self, key)
      return utils.PlanesTypes['default']
    end})

function utils.setDefaultMissile(mslTbl) 
  
  utils.WeaponTypes['default'] = {
    MaxRange = mslTbl.MaxRange or utils.WeaponTypes['default'].MaxRange, 
    MAR = mslTbl.MAR or utils.WeaponTypes['default'].MAR
    }
end

function utils.setDefaultPlane(planeTbl) 
  
  utils.PlanesTypes['default'] = {
    Missile = planeTbl.Missile or utils.PlanesTypes['default'].Missile,
    RadarRange = planeTbl.RadarRange or utils.PlanesTypes['default'].RadarRange
    } 
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 1EventHandler.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

-------------------------------------------------------------------
---- EventHander signleton which track all related to script objects
-------------------------------------------------------------------
---@class EventHandler
---@field private _inst EventHandler?
---@field private objects ObjectWithEvent[]
EventHandler = {
  _inst = nil
  }

function EventHandler:create() 
  if not self._inst then 
      local instance = {}  
      
      instance.objects = {}--all objects stored here
      world.addEventHandler(instance)
      self._inst = setmetatable(instance,  {__index = self, __eq = utils.compareTables})
    end
    return self._inst
  end

  ---@param event Event
  ---@return nil
  function EventHandler:onEvent(event) 
    local result, err = xpcall(function() 
        
      if event.id == world.event.S_EVENT_SHOT then 
        for _, obj in pairs(self.objects) do 
          obj:shotEvent(event)
        end
      elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
        for _, obj in pairs(self.objects) do 
          obj:engineOffEvent(event)
        end
      elseif event.id == world.event.S_EVENT_MISSION_END then
        self:shutdown()
      end
    end, debug.traceback)
  
    if not result then 
      GlobalLogger:create():warning("EventHandler: error during processing event: " .. tostring(err))
    end
  end
  
  ---@param object ObjectWithEvent
  function EventHandler:registerObject(object)  
   self.objects[object:getID()] = object
  end
  
  ---@param object ObjectWithEvent
  function EventHandler:removeObject(object) 
    self.objects[object:getID()] = nil
  end
  
  ---Shutdown event handler and delete sigleton, after this call it unusable
  ---subsequent call to create() will instantiate new intance
  function EventHandler:shutdown() 
    world.removeEventHandler(self)
    EventHandler._inst = nil
  end

-------------------------------------------------------------------
-- End of EventHandler
-------------------------------------------------------------------

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 2AbstractClasses.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------


--BASIC ABC for future use
---@class AbstractCAP_Handler_Object
---@field id number
---@field name string
AbstractCAP_Handler_Object = {}

---@return number
function AbstractCAP_Handler_Object:getID()
  return self.id
end

---@return string
function AbstractCAP_Handler_Object:getName()
  return self.name
end

---@return string
function AbstractCAP_Handler_Object:getDebugStr(settings) 
  return ""
  end

-------------------------------------------------------------------
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject     
-------------------------------------------------------------------
---@class AbstractDCSObject: AbstractCAP_Handler_Object
---@field dcsObject table
AbstractDCSObject = utils.inheritFrom(AbstractCAP_Handler_Object)

---@return Vec3
function AbstractDCSObject:getPoint()
  return self.dcsObject:getPoint()
end

---@return Vec3
function AbstractDCSObject:getVelocity()
  return self.dcsObject:getVelocity()
end

---@return Position
function AbstractDCSObject:getPosition()
  return self.dcsObject:getPosition()
end

---@return Controller
function AbstractDCSObject:getController() 
  return self.dcsObject:getController()
end

---@return boolean
function AbstractDCSObject:isExist()
  --double check cause dcs can fail to report in some cases
  if self.dcsObject then
    return self.dcsObject:isExist()
  else
    return false
  end
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 3BasicWrappers.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------


----------------------------------------------------
----           Wraps around DCS object
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----------------------------------------------------
---@class DCS_Wrapper: AbstractDCSObject
---@field typeName string
---@field name string
---@field id number
DCS_Wrapper = utils.inheritFrom(AbstractDCSObject)

---@param dcsObject table
---@return DCS_Wrapper
function DCS_Wrapper:create(dcsObject) 
  local instance = {}
  ---@protected
  instance.dcsObject = dcsObject
  instance.typeName = dcsObject:getTypeName()
  instance.name = dcsObject:getName()
  instance.id = dcsObject:getID()
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

---@return string
function DCS_Wrapper:getTypeName() 
  return self.typeName
end

---@return table
function DCS_Wrapper:getObject()
  return self.dcsObject
end

---@return boolean
function DCS_Wrapper:hasAttribute(attr) 
  return self.dcsObject:hasAttribute(attr)
end

----------------------------------------------------
-- End of DCS_Wrapper
---------------------------------------------------

----------------------------------------------------
-- Wrapper with events, for use in EventHandler class
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----           ObjectWithEvent
----------------------------------------------------
---@class ObjectWithEvent: DCS_Wrapper
---@field create fun(self, dcsObject: table): ObjectWithEvent
ObjectWithEvent = utils.inheritFrom(DCS_Wrapper)

---to detect shots
---@param event Event
function ObjectWithEvent:shotEvent(event) 
  
end


---will be used to detect shutdown of aircraft
---@param event Event
function ObjectWithEvent:engineOffEvent(event) 
  
end

----------------------------------------------------
-- end of ObjectWithEvent
----------------------------------------------------    

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 4_1Target.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- Container for detected object, wrapper around default detection table
-- https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
----------------------------------------------------    
---@class TargetContainer
---@field private dcsObject table
---@field private detector AbstractDCSObject
---@field private typeKnown boolean
---@field private rangeKnown boolean
TargetContainer = {}

---@param dcsDetectionTable DCSDetectionTable
---@param detectorObject AbstractDCSObject
---@return TargetContainer
function TargetContainer:create(dcsDetectionTable, detectorObject)   
  local instance = {}

  instance.dcsObject = dcsDetectionTable.object
  instance.detector = detectorObject
  instance.typeKnown = dcsDetectionTable.type

  --dcsController can know distance from RWR, so check if target detected by some ranging sensors
  instance.rangeKnown = detectorObject:getController():isTargetDetected(instance.dcsObject,
     Controller.Detection.RADAR, Controller.Detection.IRST)
  return setmetatable(instance, {__index = self})
end

---@return table
function TargetContainer:getTarget() 
  return self.dcsObject
end

---@return AbstractDCSObject
function TargetContainer:getDetector()
  return self.detector
end

---@return boolean
function TargetContainer:isTypeKnown() 
  return self.typeKnown
end

---@return boolean
function TargetContainer:isRangeKnown() 
  return self.rangeKnown
  end
----------------------------------------------------    
-- End of TargetContainer
----------------------------------------------------    

----------------------------------------------------    
-- AbstractTarget object
----------------------------------------------------    
---@class AbstractTarget
---@field protected currentROE AbstractTarget.ROE
---@field protected typeModifier AbstractTarget.TypeModifier
---@field protected targeted boolean
AbstractTarget = {}
---@enum AbstractTarget.ROE
AbstractTarget.ROE = {
  Bandit = 1,  --target outside border, will not be attacket until shot to friendlies
  Hostile = 2 --valid target
}
---@enum AbstractTarget.TypeModifier
AbstractTarget.TypeModifier = {
  FIGHTER = 1,
  ATTACKER = 2,
  HELI = 3
}

AbstractTarget.names = {}
AbstractTarget.names.ROE = {
  [AbstractTarget.ROE.Bandit] = "BANDIT",
  [AbstractTarget.ROE.Hostile] = "HOSTILE",
}
AbstractTarget.names.typeModifier = {
  [AbstractTarget.TypeModifier.FIGHTER] = "FIGHTER",
  [AbstractTarget.TypeModifier.ATTACKER] = "ATTACKER",
  [AbstractTarget.TypeModifier.HELI] = "HELI"
}

---update ROE for target
---@param roeEnum AbstractTarget.ROE
function AbstractTarget:setROE(roeEnum) 
  self.currentROE = roeEnum
end

---@return AbstractTarget.ROE
function AbstractTarget:getROE() 
  return self.currentROE 
end

---@return boolean
function AbstractTarget:getTargeted() 
  return self.targeted
end

--flag mean target attacked by fighter
function AbstractTarget:setTargeted(newVal) 
  self.targeted = newVal
end

--type of target( FIGHTER or ATTACKER )used for priority calc
---@return AbstractTarget.TypeModifier
function AbstractTarget:getTypeModifier() 
  return self.typeModifier
end
----------------------------------------------------    
-- end of AbstractTarget
----------------------------------------------------  

----------------------------------------------------    
-- Target object, hide real object properties
-- uses it's own calculations for determining position
-- We have 3 types of 'control':
-- 1)Type1: radar contact, most accurate provide data directly from dcsObject
-- 2)Type2: no radar but we have NAILS, estimate position by Bearing and signal power
-- 3)Type3: no contact extrapolate for given time(standart 45 sec) then in should be deleted
----------------------------------------------------  
----            AbstractTarget    ObjectWithEvent
----                  ↓                  ↓
----               Target  <-------------    
----------------------------------------------------  
---@class Target: AbstractTarget, ObjectWithEvent
---@field private holdTime number how long keep extrapolate contact until drop
---@field private point Vec3 calculated point
---@field private position Position calculated data for getPosition()
---@field private velocity Vec3 calculated velocity
---@field private deltaVelocity Vec3 
---@field private lastSeen {['L1']: number, ["L2"]: number, ["L3"]: number} 
---@field private seenBy TargetContainer[] all containers contains this target in current detection frame
---@field private controllType Target.ControlType
---@field private shooter boolean
Target = utils.inheritFromMany(AbstractTarget, ObjectWithEvent)

---@enum Target.ControlType
Target.ControlType = {
LEVEL1 = 1,
LEVEL2 = 2,
LEVEL3 = 3
}

--for message forming
Target.names = {}
Target.names.ControlType = {
  [Target.ControlType.LEVEL1] = "L1",
  [Target.ControlType.LEVEL2] = "L2",
  [Target.ControlType.LEVEL3] = "L3"
  }

  ---@param targetContainer TargetContainer
  ---@param extrapolateTime number
  ---@return Target
function Target:create(targetContainer, extrapolateTime) 
  local instance = ObjectWithEvent:create(targetContainer:getTarget())--call explicitly
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  ---@cast instance Target
  
  local zeroVec = {x = 0, y = 0, z = 0}
  
  instance.holdTime = extrapolateTime or 45
  instance.point = zeroVec --calculated pont
  instance.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = zeroVec}
  instance.velocity = zeroVec
  instance.deltaVelocity = zeroVec
  instance.lastSeen = {L1 = 0, L2 = 0, L3 = timer.getAbsTime()} --when target was last seen in different control types(L3 always assumed)
  instance.seenBy = {targetContainer} --table contains all container with this target
  instance.controlType = Target.ControlType.LEVEL3
  
  instance.currentROE = AbstractTarget.ROE.Bandit
  instance.targeted = false
  instance.shooter = false --flag shows this target shoot at object belonging to our coalition
  instance.typeName = "Unknown" --leave unknown so it will be populate by updateTypes() in first run if type known
  instance.typeKnown = false --leave false so it will be populate by updateTypes() in first run if type known
  instance.typeModifier = AbstractTarget.TypeModifier.ATTACKER
  
  if targetContainer:isTypeKnown() then 
    --just set real typename
    instance:updateType()
  end
  
  --register this guy in eventHander so we can track his shots
  EventHandler:create():registerObject(instance)
  return instance
end

---@return string
function Target:getDebugStr() 
  return self:getName() .. " targeted: " .. tostring(self.targeted) .. " | ROE: " .. AbstractTarget.names.ROE[self.currentROE] .. " | Type: " .. self:getTypeName() 
    .. " | TypeMod: " .. AbstractTarget.names.typeModifier[self.typeModifier] .. " | Control: " .. Target.names.ControlType[self.controlType] .. "\n" 
  end

function Target:engineOffEvent(event) 
  --not interested in this
end

---@param event ShotEvent
function Target:shotEvent(event) 
  local t = event.weapon:getTarget()
    
    if t and event.initiator == self.dcsObject and event.weapon:getDesc().category == Weapon.Category.MISSILE then 
      local coal = t:getCoalition()
      if coal ~= self.dcsObject:getCoalition() and coal ~= 0 then --if it no friendly fire or attack neutral so it attack us(thankfull dcs not model multunational war)
        self.shooter = true
      end
    end
  end
  
---@return boolean
function Target:isExist() 
  --we can magically know target alive or not
  if self.dcsObject and self.dcsObject:isExist() and not self:isOutages() then 
    return true
  end
    
  EventHandler:create():removeObject(self)--we dead or contact lost deregister us
  return false
end

---@return boolean
function Target:isShooter() 
  return self.shooter
  end

  ---@return Vec3
function Target:getPoint() 
  return self.point
end

---@return Position
function Target:getPosition() 
  return self.position
end

---@return Vec3
function Target:getVelocity() 
  return self.velocity
end

---@return number
function Target:getSpeed() 
  --small helper
  return mist.vec.mag(self.velocity)
end

--return AOB for point
---@param point Vec3
---@return number
function Target:getAA(point) 
  local targetVel = self.velocity
  
  if mist.vec.mag(targetVel) == 0 then 
    --zero vec, velocity unknown, assume fly away from point
    return 180 
  end
  
  
  local fromTgtToPoint = mist.vec.getUnitVec(mist.vec.sub(point, self:getPoint()))
  --acos from tgt velocity and vector from tgt to point
  return math.abs(math.deg(math.acos(mist.vec.dp(mist.vec.getUnitVec(targetVel), fromTgtToPoint))))
  end

--this object was detected
---@param targetContainer TargetContainer
function Target:hasSeen(targetContainer)
  self.seenBy[#self.seenBy+1] = targetContainer
end

function Target:flushSeen()
  self.seenBy = {}
end

function Target:updateLEVEL1() 
  --just update all field with 'true' data
  self.point = self.dcsObject:getPoint()
  self.position = self.dcsObject:getPosition()
  self.deltaVelocity = mist.vec.sub(self.dcsObject:getVelocity(), self.velocity)
  self.velocity = self.dcsObject:getVelocity()
  
  --update timing
  local currentTime = timer.getAbsTime()
  self.lastSeen = {L1 = currentTime, L2 = currentTime, L3 = currentTime}
  self.controlType = Target.ControlType.LEVEL1
  
  self:flushSeen()
end

function Target:updateLEVEL2() 
  --guess position on bearing and signal strength
  --first find closest detector(for accuracy)
  local closestDet = {range = -1, detector = {}}
  
  for _, detect in pairs(self.seenBy) do 
    local range = mist.utils.get2DDist(self.dcsObject:getPoint(), detect:getDetector():getPoint())
    if range > closestDet.range then 
      closestDet.range = range
      closestDet.detector = detect
    end
  end
  
  --rounded distance to ~5 km till 100km and ~10 after
  local mult = 10^(math.floor(math.log(closestDet.range, 10))-2)
  closestDet.range = utils.round(closestDet.range/mult, 5)*mult
  
  --use real object pos to determine bearing
  local LOS = mist.vec.getUnitVec(mist.vec.sub(self.dcsObject:getPoint(), closestDet.detector:getDetector():getPoint()))
  
  --update data
  local zeroVec = {x = 0, y = 0, z = 0}
  self.point = mist.vec.add(closestDet.detector:getDetector():getPoint(), mist.vec.scalar_mult(LOS, closestDet.range))
  self.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = self.point}
  --self.velocity = zeroVec --velocity, leave last known
  self.deltaVelocity = zeroVec
  
  --update timing 2 and 3
  local currentTime = timer.getAbsTime()
  self.lastSeen.L2 = currentTime
  self.lastSeen.L3 = currentTime
  self.controlType = Target.ControlType.LEVEL2
  
  self:flushSeen()
end

function Target:updateLEVEL3() 
  --dumb extrapolate with last known velocity
  --update data
  local zeroVec = {x = 0, y = 0, z = 0}
  self.point = mist.vec.add(self.point, mist.vec.scalar_mult(self.velocity, timer.getAbsTime() - self.lastSeen.L3))
  self.position = {x = zeroVec, y = zeroVec, z = zeroVec, p = self.point}
  --self.velocity = zeroVec --velocity, leave last known
  self.deltaVelocity = zeroVec
  
  --update controlType
  self.controlType = Target.ControlType.LEVEL3
  --update timer
  self.lastSeen.L3 = timer.getAbsTime()
end

--update type of target
function Target:updateType() 
  if self.typeKnown then 
    return
  end
  
  local typeKnown = false
  for _, container in pairs(self.seenBy) do 
    if container:isTypeKnown() then 
      typeKnown = true
      break
      end
    end
  
  if not typeKnown then 
    --don't find a container with known type
    return
    end
  
  local obj = self.dcsObject
  self.typeName = obj:getTypeName()
  self.typeKnown = true
  
  if obj:hasAttribute("Fighters") or obj:hasAttribute("Interceptors") or obj:hasAttribute("Multirole fighters") then 
    self.typeModifier = AbstractTarget.TypeModifier.FIGHTER
  elseif obj:hasAttribute("Helicopters") then
    self.typeModifier = AbstractTarget.TypeModifier.HELI
  end
end

---@return boolean
function Target:isOutages() 
  return timer.getAbsTime() - self.lastSeen.L2 >= self.holdTime and timer.getAbsTime() - self.lastSeen.L1 >= self.holdTime
  end

--update track
function Target:update() 
  --if we don't have any containers which see us, we go to extrapolate
  if #self.seenBy == 0 then 
    self:updateLEVEL3()
    return 
  end
  
  --we have atleast 1 container trying to update type
  self:updateType()
  
  --try find container with level1 detection and also find that detector which know our type
  for _, container in pairs(self.seenBy) do     
    if container:isRangeKnown() then 
      --range known in this container just update LEVEL1
      self:updateLEVEL1()
      return
    end
  end
  
  --no LEVEL1 but still detected, go L2
  self:updateLEVEL2()
  return
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 4_2TargetGroup.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 5RadarsWrappers.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- Abstract Wrapper around radar object for detection
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----------------------------------------------------
AbstractRadarWrapper = utils.inheritFrom(DCS_Wrapper)

function AbstractRadarWrapper:getDetectedTargets() 
end

----------------------------------------------------
-- End of AbstractRadarWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around radar object for detection
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----                  ↓
----             RadarWrapper
----------------------------------------------------
RadarWrapper = utils.inheritFrom(AbstractRadarWrapper)

function RadarWrapper:create(dcsObject) 
  local instance = self:super():create(dcsObject)
  
  instance.detectionRange = 0
  --find detection range in desc table, if can't find leave 0 so it won't affect on go autonomous
  for _, sensor in pairs(dcsObject:getSensors()[1]) do 
    --type 1 for radar, take mean from all 4
    --table for reference: https://wiki.hoggitworld.com/view/DCS_func_getSensors
     if sensor["type"] == 1 then
        instance.detectionRange = (sensor.detectionDistanceAir.upperHemisphere.tailOn + sensor.detectionDistanceAir.upperHemisphere.headOn
          + sensor.detectionDistanceAir.lowerHemisphere.tailOn + sensor.detectionDistanceAir.lowerHemisphere.headOn)/4
        break
      end
  end
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function RadarWrapper:getDetectedTargets() 
  --return all detected targets by Radar/Optic/RWR(assume ELINT) wrapped in target Container
  --detection table https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
  local result = {}
  
  for _, contact in pairs(self:getController():getDetectedTargets(1, 2, 4, 16)) do 
      
      local _res, _err = xpcall(function ()
        
        if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") then
            result[#result+1] = TargetContainer:create(contact, self)
          end
      end, --VISUAL/OPTIC/RADAR/RWR
      debug.traceback)
    if not _res then 
      GlobalLogger:create():warning("RadarWrapper: Error when contack processing" .. mist.utils.serialize("\n traceback", _err))
    end
  end
  return result
end

--return true if point inside detection range
function RadarWrapper:inZone(point) 
  return mist.utils.get3DDist(self:getPoint(), point) < self.detectionRange
  end
----------------------------------------------------
-- end of RadarWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around radar object for detection
-- return only targets which 'can' be detected using 
-- line-of-sight and distance checks
-- for now(12.12.2023) if DCS_controller detect unit,
-- it will return it until detected Unit dies
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----                  ↓
----             RadarWrapper
----                  ↓
----         RadarWrapperWithChecks
----------------------------------------------------
RadarWrapperWithChecks = utils.inheritFrom(RadarWrapper)

function RadarWrapperWithChecks:getDetectedTargets() 
  --return all detected targets by Radar/Optic/RWR(assume ELINT) wrapped in target Container
  --detection table https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
  local result = {}
  local ourPos = self:getPoint()
  
  for _, contact in pairs(self:getController():getDetectedTargets(1, 2, 4, 16)) do  
      
    local _res,_err = xpcall(function ()
      --this will add target only if it has clear LOS and distance < self.detectionRange * 1.5
      if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") 
        and land.isVisible(contact.object:getPoint(), ourPos) --CHECK LOS
        and mist.utils.get3DDist(contact.object:getPoint(), ourPos) < self.detectionRange * 1.5 then --check range
          result[#result+1] = TargetContainer:create(contact, self)
      end
    end, 
    debug.traceback)

    if not _res then 
      GlobalLogger:create():warning("RadarWrapperWithChecks: Error when contack processing" .. mist.utils.serialize("\n traceback", _err))
    end
  end
    return result
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 6AirbaseWrapper.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- Wrapper around airbase
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----------------------------------------------------
AbstractAirbaseWrapper = utils.inheritFrom(DCS_Wrapper)

function AbstractAirbaseWrapper:getParking() 
  
end

--return true if it still usable, so atleas you can get parkings in future
--return false if airbase totally not usable(i.e. captured or destroyed)
function AbstractAirbaseWrapper:isAvail() 
  
end

--how many parking avail()
function AbstractAirbaseWrapper:howManyParkingAvail() 
  return 0
end

----------------------------------------------------
-- end of AbstractAirbaseWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around airbase
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----                  ↓
----            AirbaseWrapper
----------------------------------------------------
AirbaseWrapper = utils.inheritFrom(AbstractAirbaseWrapper)
AirbaseWrapper._instances = {}

function AirbaseWrapper:create(id) 
  
  local key = tostring(id)
  if self._instances[key] then 
    return self._instances[key]
  end
  
  local instance = nil
  
 --find airbase by id
  for _, airbase in pairs(world.getAirbases(nil)) do 
    if airbase:getID() == id then
      instance = self:super():create(airbase)
      break
    end
  end
  
  --check if we find something
  if not instance then 
    GlobalLogger:create():warning("WARNING: AirbaseWrapper CANT FIND AIRBASE WITH ID: " .. tostring(id))
    return
  end
  --save original coalition, cause airfield can be captured
  instance.originalCoalition = instance.dcsObject:getCoalition()
  
  self._instances[key] = instance
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function AirbaseWrapper:getParking()
  --if airbase was captured, return nil
  if self.dcsObject:getCoalition() ~= self.originalCoalition then 
    return nil
  end
  
  --try to return avail parking, if can't just return nil
  return self.dcsObject:getParking(true)[1]
end
  
function AirbaseWrapper:isAvail() 
  --if airbase was captured, return false
  if self.dcsObject:getCoalition() ~= self.originalCoalition then 
    return false
  end
  return true
end
  
  
--how many parking avail(), for carrier return 4 always
function AirbaseWrapper:howManyParkingAvail() 
  local counter = 0
  --[[
   16 : Valid spawn points on runway
   40 : Helicopter only spawn  
   68 : Hardened Air Shelter
   72 : Open/Shelter air airplane only
   104: Open air spawn
  ]]
  local parkings = self.dcsObject:getParking(true)
  if #parkings > 100 then 
    --i think it's big enough
    return 75
  end
  
  for _, park in pairs(parkings) do 
    
    if park.Term_Type == 68 or park.Term_Type == 72 or park.Term_Type == 104 then 
      counter = counter + 1
    end
  end
  
  return counter
end  

----------------------------------------------------
-- end of AirbaseWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around AircraftCarrier
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----                  ↓
----            CarrierWrapper
----------------------------------------------------

CarrierWrapper = utils.inheritFrom(AbstractAirbaseWrapper)
CarrierWrapper._instances = {}

function CarrierWrapper:create(id) 
    local key = tostring(id)
    if self._instances[key] then 
      return self._instances[key]
    end
    
    local instance = nil

    for _, airbase in pairs(world.getAirbases()) do 
      if airbase:hasAttribute("AircraftCarrier") and tonumber(airbase:getID()) == id then 
        instance = self:super():create(airbase)
        break
      end
    end
    
    if not instance then 
      GlobalLogger:create():warning("WARNING: CarrierWrapper CANT FIND CARRIER WITH ID: " .. tostring(id))
      return nil
    end

    instance.parkingCount = #instance.dcsObject:getParking()
    self._instances[key] = instance
    return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


function CarrierWrapper:getParking()
  if not self:isAvail() then 
    --carrier not exist return nil
    return nil
  end
  
  --parkings on carrier broken, return osition of carrier
  local point = self:getPoint()
  return {vTerminalPos = {
      x = point.x,
      y = point.y,
      z = point.z
      }
    }
end

function CarrierWrapper:isAvail() 

 return self:isExist()
end

--how many parking avail(), for carrier return maximum 2 always
--(parking data broken))))
function CarrierWrapper:howManyParkingAvail() 
  if not self:isExist() then 
    return 0
  end
  return #self.dcsObject:getParking(true) - self.parkingCount + 2
end

----------------------------------------------------
-- end of CarrierWrapper
----------------------------------------------------

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 7MissileWrapper.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- Wrapper around A/A Missile
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----            MissileWrapper
----------------------------------------------------

MissileWrapper = utils.inheritFrom(DCS_Wrapper)

function MissileWrapper:create(dcsObject) 
  --firstly check if this weapon have target(where it guiding to), if no target -> we not interested in this
  if not dcsObject:getTarget() then 
    return nil
  end

  local descTable = dcsObject:getDesc()
  --check guidance, we interested only in IR/SARH/ARH
  if descTable.guidance ~= 2 and descTable.guidance ~= 3 and descTable.guidance ~= 4 then 
    return nil
  end
  local instance = {}
  --missile doesn't have id, populate all values
  instance.dcsObject = dcsObject
  instance.name = "Missile"
  instance.typeName = dcsObject:getTypeName()
  instance.guidance = descTable.guidance
  instance.target = dcsObject:getTarget()
  instance.id = utils.getGeneralID()
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function MissileWrapper:getGuidance() 
  --guidance types:https://wiki.hoggitworld.com/view/DCS_Class_Weapon
  return self.guidance
end

function MissileWrapper:getClosingSpeed() 
  local speed = mist.vec.mag(self:getVelocity())
  return speed - mist.vec.dp(mist.vec.getUnitVec(mist.vec.sub(self.target:getPoint(), self:getPoint())), 
    self.target:getVelocity())
end

--return time to Hit
function MissileWrapper:getTTI()
  return mist.utils.get3DDist(self:getPoint(), self.target:getPoint()) / self:getClosingSpeed()
  end

--checks is missile still a factor, will return true if it dead or closingSpeed < 100 m/s
function MissileWrapper:isTrashed() 
  if not self.target:isExist() or not self:isExist() then --if target dead we also not interested
    return true
  end
  
  if self:getClosingSpeed() < 100 then 
    GlobalLogger:create():info("missile trashed, target: " .. self.target:getName() .. " closing: " .. tostring(self:getClosingSpeed()))
    return true
  end
  
  return false
end

--missile pittbull or Fox2, so no more support needed
--pittbull assumed when missile in ~ 18000m from target
function MissileWrapper:isActive() 
  return self:getGuidance() == Weapon.GuidanceType.IR 
    or (self:getGuidance() == Weapon.GuidanceType.RADAR_ACTIVE and mist.utils.get3DDist(self:getPoint(), self.target:getPoint()) < 18000)
  end
----------------------------------------------------
-- end of MissileWrapper
----------------------------------------------------

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 8_1DeferredContainer.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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


---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_0AbstractFSM.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- Absract FSM state
----------------------------------------------------

AbstractState = utils.inheritFrom(AbstractCAP_Handler_Object)
AbstractState.enumerator = -999999

--arg - is object which we should control
function AbstractState:create(handedObj) 
  local instance = {}
  
  instance.object = handedObj
  instance.id = utils.getGeneralID()
  instance.enumerator = AbstractState.enumerator --uniq ID of state
  --name used for debug
  instance.name = "AbstractState"
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end
  
--execute current state routines, arg is dictionary, can be empty
function AbstractState:run(arg) 
  
end

--doing all needed setups, hich should be maked only once(on creation or on transition from different state)
--primary set AI options
function AbstractState:setup() 
  
end

--all clean up needed(line target reset)
function AbstractState:teardown() end
----------------------------------------------------
-- end of AbstractState
----------------------------------------------------

----------------------------------------------------
-- Stack used for contain and call FSM states
----------------------------------------------------

FSM_Stack = {}
FSM_Stack.MAX_SIZE = 50
FSM_Stack.MAX_CHANGES = 75

function FSM_Stack:create()
  local instance = {}
  
  instance.data = {}
  --pointer on top of the stack
  instance.topItem = 0
  instance.stateChanges = 0
  return setmetatable(instance, {__index = self})
end

function FSM_Stack:clear()
  --unwind stack
  for i = self.topItem, 1, -1 do 
    self.data[i]:teardown()
  end 
  
  self.stateChanges = self.stateChanges + 1
  self.topItem = 0
end

--FSM_State is valid AbstractState(or derived) object
--FSM_State added to top of the stack
--calls FSM_state:setup() so state will be properly configured
function FSM_Stack:push(FSM_state)
  self.topItem = self.topItem + 1
  self.stateChanges = self.stateChanges + 1

  if self.stateChanges > self.MAX_CHANGES then 
    self.stateChanges = 0
    error("reach max state changes " .. self:getCurrentState().object:getName())
  end

  if self.topItem > FSM_Stack.MAX_SIZE then 
    self.topItem = 1
    error("STACK SIZE EXCECEED")
  end
  self.data[self.topItem] = FSM_state
  self.data[self.topItem]:setup()
end

--delete item from top of the stack
--calls setup() so new active state will be properly configured
function FSM_Stack:pop() 
  self.stateChanges = self.stateChanges + 1
  
  if self.stateChanges > self.MAX_CHANGES then 
    self.stateChanges = 0
    error("reach max state changes " .. self:getCurrentState().object:getName())
  end
  --check if stack already empty
  if self.topItem == 1 then 
    return
  end
  
  self.data[self.topItem]:teardown()
  self.topItem = self.topItem - 1
  self.data[self.topItem]:setup()
end

--return state enumerator from top of the stack
function FSM_Stack:getStateEnumerator() 
  return self.data[self.topItem].enumerator
end

--return state  from top of the stack
function FSM_Stack:getCurrentState() 
  return self.data[self.topItem]
  end

--Runs FSM state from top of the stack
--also guaranties arg ~= nil
function FSM_Stack:run(arg) 
  
  self.data[self.topItem]:run(arg or {})
end

function FSM_Stack:resetCounter()
  self.stateChanges = 0
end

function FSM_Stack:unwind()
  if self.topItem > 0 then
    self.topItem = 1
  end
end

--static function to print stack
function FSM_Stack.printStack(stack, margin) 
  local m = utils.getMargin(margin) .. "STACK:\n"
  
  for i = stack.topItem, 1, -1 do 
    m = m .. utils.getMargin(margin + 2) .. stack.data[i].name .. "\n"
  end
  
  return m
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_1CapPlaneFSM.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_2CapPlane.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------


----------------------------------------------------
-- Abstract fighter aircraft with FSM
----------------------------------------------------  
FighterEntity_FSM = {}


function FighterEntity_FSM:setFSM_Arg(name, val) 
  self.FSM_args[name] = val
  end

--FSM_state is valid object, add it to stack and call it
function FighterEntity_FSM:setFSM(FSM_state) 
  self.FSM_stack:push(FSM_state)
  self.FSM_stack:run(self.FSM_args)
end

function FighterEntity_FSM:setFSM_NoCall(FSM_state) 
  self.FSM_stack:push(FSM_state)
  end

function FighterEntity_FSM:clearFSM()
  self.FSM_stack:clear()
  end

function FighterEntity_FSM:callFSM() 
  self.FSM_stack:run(self.FSM_args)--run current state
  
  --vipe args
  self.FSM_args = {}
end

function FighterEntity_FSM:popFSM() 
  self.FSM_stack:pop()
  --calls new state
  self.FSM_stack:run(self.FSM_args)
end

function FighterEntity_FSM:popFSM_NoCall() 
  self.FSM_stack:pop()
end

--return enumerator of current FSM state
function FighterEntity_FSM:getCurrentFSM() 
  return self.FSM_stack:getStateEnumerator()
end

----------------------------------------------------
-- Single fighter aircraft
----------------------------------------------------  
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper    FighterEntity_FSM
----                  ↓                ↓
----              CapPlane <-----------
----------------------------------------------------


CapPlane = utils.inheritFromMany(DCS_Wrapper, FighterEntity_FSM)
CapPlane.options = {
  ThreatReaction = 1,
  ROE = 2,
  RDR = 4,
  ECM = 8,
  AttackRange = 16,
  BurnerUse = 32
  }

function CapPlane:create(PlaneGroup) 
  --call consructor explicitly
  local instance = DCS_Wrapper:create(PlaneGroup:getUnit(1))--we get a group with only 1 unit
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.groupID = PlaneGroup:getID()
  --override controller field, we need group level controller
  instance.controller = PlaneGroup:getController()

  instance.waitAfterLiftOff = 60 --default time
  if PlaneGroup:getUnit(1):inAir() then 
    --plane in Air, will wait 5sec so it can properly configure
    instance.waitAfterLiftOff = 5
  end
  
  instance.isAirborne = false
  instance.liftOffTime = nil
  
  --set to true when aircraft land and turn off it engines, so it can be deactivated
  instance.shutdown = false
  
  --missile with most range
  instance.bestMissile = {MaxRange = 0, MAR = 0}
  --last lauched missile
  instance.ourMissile = nil
  --all missile which guided to us
  instance.threatMissiles = {}
  
  instance.myGroup = nil --CapGroup i belong to
  instance.myElement = nil --CapElement i belong to
  
  --overriden options(external caller can set custon option i.e. use radar instead of default for fsm state)
  instance.overridenOptions = {}
  --implement FighterEntity FSM field
  instance.FSM_stack = FSM_Stack:create()
  --initialize with stub FSM
  instance.FSM_stack:push(FSM_Start:create(instance))
  instance.FSM_args = {
    waypoint = nil, --new waypoint for FlyToPoint
    newTarget = nil --new target for Attack states
    } --dictionary with args for FSM
  
  instance.target = nil --target object which we attack
  
  EventHandler:create():registerObject(instance)
  return instance
end

function CapPlane:getGroupID() 
  return self.groupID
  end

function CapPlane:getController() 
  return self.controller
  end

--return true if group in air and ready for tasking
---or group was airbirne when spawned, or after 60 sec from inAir (in return true when aircraft finishes it's departure routines????)
---so ai can execute all it's take off routines
function CapPlane:inAir()
  --return true if we already in air
  if self.isAirborne then 
    return true
  end
  
  --check if group in air, then set timer
  if not self.dcsObject:inAir() then 
    return false
  elseif not self.liftOffTime then
    --set timer
    self.liftOffTime = timer.getAbsTime()
  elseif timer.getAbsTime() - self.liftOffTime >= self.waitAfterLiftOff then  
    --set flag for future early exit
    self.isAirborne = true
    return true
  end

  return false
end

function CapPlane:isExist() 
  if self.dcsObject and self.dcsObject:isExist() then
    return true
  end
  
  --delete target to remove targeted flag
  self:resetTarget()
  EventHandler:create():removeObject(self)
  return false
end


function CapPlane:engineOffEvent(event) 
  if event.initiator == self.dcsObject then
    self.shutdown = true
  end
end

function CapPlane:shotEvent(event) 
  if event.initiator == self.dcsObject then
    self.ourMissile = MissileWrapper:create(event.weapon)
  elseif event.weapon:getTarget() == self.dcsObject then
    self.threatMissiles[#self.threatMissiles+1] = MissileWrapper:create(event.weapon)
  end
end

function CapPlane:getFuel() 
  
  if not self:isExist() then
    return 0
  end
  return self.dcsObject:getFuel()
end

--return true if support ourMissile no more needed
--also missile if so
function CapPlane:canDropMissile() 
  return not self.ourMissile
end

--update best missile to passed msl or missile in air if it has more range
function CapPlane:updateBestMissile(msl)   
  --if have missile in air, also check it for
  if self.ourMissile and utils.WeaponTypes[self.ourMissile:getTypeName()].MaxRange >= self.bestMissile.MaxRange then 
    self.bestMissile = utils.WeaponTypes[self.ourMissile:getTypeName()]
    return
  end
  
  self.bestMissile = msl
end

--check status and delete if no need to support it
function CapPlane:updateOurMissile() 
  if not self.ourMissile then 
    return
  elseif self.ourMissile:isTrashed() or self.ourMissile:isActive() then 
    GlobalLogger:create():info(self:getName() .. " missile done")
    self.ourMissile = nil
  end
end

--yeah this is shit, but we it makes 2 job at once, and it would be called only once on each update
function CapPlane:getAmmo()
  
  local resultAmmo = {
    [Weapon.GuidanceType.IR] = 0, --IR
    [Weapon.GuidanceType.RADAR_ACTIVE] = 0, --ARH
    [Weapon.GuidanceType.RADAR_SEMI_ACTIVE] = 0  --SARH
    }
  if not self:isExist() then
    return resultAmmo
  end
  
  local ammoTable = self.dcsObject:getAmmo()
  if not ammoTable then 
    return resultAmmo
  end
  
  local bestMissile = {MaxRange = 0, MAR = 0}
  --populate with data, also update bestMissile
  for idx, ammo in pairs(ammoTable) do 
    --get all ammo
    if ammo.desc and resultAmmo[ammo.desc.guidance]  then
      resultAmmo[ammo.desc.guidance] = resultAmmo[ammo.desc.guidance] + ammo.count
      
      --update best missile
      if utils.WeaponTypes[ammo.desc.typeName].MaxRange > bestMissile.MaxRange then 
        bestMissile = utils.WeaponTypes[ammo.desc.typeName]
      end
    end
  end
  
  self:updateBestMissile(bestMissile)
  return resultAmmo
end

--return missile with most range(including missile in air)
function CapPlane:getBestMissile() 

  return self.bestMissile
end

function CapPlane:getDetectedTargets()
  if not self:isExist() then 
    return {}
    end
  
  --all detection except DLink
  return self:getController():getDetectedTargets(Controller.Detection.VISUAL, 
      Controller.Detection.OPTIC, Controller.Detection.RADAR, 
      Controller.Detection.IRST, Controller.Detection.RWR)
end

function CapPlane:getNails()
  --return array with targets detected by RWR wrapped in DCS_Wrapper
  return self:getController():getDetectedTargets(16)
end

function CapPlane:registerGroup(capGroup) 
  self.myGroup = capGroup
end

function CapPlane:registerElement(capElement) 
  self.myElement = capElement
end

function CapPlane:setTarget(target) 
  --delete old target if present
  if self.target then 
    self:resetTarget()
    end
  
  --set targeted flag, indicate we attack it
  target:setTargeted(true)
  self.target = target
end

function CapPlane:resetTarget() 
  --set targeted flag, indicate we drop it
  if not self.target then 
    return
    end
  self.target:setTargeted(false)
  self.target = nil
end

function CapPlane:getAoA() 
  --sometimes return nil(?)
  return mist.getAoA(self.dcsObject) or 0
  end

--optionTbl is packed option from utils or nil if you want to delete IT
--optionName is CapPlane.options
function CapPlane:setOption(optionName, optionTbl) 
  self.overridenOptions[optionName] = optionTbl
  
  if not optionTbl then 
    --set default options for FSM
    self.FSM_stack:getCurrentState():setOptions()
    return
  end
  
  --push option to DCS AI, overriden option for new FSM states
  --now need override current setting
  self:getController():setOption(unpack(optionTbl))
end

function CapPlane:resetOptions() 
  self.overridenOptions = {}
  --set default options for FSM
  self.FSM_stack:getCurrentState():setOptions()
  end

function CapPlane:callFSM() 
  self.FSM_stack:run(self.FSM_args)--run current state
  
  --check if need to reapply task
  self.FSM_stack:getCurrentState():checkTask()
  
  --vipe args
  self.FSM_args = {}
  self.FSM_stack:resetCounter()
  end


function CapPlane:getDebugDump()
  local result = {
    exist = utils.getInProcected(self.isExist, self),
    inAir = utils.getInProcected(self.inAir, self),
    FSM_Stack = self.FSM_stack,
    point = utils.getInProcected(self.getPoint, self),
    ammo = utils.getInProcected(self.getAmmo, self),
    bestMissile = utils.getInProcected(self.getBestMissile, self),
    fuel = utils.getInProcected(self.getFuel, self)
  }
  return result
end
----------------------------------------------------
-- end CapPlane
----------------------------------------------------

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_3_1CapElementFSM.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
---- Start task, will wait until all aircraft airborne
-----and ready for tasking, also set each plane 
-----to hold as soon as it airborne
----------------------------------------------------  
----             AbstractState
----                  ↓
----          FSM_Element_Start
----------------------------------------------------

FSM_Element_Start = utils.inheritFrom(AbstractState)

function FSM_Element_Start:create(handledElem)
  local instance = self:super():create(handledElem)
  
  --check if all aircraft airborne on start
  instance.isInAir = true
  for _, plane in pairs(handledElem.planes) do 
    if not plane:getObject():inAir() then 
      instance.isInAir = false
    end
  end
  --orbit task for all aircraft
  instance.task = { 
     id = 'Orbit', 
     params = { 
       pattern = "Circle",
       point = mist.utils.makeVec2(handledElem:getPoint()),
       speed = 140,
       altitude = 1000
     } 
    }
  instance.numberPlanes = #handledElem.planes
  instance.name = "FSM_Element_Start"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Start
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end


--check if plane in Air and if so, push task
function FSM_Element_Start:run(arg) 

  if self.isInAir then 
    --already in air, just wait until group replace us
    return
  end

  local inAir = true
  
  for _, plane in pairs(self.object.planes) do 
    if not plane:getObject():inAir() then 
      inAir = false
    elseif plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.AbstractPlane_FSM then 

      plane:clearFSM()
      --restrict burner(yes by default in state it on, but
      --fuel consuption too great)
      plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off)
      plane:setFSM_NoCall(FSM_FlyOrbit:create(plane, self.task))
    end
  end
  
  self.isInAir = inAir
end

----------------------------------------------------
-- end of FSM_Element_Start
----------------------------------------------------

----------------------------------------------------
---- First plane assumed lead and will fly in passed
---- state, other planes in FSM_Formation
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_FlyFormation
----------------------------------------------------
FSM_Element_FlyFormation = utils.inheritFrom(AbstractState)

function FSM_Element_FlyFormation:create(handledElem, state, ...)
  local instance = self:super():create(handledElem)
  
  instance.state = state
  instance.stateArg = {...}
  instance.numberPlanes = #handledElem.planes
  instance.name = "FSM_Element_FlyFormation"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlyFormation
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_FlyFormation:setup() 
  --set wingmans to formation
  local leadID = self.object.planes[1]:getGroupID()
  
  for i = 2, #self.object.planes do 
    self.object.planes[i]:clearFSM()
    self.object.planes[i]:setFSM(FSM_Formation:create(self.object.planes[i], leadID, utils.tasks.formation.Cruise[i]))
  end
  
  --set lead to state
  self.object.planes[1]:clearFSM()
  self.object.planes[1]:setFSM(self.state:create(self.object.planes[1], unpack(self.stateArg)))
end

function FSM_Element_FlyFormation:teardown() 
  --disable burner override
  for _, plane in pairs(self.object.planes) do 
    plane:setOption(CapPlane.options.BurnerUse, nil)--restrict burner
  end
end

function FSM_Element_FlyFormation:run(arg) 
  --push argument to lead
  self.object.planes[1]:setFSM_Arg("waypoint", arg.waypoint)
  self.object.planes[1]:setFSM_Arg("newTarget", arg.newTarget)
  
  --check if someone dies 
  if #self.object.planes ~= self.numberPlanes then
    --someone dies, or has been moved from element,
    --reapply task
    self:setup()
    
    --update counter
    self.numberPlanes = #self.object.planes
  end
end



----------------------------------------------------
-- end of FSM_Element_FlyFormation
----------------------------------------------------

----------------------------------------------------
---- Group fly toward point, but as singletons
---- (all planes using passed state)
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_FlyFormation
----                  ↓
----        FSM_Element_FlySeparatly
----------------------------------------------------
FSM_Element_FlySeparatly = utils.inheritFrom(FSM_Element_FlyFormation)


function FSM_Element_FlySeparatly:create(handledElem, state, ...)
  local instance = self:super():create(handledElem, state, ...)
  
  instance.name = "FSM_Element_FlySeparatly"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlySeparatly
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_FlySeparatly:setup() 
  --set all planes to passed state
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    --restrict burner(yes by default in state it on, but
      --fuel consuption too great)
    plane:setFSM(self.state:create(plane, unpack(self.stateArg)))
  end
end

--teardown inherited

function FSM_Element_FlySeparatly:run(arg) 
  --push argument to planes
  for _, plane in pairs(self.object.planes) do 
    plane:setFSM_Arg("waypoint", arg.waypoint)
    plane:setFSM_Arg("newTarget", arg.newTarget)
  end
  --no need check if someone dies 
end

----------------------------------------------------
---- Abstract combat tactic with methods needed during combat
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----------------------------------------------------

FSM_Element_AbstractCombat = utils.inheritFrom(AbstractState)

  
--shortcut to get group target
function FSM_Element_AbstractCombat:getTargetGroup() 
  return self.object.myGroup.target
end  

function FSM_Element_AbstractCombat:logPrefix()
  return "Group: " .. self.object.myGroup:getName() .. " Element: " .. self.object:getName()
end

----------------------------------------------------
---- Abstract combat tactic with tactic inst
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----------------------------------------------------

FSM_Element_TacticWrapper = utils.inheritFrom(FSM_Element_AbstractCombat)

function FSM_Element_TacticWrapper:create(handledElem, tacticInst) 
  local instance = self:super():create(handledElem)
  
  --timestamp when tactic starts
  instance.startTime = 0
  instance.tactic = tacticInst
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_TacticWrapper:setup() 
  self.startTime = timer.getAbsTime()
end

function FSM_Element_TacticWrapper:getTimer() 
  return timer.getAbsTime() - self.startTime
end

----------------------------------------------------
---- Basic combat flying tactic(inmplement rejoin lead
---- by wingmans)
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----------------------------------------------------
FSM_Element_FlyPoint = utils.inheritFrom(FSM_Element_TacticWrapper)

--all planes set FlyToPoint
--Lead always fly to point, wingmans if in 5km
--fly to point or trying to intercept lead
function FSM_Element_FlyPoint:flyToPoint(point)
  local lead = self.object.planes[1]
  lead:setFSM_Arg("waypoint", point)

  --for other planes task will depend on distance from lead
  for i = 2, #self.object.planes do 
    local plane = self.object.planes[i]
    
    if mist.utils.get3DDist(plane:getPoint(), lead:getPoint()) > 7500 then 
      --we far away from lead, intercept our flightLead instead
      local leadIntercept = mist.fixedWing.buildWP(
        utils.getInterceptPoint(lead, plane, mist.vec.mag(lead:getVelocity())), 
          "turningpoint", 500, lead:getPoint().y, "BARO")
      plane:setFSM_Arg("waypoint", leadIntercept)

      GlobalLogger:create():drawPoint({pos = leadIntercept, text = plane:getName() .. " LEAD intercept point"})
    else
      --we close enough, set intercept point
      plane:setFSM_Arg("waypoint", point)
    end
  end
end
----------------------------------------------------
---- Basic intercept
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----                  ↓
----         FSM_Element_Intercept
----------------------------------------------------

FSM_Element_Intercept = utils.inheritFrom(FSM_Element_FlyPoint)

--tactic instance used to checkFor transition between states
function FSM_Element_Intercept:create(handledElem, tacticInst) 
  local instance = self:super():create(handledElem, tacticInst)
  instance.name = "FSM_Element_Intercept"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Intercept
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--FSM_Element_Intercept:setup() inherited

--create intercept point, intercept speed should be equals 
--to target speed + 75 but not below 300m/s
function FSM_Element_Intercept:getInterceptPoint() 
  local Speed = mist.vec.mag(self:getTargetGroup():getLead():getVelocity()) + 75
  if Speed < 300 then 
    Speed = 300
  end

  local point = mist.fixedWing.buildWP(
    utils.getInterceptPoint(self:getTargetGroup():getLead(), self.object.planes[1], Speed), 
      "turningpoint", Speed, self.tactic.alt)
  
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() 
      .. " intercept point speed/alt: " .. tostring(Speed) .. "/" .. tostring(self.tactic.alt)})
  return point
end

function FSM_Element_Intercept:run(arg)
  --check if we should stop
  if self.tactic:interceptCheck() then
    return
  end
  --set point for element
  self:flyToPoint(self:getInterceptPoint())
end


----------------------------------------------------
---- Fly away from target at given speed, tactic 
---- should replace this state at their own
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_FlyPoint
----                  ↓
----           FSM_Element_Pump
----------------------------------------------------

FSM_Element_Pump = utils.inheritFrom(FSM_Element_FlyPoint)

function FSM_Element_Pump:create(handledElem, tactic, speed)
  local instance = self:super():create(handledElem, tactic)
  instance.speed = speed
  instance.name = "FSM_Element_Pump"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Pump
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

--FSM_Element_Intercept:setup() inherited

function FSM_Element_Pump:run(arg)
  --check if we should stop
  if self.tactic:checkPump() then 
    return
  end
  
  --[[if we have second element, fly toward it, or just fly away
  local point = {}
  local element = self.object:getSecondElement()
  if element then 
    local elemPos = element:getPoint()
    local targetToElem = mist.vec.getUnitVec(mist.vec.sub(elemPos, self:getTargetGroup():getPoint()))
    point = mist.fixedWing.buildWP(
      mist.vec.add(elemPos, mist.vec.scalar_mult(targetToElem, 50000)), "turningpoint", self.speed, 7000, "BARO")
    
    GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT, to other elem: " .. tostring(element)})
  else
    local ourPos = self.object:getPoint()
    local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(ourPos, self:getTargetGroup():getPoint()))
    point = mist.fixedWing.buildWP(
      mist.vec.add(ourPos, mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", self.speed, 7000, "BARO")  
    
    GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT, to elem: " .. tostring(element)})
  end--]]
  
  local ourPos = self.object:getPoint()
  local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(ourPos, self:getTargetGroup():getPoint()))
  local point = mist.fixedWing.buildWP(
      mist.vec.add(ourPos, mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", self.speed, self.tactic.alt)  
    
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " PUMP POINT speed/alt: " 
      .. tostring(self.speed) .. "/" .. tostring(self.tactic.alt)})
  
  --set point for element
  self:flyToPoint(point)
end

----------------------------------------------------
---- Attack state tactic 
---- should replace this state at their own
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----          FSM_Element_Attack
----------------------------------------------------

FSM_Element_Attack = utils.inheritFrom(FSM_Element_Intercept)

function FSM_Element_Attack:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.tactic = tactic
  instance.name = "FSM_Element_Attack"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Attack
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})  
end



function FSM_Element_Attack:getDataForPriorityCalc(target) 
  local speed = mist.vec.mag(target:getVelocity())
  local alt = target:getPoint().y
  --use this because getAA return absolute and in degrees
  local los = mist.vec.dp(mist.vec.getUnitVec(target:getPoint(), self.object:getPoint()), mist.vec.getUnitVec(target:getVelocity()))
  local range = mist.utils.get3DDist(target:getPoint(), self.object:getPoint())
  
  return target, speed, alt, los, range
end

function FSM_Element_Attack:calculatePriority(target, speed, alt, los, range)   
  local MAR, capGroup = utils.PlanesTypes[target:getTypeName()].Missile.MAR, self.object.myGroup
  local typeModifier = capGroup.priorityForTypes[target:getTypeModifier()]
  local targeted = 1
  
  if target.targeted then 
    targeted = 0.75 
  end
  
  return (((speed^2)/2 + 10*alt)*1.5 + 0.1*((80000*(los+1.5)*(capGroup:getBestMissile().MaxRange/range)^2)
      *(MAR/range)*targeted) + 2.5*MAR*(los+1))*typeModifier
end

function FSM_Element_Attack:prioritizeTargets(targets) 
  local result = {}
  for _, target in pairs(targets) do 
    result[#result+1] = {tgt = target, priority = self:calculatePriority(self:getDataForPriorityCalc(target))}
  end
  
  --IN DESCENDING ORDER YPU IDIOT
  table.sort(result, function(e1, e2) return e1.priority > e2.priority end)
  return result
end

--add target to plane without fsmAttack and wiothout target
function FSM_Element_Attack:tryAddTarget(plane, targetList) 
  
  if plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.FSM_Defence then 
    return 
    end
  
  for _, targetTbl in pairs(targetList) do 
    local target = targetTbl.tgt
    
    if not target:getTargeted() then 
      plane:setTarget(target)
      plane:setFSM(FSM_Attack:create(plane, target:getID()))
      return
      --set targeted target only is higher then non targeted target at high energy at our max range
    elseif targetTbl.priority/self:calculatePriority(
        target, 300, 8000, 1, self.object.myGroup:getBestMissile().MaxRange) >= 1.10 then
        
      --add targeted 
      GlobalLogger:create():debug(plane:getName() .. " add targeted: " .. target:getName())
      plane:setTarget(target)
      plane:setFSM(FSM_Attack:create(plane, target:getID()))
      return
    end
  end
end

--replace target in group
function FSM_Element_Attack:tryReplaceTarget(plane, targetList) 
  
  for _, targetTbl in pairs(targetList) do 
    local target = targetTbl.tgt
    
    --replace only if different target
    if target ~= plane.target then
    
      local ourPriority = self:calculatePriority(self:getDataForPriorityCalc(plane.target))
      local ratio = targetTbl.priority/ourPriority
      if ratio > 1.2 and not target:getTargeted() then 
        GlobalLogger:create():debug(plane:getName() ..  " change target, ratio: " .. tostring(ratio))
        plane:resetTarget()
        plane:setTarget(target)
        plane:setFSM_Arg("newTarget", target:getID())
        return
      end
    end
  end
end

function FSM_Element_Attack:setup() 
  --set attack states
  local targetSorted = self:prioritizeTargets(self:getTargetGroup():getTargets())
  
  for idx, plane in pairs(self.object:sortByAmmo()) do 
    self:tryAddTarget(plane, targetSorted)
  end
end


function FSM_Element_Attack:teardown() 
  GlobalLogger:create():debug(self.object:getName() .. " reset attack state")
  
   for idx, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      
      plane:resetTarget()--target deleted from plane and it will be automatically POPed from FSM
    end
  end
end

function FSM_Element_Attack:run(arg)

  if self.tactic:checkAttack() then 
    return
  end
  
  --intercept point 
  local interceptPoint = self:getInterceptPoint()

  local targetSorted = self:prioritizeTargets(self:getTargetGroup():getTargets())
  for idx, plane in pairs(self.object:sortByAmmo()) do 
    if not plane.target then 
      self:tryAddTarget(plane, targetSorted)
    else
      self:tryReplaceTarget(plane, targetSorted)
    end
    --if plane don't have target it just fly toward target
    plane:setFSM_Arg("waypoint", interceptPoint)
  end
end


----------------------------------------------------
---- Defend against missile, just call planes fsm
---- allow him to execute their defend behaviour
---- will maintain state until all planes clear
---- if plane exit from defend earlier
---- will set new WP for flying away from target
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Defending
----------------------------------------------------
FSM_Element_Defending = utils.inheritFrom(FSM_Element_TacticWrapper)

function FSM_Element_Defending:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.name = "Defending"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Defending
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--function FSM_Element_Defending:setup() inherited

--return true when ALL aircraft not defending
function FSM_Element_Defending:checkDefend() 
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() == AbstractPlane_FSM.enumerators.FSM_Defence then 
      return false
    end
  end
  
  return true
end

function FSM_Element_Defending:run(arg) 
  if self:checkDefend() then 
    --we stop defend, return to called
    self.object:popFSM()
    return
  elseif self.tactic:checkColdOps() then
    --we switch to cold ops
    return
  end
  
  local targetToSelf = mist.vec.getUnitVec(mist.vec.sub(self:getTargetGroup():getPoint(), self.object:getPoint()))
  local point = mist.fixedWing.buildWP(
    mist.vec.add(self.object:getPoint(), mist.vec.scalar_mult(targetToSelf, 50000)), "turningpoint", 600, 1000)
  
  GlobalLogger:create():drawPoint({pos = point, text = self.object:getName() .. " DEFEND POINT"})
  --set point for not defending plane
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      
      GlobalLogger:create():debug(plane:getName() .. " pumping")
      plane:setFSM_Arg("waypoint", point)
    end
  end
end

----------------------------------------------------
---- Defend against missile with HIGH ALR, will exit 
---- as soon as atleast 1 plane not defending
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Defending
----                  ↓
----       FSM_Element_DefendingHigh
----------------------------------------------------
FSM_Element_DefendingHigh = utils.inheritFrom(FSM_Element_Defending)

function FSM_Element_DefendingHigh:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)
  
  instance.name = "DefendingHigh"
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--return as soon as atleast 1 plane not defending
function FSM_Element_DefendingHigh:checkDefend() 
  --will return true if alteast one plane not defending
  return not self.tactic:inDefending()
end
--run() same just override checkDefend()

----------------------------------------------------
---- Crank to given direction at given angle
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----          FSM_Element_Crank
----------------------------------------------------

FSM_Element_Crank = utils.inheritFrom(FSM_Element_Intercept)
FSM_Element_Crank.DIR = {}
FSM_Element_Crank.DIR.Left = -1
FSM_Element_Crank.DIR.Right = 1

FSM_Element_Crank.names = {}
FSM_Element_Crank.names[FSM_Element_Crank.DIR.Left] = "Left"
FSM_Element_Crank.names[FSM_Element_Crank.DIR.Right] = "Right"

--callback is function from tactic used for state checks, default is checkCrank
function FSM_Element_Crank:create(handledElem, tactic, angle, side,callback)
  local instance = self:super():create(handledElem, tactic)

  instance.callback = callback or tactic.checkCrank
  instance.angle = math.rad(angle) or math.rad(60)
  instance.side = side or FSM_Element_Crank.DIR.Left
  instance.name = "Crank " .. FSM_Element_Crank.names[instance.side]
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Crank
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--setup() not needed

function FSM_Element_Crank:getCrankPoint() 
  local ourPos = self.object:getPoint()
  local dirToTarget = mist.utils.makeVec2(mist.vec.getUnitVec(mist.vec.sub(self:getTargetGroup():getPoint(), ourPos)))
  local dirToCrankPoint = mist.utils.makeVec3(mist.vec.rotateVec2(dirToTarget, self.angle*self.side))

  return mist.vec.add(ourPos, mist.vec.scalar_mult(dirToCrankPoint, 50000))
end

function FSM_Element_Crank:run(arg) 
  if self.callback(self.tactic) then 
    return
  end
  
  local crankPoint = self:getCrankPoint()
  self:flyToPoint(mist.fixedWing.buildWP(crankPoint, "turningpoint", self.tactic.speed, self.tactic.alt))
  GlobalLogger:create():drawPoint({pos = crankPoint, text = self:getName() .. " point, speed/alt: " 
      .. tostring(self.tactic.speed) .. "/" .. tostring(self.tactic.alt)})
  end

----------------------------------------------------
---- Maintain lateral separation from target,
---- just fly parallel line
----------------------------------------------------  
----             AbstractState
----                  ↓
----       FSM_Element_AbstractCombat
----                  ↓
----      FSM_Element_TacticWrapper
----                  ↓
----         FSM_Element_Intercept
----                  ↓
----        FSM_Element_FlyParallel
----------------------------------------------------

FSM_Element_FlyParallel = utils.inheritFrom(FSM_Element_Intercept)


function FSM_Element_FlyParallel:create(handledElem, tactic) 
  local instance = self:super():create(handledElem, tactic)

  instance.name = "Fly Parallel"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_FlyParallel
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end



function FSM_Element_FlyParallel:getTargetPoint() 
  local ourPos = self.object:getPoint()
  local lead = self:getTargetGroup():getLead()
  local aspect = lead:getAA(ourPos)
  if aspect > 90 then 
    --target cold, just use it velocity
    return mist.vec.add(ourPos, mist.vec.scalar_mult(lead:getVelocity(), 20000))
  else
    --target hot, use negative velocity
    local vel = lead:getVelocity()
    local negVelocity = {x = -vel.x, y = -vel.y, z = -vel.z}
    return mist.vec.add(ourPos, mist.vec.scalar_mult(negVelocity, 20000))
  end
end

function FSM_Element_FlyParallel:run(arg) 
  if self.tactic:checkFlyParallel() then 
    return
  end
  
  local point = self:getTargetPoint()
  GlobalLogger:create():drawPoint({pos = point, text = self:getName() .. " fly parallel point, speed/alt: " 
      .. tostring(self.tactic.speed) .. "/" .. tostring(self.tactic.altitude)})
  
  self:flyToPoint(mist.fixedWing.buildWP(point, "turningpoint", self.tactic.speed, self.tactic.alt))
end


----------------------------------------------------
---- Wrapper which simulate capGroup, allow execute
---- group level tactic inside element and on different
---- target
----------------------------------------------------  
----             AbstractState
----                  ↓
----        FSM_Element_GroupEmul
----------------------------------------------------
FSM_Element_GroupEmul = utils.inheritFrom(AbstractState)

--groupTarget is bool determining this element attack grou target or different targtet
function FSM_Element_GroupEmul:create(elementToWrap, target, groupTarget) 
  local instance = self:super():create(elementToWrap)

  target:setTargeted(true)
  instance.target = target
  
  instance.elements = {}
  instance.elements[1] = CapElement:create({elementToWrap.planes[1]})
  --create elements from element
  if #elementToWrap.planes > 1 then 
    instance.elements[2] = CapElement:create({elementToWrap.planes[2]})
    
    --register elements to each other
    instance.elements[1]:setSecondElement(instance.elements[2])
    instance.elements[2]:setSecondElement(instance.elements[1])
  end
  
  for _, elem in pairs(instance.elements) do 
    elem:registerGroup(instance)
    elem.planes[1]:registerGroup(instance)
  end
  
  --copy some fields from group, so this instance can be used for tactic selection
  instance.preferableTactics = elementToWrap.myGroup.preferableTactics
  instance.countPlanes = #elementToWrap.planes
  instance.alr = elementToWrap.myGroup.alr
  instance.priorityForTypes = elementToWrap.myGroup.priorityForTypes
  
  instance.name = "Element Wrapper-" .. target:getName()
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_GroupEmul

  instance.attackGroupTarget = groupTarget or false
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_GroupEmul:getBestMissile() 
  return self.object:getBestMissile()
  end

function FSM_Element_GroupEmul:selectTactic() 
  local counter, tblWithWeights = 0, {}
  
  for enum, tactic in pairs(FSM_Engaged.tactics) do 
    local w = tactic:getWeight(self)
    tblWithWeights[enum] = w
    counter = counter + w
  end
  
  local stepSize = 100/counter
  local prevRange = 0
  local randomChoice = mist.random(100)
  
  for enum, weight in pairs(tblWithWeights) do 
    local newRange = prevRange + stepSize*weight
    if prevRange <= randomChoice and randomChoice <= newRange then 
      return FSM_Engaged.tactics[enum]
    end
    prevRange = newRange
  end
end

function FSM_Element_GroupEmul:setup() 
  
  local tactic = self:selectTactic()
  for _, elem in pairs(self.elements) do 
    
    elem:clearFSM()
    elem:setFSM(tactic:create(elem))
  end
end

function FSM_Element_GroupEmul:teardown() 
  --reset targeted 
  self.target:setTargeted(false)
  
  --return everything back, so element can be safely returned to group
  for _, plane in pairs(self.object.planes) do 
    --return links
    plane:registerElement(self.object)
    plane:registerGroup(self.object.myGroup)
    plane:clearFSM()
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
end

function FSM_Element_GroupEmul:update() 
  --update elements, delete dead
  self.countPlanes = 0
  
  local newElems = {}
  for _, elem in pairs(self.elements) do 
    
    if elem:isExist() then 
      newElems[#newElems + 1] = elem
      self.countPlanes = self.countPlanes + #elem.planes
      end
    end
    
  self.elements = newElems
  
  -- no check cause it will checked in update elements, and will be deleted
  --[[if #self.elements == 0 then 
    --dead
    return
    end--]]
  
  --update links
  if #self.elements == 1 then 
    self.elements[1]:setSecondElement(nil)
    return
  end
  
  self.elements[1]:setSecondElement(self.elements[2])
  self.elements[2]:setSecondElement(self.elements[1])
end

function FSM_Element_GroupEmul:callElements() 
  for _, elem in pairs(self.elements) do 
    elem:callFSM()
    end
end

function FSM_Element_GroupEmul:run(arg) 
  self:update() 

  if not self.target:isExist() then 
    GlobalLogger:create():debug(self.object:getName() .. " target dead")
    self.object:popFSM()
    return
  end

  --return if we should attack group target but target changes
  if self.attackGroupTarget then 
    
    if self.target ~= self.object.myGroup.target then 
      GlobalLogger:create():debug(self.object:getName() .. " group target chages")
      self.object:popFSM()
      return
    end
    --return here, no range check for group target
    self:callElements() 
    return
  end

  if arg.newTarget == self.object.myGroup.target then 
    --we recieve same target as our group, no need to split more
    GlobalLogger:create():debug(self.object:getName() .. " element have same target as group")
    self.object:popFSM()
    return
  end

  --update target
  if arg.newTarget and arg.newTarget ~= self.target then 
    
    GlobalLogger:create():debug(self.object:getName() .. " change target for split")
    self.target:setTargeted(false)
    
    self.target = arg.newTarget
    self.target:setTargeted(true)
    self.name = "Element Wrapper-" .. self.target:getName()
  end

  --distance more 20nm or MaxRange or Mar + 15000
  local rangeToTarget = mist.utils.get2DDist(self.object:getPoint(), self.target:getPoint()) 
  local ourRangeMargin = self.object:getBestMissile().MaxRange + 5000
  local targetRangeMargin = self.target:getHighestThreat().MAR + 15000

  if rangeToTarget > math.max(35000, math.min(ourRangeMargin, targetRangeMargin)) then 

    GlobalLogger:create():debug(self.object:getName() .. " return back to far")
    self.object:popFSM_NoCall()
    return
  elseif self.target:getTypeModifier() ~= AbstractTarget.TypeModifier.FIGHTER then
    GlobalLogger:create():debug(self.object:getName() .. " return back target not a factor")
    self.object:popFSM_NoCall()
    return
  end--]]
  
  --call elements
  self:callElements() 
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_3_2CapElementTactics.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------


----------------------------------------------------
---- interface for tactics
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----------------------------------------------------
FSM_Element_Tactic = utils.inheritFrom(FSM_Element_AbstractCombat)

function FSM_Element_Tactic:create(handledObject) 
  local instance = self:super():create(handledObject)
  
  --when last parameter update was made
  instance.updateTimeStamp = -math.huge
  instance.distance2Target = 0
  instance.distance2Mar = 0
  instance.aspect = 0
  
  --speed and alt during tactic
  instance.speed = 300 --0.9M good amound of enegry with reasonable fuel consumpsion
  instance.alt = 7500 --~25000ft
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_Tactic:compareAlrAndPreferred(capGroup, alrEnum, tacticEnum) 
  local score = 0
  if capGroup.alr == alrEnum then 
    score = score + 1
  end
  
  if utils.itemInTable(capGroup.preferableTactics, tacticEnum) then 
    score = score + 1
  end
  
  return score
  end


function FSM_Element_Tactic:getWeight(capGroup) 
  return 0
end

function FSM_Element_Tactic:isOtherElementInTrouble() 
  return self.object:getSecondElement() and 
    self.object:getSecondElement():getCurrentFSM() >= CapElement.FSM_Enum.FSM_Element_WVR
  end

function FSM_Element_Tactic:update() 
  --update if more than 1 sec elapsed
  local currentTime = math.floor(timer.getAbsTime() + 0.5) --round to int
  if currentTime == self.updateTimeStamp then 
    return
  end
  
  local range = math.huge
  --smallest ditance between plane and target
  for _, plane in pairs(self.object.planes) do
    
    for _, target in pairs(self:getTargetGroup():getTargets()) do 
      local range2Target = mist.utils.get3DDist(plane:getPoint(), target:getPoint())
      
      if range2Target < range then 
        range = range2Target
      end
    end
  end
  
  self.distance2Target = range
  --Use target alt for MAR calc
  self.distance2Mar = range - utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MAR
  self.aspect = self:getTargetGroup():getAA(self.object:getPoint())
  self:updateSpeedAlt()
  
  self.updateTimeStamp = currentTime
end

function FSM_Element_Tactic:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  elseif self.alt - targetAlt > 2000 then
    --we too high, set target alt, or 1000meters
    self.alt = math.max(targetAlt, 1000)
  elseif self.alt - targetAlt < -2000 then
    --we too low,  set target alt, or 10000 meters
    self.alt = math.min(10000, targetAlt)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--check if we can drop missile and turn cold
-- return true if: pitbull/no Missile/ missile trashed
-- false if any aircraft has missile to support
function FSM_Element_Tactic:checkOurMissiles() 
  for _, plane in pairs(self.object.planes) do 
    if not plane:canDropMissile() then 
      return false
      end 
    end
    return true
  end

--check if all element is defending against missiles
function FSM_Element_Tactic:inDefending() 
  for _, plane in pairs(self.object.planes) do 
    if plane:getCurrentFSM() ~= AbstractPlane_FSM.enumerators.FSM_Defence then 
      return false
      end
    end

  return true
end

--check if we to close to enemy
function FSM_Element_Tactic:inWVR() 
  return self.distance2Target < 15001
end

--check if all element is defending against missiles
--set state to FSM_Element_Defending and return true to indicate change
function FSM_Element_Tactic:isDefending() 
  if not self:inDefending() then 
    return false
  end
  --set proper Defend state
  if self.object.myGroup.alr == CapGroup.ALR.Normal then 
    self.object:setFSM(FSM_Element_Defending:create(self.object, self))
  else
    self.object:setFSM(FSM_Element_DefendingHigh:create(self.object, self))
  end
  return true
end
  

--check if we to close to enemy and should switch to WVR
function FSM_Element_Tactic:isWVR() 
  if not self:inWVR() then
    --we ok
    return false
  end
  
  self.object:setFSM(FSM_Element_WVR:create(self.object))
  return true
end

--return lowest distance from plane to target
function FSM_Element_Tactic:distanceToTarget() 
  return self.distance2Target
end

--distance to MAR of targetGroup highest threat, return negative if inside mar
function FSM_Element_Tactic:distanceToMar() 
  if self.object.myGroup.alr == CapGroup.ALR.Normal then
    return self.distance2Mar
  end

  return self.distance2Target
end

function FSM_Element_Tactic:getAA() 
  return self.aspect
  end

--check for starting executing of coldOps tactic(like notchBack, Bracket or smth)
--for now just place holder, will return to force attack
--should return true if state was changed
function FSM_Element_Tactic:checkColdOps() 
  return false
end

--checks can this element execute current tactic, if no set new state and return true
function FSM_Element_Tactic:checkCondition() 
  return false
  end

--All functions below will be called from respective fsm states, when they active
--they check if state should change and change it, replace top item it stack
--and return true, to indicate that, so previous state can early return
function FSM_Element_Tactic:checkCrank() 
  return false
end

function FSM_Element_Tactic:checkFlyParallel() 
 return false
end

function FSM_Element_Tactic:checkIntercept() 
  return false
  end

function FSM_Element_Tactic:checkAttack() 
  return false
end

function FSM_Element_Tactic:checkPump() 
  return false
end

--check for continue attack for different ALR
function FSM_Element_Tactic:checkAttackNormal() 
  return false
end

function FSM_Element_Tactic:checkAttackHigh() 
  return false
end

--should be replaced by callbacks above, depend on what alr used
function FSM_Element_Tactic:ALR_check() 
end


----------------------------------------------------
---- Mixin for with methods for skateOffset
----------------------------------------------------  

SkateOffsetChecks = {}
SkateOffsetChecks.aspectThreshold = {}
SkateOffsetChecks.aspectThreshold.intercept = 60 --above this aspect group go intercept
SkateOffsetChecks.aspectThreshold.crank = 30 --below this aspect group go crank

function SkateOffsetChecks:setupForOffset() 
  self.object.sideOfElement = nil
  
  --clear FSM, task will be set on each run()
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    
    --set all needed options
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    plane:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On)
    plane:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On)
    --attack range/ROE will set plane Attack states
    
    --set first task in stack(no call cause task will be changed after)
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
  --
  --go to flyParallel other magic will happen in states check
  self.object:setFSM(FSM_Element_FlyParallel:create(self.object, self))
end

--find where(left or right) we should crank and return side enum for crank
function SkateOffsetChecks:directionOfCrank() 
  if self.object.sideOfElement then 
    
    return self.object.sideOfElement
  elseif self.object:getSecondElement() and self.object:getSecondElement().sideOfElement then
    
    --use side of second element
    self.object.sideOfElement = self.object:getSecondElement().sideOfElement
    return self.object.sideOfElement
  end
  
  local leadTarget, ourPos = self:getTargetGroup():getLead(), self.object:getPoint()
  local aspect = leadTarget:getAA(ourPos)
  
  local targetTrackLine = {mist.vec.add(leadTarget:getPoint(), leadTarget:getVelocity()), leadTarget:getPoint()}
  if aspect < 90 then 
    targetTrackLine = {leadTarget:getPoint(), mist.vec.add(leadTarget:getPoint(), leadTarget:getVelocity())}
  end

  local side = utils.sideOfLine(targetTrackLine, ourPos)
  if side == 1 then 
    self.object.sideOfElement = FSM_Element_Crank.DIR.Right 
  else
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
  end

  return self.object.sideOfElement
end



--check if aspect below minimum for intercept state, if so return back to flyParallel
function SkateOffsetChecks:interceptAspectCheck() 
  local aspect = self:getAA()
  
  if aspect < self.aspectThreshold.intercept then
    --go fly parallel
    self.object:popFSM()
    return true
  end
  
  return false
end

--check if aspect above minimum for crank state, if so return back to flyParallel
function SkateOffsetChecks:crankAspectCheck() 
  local aspect = self:getAA()
  
  if aspect > self.aspectThreshold.crank then
    --go fly parallel
    self.object:popFSM()
    return true
  end
  
  return false
end

--check if aspect exceed limits for flyParallel and set correct state for correction
function SkateOffsetChecks:flyParallelAspectCheck() 
  local aspect = self:getAA()
  
  if aspect > self.aspectThreshold.intercept then
    --go intercept
    self.object:setFSM(FSM_Element_Intercept:create(self.object, self))
    return true
  elseif aspect < self.aspectThreshold.crank then
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 60, self:directionOfCrank()))--no alt, will use tactic alt
    return true
  end
  
  return false
end



----------------------------------------------------
---- Skate Wall, two elements without separation
---- used when missiles range ~equals
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----------------------------------------------------
FSM_Element_Skate = utils.inheritFrom(FSM_Element_Tactic)


function FSM_Element_Skate:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "Skate"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Skate
  instance.abortAttackAspect = 90 --if target aspect below that we turn cold at MAR
  
  --set proper callback for attack check
  if instance.object.myGroup.alr == CapGroup.ALR.Normal then 
    instance.ALR_check = self.checkAttackNormal
  else
    instance.ALR_check = self.checkAttackHigh
  end

  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_Skate:setup() 
  --clear FSM, task will be set on each run()
  for _, plane in pairs(self.object.planes) do 
    plane:clearFSM()
    
    --set all needed options
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    plane:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On)
    plane:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On)
    --attack range/ROE will set plane Attack states
    
    --set first task in stack(no call cause task will be changed after)
    plane:setFSM_NoCall(FSM_FlyToPoint:create(plane, mist.fixedWing.buildWP({x = 0, y = 0})))
  end
  
  --go to intercept other magic will happen in states check
  self.object:setFSM(FSM_Element_Intercept:create(self.object, self))
end

--return true if we should go to attack state
function FSM_Element_Skate:inRangeForAttack() 
  local distance = self:distanceToTarget()
  
  local ourMaxRange = utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange
  return distance < ourMaxRange 
end

--check if should go attack and return true if state change happened
function FSM_Element_Skate:isAttack() 
  if not self:inRangeForAttack() then 
    return false
  end
  
  self.object:setFSM(FSM_Element_Attack:create(self.object, self))
  return true
end

--will be used also for weight calc
--switch to skateOffset when enemy has more than 5NM MaxRange advantage
--of 1.25 range(which is greater)
function FSM_Element_Skate:checkRequrements(targetRange, ourRange) 
  local ratio = targetRange/ourRange
  
  return ratio < 1.25 or ourRange + 10000 > targetRange
end

function FSM_Element_Skate:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.Skate) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " Skate Score: " .. tostring(score))
  return score 
end

function FSM_Element_Skate:checkCondition() 
  if not self:checkRequrements(self:getTargetGroup():getHighestThreat().MaxRange, 
    self.object:getBestMissile().MaxRange) then 
    
      GlobalLogger:create():debug(debug.getinfo(1).name .. " " .. tostring(debug.getinfo(1).linedefined) .. " checkCondition() true")
    --switch tactic
    self.object:setFSM(FSM_Element_SkateOffset:create(self.object))
    return true
  end
  
  return false
end


--will work only if have second element, if so:
---1)we far enough from MAR -> Grinder
---2)not far go Bracket
----selection of coldState start after 60 sec in defend state
function FSM_Element_Skate:checkColdOps() 
  
  if not self.object:getSecondElement() or self.object.FSM_stack:getCurrentState():getTimer() < 60 then 
    return false
  elseif not (self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Pump 
    or self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Defending) then   
    --second element ok
    return false
  end
  
  local distance2Mar = self:distanceToMar()
  if distance2Mar > 10000 then 
    --far enough, can go grinder
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    
    local secondElem = self.object:getSecondElement()
    secondElem:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(secondElem))
    return true
  end

  --too close go Delouse
  self.object:setFSM_NoCall(FSM_Element_Delouse:create(self.object))
  local secondElem = self.object:getSecondElement()
  secondElem:setFSM_NoCall(FSM_Element_Delouse:create(secondElem))
  return true
end

--go pump if we to close
function FSM_Element_Skate:interceptCheck() 
  self:update()
  
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return 
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack()
end


--return back if we in WVR, Defending or to far from target
--call respective check for ALR
function FSM_Element_Skate:checkAttack() 
  self:update()
  if self:inWVR() or self:inDefending() then 
    --should go to WVR or Defend, set Pump to stack, so when defending/WVR will pop
    --Pump will be called
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    return true
  elseif self:distanceToTarget() > utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange + 7500
    and not (self.object:getSecondElement() 
      and self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_WVR) then
      
    GlobalLogger:create():info("distance to great")
    --to far to attack, return to intercept
    self.object:popFSM()
    return true
  end
  
  if self:ALR_check() then 
    --delete attack
    self.object:popFSM_NoCall()
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return false
end


--we fly cold and should stop PUMP
---1)second element in troble and we ~5nm From Mar
---2)we far enough from target 
function FSM_Element_Skate:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() or self:checkColdOps() then 
    --we switched to WVR or Defend
    return true
  end
  
  local dist2Mar = self:distanceToMar()
  if dist2Mar > 18500 then 
    --we far enough
    self.object:popFSM()
    return true
  elseif self:isOtherElementInTrouble() and dist2Mar > 10000 then
    --element defending/WVR and dist2Mar > 5NM
    self.object:popFSM()
    return true
  end
  
  return false
end

--if close to MAR:
---1)missile support no needed -> Pump()
---2)support needed then continue only if targetAA > 90 else -> Pump()
function FSM_Element_Skate:checkAttackNormal() 
  if self:distanceToMar() > 0 then 
    return false
  elseif (not self:checkOurMissiles() and self:getAA() > self.abortAttackAspect) then
    return false
  end

  return true
end

--return back to intercept if:
--1) defending -> replace attack, with defending
--2) WVR -> replace attack with WVR

--3) if distance < MAR - > continue only if FOX1 or aspect > 90 or numerical advantage 2.5:1
--4) other go pump
function FSM_Element_Skate:checkAttackHigh() 
  if self:distanceToMar() < 0 --we inside MAR and target hot on us or we don't have enough numerical advantage
    and (#self.object.planes/self:getTargetGroup():getCount() < 2 and self:getAA() < self.abortAttackAspect) then
    return true 
  end
  
  --continue
  return false
end



----------------------------------------------------
---- Skate with single side offset, used when
---- little disadvantage in launch range 
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate           SkateOffsetChecks
----                  ↓                           ↓   
----        FSM_Element_SkateOffset<--------------
----------------------------------------------------

FSM_Element_SkateOffset = utils.inheritFromMany(FSM_Element_Skate, SkateOffsetChecks)

function FSM_Element_SkateOffset:create(handledElem) 
  local instance = FSM_Element_Skate:create(handledElem)--call parent explicitly
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Skate Offset"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateOffset
  
  --use setup from skateOffset
  instance.setup = self.setupForOffset
  return instance
end

--will be used also for weight calc
--ratio enemy MaxRange/ourRange > 1.5 or difference between ranges > 10 NM
function FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange) 
  local ratio = targetRange/ourRange
  
  return ratio < 1.5 or ourRange + 20000 > targetRange
end


function FSM_Element_SkateOffset:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange) then 
    return 0
  end
  
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateOffset) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateOffset Score: " .. tostring(score))
  return score 
end

function FSM_Element_SkateOffset:checkCondition() 
  if not self:checkRequrements(self:getTargetGroup():getHighestThreat().MaxRange, 
    self.object:getBestMissile().MaxRange) then 
    
    --switch tactic
    self.object:setFSM(FSM_Element_ShortSkate:create(self.object))
    return true
  end
  
  return false
end


function FSM_Element_SkateOffset:interceptCheck() 
  self:update()
  
  --No MAR check cause target cold to us
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:interceptAspectCheck()
end

function FSM_Element_SkateOffset:checkCrank() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:crankAspectCheck()
end

function FSM_Element_SkateOffset:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:flyParallelAspectCheck()
end


--interceptAscectCheck() same
--crankAspectCheck() same
--FlyParallelAspectCheck() same
--checkPump() same
--checkAttack() same
--checkAttackNormal() same
--checkAttackHigh() same
--checkColdOps() same

----------------------------------------------------
---- Short Skate with offset, mostly same 
---- with FSM_Element_SkateOffset but allow usage 
---- with more disadvantage in missile range or with higher
---- ALR, will go attack when distance < MaxRange * 0.75
---- or MAR + 5NM
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate           SkateOffsetChecks
----                  ↓                           ↓   
----        FSM_Element_SkateOffset<--------------
----                  ↓
----         FSM_Element_ShortSkate
----------------------------------------------------
FSM_Element_ShortSkate = utils.inheritFrom(FSM_Element_SkateOffset)

function FSM_Element_ShortSkate:create(handledElem)
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Short Skate"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_ShortSkate

  return instance
end

--other same

--try being lower then target atleast 3000, or 1000m, but not higher then 5000
function FSM_Element_ShortSkate:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  else
    self.alt = math.min(math.max(targetAlt - 3000, 1000), 5000)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--MAR + 5nm
function FSM_Element_ShortSkate:inRangeForAttack() 
  --use target alt for MAR calc
  local MarMargin = utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MAR + 10000
  local ourRange = utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange
  return self:distanceToTarget() < math.min(MarMargin, ourRange)
end


function FSM_Element_ShortSkate:getWeight(capGroup) 

  local score = 2 --ALR always match, no condition
  if utils.itemInTable(capGroup.preferableTactics, CapGroup.tactics.ShortSkate) then 
    score = score + 1
  end
  
  GlobalLogger:create():debug(capGroup:getName() .. " ShortSkate Score: " .. tostring(score))
  return score
end

--no op, this tactic always true
function FSM_Element_ShortSkate:checkCondition() 
  return false
end


----------------------------------------------------
---- Skate Grinder, two elements in trail ~20nm
---- used when missiles range ~equals
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----       FSM_Element_SkateGrinder
----------------------------------------------------

FSM_Element_SkateGrinder = utils.inheritFrom(FSM_Element_Skate)


function FSM_Element_SkateGrinder:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "SkateGrinder"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateGrinder
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

--function FSM_Element_SkateGrinder:setup() inherited
--run() not used
--function FSM_Element_SkateGrinder:isAttack() inherited

--new
--return true if this element far enough
function FSM_Element_SkateGrinder:isGoodSeparation() 
  --just check distance between elements, it looks loke it works, but need more testing
  return mist.utils.get2DDist(self.object:getPoint(), self.object:getSecondElement():getPoint()) > 13000
  
  --[[ old version check is element behind other
  return mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getPoint())
          - mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getSecondElement():getPoint()) > 13000--]]
end
  
--return true if this element far enough and beyound other element
function FSM_Element_SkateGrinder:isBeyondOtherElem() 
  
  return mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getPoint())
          - mist.utils.get2DDist(self:getTargetGroup():getPoint(), self.object:getSecondElement():getPoint()) > 13000--]]
end

--check if we should start separating during intercept
--if second element Attack or Intercept
--and we not far enough
function FSM_Element_SkateGrinder:needSeparate() 
  return self.object:getSecondElement() 
    and (self.object:getSecondElement():getCurrentFSM() > CapElement.FSM_Enum.FSM_Element_Pump
      and self.object:getSecondElement():getCurrentFSM() < CapElement.FSM_Enum.FSM_Element_WVR)
    and not self:isGoodSeparation() 
end

--check if we should start separating during intercept and return true if state was changed
function FSM_Element_SkateGrinder:isSeparating() 
  if not self:needSeparate() then 
    return false
  end
  
  self.object:setFSM(FSM_Element_Pump:create(self.object, self, 300))
  return true
end

--return true if can use grinder
-- can use grinder when:
---1)has second element(planes > 1)
---2)if group have more than > 2 planes(so atleast one element will be 2 planes) 
---3)if our missile range > 40000m(or use grinder don't help we can't help eachother)
function FSM_Element_SkateGrinder:checkForGrinder(numberPlanes, ourRange)
  if numberPlanes == 1 then 
    --no second element, return
    return false
  end
  
  if numberPlanes > 2 then 
    --atleast 1 element will have 2 planes, can split even if no range
    return true
  end
  
  --2 planes split only if distance allow
  return ourRange > 40000
end

--overriden: if can't continue tactic go to shortSkate
--if can't go grinder go to skate
function FSM_Element_SkateGrinder:checkCondition() 
  local targetRange = self:getTargetGroup():getHighestThreat().MaxRange
  local ourRange = self.object:getBestMissile().MaxRange
  
  --check for tactic
  if not FSM_Element_Skate:checkRequrements(targetRange, ourRange) then 
    GlobalLogger:create():debug(self.object:getName() .. " can't continue Skate")
    
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    return true
  elseif not self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then
    GlobalLogger:create():debug(self.object:getName() .. " can't continue Skate Grinder")
    
    self.object:setFSM_NoCall(FSM_Element_Skate:create(self.object))
    return true
  end
  
  return false
end

--overriden: also check grinder
function FSM_Element_SkateGrinder:checkRequrements(targetRange, ourRange, numberPlanes) 
  --call explicitly base class, cause we can't use super
  return self:checkForGrinder(numberPlanes, ourRange) and FSM_Element_Skate:checkRequrements(targetRange, ourRange)
end

function FSM_Element_SkateGrinder:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange, capGroup.countPlanes) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateGrinder) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateGrinder Score: " .. tostring(score))
  return score 
end

--add separation check
function FSM_Element_SkateGrinder:interceptCheck() 
  self:update()

  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating()
end

--will work only if have second element
--if both element defending/Pump and distance2Mar < 0 both elements then go Bracket
function FSM_Element_SkateGrinder:checkColdOps() 
  
  if self.object.FSM_stack:getCurrentState():getTimer() < 60 then 
    return false
  end
  
  local otherElem = self.object:getSecondElement()
  if not (otherElem:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Defending
    or otherElem:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_Pump) then 
    --other element ok
    return false
  end
  
  --check if second element inside MAR + 5nm
  local MAR = utils.missileForAlt(self:getTargetGroup():getHighestThreat(), otherElem:getPoint().y).MAR + 10000
  for _, plane in pairs(otherElem.planes) do 
    for __, target in pairs(self:getTargetGroup():getTargets()) do 
      
      if mist.utils.get3DDist(plane:getPoint(), target:getPoint()) < MAR then 
        --second elem inside MAR
        GlobalLogger:create():info(self.object:getName() .. " go Cold Ops")
        
        self.object:setFSM_NoCall(FSM_Element_Delouse:create(self.object))
        otherElem:setFSM_NoCall(FSM_Element_Delouse:create(otherElem))
        return true
        end
      end
    end
    return false
end


--we fly cold and should stop PUMP
---1)second element WVR to help him
---1.5)second element defending then turn hot if distance > MAR + 5nm
---2)we separated
function FSM_Element_SkateGrinder:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() or self:checkColdOps() then 
    --we switched to WVR or Defend
    return true
  end
  
  local rangeCond = self:distanceToMar() > 10000
  --2 elements scenaries:
  if rangeCond and (self:isOtherElementInTrouble() or self:isBeyondOtherElem()) then
    self.object:popFSM()
    return true
  end
  
  return false
end

--function FSM_Element_SkateGrinder:checkAttack() same
--function FSM_Element_SkateGrinder:checkAttackNormal() same
--function FSM_Element_SkateGrinder:checkAttackHigh() same


----------------------------------------------------
---- Skate Grinder with single side offset, used when
---- little disadvantage in launch range 
---- two elements in trail ~20nm
---- launch at max range and abort at mar if target hot
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----------------------------------------------------
FSM_Element_SkateOffsetGrinder = utils.inheritFromMany(FSM_Element_SkateGrinder, SkateOffsetChecks)

function FSM_Element_SkateOffsetGrinder:create(handledElem) 
  local instance = FSM_Element_SkateGrinder:create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "SkateGrinderOffset"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_SkateOffsetGrinder
  
  --use setup from skateOffset
  instance.setup = self.setupForOffset
  return instance
end

--function FSM_Element_SkateOffsetGrinder:setup() same
--checkCondition() same
--run() same
--inRangeForAttack() same
--isGoodSeparation() same
--needSeparate() same
--isSeparating() same
--directionOfCrank() same
--interceptAspectCheck()  same
--crankAspectCheck()  same
--flyParallelAspectCheck()  same

--overriden, also will check missile range, we don't use grinder when our MaxRange < 25NM
--cause elements can't help eachother
function FSM_Element_SkateOffsetGrinder:checkRequrements(targetRange, ourRange, numberPlanes) 
  return self:checkForGrinder(numberPlanes, ourRange) and FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange)
end

function FSM_Element_SkateOffsetGrinder:getWeight(capGroup) 
  if not self:checkRequrements(capGroup.target:getHighestThreat().MaxRange, capGroup:getBestMissile().MaxRange, capGroup.countPlanes) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.Normal, CapGroup.tactics.SkateOffsetGrinder) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " SkateOffset Grinder Score: " .. tostring(score))
  return score 
end

--overriden: if can't continue tactic go to shortSkate
--if can't go grinder go to skateOfsset
function FSM_Element_SkateOffsetGrinder:checkCondition() 
  local targetRange = self:getTargetGroup():getHighestThreat().MaxRange
  local ourRange = self.object:getBestMissile().MaxRange
  
  --check for tactic
  if not FSM_Element_SkateOffset:checkRequrements(targetRange, ourRange) then 
    GlobalLogger:create():debug(self.object:getName() .. " can't continue SkateOffset")
    
    self.object:setFSM_NoCall(FSM_Element_ShortSkateGrinder:create(self.object))
    return true
  elseif not self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then
    GlobalLogger:create():debug(self.object:getName() .. " can't continue SkateOffset Grinder")
    
    self.object:setFSM_NoCall(FSM_Element_SkateOffset:create(self.object))
    return true
  end
  
  return false
end



--added separation Checks 
function FSM_Element_SkateOffsetGrinder:interceptCheck()
  self:update()
  
  --no MAR check, target cold
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:interceptAspectCheck()
end

function FSM_Element_SkateOffsetGrinder:checkCrank() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:crankAspectCheck()
end

function FSM_Element_SkateOffsetGrinder:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set FSM_Pump, speed ~1.5M
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:isSeparating() or self:flyParallelAspectCheck()
end


--checkPump() same
--checkColdOps() same
--checkAttack() same
--checkAttackNormal() same
--checkAttackHigh() same


----------------------------------------------------
---- Short Skate with offset, mostly same 
---- with FSM_Element_SkateOffsetGrinder but allow usage 
---- with more disadvantage in missile range or with higher
---- ALR, will go attack when distance < MaxRange * 0.75
---- or MAR + 5NM
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----     FSM_Element_ShortSkateGrinder
----------------------------------------------------
FSM_Element_ShortSkateGrinder = utils.inheritFrom(FSM_Element_SkateOffsetGrinder)

function FSM_Element_ShortSkateGrinder:create(handledElem)
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "ShortSkateGrinder"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder
  return instance
end

--other same
--function FSM_Element_ShortSkateGrinder:inRangeForAttack() SAME

--use same version as standart shortSkate(), yes this ugly i know
FSM_Element_ShortSkateGrinder.updateSpeedAlt = FSM_Element_ShortSkate.updateSpeedAlt

function FSM_Element_ShortSkateGrinder:getWeight(capGroup) 
  
  if not self:checkForGrinder(capGroup.countPlanes, capGroup:getBestMissile().MaxRange) then 
    return 0
  end

  local score = 1 --ALR always match
  if utils.itemInTable(capGroup.preferableTactics, CapGroup.tactics.ShortSkateGrinder) then 
    score = score + 1
  end
  
  GlobalLogger:create():debug(capGroup:getName() .. " ShortSkateGrinder Score: " .. tostring(score))
  return score
end

--this tactic only require MaxRange > 40000 and second element avail
--or will used WALL version
function FSM_Element_ShortSkateGrinder:checkCondition() 
  local ourRange = self.object:getBestMissile().MaxRange
  if self:checkForGrinder(self.object.myGroup.countPlanes, ourRange) then 
    return false
  end
  
  --switch tactic
  self.object:setFSM_NoCall(FSM_Element_ShortSkate:create(self.object))
  return true
end



----------------------------------------------------
---- Short Skate with bracket, crank to different
---- directions, of target leaning to element, continue crank
---- if inside enemy MAR*1.25 go reverse bracket(crank 120 from target)
---- other element
---- at that time intercept and go to merge
---- if second element merge(WVR) then go attack
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----------------------------------------------------
FSM_Element_Bracket = utils.inheritFrom(FSM_Element_SkateOffsetGrinder)

function FSM_Element_Bracket:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Bracket"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Bracket
  
  instance.abortAttackAspect = 60 --if target aspect below that we turn cold at MAR, override this to lower aspect
  instance.ALR_check = self.checkAttackHigh --always use high, cause we want press if have aspect/numericat advantage
  return instance
end


--no second element or not count advantage 2:1 when no missile range advantage 1.75
function FSM_Element_Bracket:checkRequrements(hasSecondElem, missileRatio, aircraftRatio) 
  
  return hasSecondElem and (missileRatio > 1.75 or aircraftRatio >= 2) 
end

function FSM_Element_Bracket:getWeight(capGroup) 
  local hasElem = capGroup.countPlanes > 1 --when sigleton there's no second element
  local ratio = capGroup:getBestMissile().MaxRange / capGroup.target:getHighestThreat().MaxRange
  local aircraftRatio = capGroup.countPlanes/capGroup.target:getCount()
  
  if not self:checkRequrements(hasElem, ratio, aircraftRatio) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.High, CapGroup.tactics.Bracket) 
  GlobalLogger:create():debug(capGroup:getName() .. " Bracket Score: " .. tostring(score))
  return score
end

--no second element or not count advantage 2:1 when no missile range advantage 1.75
function FSM_Element_Bracket:checkCondition() 
  local ratio = self.object:getBestMissile().MaxRange / self:getTargetGroup():getHighestThreat().MaxRange
  local aircraftRatio = self.object.myGroup.countPlanes/self:getTargetGroup():getCount()

  if not self:checkRequrements(self.object:getSecondElement(), ratio, aircraftRatio) then 
   
    GlobalLogger:create():info(self.object:getName() .. " bracket can't continue, weapon ratio: " .. tostring(ratio) 
      .. " aircraft ratio: " .. tostring(aircraftRatio))
    
    self.object:setFSM_NoCall(FSM_Element_SkateOffsetGrinder:create(self.object))
    return true
  end
  return false
end


--run() same
--inRangeForAttack() not same, go attack only if target cold to us
--or if second element engaged in WVR
function FSM_Element_Bracket:inRangeForAttack() 
  return (self:getAA() > 60 
    and self:distanceToTarget() < utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange)
    or self.object:getSecondElement():getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_WVR
end


--isGoodSeparation()  no used

--nothing to do
function FSM_Element_Bracket:checkColdOps() 
  return false
end


--overrided, elements should have different sides
--find where(left or right) we should crank and return side enum for crank
--we should crank to opposite direction from our element
function FSM_Element_Bracket:directionOfCrank() 
  if self.object.sideOfElement then 
    --side known
    return self.object.sideOfElement
  elseif not self.object:getSecondElement() then
    
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
    return self.object.sideOfElement
  end
 
  local ourPos = self.object:getPoint()
  local line = {self.object:getSecondElement():getPoint(), self:getTargetGroup():getPoint()}
  
  if utils.sideOfLine(line, ourPos) == 1 then 
    self.object.sideOfElement = FSM_Element_Crank.DIR.Left
    return self.object.sideOfElement
  end
  
  self.object.sideOfElement = FSM_Element_Crank.DIR.Right 
  return self.object.sideOfElement
end


--isSeparating() not used
--needSeparate() not used

--interceptAspectCheck() same
--crankAspectCheck() same
--flyParallelAspectCheck() same

--overriden, no exit if other element in trouble
function FSM_Element_Bracket:checkAttack() 
  self:update()
  
  if self:inWVR() or self:inDefending() then 
    --should go to WVR or Defend, set Pump to stack, so when defending/WVR will pop
    --Pump will be called
    self.object:setFSM(FSM_Element_Pump:create(self.object, self, 500))
    return true
  elseif self:isOtherElementInTrouble() then
    return false
  elseif self:distanceToTarget() > utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange + 7500 then
      
    GlobalLogger:create():info("distance to great")
    --to far to attack, return to intercept
    self.object:popFSM()
    return true
  end
  
  if self:ALR_check() then 
    self.object:popFSM_NoCall()
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return false
end




--decorators for orinal methods, will early exit if other element defending/WVR
function FSM_Element_Bracket:checkAttackNormal() 
  --CALL base explicitly cause my inheritance suck)
  return not self:isOtherElementInTrouble() and FSM_Element_Skate.checkAttackNormal(self) 
end

function FSM_Element_Bracket:checkAttackHigh() 
  --CALL base explicitly cause my inheritance suck)
  return not self:isOtherElementInTrouble() and FSM_Element_Skate.checkAttackHigh(self) 
end

--override:
-- remove 1 element scenarios, cause this tactic only for 2 elements
---stop pump if :
--- 1)AA > aspect threshold for ALR check, or 10nm from MAR, or secondElement in trouble
function FSM_Element_Bracket:checkPump() 
  self:update()
  if self:isWVR() or self:isDefending() or self:checkCondition() then 
    --we switched to WVR or Defend
    return true
  end
  
  if self:getAA() > self.abortAttackAspect + 10 or self:distanceToMar() > 10000 or self:isOtherElementInTrouble() then
    self.object:popFSM()
    return true
  end
  
  return false
end

--same as previous except no check for separation
function FSM_Element_Bracket:interceptCheck() 
  self:update()
  
  --no MAR check, target cold
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:interceptAspectCheck()
end

function FSM_Element_Bracket:checkCrank()
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:crankAspectCheck()
end

--same as base, but no check for separate
function FSM_Element_Bracket:checkFlyParallel() 
  self:update()
  
  --if in MAR go cold
  if self:ALR_check() then 
    --set Reverse crank, speed ~1.5M, no alt, use tactic alt
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump))
    return true
  end
  
  return self:isWVR() or self:isDefending() or self:checkCondition() or self:isAttack() or self:flyParallelAspectCheck()
end



----------------------------------------------------
---- Bracket for cold Ops situations, same as normal
---- but with only 1 condition: should be a second
---- element
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----                  ↓
----         FSM_Element_Delouse
----------------------------------------------------
FSM_Element_Delouse = utils.inheritFrom(FSM_Element_Bracket)

function FSM_Element_Delouse:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Delouse"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Delouse
  return instance
end

function FSM_Element_Delouse:checkCondition() 
  if not self.object:getSecondElement() then 
   
    GlobalLogger:create():info(self.object:getName() .. " can't continue delouse, no second element")
    
    self.object:setFSM(FSM_Element_ShortSkate:create(self.object))
    return true
  end
  return false
end

----------------------------------------------------
---- Banzai tactic, go bracket until enemy max range
---- then go notch until enemy Mar+3NM, then spiked element
---- go reverse notch, not spiked attack
---- if both spiked then go Bracket tactic
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----          FSM_Element_Skate
----                  ↓
----        FSM_Element_SkateGrinder          SkateOffsetChecks
----                  ↓                               ↓
----      FSM_Element_SkateOffsetGrinder<-------------
----                  ↓
----         FSM_Element_Bracket
----                  ↓
----          FSM_Element_Banzai
----------------------------------------------------
FSM_Element_Banzai = utils.inheritFrom(FSM_Element_Bracket)

function FSM_Element_Banzai:create(handledElem) 
  local instance = self:super():create(handledElem)
  setmetatable(instance, {__index = self, __eq = utils.compareTables})
  
  instance.name = "Banzai"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_Banzai
  return instance
end

function FSM_Element_Banzai:getWeight(capGroup) 
  local hasElem = capGroup.countPlanes > 1 --when sigleton there's no second element
  local ratio = capGroup:getBestMissile().MaxRange / capGroup.target:getHighestThreat().MaxRange
  local aircraftRatio = capGroup.countPlanes/capGroup.target:getCount()
  
  if not self:checkRequrements(hasElem, ratio, aircraftRatio) then 
    return 0
  end
  local score = 1 + self:compareAlrAndPreferred(capGroup, CapGroup.ALR.High, CapGroup.tactics.Banzai) 
  
  GlobalLogger:create():debug(capGroup:getName() .. " Banzai Score: " .. tostring(score))
  return score 
end

--just try stay below target atleast at 3000m
function FSM_Element_Banzai:updateSpeedAlt() 
  local targetAlt = self:getTargetGroup():getPoint().y --mean altitude
  
  --if closer then 20nm, then use target alt
  if self.distance2Target < 37000 then 
    self.alt = targetAlt
  else
    self.alt = math.max(targetAlt - 3000, 1000)
  end
  
  --update speed: if below 3000m then use M0.75, instead standart 0.9
  if self.alt < 4000 then 
    self.speed = 250
  else
    self.speed = 300
  end
end

--run() same
--checkCondition() same
--checkRequrements() same
--inRangeForAttack() no used
--isGoodSeparation()  no used
--needSeparate() 
--directionOfCrank() 
--checkAttack() same
--interceptAspectCheck() same, no check for banzai, cause aspect good for attack
--flyParallelAspectCheck() same

--notch until aspect > 70 
--or distance to MAR < 3nm -> then if spiked go pump
-- else go attack
function FSM_Element_Banzai:notchCheck() 
  self:update()
  if self:isOtherElementInTrouble() 
    or self:getAA() > 30 then 
    --other element in trouble/aspect to great go hot
    self.object:popFSM()
    return true
  elseif self:distanceToMar() > 8000 then 
    --still to far
    return false
  end
  
  if self:getAA() < 60 then 
    --assume we spiked, go pump
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 150, self:directionOfCrank(), self.checkPump)) --no alt, use tactic alt
    return true
    end
  
  --not spiked go attack
  self.object:popFSM()
end

--add additional check for aspect, if in range and target cold, go attack
--else go notch
function FSM_Element_Banzai:isAttack() 
  local distance = self:distanceToTarget()
  local aspect = self:getAA()
  
  if distance < utils.missileForAlt(self:getTargetGroup():getHighestThreat(), self:getTargetGroup():getPoint().y).MaxRange and aspect < 30 then 
    --go notch
    self.object:setFSM(FSM_Element_Crank:create(self.object, self, 90, self:directionOfCrank(), self.notchCheck))  --no alt
    return true
  elseif distance < utils.missileForAlt(self.object:getBestMissile(), self.object:getPoint().y).MaxRange or self:isOtherElementInTrouble() then
    
    self.object:setFSM(FSM_Element_Attack:create(self.object, self))
    return true
  end
  
  return false
end



----------------------------------------------------
---- WVR state, planes will execute FSM_WVR,
---- will return back when no enemy aircraft within 20000m
----------------------------------------------------  
----             AbstractState
----                  ↓
----      FSM_Element_AbstractCombat
----                  ↓
----          FSM_Element_Tactic
----                  ↓
----           FSM_Element_WVR
----------------------------------------------------
FSM_Element_WVR = utils.inheritFrom(FSM_Element_Tactic)

function FSM_Element_WVR:create(handledElem) 
  local instance = self:super():create(handledElem)
  
  instance.name = "Element WVR"
  instance.enumerator = CapElement.FSM_Enum.FSM_Element_WVR
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Element_WVR:setup() 
  for _, plane in pairs(self.object.planes) do 
    plane:setFSM(FSM_WVR:create(plane))
  end
end

function FSM_Element_WVR:teardown() 
  for _, plane in pairs(self.object.planes) do 
    plane:popFSM()
  end
end

function FSM_Element_WVR:run(arg) 
  self:update()
  if self:inWVR() then 
    --still in WVR 
    return
  end
  
  self.object:popFSM()
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_4CapElement.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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

    local _res, _err = xpcall(
      function ()
        return plane:isExist()
      end,
    debug.traceback)
    
    if not _res then
      GlobalLogger:create():error(self:getName() .. " erron in isExist(): " .. tostring(_err))
    end
    if _res and _err then 
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
    local res, val = xpcall(function() plane:callFSM() end, debug.traceback)

    if not res then 
      GlobalLogger:create():error("error in plane FSM " .. plane:getName() .. " traceback:\n" .. tostring(val))
      local msg = mist.utils.serializeWithCycles(plane:getName() .. " dump", plane:getDebugDump())
      GlobalLogger:create():error(msg)
      GlobalLogger:create():addToFile(msg)
    end
  end
end

function CapElement:callFSM() 
  self.FSM_stack:run(self.FSM_args)

  self:callPlanes()
  self.FSM_args = {}
  self.FSM_stack:resetCounter()
end

function CapElement:getDebugDump()
  local result = {}
  result.isExist = utils.getInProcected(self.isExist, self)
  result.point = mist.utils.deepCopy(utils.getInProcected(self.getPoint, self))
  result.name = utils.getInProcected(self.getName, self)
  result.missile = mist.utils.deepCopy(utils.getInProcected(self.getBestMissile, self))
  result.stack = mist.utils.deepCopy(self.FSM_stack)
  if self:getSecondElement() then
    local e = self:getSecondElement()
    result.otherElement = {
      point = mist.utils.deepCopy(utils.getInProcected(e.getPoint, self)),
      name = utils.getInProcected(e.getName, self),
      exist = utils.getInProcected(e.isExist, self),
      stackTop = mist.utils.deepCopy(utils.getInProcected(e.FSM_Stack.getCurrentState, self))
    }
  end

  result.planes = {}
  for _, plane in pairs(self.planes) do 
    result.planes[#result.planes+1] = {}
    if utils.getInProcected(plane.isExist, self) then 
      result.planes[#result.planes] = {
        name = utils.getInProcected(plane.getName, self),
        point = mist.utils.deepCopy(utils.getInProcected(plane.getPoint, self)),
        stackTop = mist.utils.deepCopy(utils.getInProcected(plane.FSM_Stack.getCurrentState, self)),
        ammo = mist.utils.deepCopy(utils.getInProcected(plane.getAmmo, self))
      }
    end
  end

return result
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_5CapGroup.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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
    local res, err = pcall(function() return plane:getBestMissile() end)
    if res and err.MaxRange > self.missile.MaxRange then 
      self.missile = err
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

    local _res, _err = pcall(
    function()
      return elem:isExist()
    end)

    if _res and _err then 
      local _r, _e = xpcall(function ()
        elem:update()
      end, debug.traceback)

      if _r then 
        aliveElems[#aliveElems+1] = elem
        self.countPlanes = self.countPlanes + #elem.planes
        elemPos[#elemPos + 1] = elem:getPoint()
      else
        GlobalLogger:create():error("Error in updating element " .. elem:getName() .. tostring(_e))
      end
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

function CapGroup:getDebugDump()
  local result = {
    name = utils.getInProcected(self.getName, self),
    typeName = utils.getInProcected(self.getTypeName, self),
    exist = utils.getInProcected(self.isExist, self),
    airborne = utils.getInProcected(self.isAirborne, self),
    landed = utils.getInProcected(self.isLanded, self),
    engineOff = utils.getInProcected(self.isLanded, self),
    autonomous = utils.getInProcected(self.getAutonomous, self),
    point = mist.utils.deepCopy(utils.getInProcected(self.getPoint, self)),
    stack = mist.utils.deepCopy(self.FSM_stack)
  }
  if self.target then 
    result.target = {
      name = utils.getInProcected(self.target.getName, self),
      point = mist.utils.deepCopy(utils.getInProcected(self.target.getPoint, self)),
      highestThread = mist.utils.deepCopy(utils.getInProcected(self.target.getHighestThreat, self))
    }   
  end

  result.elements = {}
  for _, elem in pairs(self.elements) do 
    result.elements[#result.elements+1] = {
      name = utils.getInProcected(elem.getName, self),
      point = mist.utils.deepCopy(utils.getInProcected(elem.getPoint, self)),
      exists = utils.getInProcected(elem.isExist, self),
      topState = mist.utils.deepCopy(utils.getInProcected(elem.FSM_stack.getCurrentState, self))
    }
    
  end

  result.planes = {}
  for _, plane in self:planes() do 
    result.planes[#result.planes+1] = {
      exist = utils.getInProcected(plane.isExist, self),
      name = utils.getInProcected(plane.getName, self),
      topState = mist.utils.deepCopy(utils.getInProcected(plane.FSM_stack.getCurrentState, self)),
      point = mist.utils.deepCopy(utils.getInProcected(plane.getPoint, self))
    }
  end
  return result
end

--call elements FSM
function CapGroup:callElements()
  for _, element in pairs(self.elements) do
    local _r, _e = xpcall(function() element:callFSM() end, debug.traceback)

    if not _r then 
      GlobalLogger:create():error(element:getName() .. " error in element fsm: \n" .. tostring(_e))
      GlobalLogger:create():error(mist.utils.serializeWithCycles(element:getName() .. " dump", element:getDebugDump()))
      GlobalLogger:create():addToFile(mist.utils.serializeWithCycles(element:getName() .. " dump", element:getDebugDump()))

      --reset element fsm to first state
      element.FSM_stack:unwind()
    end
  end
end

function CapGroup:callFSM() 
  local res, _err = xpcall(function() self.FSM_stack:run(self.FSM_args) end, debug.traceback)
  
  if not res then 
    GlobalLogger:create():error(self:getName() .. " error in group fsm call: \n" .. tostring(_err))
    local dump = mist.utils.serializeWithCycles(self:getName() .. " dump", self:getDebugDump())
    GlobalLogger:create():error(dump)
    GlobalLogger:create():addToFile(dump)
    --reset fsm to first state
    self.FSM_stack:unwind()
    --initialize with stub FSM
    res, _err = pcall(function() self.FSM_stack:run(self.FSM_args) end, debug.traceback)

    if not res then 
      --CRITICAL ERROR
      GlobalLogger:create():error(self:getName() .. " error in restart fsm: \n" .. tostring(_err))
      dump = mist.utils.serializeWithCycles(self:getName() .. " restart dump", self:getDebugDump())
      GlobalLogger:create():error(dump)
      GlobalLogger:create():addToFile(dump)
      --throw to mainloop handler
      error("error in restart fsm")
    end
    return
  end

  self:callElements()
  self.FSM_args = {
    radars = {},
    contacts = {}
    }

    self.FSM_stack:resetCounter()
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


  local msg = self:getName() .. " CapGroup:checkTargets() called from " .. 
    tostring(debug.getinfo(2).name) .. " " .. tostring(debug.getinfo(2).linedefined) 
    .. "\n contacts: " .. tostring(targetCandidates) .. "\n FSM_Arg " .. tostring(self.FSM_args.contacts)
  GlobalLogger:create():debug(msg)

  local emptyTable = {
      target = nil,
      priority = -math.huge,
      range = -10,
      commitRange = -10, --calculated commit range for target
      aspect = 180       --lowest aspect by getAspectFromElements()
    }

  if targetCandidates == {} then 
    GlobalLogger:create():debug(self:getName() .. " no target supplied")
    return mist.utils.deepCopy(emptyTable) 
  end

  local resultTarget = mist.utils.deepCopy(emptyTable)
  
  --get target with most priority
  for _, targetTbl in pairs(self:calculateTargetsPriority(targetCandidates)) do 
    if targetTbl.priority > resultTarget.priority then 
      resultTarget = targetTbl
    end
  end
  
  if not resultTarget.target then 
    GlobalLogger:create():debug(self:getName() .. " no target finded")
    return emptyTable
  end
  
  --option for route check:
  -- target will be returned if option off
  -- or distance from target to current leg < commitRange OR dist to target less then 20nm(to prevent disengaging in combat)
  local inRouteArea = not self.checkRouteDist or (resultTarget.range < 40000 or
    self.route:distanceToLeg(resultTarget.target:getPoint()) < self.commitRange)
  
  --return target if it inside one of commit Zones or inside commitRange and to close to route(if option set)
  local commitRange = self:calculateCommitRange(resultTarget.target, resultTarget.aspect)
  if(resultTarget.target == self.target) then 
  GlobalLogger:create():debug(self:getName() .. " increase range")
    commitRange = commitRange + 25000
  end

  if (resultTarget.range < commitRange and inRouteArea)
    or self:checkInZones(resultTarget.target) then
    
    resultTarget.commitRange = commitRange
    GlobalLogger:create():debug(self:getName() .. " target is " .. tostring(resultTarget.target))
    return resultTarget
  end
  
  GlobalLogger:create():debug(self:getName() .. " no target pass check")
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
      
      local result, err = xpcall(function()
        --return only alive and aircraft
        if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") then
          result[nbr] = TargetContainer:create(contact, plane)
          nbr = nbr + 1
          end
        end, debug.traceback)

      if not result then 
          GlobalLogger:create():error(" CapGroup:getDetectedTargets bad contact: " .. tostring(err))
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
      
      local res, err = xpcall(function ()
        
        if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air")
          and land.isVisible(contact.object:getPoint(), ourPos) --CHECK LOS
          and mist.utils.get3DDist(contact.object:getPoint(), ourPos) < self.radarRange
          and self:calculateAOB(contact.object:getPoint(), plane) < 90 then --target in front of aircraft
            
          result[nbr] = TargetContainer:create(contact, plane)
          nbr = nbr + 1
          end
        end, debug.traceback)
      
      if not res then 
        GlobalLogger:create():error(" CapGroup:getDetectedTargetsWithChecks bad contact: " .. tostring(err))
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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_6CapGroupFSM.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

------------------------------------------------
-- First state, wait until group take off
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupStart
----------------------------------------------------

FSM_GroupStart = utils.inheritFrom(AbstractState)

--arg does nothing
function FSM_GroupStart:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_GroupStart"
  instance.enumerator = CapGroup.FSM_Enum.FSM_GroupStart
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end


function FSM_GroupStart:setup() 
  --update point to skip first stpt
  self.object.route:checkWpChange(self.object:getPoint())
  
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM_NoCall(FSM_Element_Start:create(self.object.elements[1]))
  end--]]
--no teardown() 


function FSM_GroupStart:run(arg) 
  if not self.object:isAirborne() then
    --group still on ground
    return
  end
  
  GlobalLogger:create():debug(self.object:getName() .. " airborne, push to FlyRoute")
  self.object:setFSM(FSM_FlyRoute:create(self.object))
end




----------------------------------------------------
--- helper class, implement helpers for transition
--- checks
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----------------------------------------------------

FSM_GroupChecks = utils.inheritFrom(AbstractState)

function FSM_GroupChecks:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --minimum desired speed
  instance.targetSpeed = 0
  instance.burnerAllowed = false
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_GroupChecks:checkAttack(contacts) 

  local tgt = self.object:checkTargets(contacts)
  
  if not tgt.target then 
    return false
  end
  
  if tgt.range > tgt.commitRange then 
    GlobalLogger:create():debug(self.object:getName() .. " go commit on: " .. tgt.target:getName() .. " range: " 
      .. tostring(tgt.range) .. " CR: " .. tostring(tgt.commitRange))
    self.object:setFSM(FSM_Commit:create(self.object, tgt.target))
    return true
  end
  
  self.object:setFSM(FSM_Engaged:create(self.object, tgt.target))
  return true
end

function FSM_GroupChecks:setBurner(val) 
  --if value false, then return original values
  local command = nil
  if val then 
    command = utils.tasks.command.Burner_Use.On
  end
  
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, command)
  end
end

--if group flies to slow(commanded speed - actual > 50m/s(100kn))
-- then we allow usage of afterburner, and restrict it back when
-- speed is ~40kn from target speed
function FSM_GroupChecks:checkForBurner() 
  local deltaSpeed = self.targetSpeed - mist.vec.mag(self.object:getLead():getVelocity())
  
  if deltaSpeed < 20 and self.burnerAllowed then 
    self.burnerAllowed = false
    self:setBurner(false)
    GlobalLogger:create():debug(self.object:getName() .. " allow burner")
  elseif deltaSpeed > 50 and not self.burnerAllowed then 
    self.burnerAllowed = true
    self:setBurner(true)
    GlobalLogger:create():debug(self.object:getName() .. " restrict burner")
  end
end

function FSM_GroupChecks:setTargetSpeed(newSpeed) 
  self.targetSpeed = newSpeed or 0
end

--check for RTB/Attack and set correct state if so,
--return true if change state is occured
--also checks updateAutonomous
function FSM_GroupChecks:groupChecks(arg) 

  --firstly check for RTB
  if self.object:needRTB() then 
    --go RTB
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return true
  end
  
  if self:checkAttack(arg.contacts) then 
    return true
  end
  
  --check for autonomous
  self.object:updateAutonomous(arg.radars)
  --check for burner
  self:checkForBurner()
  return false
end

----------------------------------------------------
--- Rejoin state, first aircraft will orbit at current
--- position until all group is rejoined(this mean maxDist < 10000)
--- except Target detected or shouldRTB() returns true
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----              FSM_Rejoin
----------------------------------------------------

FSM_Rejoin = utils.inheritFrom(FSM_GroupChecks)

function FSM_Rejoin:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --no speed, DCS will set stallSpeed*1.5
  instance.task = { 
     id = 'Orbit', 
     params = { 
       pattern = "Circle",
       point = mist.utils.makeVec2(handledGroup:getPoint()),
       altitude = 6000,
       speed = 150
     } 
    }
  instance.name = "FSM_Rejoin"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Rejoin
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Rejoin:setup() 
  GlobalLogger:create():info(self.object:getName() .. " FSM_Rejoin:setup(), range to lead " .. tostring(self.object:getMaxDistanceToLead()))

  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyOrbit, self.task))
end

--no teardown()

--arg does nothing
function FSM_Rejoin:run(arg)
  --perform checks for transition
  if self:groupChecks(arg) then 
    return
  end
  
  --check for exit
  if self.object:getMaxDistanceToLead() > 20000 then 
    return
  end

  GlobalLogger:create():info(self.object:getName() .. " rejoin complete")
  --we close enough, return to prev state
  self.object:popFSM()
end



----------------------------------------------------
--- RTB state, when group just fly to home, 
--- and don't engage dua lack Ammo/Fuel, 
--- can transit to Deactivate if shouldDeactivate()
--- return true, mostly similar to FlyRoute
--- but no interrupt for attack of rejoin
--- Also prohibit use of afterburner
----------------------------------------------------
----             AbstractState
----                  ↓
----             FSM_GroupRTB
----------------------------------------------------
FSM_GroupRTB = utils.inheritFrom(AbstractState)

function FSM_GroupRTB:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  --create task
  instance.waypoint = handledGroup.route:getHomeBase()
  instance.name = "FSM_GroupRTB"
  instance.enumerator = CapGroup.FSM_Enum.FSM_GroupRTB
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end

function FSM_GroupRTB:setup() 
  self.object:setAutonomous(false)
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --prohibit AB using
  --allow infinite fuel, or can crash
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off)
    plane:getController():setCommand({ 
      id = 'SetUnlimitedFuel', 
      params = { 
        value = true 
      } 
    })
    end
  
  --if homeBase if airfield, fly as singletons, set FSM_PlaneRTB, if it just a point set FlyToPoint
  if self.object.route:hasAirfield() then 
    GlobalLogger:create():info(self.object:getName() .. " FSM_GroupRTB:setup(), RTB to airfield")

    self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_PlaneRTB, self.waypoint))
  else
    GlobalLogger:create():info(self.object:getName() .. " FSM_GroupRTB:setup(), RTB to WP")

    --create waypoint at wp position at altitude of 5000m, use standart fly in formation
    self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyToPoint, 
        mist.fixedWing.buildWP(self.waypoint, "turningpoint", 250, 5000, "BARO")))
  end
end

function FSM_GroupRTB:run(arg) 
  --no need to send argument
  
  --check for deactivate
  if not self.object:shouldDeactivate() then 
    return
  end
  
  self.object:setFSM(self.object.deactivateClass:create(self.object))
end

----------------------------------------------------
--- decorator for RTB for route version, will remove
--- planes from objective when start
----------------------------------------------------
----             AbstractState
----                  ↓
----             FSM_GroupRTB
----                  ↓
----           FSM_GroupRTB_Route
----------------------------------------------------

FSM_GroupRTB_Route = utils.inheritFrom(FSM_GroupRTB)

function FSM_GroupRTB_Route:setup() 
  --i think it's safe cause no transitions except to deativate so setup() will be called only once
  self.object.objective:addCapPlanes(-self.object:getOriginalSize())
  
  self:super().setup(self)
end

----------------------------------------------------
-- Flying route state, few transitions here:
-- 1) if shouldRTB() return true or when group very close to homeBase(distance < 20km) -> FSM_RTB
-- 2) if target detected within commitRange -> FSM_Engage
-- 3) if valid target detected withou commitRange -> FSM_Commit(just move towards target without executing combat tactics)
-- 4) if approach to PatrolZone -> FSM_PatrolZone
-- 5) if distance between planes > 20000 -> FSM_Rejoin
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----             FSM_FlyRoute
----------------------------------------------------

FSM_FlyRoute = utils.inheritFrom(FSM_GroupChecks) 

function FSM_FlyRoute:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_FlyRoute"
  instance.enumerator = CapGroup.FSM_Enum.FSM_FlyRoute
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


--check if we close enough to deactivate point and we fly toward it
--return true if so
function FSM_FlyRoute:checkBaseProximity() 
  return self.object.route:isReachEnd() and mist.utils.get2DDist(self.object:getPoint(), self.object.route:getHomeBase()) < 20000
end


function FSM_FlyRoute:setNextWP() 
  if self.object.route:isReachEnd() then 
    --we fly toward home, create WP at airfield position, but type of 'Turning point'
    self.object.elements[1]:setFSM_Arg("waypoint", mist.fixedWing.buildWP(self.object.route:getHomeBase(), "turningpoint", 200, 8000, "BARO"))
    
    --update target speed
    self:setTargetSpeed(200)
    GlobalLogger:create():drawPoint({point = self.object.route:getHomeBase(), text = self.object:getName() .. " Home Point"})
    return
  end
 
  --we just fly toward wp, set it
  self.object.elements[1]:setFSM_Arg("waypoint", self.object.route:getCurrentWaypoint())
  
  --update target speed
  self:setTargetSpeed(self.object.route:getCurrentWaypoint().speed)
  GlobalLogger:create():drawPoint({point = self.object.route:getCurrentWaypoint(), text = self.object:getName() .. " Next WP"})
end

function FSM_FlyRoute:setup()
  if self:checkPatrolZone() then 
    --prevent RTB when route very compact(i.e. hold placed right over airfield)
    return
  end
  
  --prepare elements
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --check we should change WP
  self.object.route:checkWpChange(self.object:getPoint())
  
  --if we fly toward home, but to far from it
  --we need to remove type = "Land", so checkTask not be broken
  --not set RTB here, cause we can't interrupt it for attack
  --even if fuel/ammo allows, also when plane execute
  --treir landing behaviour, Follow task don't work correctly
  --even if target plane flying straight
  if self.object.route:isReachEnd() then 
    --we fly toward home, create WP at airfield position, but type of 'Turning point'
    self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(
        self.object.elements[1], FSM_FlyToPoint, mist.fixedWing.buildWP(self.object.route:getHomeBase(), "turningpoint", 200, 8000, "BARO")))
    
    self:setTargetSpeed(200)
    
    GlobalLogger:create():info(self.object:getName() .. " FSM_FlyRoute:setup(), fly toward home")
    return
  end
  
  --we just fly toward wp, set it
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyToPoint, self.object.route:getCurrentWaypoint()))
  --update target speed
  self:setTargetSpeed(self.object.route:getCurrentWaypoint().speed)
end


 --check approach for any of patrols zones for current WP, and if so 
 --transit to FSM_PatrolZone and return true
function FSM_FlyRoute:checkPatrolZone() 
  local zones = self.object.patrolZones[self.object.route:getWaypointNumber()]
  if not zones then 
    return false
  end
  
  for _, zone in pairs(zones) do 
    
    if mist.utils.get2DDist(self.object:getPoint(), zone:getPoint()) < 15000 
      and zone:checkPreCondition() then 
      self.object:setFSM(FSM_PatrolZone:create(self.object, zone))
      return true
    end
  end
  
  return false
end

function FSM_FlyRoute:run(arg) 
  --Attack and RTB
  if self:groupChecks(arg) then 
    return
  end
  
  --to Rejoin
  if self.object:getMaxDistanceToLead() > 20000 then 
    --go to FSM_Rejoin
    self.object:setFSM(FSM_Rejoin:create(self.object))
    return
  end
  
  --transition to FSM_PatrolZone
  if self:checkPatrolZone() then 
    return
  end
  
  if self:checkBaseProximity() then 
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  elseif self.object.route:checkWpChange(self.object:getPoint()) then
    --time to change wp
    self:setNextWP()
  end
end
----------------------------------------------------
-- Deactivate state, delete all planes
----------------------------------------------------
----            AbstractState
----                  ↓
----            FSM_Deactivate
----------------------------------------------------

FSM_Deactivate = utils.inheritFrom(AbstractState)

function FSM_Deactivate:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_Deactivate"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Deactivate
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Deactivate:run(arg) 
  --delete all aircraft
  for _, plane in self.object:planes() do 
    plane:getObject():destroy()
  end
  
  --wipe elements
  self.object.elements = {}

  GlobalLogger:create():info(self.object:getName() .. " FSM_Deactivate:run() deactivate group")
  end

----------------------------------------------------
-- Deactivate state, for route version, also remove
-- remaining airplanes to squadron
----------------------------------------------------
----            AbstractState
----                  ↓
----           FSM_Deactivate
----                  ↓
----          FSM_Deactivate_Route
----------------------------------------------------

FSM_Deactivate_Route = utils.inheritFrom(FSM_Deactivate)

function FSM_Deactivate_Route:setup() 
  --return remaining aircraft to squadron
  GlobalLogger:create():info(self.object:getName() .. " FSM_Deactivate_Route:setup(), return planes: " .. tostring(self.object.countPlanes))
  self.object.sqn:returnAircrafts(self.object.countPlanes)
end

----------------------------------------------------
-- Commit, group move to intercept, but at lower speed
-- to save fuel and maintaining formation, at commitRange
-- will switch to Engage and start execute combat tactics
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----              FSM_Commit
----------------------------------------------------

FSM_Commit = utils.inheritFrom(FSM_GroupChecks)

function FSM_Commit:create(handledGroup, target) 
  local instance = self:super():create(handledGroup)
  
  --update target
  instance.object.target = target
  --Dont't set targeted, so it can be attacked by other groups
  --will set flag in FSM_engage
  --self.object.target:setTargeted(true)
  
  instance.name = "FSM_Commit"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Commit
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Commit:setup() 

  if not (self.object.target and self.object.target:isExist()) then 
    GlobalLogger:create():info(self.object:getName() .. " FSM_Commit:setup() no target")

    --no target, continue unwind
    self.object:popFSM()
    return
  end
  
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --set autonomous so radar will be enabled
  self.object:setAutonomous(true)
  
  --take lead target, speed during this state will be 290 this is ~0.85M
  self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_FlyToPoint, 
    self:getInterceptWaypoint(290)))

  --set new Target Speed(it's always same for this state)
  self:setTargetSpeed(290)
  end
  
function FSM_Commit:teardown() 
  self.object.target = nil
  end
  

function FSM_Commit:getInterceptWaypoint(speed) 
  local p = utils.getInterceptPoint(self.object.target:getLead(), self.object:getLead(), speed)
  return mist.fixedWing.buildWP(p, "turningpoint", speed, self.object.target:getPoint().y, "BARO")
end

--return true if state switch occured
function FSM_Commit:checkTargetStatus(contacts) 
  --check if target still avail
  local tgt = self.object:checkTargets(contacts)
  
  if not tgt.target then 
    --no target for commit
    self.object:popFSM()
    return true
  elseif tgt.target ~= self.object.target then 
    --update target
    self.object.target = tgt.target
  end
  
  --check for transition to Engaged
  if tgt.range < tgt.commitRange then 
      
    self.object:setFSM(FSM_Engaged:create(self.object, tgt.target))  
    return true
  end 
  return false
end
  
function FSM_Commit:run(arg) 
  --check for RTB
  if self.object:needRTB() then 
    self:teardown()--delete target
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  end
  
  if self:checkTargetStatus(arg.contacts) then 
    return
  end
  
  --update point for first plane
  self.object.elements[1]:setFSM_Arg("waypoint", self:getInterceptWaypoint(290))
end
----------------------------------------------------
-- Engage state, elements execute their combat tactics
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----             FSM_Engaged
----------------------------------------------------

FSM_Engaged = utils.inheritFrom(FSM_GroupChecks)
FSM_Engaged.tactics = {}
FSM_Engaged.tactics[CapGroup.tactics.Skate] = FSM_Element_Skate
FSM_Engaged.tactics[CapGroup.tactics.SkateGrinder] = FSM_Element_SkateGrinder
FSM_Engaged.tactics[CapGroup.tactics.SkateOffset] = FSM_Element_SkateOffset
FSM_Engaged.tactics[CapGroup.tactics.SkateOffsetGrinder] = FSM_Element_SkateOffsetGrinder
FSM_Engaged.tactics[CapGroup.tactics.ShortSkate] = FSM_Element_ShortSkate
FSM_Engaged.tactics[CapGroup.tactics.ShortSkateGrinder] = FSM_Element_ShortSkateGrinder
FSM_Engaged.tactics[CapGroup.tactics.Bracket] = FSM_Element_Bracket
FSM_Engaged.tactics[CapGroup.tactics.Banzai] = FSM_Element_Banzai


function FSM_Engaged:create(handledGroup, target) 
  local instance = self:super():create(handledGroup)

  target:setTargeted(true)
  handledGroup.target = target
  instance.name = "FSM_Engaged"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Engaged
  instance.tactic = nil
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Engaged:selectTactic() 
  local counter, tblWithWeights = 0, {}
  
  for enum, tactic in pairs(self.tactics) do 
    local w = tactic:getWeight(self.object)
    tblWithWeights[enum] = w
    counter = counter + w
  end
  
  local stepSize = 100/counter
  local prevRange = 0
  local randomChoice = mist.random(100)
  
  for enum, weight in pairs(tblWithWeights) do 
    local newRange = prevRange + stepSize*weight
    if prevRange <= randomChoice and randomChoice <= newRange then 

      return self.tactics[enum]
    end
    prevRange = newRange
  end
end

function FSM_Engaged:setup() 
  self.object:splitElement()
  --set autonomous so radar will be enabled
  self.object:setAutonomous(true)
  
  self.tactic = self:selectTactic()

  for _, elem in pairs(self.object.elements) do 
    elem:clearFSM()
    elem:setFSM(self.tactic:create(elem))
  end
end


function FSM_Engaged:teardown() 
  if not self.object.target then
    return
  end
  self.object.target:setTargeted(false)
  self.object.target = nil
  
  --clear element side
  for _, elem in pairs(self.object.elements) do 
    elem.sideOfElement = nil
  end
end

--if we reach RTB ammo or ~0.1 away from bingo go pump
--splitElement if no second elem
--if no target go back
function FSM_Engaged:run(arg) 
  if self.object.ammoState <= self.object.rtbWhen or self.object:getFuel() < (self.object.bingoFuel + 0.1) then 
    self.object:popFSM_NoCall()
    self.object:setFSM(FSM_Pump:create(self.object))
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, need RTB")
    return
    
  elseif not self.object.target:isExist() then
    --target dead, return
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, target dead")
    self.object:popFSM()
    return
  end
  
  self.object:splitElement()
  
  local tgt = self.object:checkTargets(arg.contacts)

  if not tgt.target then 
    --no target for commit
    GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: exit, no more targets")
    self.object:popFSM()
    return
  
  elseif tgt.target == self.object.target then
    --return to prev state if range more then CommitRange + 10nm
    
    local commitRange = tgt.commitRange
    if commitRange + 18500 < tgt.range then
      
      GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: drop target, range: " .. tostring(tgt.range) .. " cr: " .. tostring(commitRange))
      self.object:popFSM()
      return
    end
  
  else
    local ourTgt = self.object.target
    local typeModifier = self.object.priorityForTypes[ourTgt:getTypeModifier()]
    local ourTargetPriority = self.object:getTargetPriority(ourTgt, ourTgt:getCount(), typeModifier, 1, 
        mist.utils.get2DDist(self.object:getPoint(), ourTgt:getPoint()), ourTgt:getAA(self.object:getPoint()))
    
    if tgt.priority/ourTargetPriority >= 1.1 then

      GlobalLogger:create():debug(self.object:getName() .. " FSM_Engaged: set new target for group: " .. tgt.target:getName())
      --update target
      self.object.target:setTargeted(false)
      tgt.target:setTargeted(true)
      self.object.target = tgt.target
    end
  end

  self:checkForSplit(arg.contacts)
  self:checkForRejoin(arg.contacts)
end

--check if any other groups to close to second element
--split group if so

function FSM_Engaged:checkForSplit(targets) 
  
  local element = self.object.elements[2]
  if not element or element:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then 
    --element dead or already splitted
    return
  end
  
  local closestTarget = self:findClosestTarget(targets) 
  if not (closestTarget.target and closestTarget.target ~= self.object.target) then 
    return
  end
  GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: Split elements")

  --split group, first element continue attack original target
  --no range check, should pop manually
  self.object.elements[1]:setFSM(FSM_Element_GroupEmul:create(self.object.elements[1], self.object.target, true))
  
  --second element goes on his own target
  self.object.elements[2]:setFSM(FSM_Element_GroupEmul:create(self.object.elements[2], closestTarget.target, false))
end



--target inside max(15NM, Min(MaxRANGE/MAR+7500)) get closest from this
--added 08.01.24: skip all target groups except fighters
function FSM_Engaged:findClosestTarget(targets) 
  local element = self.object.elements[2]
  local elemPos, elemRange = element:getPoint(), element:getBestMissile().MaxRange
  local lowestRangeTarget = {target = nil, range = math.huge}
  for _, target in pairs(targets) do 
    
    local range = mist.utils.get2DDist(target:getPoint(), elemPos)
    if range < math.max(27000, math.min(elemRange, target:getHighestThreat().MAR + 7500)) 
      and range < lowestRangeTarget.range 
      and target:getTypeModifier() == AbstractTarget.TypeModifier.FIGHTER then 
      
      lowestRangeTarget = {target = target, range = range}
    end
  end
  
  return lowestRangeTarget
end

function FSM_Engaged:checkForRejoin(targets) 
  if self.object.elements[1]:getCurrentFSM() ~= CapElement.FSM_Enum.FSM_Element_GroupEmul then 
    --elements not splitted
    return
    end
  
  --other element dead or return from split state, when first element also return to normal tactics
  local element = self.object.elements[2]
  if element and element:getCurrentFSM() == CapElement.FSM_Enum.FSM_Element_GroupEmul then
    --element still in state update target    
    local closestTarget = self:findClosestTarget(targets).target
    self.object.elements[2]:setFSM_Arg('newTarget', closestTarget)
    return
  end
  
  GlobalLogger:create():info(self.object:getName() .. " FSM_Engaged: rejoin elements")
  self.object.elements[1]:popFSM_NoCall()
end

----------------------------------------------------
-- Group flying at max speed toward home base, 
-- trying to increate distance, called from engage
-- when NoAmmo/fuel approach bingo to break contact
-- if fuel below Bingo -> RTB
-- or no targets inside commit range or 20km from home base
----------------------------------------------------
----             AbstractState
----                  ↓
----               FSM_Pump 
----------------------------------------------------

FSM_Pump = utils.inheritFrom(AbstractState)

function FSM_Pump:create(handledGroup) 
  local instance = self:super():create(handledGroup)
  
  instance.name = "FSM_Pump"
  instance.enumerator = CapGroup.FSM_Enum.FSM_Pump
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_Pump:setup() 
  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  --allow usage of afterburner
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On)
    --set infinite fuel
    plane:getController():setCommand({ 
      id = 'SetUnlimitedFuel', 
      params = { 
        value = true 
      } 
    })
  end
  
  --convert to vec2 or it will use speed/alt from point
  local wp = mist.fixedWing.buildWP(mist.utils.makeVec2(self.object.route:getHomeBase()), "turningpoint", 500, 7000, "BARO")
  self.object.elements[1]:setFSM(FSM_Element_FlySeparatly:create(self.object.elements[1], FSM_FlyToPoint, wp))

  GlobalLogger:create():info(self.object:getName() .. " FSM_Pump:setup() done")
end
  
function FSM_Pump:teardown() 
  --restrict use of burner
  for _, plane in self.object:planes() do 
    plane:setOption(CapPlane.options.BurnerUse, nil)
  end
end
  
function FSM_Pump:run(arg) 

  local selfPos = self.object:getPoint()
  local hasTarget = false
  for _, contact in pairs(arg.contacts) do 
    if mist.utils.get2DDist(contact:getPoint(), selfPos) < self.object.commitRange then 
      hasTarget = true
      break
    end
  end
  
  if not hasTarget 
    or mist.utils.get2DDist(self.object:getPoint(), self.object.route:getHomeBase()) < 20000
    or self.object:getFuel() < self.object.bingoFuel then 
      
    --no targets nearby, or we close to home, or fuel low
    self.object:setFSM(self.object.rtbClass:create(self.object))
    return
  end
end

----------------------------------------------------
-- Group flying in patrol zone, until 
--  1)postCondition() return true -> return back
--  2)groupChecks -> go respective state
--  3)distance > 20000 go rejoin
----------------------------------------------------
----             AbstractState
----                  ↓
----            FSM_GroupChecks 
----                  ↓
----            FSM_PatrolZone 
----------------------------------------------------
FSM_PatrolZone = utils.inheritFrom(FSM_GroupChecks)

function FSM_PatrolZone:create(handledGroup, zone) 
  local instance = self:super():create(handledGroup)

  instance.zone = zone
  instance.name = "FSM_PatrolZone"
  instance.enumerator = CapGroup.FSM_Enum.FSM_PatrolZone
  --start exist conditons
  for _, cond in pairs(instance.zone.postConditions) do 
    cond:start()
    end
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function FSM_PatrolZone:setup() 
  GlobalLogger:create():info(self.object:getName() .. " FSM_PatrolZone:setup()")

  self.object:mergeElements()
  self.object.elements[1]:clearFSM()
  
  self.object.elements[1]:setFSM(FSM_Element_FlyFormation:create(self.object.elements[1], FSM_FlyOrbit, self.zone:getTask()))
  --update speed
  self:setTargetSpeed(self.zone:getTask().params.speed or 0)
end

function FSM_PatrolZone:run(arg)

  if self:groupChecks(arg) then 
    return
  elseif self.zone:checkExitCondition() then 
    GlobalLogger:create():info(self.zone:getName() .. " Exit")
    self.object:removePatrolZone(self.zone)
    self.object:popFSM()
    return
  end
  
  if self.object:getMaxDistanceToLead() > 20000 then 
    --go to FSM_Rejoin
    self.object:setFSM(FSM_Rejoin:create(self.object))
    return
  end
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_7_1DetectorHandler.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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
  
  for id, groundRadar in pairs(self.radars) do 
    local result, err = xpcall(
      function()       
        if not groundRadar:isExist() then 
          GlobalLogger:create():debug("Ground radar: " .. groundRadar:getName() .. " dead")
          self.radars[groundRadar:getID()] = nil
        end
      end,
      debug.traceback)
    
    if not result then 
      GlobalLogger:create():error("DetectionHandler: error during radar update,delete " .. mist.utils.serialize("\n traceback", err))
      self.radars[id] = nil
    end
  end
    
  for id, airGroup in pairs(self.airborneRadars) do 
    if not airGroup:isExist() or not airGroup:getAutonomous() then

      local result, err = xpcall(function()
        GlobalLogger:create():debug("Airborne radar: " .. airGroup:getName() .. " dead")
        self.airborneRadars[id] = nil
      end, debug.traceback)

      if not result then 
        GlobalLogger:create():error("DetectionHandler: error during radar update,delete " .. mist.utils.serialize("\n traceback", err))
        self.airborneRadars[id] = nil
      end
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
  
  for id, radar in pairs(self:getRadars()) do 

    local res, _err = xpcall(function()
      for __, target in pairs(radar:getDetectedTargets()) do 
        contacts[#contacts+1] = target
      end
    end, debug.traceback)
    if not res then 
        GlobalLogger:create():warning("DetectionHandler:askRadars bad radar ask " .. tostring(_err))
        self.radars[id] = nil
    end
  end
  
  for id, radar in pairs(self.airborneRadars) do 

    local res, _err = xpcall(function()
      for __, target in pairs(radar:getDetectedTargets()) do 
        contacts[#contacts+1] = target
      end
    end, debug.traceback)
    if not res then 
        GlobalLogger:create():warning("DetectionHandler:askRadars bad AIR radar ask " .. tostring(_err))
        self.airborneRadars[id] = nil
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


---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_7_2CapObjective.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

----------------------------------------------------
-- CapObjective whick GciCapHandler will try to cover
---with groups
----------------------------------------------------
----        AbstractCAP_Handler_Object
----                  ↓
----            CapObjective
----------------------------------------------------
---@module "AnnotationsMeta"

---@class CapObjective
---@field private id number
---@field private name string
---@field zone AbstractZone
---@field private point vec3
---@field private requestCap boolean = false
---@field private requestGci boolean = false
---@field private priority CapObjective.Priority
---@field private modifierFigher number
---@field private modifierOther number 
---@field private capRequestAmount number
---@field private maxGciPlanes number
---@field private threatAircraft number
---@field private aircraftAssigned number
---@field private squadrons CapSquadronAir[]
CapObjective = utils.inheritFrom(AbstractCAP_Handler_Object)

---@enum CapObjective.Priority
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
---@param point vec2 | vec3
---@return CapObjective
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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_7_3CapSquadron.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------


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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_8Logger.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--     Source file: 9_9AiHandler.lua
---------------------------------------------------------------------------
---------------------------------------------------------------------------

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

function AbstractMainloop:createForBlue()
  return AbstractMainloop:create(AbstractMainloop.coalition.BLUE)
end

function AbstractMainloop:createForRed()
  return AbstractMainloop:create(AbstractMainloop.coalition.RED)
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
  GlobalLogger:create():info("Added radar: " .. radar:getName())
end

--add ALL EW from coalition
function AbstractMainloop:addEWs() 
  for _, group in pairs(coalition.getGroups(self.coalition, Group.Category.GROUND)) do 
    
    for _, unit in pairs(group:getUnits()) do 
      if unit:hasAttribute("EWR") then 
          GlobalLogger:create():info("addEWs(): Add new EW: " .. unit:getName())
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
    GlobalLogger:create():error("AiHandler: error during detector update, traceback: \n" .. mist.utils.serialize("", _err))
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
      
      GlobalLogger:create():info(group:getName() .. " activated")
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

function GciCapHandler:createSqnFromPrefix(capGroupPrefix)
  --search all cap group
  local sqnCandidates = utils.getItemsByPrefix(coalition.getGroups(self.coalition, 0), capGroupPrefix)
  for _, group in pairs(sqnCandidates) do 
    local planeAmount = mist.random(2, 6)
    local readyAmount = mist.random(2, planeAmount)
    GlobalLogger:create():info("Create sqn for group: " .. group:getName() .. " with ready/all: " .. tostring(readyAmount) .. "/" .. tostring(planeAmount))
    self:addSquadron(CapSquadron:create(group:getName(), readyAmount, planeAmount))
  end
end


function GciCapHandler:addRandomizedObj(point, radius, zoneName)
  GlobalLogger:create():info("Create Obj " .. zoneName)
  local useForCap = false

  if mist.random(4) == 1 then 
    GlobalLogger:create():info(zoneName .. " will use Cap")
    useForCap = true
  end
  local priority = mist.random(6)
  if priority == 1 then 
    priority = CapObjective.Priority.Low
    GlobalLogger:create():info(zoneName .. " will low prioiry")
  elseif priority == 2 then 
    priority = CapObjective.Priority.Normal
    GlobalLogger:create():info(zoneName .. " will high priority")
  else
    priority = CapObjective.Priority.Low
    GlobalLogger:create():info(zoneName .. " will normal")
  end

  self:addObjective(CapObjective:create(point, CircleZone:create(point, radius), useForCap, true, priority, zoneName))
end

function GciCapHandler:addRandomizedObj2(ZONE, generateLow, generateHigh)
  GlobalLogger:create():info("Create Obj from zone" .. ZONE)
  local useForCap = false
  if mist.random(4) == 1 then 
    GlobalLogger:create():info(ZONE .. " will use Cap")
    useForCap = true
  end
  local priority = mist.random(5)
  if priority == 1 and generateLow then 
    priority = CapObjective.Priority.Low
    GlobalLogger:create():info(ZONE .. " will low prioiry")
  elseif priority == 2 and generateHigh then 
    priority = CapObjective.Priority.High
    GlobalLogger:create():info(ZONE .. " will high priority")
  else
    priority = CapObjective.Priority.Normal
    GlobalLogger:create():info(ZONE .. " will normal")
  end

  local zone = trigger.misc.getZone(ZONE)
  self:addObjective(CapObjective:create(zone.point, CircleZone:create(zone.point, zone.radius), useForCap, true, priority, ZONE))
end

function GciCapHandler:_createDefence(coal, capGroupPrefix, zonePrefix)
  capGroupPrefix = capGroupPrefix or "CAP"
  zonePrefix = zonePrefix or "CAPZONE"

  local handler = GciCapHandler:create(coal)
  handler:createSqnFromPrefix(capGroupPrefix)

  local i = 1
  for name, zone in pairs(mist.DBs.zonesByName) do 
    if string.find(name, zonePrefix) then 
        handler:addRandomizedObj2(zone, true, true)
        i = i + 1
    end
  end

  if i == 1 then 
    GlobalLogger:create():info("No zones was finded")

    for _, sqn in pairs(handler:getSquadrones()) do 
      handler:addRandomizedObj(sqn:getPoint(), mist.random(30*1852, 80*1852), sqn:getName())
    end
  end 

  return handler
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
  self:addObjective(sqn:generateObjective(objRadius or 200000))
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

function GciCapHandler:createDefenceForRed(capPrefix, zonePrefix)
  return GciCapHandler:_createDefence(GciCapHandler.coalition.RED)
end

function GciCapHandler:createDefenceForBlue(capPrefix, zonePrefix)
  return GciCapHandler:_createDefence(GciCapHandler.coalition.BLUE)
end

