dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")


test_Timecontainer = {}

local originalWorld = mist.utils.deepCopy(world)

function test_Timecontainer:setup() 
  --return back mocked functions
  for name, field in pairs(originalWorld) do 
    if type(field) == "function" then 
      world[name] = field
    end
  end
end

function test_Timecontainer:teardown() 
  AirbaseWrapper._instances = {}
end

function test_Timecontainer:test_creation() 
  local group, unit, m = Group:create(), Unit:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  group.getID = m.getID
  when(group:getID()).thenAnswer(99)
  
  unit.getCountry = m.getCountry 
  when(m.getCountry(any())).thenAnswer(99)
  

  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  lu.assertNotNil(testedObj)
  lu.assertEquals(testedObj.country, 99)
  lu.assertEquals(testedObj:getID(), group:getID())
  lu.assertNotNil(testedObj:getName())
end

function test_Timecontainer:test_isActive() 
  --verify call to hasTask()
  local group, unit, m = Group:create(), Unit:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  unit.getCountry = m.getCountry 
  when(m.getCountry(any())).thenAnswer(99)
  
  group.getController = m.getController
  when(group:getController()).thenAnswer(m)
  when(m:hasTask()).thenAnswer(true)
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  lu.assertEquals(testedObj:isActive(), true)
  verify(m:hasTask())
  end

function test_Timecontainer:test_checkForAirbase_airfield_takeoffRunway() 
  --can find different startup types
  local group, unit, airbase, m = Group:create(), Unit:create(), Airbase:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  testedObj.groupTable = {}
  testedObj.groupTable.route = {
    points = {
      [1] = {
        type = "TakeOff",
        airdromeId = 1
        }
      }
    }
    
  lu.assertEquals(testedObj:checkForAirbase(), true)
end

function test_Timecontainer:test_checkForAirbase_airfield_takeoffParking() 
  --can find different startup types
  local group, unit, airbase, m = Group:create(), Unit:create(), Airbase:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  testedObj.groupTable = {}
  testedObj.groupTable.route = {
    points = {
      [1] = {
        type = "TakeOffParking",
        airdromeId = 1
        }
      }
    }
    
  lu.assertEquals(testedObj:checkForAirbase(), true)
end

function test_Timecontainer:test_checkForAirbase_airfield_takeoffParkingHot() 
  --can find different startup types
  local group, unit, airbase, m = Group:create(), Unit:create(), Airbase:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  testedObj.groupTable = {}
  testedObj.groupTable.route = {
    points = {
      [1] = {
        type = "TakeOffParkingHot",
        airdromeId = 1
        }
      }
    }
    
  lu.assertEquals(testedObj:checkForAirbase(), true)
end

function test_Timecontainer:test_checkForAirbase_airfield_NoAirfield() 
  --can find different startup types
  local group, unit, airbase, m = Group:create(), Unit:create(), Airbase:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  testedObj.groupTable = {}
  testedObj.groupTable.route = {
    points = {
      [1] = {
        type = "TakeOffParkingHot",
        airdromeId = 99 --no airfield will be finded
        }
      }
    }
    
  lu.assertEquals(testedObj:checkForAirbase(), false)
end

function test_Timecontainer:test_checkForAirbase_Carrier_AirfieldNotAvail() 
  --can find different startup types
  local group, unit, carrier, m = Group:create(), Unit:create(), Unit:create(), mockagne.getMock()
  
  --group mock
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit, mist.getGroupTable(group:getName()))
  
  --world mock
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({carrier})
  
  --airbase mock
  carrier.getID = m.getID
  carrier.hasAttribute = m.hasAttribute
  when(m.getID(carrier)).thenAnswer(99)
  when(m.hasAttribute(carrier, "AircraftCarrier")).thenAnswer(true)
  carrier.getParking = function() return {1, 2, 3, 4} end
  
  --carrier wrapper
  local carrierWrapper = CarrierWrapper:create(99)
  
  carrierWrapper.isAvail = m.isAvail
  when(m.isAvail(any())).thenAnswer(false)
  
  local testedObj = TimeDeferredContainer:create(group)
  testedObj.groupTable = {}
  testedObj.groupTable.route = {
    points = {
      [1] = {
        type = "TakeOffParkingHot",
        linkUnit = 99
        }
      }
    }
    
  lu.assertEquals(testedObj:checkForAirbase(), false)
end

function test_Timecontainer:test_settingAdded() 
  local group, unit, m = Group:create(), Unit:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  unit.getCountry = m.getCountry 
  when(m.getCountry(any())).thenAnswer(99)
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  lu.assertEquals(testedObj.groupSettings, {})
  
  --we call container like it capGroup, and it should record that call for future
  testedObj:setCommitRange(90000)
  testedObj:setBingo(1)
  lu.assertEquals(testedObj.groupSettings.setCommitRange, {90000})
  lu.assertEquals(testedObj.groupSettings.setBingo, {1})
  end

function test_Timecontainer:test_setSettings() 
  --add bunch of setting calls()
  --then call setSettings with capGroup and verify container make all
  --call on group
  local group, unit, m = Group:create(), Unit:create(), mockagne.getMock()
  
  group.getUnit = m.getUnit
  when(m.getUnit(group, 1)).thenAnswer(unit)
  
  unit.getCountry = m.getCountry 
  when(m.getCountry(any())).thenAnswer(99)
  --for logger call
  when(m:getName()).thenAnswer("")
  
  local testedObj = TimeDeferredContainer:create(group, mist.getGroupTable(group:getName()))
  lu.assertEquals(testedObj.groupSettings, {})
  
  --we call container like it capGroup, and it should record that call for future
  testedObj:setCommitRange(90000)
  testedObj:setBingo(1)
  
  testedObj:setSettings(m)
  verify(m.setBingo(m, 1))
  verify(m.setCommitRange(m, 90000))
end

---------------------------------------------------------------
test_AbstractSquadronContainer = {}

function test_AbstractSquadronContainer:test_creation() 
  --verify fields set(sqn, objective, amount to spawn)
  --verify planes was added to objective
  
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  
  local testedObj = AbstractSquadronContainer:create(sqn, obj, 2, 9999)
  lu.assertIs(testedObj.sqn, sqn)
  lu.assertIs(testedObj.objective, obj)
  lu.assertEquals(testedObj.amountToSpawn, 2)
  lu.assertEquals(testedObj.activateTime, 9999)
  lu.assertNotNil(testedObj.country)
  lu.assertNotNil(testedObj.id)
  
  verify(obj:addCapPlanes(2))
  
  --test basic methods
  lu.assertNotNil(testedObj:getID())
  lu.assertNotNil(testedObj:getName())
end

function test_AbstractSquadronContainer:test_setSettings() 
  local sqn = getCapSquadronMock()
  local testedObj = AbstractSquadronContainer:create(sqn, getCapObjectiveMock(), 2, 9999)
  
  sqn.squadronBingo = 0.35
  sqn.rtbAmmo = CapGroup.RTBWhen.NoAmmo
  sqn.deactivateWhen = CapGroup.DeactivateWhen.OnShutdown
  sqn.preferredTactics = {}
  sqn.goLiveThreshold = 5
  
  local p1, p2, p3 = 1.25, 0.75, 0.9
  sqn.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = p1,
    [AbstractTarget.TypeModifier.ATTACKER] = p2,
    [AbstractTarget.TypeModifier.HELI] = p3
  }
  
  local m = mockagne.getMock('group')
  testedObj:setSettings(m)
  
  verify(m:setRTBWhen(sqn.rtbAmmo))
  verify(m:setBingo(sqn.squadronBingo))
  verify(m:setDeactivateWhen(sqn.deactivateWhen))
  verify(m:setTactics(sqn.preferredTactics))
  verify(m:setPriorities(p1, p2, p3))--values from table
  verify(m:setGoLiveThreshold(sqn.goLiveThreshold))
end 

---------------------------------------------------------------
--AirContainer tests?
test_AirContainer = {}
test_AirContainer.origFunc = coalition.addGroup
test_AirContainer.argUsedForSpawn = {}
test_AirContainer.groupVal = "this is group!"
test_AirContainer.groupTbl = {
    name = "group",
    task = "CAP",
    units = {
      {
        name = "1",
        type = "abstract unit",
        x = 0, 
        y = 0,
        alt = 0,
        speed = 0,
        alt_type = "BARO",
        payload = {},
        }
      },
      route = {
        points = {
          mist.fixedWing.buildWP({x = 0, y = 0})
          }
        },
      x = 0, 
      y = 0
      }
test_AirContainer.originalRandom = mist.random      

function test_AirContainer:mockAddGroup() 
  coalition.addGroup = function(country, enum, table)
    
    self.argUsedForSpawn[#self.argUsedForSpawn + 1] = {country = country, enum = enum, table = mist.utils.deepCopy(table)}
    return self.groupVal end
  
end

function test_AirContainer:teardown() 
  --delete mock
  coalition.addGroup = test_HotContainer.origFunc
  self.argUsedForSpawn = {}
  mist.random = self.originalRandom
end

--verify unit and group names changes on every call to addGroup()
function test_AirContainer:checkNamesInTable(tbl) 
  local seenNames = {}

  for _, call in pairs(tbl) do 

    if not seenNames[call.table.name] then 
      seenNames[call.table.name] = true
    else
      return false
    end
    
    if not seenNames[call.table.units[1].name] then 
      seenNames[call.table.units[1].name] = true
    else
      return false
    end
  end
  
  return true
end

function test_AirContainer:test_activateAir() 

  local sqn = getCapSquadronMock()
  sqn:getAirbase().howManyParkingAvail = function() return 99 end
  --return just waypoint
  sqn.getPrototypeTable = function() return self.groupTbl end
  
  local m = mockagne.getMock()
  mist.random = m.rand
  when(m.rand(any())).thenAnswer(0)
  
  self:mockAddGroup()
  
  local testedObj = AirContainer:create(sqn, getCapObjectiveMock(), 3, 9999)
  
  lu.assertEquals(testedObj:activate(), {self.groupVal, self.groupVal, self.groupVal})
  --check names changes
  lu.assertTrue(self:checkNamesInTable(self.argUsedForSpawn))
  
  --check pos chanded, and random used
  verify(m.rand(any()))
  
  --first group should be at spawn pos(because random return 0)
  local spawnTable1 = self.argUsedForSpawn[1].table
  lu.assertEquals(spawnTable1.units[1].x, self.groupTbl.units[1].x)
  lu.assertEquals(spawnTable1.units[1].y, self.groupTbl.units[1].y)
  lu.assertEquals(spawnTable1.units[1].alt, self.groupTbl.units[1].alt)
  --wp coords also same
  lu.assertEquals(spawnTable1.route.points[1].x, self.groupTbl.route.points[1].x)
  lu.assertEquals(spawnTable1.route.points[1].y, self.groupTbl.route.points[1].y)
  
  --second shifted 500m
  local shiftVec = mist.projectPoint({x = 0, y = 0, z = 0}, 500, (self.groupTbl.units[1].heading or 0) + math.pi / 2)
  local origUnitPos = {x = self.groupTbl.units[1].x, z = self.groupTbl.units[1].y, y = self.groupTbl.units[1].alt}

  local newPos = mist.vec.add(origUnitPos, shiftVec)
  local spawnTable2 = self.argUsedForSpawn[2].table
  lu.assertEquals(spawnTable2.units[1].x, newPos.x)
  lu.assertEquals(spawnTable2.units[1].y, newPos.z)
  lu.assertEquals(spawnTable2.units[1].alt, self.groupTbl.units[1].alt)--no changes in alt
  --wp changes to new spawn point
  lu.assertEquals(spawnTable2.route.points[1].x, newPos.x)
  lu.assertEquals(spawnTable2.route.points[1].y, newPos.z)
end

---------------------------------------------------------------

test_HotContainer = utils.inheritFrom(test_AirContainer)

--group spawn at airbase, whcih no more avail, return empty arr
function test_HotContainer:test_activateNoAirbase() 
  local sqn = getCapSquadronMock()
  sqn:getAirbase().isAvail = function() return false end
  
  local testedObj = HotContainer:create(sqn, getCapObjectiveMock(), 2, 9999)
  
  lu.assertEquals(testedObj:activate(), {})
end

--requested aircraft amount exceed parking count, use takeOff on runway,
--verify addGroup() will recieve different tables, with different names
function test_HotContainer:test_activateNoSpots() 
  local sqn = getCapSquadronMock()
  sqn:getAirbase().howManyParkingAvail = function() return 0 end
  
  --return just waypoint
  sqn.getPrototypeTable = function() return self.groupTbl end
  
  self:mockAddGroup()
  
  local testedObj = HotContainer:create(sqn, getCapObjectiveMock(), 2, 9999)
  
  lu.assertEquals(testedObj:activate(), {self.groupVal, self.groupVal})
  
  lu.assertEquals(#self.argUsedForSpawn, 2)
  lu.assertEquals(self.argUsedForSpawn[1].country, sqn:getCountry())
  lu.assertEquals(self.argUsedForSpawn[1].enum, Group.Category.AIRPLANE)
  --verify table was modified
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1].type, "TakeOff")
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1].action, "From Runway")
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1].x, sqn:getHomeWP().x)
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1].y, sqn:getHomeWP().y)
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1].alt, sqn:getHomeWP().alt)
  
  --check names changes
  lu.assertTrue(self:checkNamesInTable(self.argUsedForSpawn))
end


--we have enough spots, activate using not modified table 
function test_HotContainer:test_activateHot()
  local sqn = getCapSquadronMock()
  sqn:getAirbase().howManyParkingAvail = function() return 99 end
  --return just waypoint
  sqn.getPrototypeTable = function() return self.groupTbl end
  
  self:mockAddGroup()
  
  local testedObj = HotContainer:create(sqn, getCapObjectiveMock(), 4, 9999)
  
  lu.assertEquals(testedObj:activate(), {self.groupVal, self.groupVal, self.groupVal, self.groupVal})
  
  lu.assertEquals(#self.argUsedForSpawn, 4)
  lu.assertEquals(self.argUsedForSpawn[1].country, sqn:getCountry())
  lu.assertEquals(self.argUsedForSpawn[1].enum, Group.Category.AIRPLANE)
  --verify start poiny unmodified
  lu.assertEquals(self.argUsedForSpawn[1].table.route.points[1], sqn:getPrototypeTable().route.points[1])

  --check names changes
  lu.assertTrue(self:checkNamesInTable(self.argUsedForSpawn))
end




---------------------------------------------------------------

test_ColdContainer = utils.inheritFrom(test_HotContainer)

--group spawn at airbase, whcih no more avail, return empty arr
function test_ColdContainer:test_activateNoAirbase() 
  local sqn = getCapSquadronMock()
  sqn:getAirbase().isAvail = function() return false end
  
  local testedObj = ColdContainer:create(sqn, getCapObjectiveMock(), 2, 9999)
  
  lu.assertEquals(testedObj:activate(), {})
end

--take planes from squadron(squadron return less plane then requested, also some of them dead/damaged)
function test_ColdContainer:test_activate() 
  local sqn = getCapSquadronMock()
  
  local planeArr = {}
  planeArr[1] = Group:create()
  planeArr[2] = Group:create()
  --mock controller for firstPlane
  local contrMock = getMockedController()
  planeArr[1].getController = function() return contrMock end
  
  --first plane slightly damaged
  planeArr[1].isExist = function() return true end
  planeArr[1].getUnit = function() return {
    getLife = function() return 5 end,
    getLife0 = function() return 10 end,
    isExist = function() return true end
  } end
  --second dead
  planeArr[2].isExist = function() return false end
  planeArr[2].getUnit = function() return {
      getLife = function() return 0 end,
      getLife0 = function() return 0 end
      } end
  sqn.getPlanes = function() return planeArr end
  
  local testedObj = ColdContainer:create(sqn, getCapObjectiveMock(), 4, 9999)
  lu.assertEquals(testedObj:activate(), {planeArr[1]})--only 1 plane started
  
  --verify plane was activated
  verify(contrMock:setCommand({ 
        id = 'Start', 
        params = { 
        } 
      }))
end


local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()