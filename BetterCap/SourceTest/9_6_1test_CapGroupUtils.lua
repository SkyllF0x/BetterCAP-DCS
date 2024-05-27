dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_GroupRoute = {}

function test_GroupRoute:test_distanceToLeg_notEnoughWP() 
  local route = GroupRoute:create()
  
  --should work when route empty or only 1 wp
  route.waypoints = {}
  lu.assertEquals(route:distanceToLeg({x = 0, y = 0}), 0)
  
  route.waypoints = {{x = 0, y = 0}}
  lu.assertEquals(route:distanceToLeg({x = 0, y = 0}), 0)
  
  --2 wps first is current
  route.waypoints = {{x = 0, y = 0}, {x = 0, y = 10}}
  route.currentWpNumber = 1
  lu.assertEquals(route:distanceToLeg({x = 5, y = 0}), 5)
  --second wp is active should use first as second point
  route.currentWpNumber = 2
  lu.assertEquals(route:distanceToLeg({x = 5, y = 0}), 5)
end

--------------------------------------------------------------

test_TimeCondition = {}

function test_TimeCondition:test_creation() 
  local inst = TimeCondition:create(900)
  
  lu.assertNotNil(inst)
  lu.assertNotNil(inst.time)
end

function test_TimeCondition:test_getResult() 
  local inst = TimeCondition:create(timer.getAbsTime() + 900)
  
  lu.assertFalse(inst:getResult())
  
  inst.time = timer.getAbsTime() - 1 
  lu.assertTrue(inst:getResult())
  end

--------------------------------------------------------------
test_DurationCond = {}

function test_DurationCond:test_creation() 
  local inst = DurationCondition:create(900)
  
  lu.assertNotNil(inst)
  lu.assertEquals(inst.duration, 900)
  lu.assertNotNil(inst.startTime)
end

function test_DurationCond:test_getResult() 
  local inst = DurationCondition:create(900)
  inst.startTime = -999
  
  inst:start()
  lu.assertEquals(inst.startTime, timer.getAbsTime())
  
  lu.assertFalse(inst:getResult())
  
  inst.startTime = timer.getAbsTime() - 901
  lu.assertTrue(inst:getResult())
end

--------------------------------------------------------------
test_flagCond = {}

local originalTrig = mist.utils.deepCopy(trigger.misc)

function test_flagCond:teardown() 
  
  for name, val in pairs(originalTrig) do 
    trigger.misc[name] = val
    end
  end

function test_flagCond:test_creation() 
  local inst = FlagCondition:create(99, true)
  lu.assertNotNil(inst)
  lu.assertNotNil(inst.flag)
  lu.assertNotNil(inst.val)
end

function test_flagCond:test_getResult_flagIsFalse() 
  local inst = FlagCondition:create(99, false)
  local m = mockagne.getMock()
  
  trigger.misc.getUserFlag = m.getUserFlag
  when(m.getUserFlag(99)).thenAnswer(0)
  
  lu.assertEquals(inst:getResult(), true)
end


function test_flagCond:test_getResult_flagIsNum() 
  local inst = FlagCondition:create(99, true)
  local m = mockagne.getMock()
  
  trigger.misc.getUserFlag = m.getUserFlag
  when(m.getUserFlag(99)).thenAnswer(99)
  
  lu.assertEquals(inst:getResult(), true)
end

--------------------------------------------------------------
test_LuaCondition = {}

function test_LuaCondition:test_creationFail() 
  local luaCode = "1[1]"
  
  local inst = LuaCondition:create(luaCode)
  lu.assertNil(inst)
end

function test_LuaCondition:test_creation() 
  local luaCode = "return true"
  
  local inst = LuaCondition:create(luaCode)
  lu.assertNotNil(inst)
  lu.assertNotNil(inst.func())
end

function test_LuaCondition:test_getResult() 
  local inst, inst2 = LuaCondition:create("return true"), LuaCondition:create("return false")
  
  lu.assertEquals(inst:getResult(), true)
  
   lu.assertEquals(inst2:getResult(), false)
  end


--------------------------------------------------------------
test_RandomCondition = {}

function test_RandomCondition:test_creation() 
  local inst = RandomCondition:create(0)
  
  lu.assertNotNil(inst)
  lu.assertFalse(inst.result)
  end

function test_RandomCondition:test_getResult() 
  local inst = RandomCondition:create(100)
  
  lu.assertTrue(inst.result)
  end

--------------------------------------------------------------

test_OrbitTask = {}

function test_OrbitTask:test_creation_onlyPoint() 
  local inst1 = OrbitTask:create({x = 0, y = 0})--only neccesarry data
  
  lu.assertNotNil(inst1)
  lu.assertEquals(inst1.task.params.pattern, "Circle")
  lu.assertNumber(inst1.task.params.altitude)
  lu.assertEquals(inst1.task.params.point, {x = 0, y = 0})
  lu.assertEquals(#inst1.preConditions, 0)
  lu.assertEquals(#inst1.postConditions, 0)
end

function test_OrbitTask:test_creation_allArgs()
  local inst = OrbitTask:create({x = 0, y = 0, z = 99}, 999, 8000, {RandomCondition:create(90)}, {DurationCondition:create(60)})
  
  lu.assertEquals(inst.task.params.pattern, "Circle")
  lu.assertEquals(inst.task.params.altitude, 8000)
  lu.assertEquals(inst.task.params.speed, 999)
  lu.assertEquals(inst.task.params.point, {x = 0, y = 99})--Vec3 to Vec2 conversion
  lu.assertEquals(#inst.preConditions, 1)
  lu.assertEquals(#inst.postConditions, 1)
end

function test_OrbitTask:test_getPoint() 
  local inst = OrbitTask:create({x = 0, y = 0, z = 99})
  lu.assertEquals(inst:getPoint(), {x = 0, y = 0, z = 99})
end

function test_OrbitTask:test_getTask() 
  local inst = OrbitTask:create({x = 0, y = 0, z = 99})
  lu.assertEquals(inst:getTask(), inst.task)
end

function test_OrbitTask:test_checkPreCondition_noCond() 
  --no condition set
  local inst = OrbitTask:create({x = 0, y = 0, z = 99})
  lu.assertTrue(inst:checkPreCondition())
end

function test_OrbitTask:test_checkPreCondition_Cond() 
  --1 condition true, second false
  local inst = OrbitTask:create({x = 0, y = 0, z = 99}, 999, 8000, {RandomCondition:create(90), DurationCondition:create(60)})
  local m = mockagne.getMock()
  inst.preConditions[1].getResult = m.getResult
  inst.preConditions[2].getResult = m.getResult
  
  when(m.getResult(inst.preConditions[1])).thenAnswer(false)
  when(m.getResult(inst.preConditions[2])).thenAnswer(true)
  
  lu.assertTrue(inst:checkPreCondition())
end

function test_OrbitTask:test_checkExitCondition_noCond() 
  --no condition set
  local inst = OrbitTask:create({x = 0, y = 0, z = 99})
  lu.assertFalse(inst:checkExitCondition())
end

function test_OrbitTask:test_checkPreCondition_Cond() 
  --1 condition true, second false
  local inst = OrbitTask:create({x = 0, y = 0, z = 99}, 999, 8000, {}, {RandomCondition:create(90), DurationCondition:create(60)})
  local m = mockagne.getMock()
  inst.postConditions[1].getResult = m.getResult
  inst.postConditions[2].getResult = m.getResult
  
  when(m.getResult(inst.postConditions[1])).thenAnswer(false)
  when(m.getResult(inst.postConditions[2])).thenAnswer(true)
  
  lu.assertTrue(inst:checkExitCondition())
end

--------------------------------------------------------------

test_RaceTrackTask = {}

function test_RaceTrackTask:test_creation_onlyPoint() 
  local inst1 = RaceTrackTask:create({x = 0, y = 0}, {x = 99, y = 0, z = 99})--only neccesarry data
  
  lu.assertNotNil(inst1)
  lu.assertEquals(inst1.task.params.pattern, "Race-Track")
  lu.assertNumber(inst1.task.params.altitude)
  lu.assertEquals(inst1.task.params.point, {x = 0, y = 0})
  lu.assertEquals(inst1.task.params.point2, {x = 99, y = 99})
  lu.assertEquals(#inst1.preConditions, 0)
  lu.assertEquals(#inst1.postConditions, 0)
end

function test_OrbitTask:test_creation_allArgs()
  local inst = RaceTrackTask:create({x = 0, y = 0, z = 99}, {x = 0, y = 88}, 999, 8000, {RandomCondition:create(90)}, {DurationCondition:create(60)})
  
  lu.assertEquals(inst.task.params.pattern, "Race-Track")
  lu.assertEquals(inst.task.params.altitude, 8000)
  lu.assertEquals(inst.task.params.speed, 999)
  lu.assertEquals(inst.task.params.point, {x = 0, y = 99})--Vec3 to Vec2 conversion
  lu.assertEquals(inst.task.params.point2, {x = 0, y = 88})
  lu.assertEquals(#inst.preConditions, 1)
  lu.assertEquals(#inst.postConditions, 1)
end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()