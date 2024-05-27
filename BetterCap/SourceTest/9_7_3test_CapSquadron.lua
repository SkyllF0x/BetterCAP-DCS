dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

--mock coalition.addGroup and mist.getGroupTable
AbstractSqnTest = utils.inheritFrom(AbstractMocksForSqn)

function AbstractSqnTest:isInstanceOf(instance, class) 
  return getmetatable(instance).__index == class
  end

function AbstractSqnTest:setup() 
  coalition.addGroup = function() return self.groupVal end
  mist.getGroupTable = function() return self.groupTable end
end

function AbstractSqnTest:teardown() 
  coalition.addGroup = AbstractSqnTest.originalAddGroup
  mist.getGroupTable = AbstractSqnTest.originalGetGroupTable
  
  timer.getAbsTime = AbstractSqnTest.originalTimer
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

test_CapSquadronReadyFSM = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronReadyFSM:test_run()
  local sqn = CapSquadronAir:create("1")
  local state = CapSquadronReady:create(sqn)
  
  --clear stack
  sqn.FSM_stack:clear()
  lu.assertEquals(sqn.FSM_stack.topItem, 0)
  
  --case1: sqn has 0 aircraft total, and ready, do nothing
  sqn.readyAircraft = 4
  sqn.readyCounter = 0
  sqn.aircraftCounter = 0
  state:run()
  lu.assertEquals(sqn.FSM_stack.topItem, 0)--still empty
  
  --case2: has 2 planes, and all 2 ready, but need 4, no op(not enough planes)
  sqn.readyAircraft = 4
  sqn.readyCounter = 2
  sqn.aircraftCounter = 2
  state:run()
  lu.assertEquals(sqn.FSM_stack.topItem, 0)--still empty
  
  --case3: 2 ready but need 4, has 3 in total go to waiting state
  sqn.readyAircraft = 4
  sqn.readyCounter = 2
  sqn.aircraftCounter = 3
  state:run()
  lu.assertEquals(sqn.FSM_stack:getStateEnumerator(), CapSquadronAir.FSM_Enum.CapSquadronWaiting)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

test_CapSquadronWaitingFSM = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronWaitingFSM:test_setup_time0()
  --preflight time 0, timer should work ok
  local sqn = CapSquadronAir:create("1")
  sqn.preflightTime = 0
  
  local state = CapSquadronWaiting:create(sqn)
  state:setup()
  lu.assertEquals(state.waitUntil, timer.getAbsTime() + 0)
  lu.assertEquals(sqn.preflightTimeLeft, 0)
end

function test_CapSquadronWaitingFSM:test_setup()
  --verify time in interval preflightTime * 0.75 to preflightTime * 1.25
  --verify sqn.preflightTimeLeft updated
  local sqn = CapSquadronAir:create("1")
  
  local state = CapSquadronWaiting:create(sqn)
  state:setup()
  lu.assertTrue(state.waitUntil >= timer.getAbsTime() + sqn.preflightTime * 0.75)
  lu.assertTrue(state.waitUntil <= timer.getAbsTime() + sqn.preflightTime * 1.25)
  lu.assertTrue(sqn.preflightTimeLeft > 0)
end

function test_CapSquadronWaitingFSM:test_run_time0() 
  local sqn = CapSquadronAir:create("1")
  sqn.preflightTime = 0
  local state = CapSquadronWaiting:create(sqn)

  --should exit on first call
  sqn.FSM_stack:push(state)
  lu.assertEquals(sqn.FSM_stack.topItem, 2)
  lu.assertEquals(sqn.FSM_stack:getStateEnumerator(), CapSquadronAir.FSM_Enum.CapSquadronWaiting)
  
  state:run()
  lu.assertEquals(sqn.FSM_stack.topItem, 1)
  lu.assertEquals(sqn.FSM_stack:getStateEnumerator(), CapSquadronAir.FSM_Enum.CapSquadronReady)
end

function test_CapSquadronWaitingFSM:test_run_Cycle() 
  local sqn = CapSquadronAir:create("1")
  sqn.readyCounter = 0
  sqn.readyAircraft = 4
  sqn.aircraftCounter = 3
  
  local state = CapSquadronWaiting:create(sqn)
  
  sqn.FSM_stack:push(state)
  lu.assertEquals(sqn.FSM_stack.topItem, 2)
  lu.assertEquals(sqn.FSM_stack:getStateEnumerator(), CapSquadronAir.FSM_Enum.CapSquadronWaiting)
  
  --not enough time passed
  state:run()
  state:run()
  state:run()
  lu.assertNotEquals(sqn.preflightTimeLeft, 0)
  lu.assertEquals(sqn.FSM_stack.topItem, 2)
  
  --time equals, exit, should fill ready aircraft but no more then aircraft in stock
  timer.getAbsTime = function() return state.waitUntil end
  state:run()
  lu.assertEquals(sqn.FSM_stack.topItem, 1)
  lu.assertEquals(sqn.FSM_stack:getStateEnumerator(), CapSquadronAir.FSM_Enum.CapSquadronReady)
  --verify sqn timer reset
  lu.assertEquals(sqn.preflightTimeLeft, 0)
  --verify added 3 planes(total amount)
  lu.assertEquals(sqn.readyCounter, 3)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
test_CapSquadronGeneral = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronGeneral:test_creationGereralFields() 
  --verify prototype table
  local tbl = mist.utils.deepCopy(self.groupTable)
  --add another unit
  tbl.units[2] = "unit mock"
  --replace first point coord
  local xCoord, yCoord, alt = 99, 999, 9999
  tbl.route.points[1].x = xCoord
  tbl.route.points[1].y = yCoord
  tbl.route.points[1].alt = alt
  
  mist.getGroupTable = function() return tbl end
  
  local inst = CapSquadronAir:create("1")
  lu.assertEquals(#inst.prototypeTable.units, 1)
  lu.assertEquals(inst.prototypeTable.units, {self.groupTable.units[1]})--use only first unit
  --flags removed
  lu.assertNil(inst.prototypeTable.lateActivation)
  lu.assertNil(inst.prototypeTable.start_time)
  lu.assertNil(inst.prototypeTable.uncontrolled)
  
  --verify coalition/country saved
  lu.assertNotNil(inst.country)
  lu.assertNotNil(inst.coalition)
  
  --verify settings auto populated
  lu.assertEquals(inst.aircraftCounter, 10)
  lu.assertEquals(inst.readyAircraft, 2)
  lu.assertEquals(inst.combatRadius, 300000)
  lu.assertEquals(inst.preflightTime, 600)
  
  --point is spawn point pos
  lu.assertEquals(inst.point, {x = xCoord, y = alt, z = yCoord})
  
  --verify name/id
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getID())
  
  --verify speed/alt
  lu.assertNumber(inst.alt)
  lu.assertNumber(inst.speed)
  lu.assertNotNil(inst.alt_type)
  
  --verify priority
  lu.assertNumber(inst.priority)
end

function test_CapSquadronGeneral:test_getters() 
  local inst = CapSquadronAir:create("1")
  
  lu.assertEquals(inst:getCoalition(), inst.coalition)
  lu.assertEquals(inst:getCountry(), inst.country)
  lu.assertEquals(inst:getPoint(), inst.point)
  lu.assertEquals(inst:getCounter(), inst.aircraftCounter)
  lu.assertEquals(inst:getReadyCount(), inst.readyCounter)
  lu.assertEquals(inst:getPrototypeTable(), inst.prototypeTable)
  lu.assertEquals(inst:getPriorityModifier(), inst.priority)
end

function test_CapSquadronGeneral:test_setSpeedAlt() 
  local inst = CapSquadronAir:create("1")
  
  inst:setSpeedAlt(100)
  lu.assertEquals(inst.speed, 100)
  --not changed
  lu.assertEquals(inst.alt, 7500)
  lu.assertEquals(inst.alt_type, "BARO")
  
  inst:setSpeedAlt(nil, 1000, "RADIO")
  lu.assertEquals(inst.speed, 100)
  lu.assertEquals(inst.alt, 1000)
  lu.assertEquals(inst.alt_type, "RADIO")
end

function test_CapSquadronGeneral:test_returnAircrafts()
  --verify home base is on same pos as start point and altitude 1000
  local inst = CapSquadronAir:create("1")
  
  lu.assertEquals(inst:getCounter(), 10)
  inst:returnAircrafts(2)
  lu.assertEquals(inst:getCounter(), 12)
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

test_CapSquadronAir = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronAir:test_homeBase()
  --verify home base is on same pos as start point and altitude 1000
  local inst = CapSquadronAir:create("1")
  
  lu.assertEquals(inst:getHomeWP().x, inst:getPoint().x)
  lu.assertEquals(inst:getHomeWP().y, inst:getPoint().z)
  lu.assertEquals(inst:getHomeWP().alt, 1000)
end

function test_CapSquadronAir:test_getGroup() 
  --spawn group with requested amount, spawn time will be in interval (preflightTime*0.75, preflightTime*1.25)
  --ready count NOT decremented, but should not higher if total amount
  --totalCounter decremented
  local inst = CapSquadronAir:create("1", 2, 5)--2 ready 5 total
  local obj = getCapObjectiveMock()
  
  local result = inst:getGroup(4, obj)
  lu.assertEquals(result:isActive(), false)--can't be instantly activated
  lu.assertTrue(result.activateTime > inst.preflightTime*0.75)
  lu.assertTrue(result.activateTime < inst.preflightTime*1.25)
  
  --check counters
  lu.assertEquals(inst:getCounter(), 1) --4 taken 1 left
  lu.assertEquals(inst:getReadyCount(), 1) --decremented, cause total is 1 plane
end

function test_CapSquadronAir:test_getReadyGroup_hasAircraft()
  --requested amount below readyCount, return container with already passed spawn time
  --decrement readyCount and aircraftCount by amount of requested planes
  local inst = CapSquadronAir:create("1", 4, 10)
  local obj = getCapObjectiveMock()

  local result = inst:getReadyGroup(1, obj)
  lu.assertEquals(result:isActive(), true)--can be instantly activated
  --decrement readyCount and aircraftCount by amount of requested planes
  lu.assertEquals(inst:getCounter(), 9)
  lu.assertEquals(inst:getReadyCount(), 3)
  
  --verify result is AirContainer instance
  lu.assertTrue(self:isInstanceOf(result, AirContainer))
end

function test_CapSquadronAir:test_getReadyGroup_notEnoughReadyAircraft()
  local inst = CapSquadronAir:create("1", 2, 10)
  local obj = getCapObjectiveMock()

  local result = inst:getReadyGroup(4, obj)
  
  lu.assertEquals(result:isActive(), false)--can be instantly activated
  --time to activation is current time + sqn.preflightTimeLeft
  lu.assertTrue(result.activateTime > inst.preflightTime*0.75)
  lu.assertTrue(result.activateTime < inst.preflightTime*1.25)
  
  --ready count not chanded, total count decrement to amounf of requested planes
  lu.assertEquals(inst:getCounter(), 6)
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
test_CapSquadronHot = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronHot:teardown() 
  --clean singletons
  AirbaseWrapper._instances = {}
  CarrierWrapper._instances = {}
  
  self:super().teardown(self)
  end

--create instance of class
function test_CapSquadronHot:getInst() 
    --should return 0 if airbase not avail
  local airbase = getAirbaseMock()
  airbase.getID = function() return 9991 end
  
  --link to airbase
  local tbl = mist.utils.deepCopy(self.groupTable)
  tbl.route.points[1].airdromeId = airbase:getID()
  mist.getGroupTable = function() return tbl end
  
  --add to singleton so it will finded and don't invoke search from world
  AirbaseWrapper._instances[tostring(airbase:getID())] = airbase

  return CapSquadronHot:create("1")
end

function test_CapSquadronHot:test_creationAirbase() 
  local airbase = getAirbaseMock()
  airbase.getID = function() return 9991 end
  
  --link to airbase
  local tbl = mist.utils.deepCopy(self.groupTable)
  tbl.route.points[1].airdromeId = airbase:getID()
  mist.getGroupTable = function() return tbl end
  
  --add to singleton so it will finded and don't invoke search from world
  AirbaseWrapper._instances[tostring(airbase:getID())] = airbase
  
  local inst = CapSquadronHot:create("1")
  lu.assertEquals(inst.homeBase, airbase)
  lu.assertEquals(inst:getAirbase(), airbase)
  
  --deactive when changed
  lu.assertEquals(inst.deactivateWhen, CapGroup.DeactivateWhen.OnShutdown)
  
  --home wp, should be first WP, but type changed to Landing
  lu.assertEquals(inst:getHomeWP().x, tbl.route.points[1].x)
  lu.assertEquals(inst:getHomeWP().y, tbl.route.points[1].y)
  lu.assertEquals(inst:getHomeWP().type, "Land")
  lu.assertEquals(inst:getHomeWP().action, "Landing")

end

function test_CapSquadronHot:test_creationCarrier() 
  local airbase = getAirbaseMock()
  airbase.getID = function() return 9991 end
  
  --link to airbase
  local tbl = mist.utils.deepCopy(self.groupTable)
  tbl.route.points[1].linkUnit = airbase:getID()
  mist.getGroupTable = function() return tbl end
  
  --add to singleton so it will finded and don't invoke search from world
  CarrierWrapper._instances[tostring(airbase:getID())] = airbase
  
  local inst = CapSquadronHot:create("1")
  lu.assertEquals(inst.homeBase, airbase)
  lu.assertEquals(inst:getAirbase(), airbase)
  
  --deactive when changed
  lu.assertEquals(inst.deactivateWhen, CapGroup.DeactivateWhen.OnLand)
  
  --home wp, should be first WP, but type changed to Landing
  lu.assertEquals(inst:getHomeWP().x, tbl.route.points[1].x)
  lu.assertEquals(inst:getHomeWP().y, tbl.route.points[1].y)
  lu.assertEquals(inst:getHomeWP().type, "Land")
  lu.assertEquals(inst:getHomeWP().action, "Landing")
end

function test_CapSquadronHot:test_Counters() 
  local inst = self:getInst() 
  
  lu.assertEquals(inst:getCounter(), 10)
  lu.assertEquals(inst:getReadyCount(), 2)
  
  --airbase not avail
  inst:getAirbase().isAvail = function() return false end
  lu.assertEquals(inst:getCounter(), 0)
  lu.assertEquals(inst:getReadyCount(), 0)
end

function test_CapSquadronHot:test_spawnGroup()  
  local inst = self:getInst()
  inst.readyCounter = 10
  inst.aircraftCounter = 10
  
  --verify hotContainer returned
  local obj = getCapObjectiveMock()
  local result = inst:spawnGroup(1, obj, 0)
  lu.assertTrue(self:isInstanceOf(result, HotContainer))
  
    --verify counters decreased
  lu.assertEquals(inst:getCounter(), 9)
  lu.assertEquals(inst:getReadyCount(), 9)--can't be higher than total
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

test_CapSquadronCold = utils.inheritFrom(AbstractSqnTest)

function test_CapSquadronCold:getInst() 
  --should return 0 if airbase not avail
  local airbase = getAirbaseMock()
  airbase.getID = function() return 9991 end
  airbase.howManyParkingAvail = function() return 100 end
  
  --link to airbase
  local tbl = mist.utils.deepCopy(self.groupTable)
  tbl.route.points[1].airdromeId = airbase:getID()
  mist.getGroupTable = function() return tbl end
  
  --add to singleton so it will finded and don't invoke search from world
  AirbaseWrapper._instances[tostring(airbase:getID())] = airbase

  return CapSquadronCold:create("1")
end

function test_CapSquadronCold:test_creation_Cold() 
  local inst = self:getInst()
  
  --verify uncontrolled flag set
  lu.assertEquals(inst.prototypeTable.uncontrolled, true)
  --verify airplanes populated
  lu.assertEquals(#inst.airplanes, inst:getCounter())
end

function test_CapSquadronCold:test_getPlanes()
  --return array with planes from self.airplanes until satisfy req or airplanes ends
  --remove plane from array
  local inst = self:getInst()
  inst.airplanes = {self.unit, self.unit, self.unit} --has 3 aircraft

  lu.assertEquals(inst:getPlanes(1), {self.groupVal})
  lu.assertEquals(#inst.airplanes, 2)--plane was removed
  
  --try request more than sqn have
  lu.assertEquals(inst:getPlanes(4), {self.groupVal, self.groupVal})
  lu.assertEquals(#inst.airplanes, 0)--planes was removed
end

function test_CapSquadronCold:test_addNewPlanes() 
  local inst = self:getInst()
  inst.airplanes = {} --has 0 spawned

  inst:getAirbase().howManyParkingAvail = function() return 1000 end
  --should just spawn until current amount of planes
  inst:addNewPlanes()
  lu.assertEquals(#inst.airplanes, 10)
  
  inst.airplanes = {} --has 0 spawned
  --spawn until all parks taken
  inst:getAirbase().howManyParkingAvail = function() return 5 end
  inst:addNewPlanes()
  lu.assertEquals(#inst.airplanes, 5)
end

function test_CapSquadronCold:test_addNewPlanes_useRequested() 
  local inst = self:getInst()
  inst.airplanes = {} --has 0 spawned
  --add dead, but previously request 2 planes
  inst.aircraftCounter = 0 
  inst.requestedCount = 2

  inst:getAirbase().howManyParkingAvail = function() return 1000 end
  --should just spawn until current amount of planes
  inst:addNewPlanes()
  lu.assertEquals(#inst.airplanes, 2)
end

function test_CapSquadronCold:test_addNewPlanes_noAcftToSpawn() 
  local inst = self:getInst()
  inst.airplanes = {} --has 0 spawned
  --add dea
  inst.aircraftCounter = 0 
  inst.requestedCount = 0

  inst:getAirbase().howManyParkingAvail = function() return 1000 end
  --should just spawn until current amount of planes
  inst:addNewPlanes()
  lu.assertEquals(#inst.airplanes, 0)
end

function test_CapSquadronCold:test_spawnGroupNoAircrafts() 
  local inst = self:getInst()
  inst.aircraftCounter = 5
  inst.readyCounter = 2
  inst.airplanes = {} --has 0 spawned
  
  inst:getAirbase().howManyParkingAvail = function() return 1 end
  
  --request exceed amount of spawned aircraft
  local r = inst:spawnGroup(4, getCapObjectiveMock(), 0)
  lu.assertTrue(self:isInstanceOf(r, HotContainer))
  --also verify addNewPlanes() was called
  lu.assertEquals(#inst.airplanes, 1)
  
  --total counter decreased to 1
  lu.assertEquals(inst.aircraftCounter, 1)
  --ready counter decremented cause only 1 plane avail
  lu.assertEquals(inst.readyCounter, 1)
end

function test_CapSquadronCold:test_spawnGroupUseAircrafts() 
  local inst = self:getInst()
  inst.aircraftCounter = 5
  inst.readyCounter = 2
  
  --can satisfy request return coldContainer
  local r = inst:spawnGroup(4, getCapObjectiveMock(), 0)
  lu.assertTrue(self:isInstanceOf(r, ColdContainer))
  
  --counter decreased
  lu.assertEquals(inst.aircraftCounter, 1)
  --ready counter decremented cause only 1 plane avail
  lu.assertEquals(inst.readyCounter, 1)
  --requested added
  lu.assertEquals(inst.requestedCount, 4)
  
  --container activates and call getPlanes(4)
  inst:getPlanes(4)
  --requested cleared
  lu.assertEquals(inst.requestedCount, 0)
end

function test_CapSquadronCold:test_update_deletePlanes() 
  local inst = self:getInst()
  inst.aircraftCounter = 4
  inst.readyCounter = 4
  inst.airplanes = {}
  inst:addNewPlanes()
  
  inst.airplanes[1] = mist.utils.deepCopy(self.groupVal:getUnit(1))
  inst.airplanes[1].isExist = function() return false end
  inst.airplanes[2] = mist.utils.deepCopy(self.groupVal:getUnit(1))
  inst.airplanes[2].isExist = function() return false end
  
  inst:update()
  --planes deleted, counter decreased, ready counter less or equals total amount
  lu.assertEquals(inst.aircraftCounter, 2)
  lu.assertEquals(inst.readyCounter, 2)
  
  --request 2 planes
  inst:spawnGroup(2, getCapObjectiveMock(), 0)
  lu.assertEquals(inst.aircraftCounter, 0)
  lu.assertEquals(inst.readyCounter, 0)
  lu.assertEquals(inst.requestedCount, 2)
  
  --aircraft 1 dead, requested counter down to 1, nothing spawned
  inst.airplanes[1] = mist.utils.deepCopy(self.groupVal:getUnit(1))
  inst.airplanes[1].isExist = function() return false end
  
  inst:update()
  lu.assertEquals(inst.aircraftCounter, 0)
  lu.assertEquals(inst.readyCounter, 0)
  lu.assertEquals(inst.requestedCount, 1)
  
  --aircraft dead, counters to 0
  inst.airplanes[1] = mist.utils.deepCopy(self.groupVal:getUnit(1))
  inst.airplanes[1].isExist = function() return false end
  
   inst:update()
  lu.assertEquals(inst.aircraftCounter, 0)
  lu.assertEquals(inst.readyCounter, 0)
  lu.assertEquals(inst.requestedCount, 0)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

test_CapSquadronFactory = utils.inheritFrom(AbstractSqnTest)

--verify return proper types for different groups?


local runner = lu.LuaUnit.new()
runner:runSuite()