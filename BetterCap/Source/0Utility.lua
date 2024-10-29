utils = {}
utils.generalID = 0 --used for internal purposes(i.e. zone ID or detector handler)
utils.unitID = 0   -- for DCS UNIT
utils.groupID = 0 --for DCS GROUP


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
  ["AIM_54C_Mk47"] = {MaxRange = 130000, MAR = 50000},
  ["AIM_54A_Mk60"] = {MaxRange = 140000, MAR = 50000},
  ["AIM_54A_Mk47"] = {MaxRange = 120000, MAR = 47000},
  ["weapons.missiles.AIM_120C"] = {MaxRange = 65000, MAR = 31000},
  ["weapons.missiles.AIM_120"] = {MaxRange = 55000, MAR = 27000},
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
