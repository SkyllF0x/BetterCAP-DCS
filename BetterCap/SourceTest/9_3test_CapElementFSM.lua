dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

do
  test_FSM_Element_Start = {}

  function test_FSM_Element_Start:test_creation_allInAir() 
    local elem = getElement()
    
    for _, plane in pairs(elem.planes) do 
      plane:getObject().inAir = function() return true end
    end
    
    local fsm = FSM_Element_Start:create(elem)
    
    lu.assertNotNil(fsm)
    lu.assertEquals(fsm.name, "FSM_Element_Start")
    lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_Start)
    lu.assertIs(fsm.object, elem)
    lu.assertEquals(tostring(fsm.object), tostring(elem))
    
    lu.assertEquals(fsm.isInAir, true)
  end
  
  function test_FSM_Element_Start:test_creation_onGround() 
    local elem = getElement()
    elem.getPoint = function() return {x = 99, y = 0, z = 10} end
    
    for _, plane in pairs(elem.planes) do 
      plane:getObject().inAir = function() return false end
    end
    
    local fsm = FSM_Element_Start:create(elem)
    
    lu.assertNotNil(fsm)
    lu.assertEquals(fsm.name, "FSM_Element_Start")
    lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_Start)
    lu.assertIs(fsm.object, elem)
    lu.assertEquals(tostring(fsm.object), tostring(elem))
    
    lu.assertEquals(fsm.isInAir, false)
    
    --verify orbit task
    lu.assertEquals(fsm.task.params.pattern, "Circle")
    lu.assertEquals(fsm.task.params.point, mist.utils.makeVec2(elem:getPoint()))
  end
  
  function test_FSM_Element_Start:test_run_pushTaskOnlyOnce() 
    --verify task will be set only once, after plane in air
    local m = mockagne.getMock()
    
    local plane1 = getCapPlane()
    local plane2 = getCapPlane()
    
    --will use clearFSM() as marker
    plane1.clearFSM = m.clearFSM
    plane2.clearFSM = m.clearFSM
    
    plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.AbstractPlane_FSM end
    plane2.getCurrentFSM = plane1.getCurrentFSM
    
    local elem = CapElement:create({plane1, plane2})
    
    local fsm = FSM_Element_Start:create(elem)
    fsm.isInAir = false
    
    --train after creation cause called in constructor
    plane1:getObject().inAir = m.inAir
    when(plane1:getObject():inAir()).thenAnswer(false)
    plane2:getObject().inAir = m.inAir
    when(plane2:getObject():inAir()).thenAnswer(false)
    
    --both on ground, nothing happen, just call to inAir
    fsm:run({})
    verify(plane1:getObject():inAir())
    verify_no_call(plane1:clearFSM())
    verify(plane2:getObject():inAir())
    verify_no_call(plane2:clearFSM())
    
    --second in air, set task
    plane2:getObject().inAir = function() return true end
    fsm:run({})
    verify(plane2:clearFSM())
    
    --create newMock
    local m2 = mockagne.getMock()
    plane2.clearFSM = m.clearFSM
    
    --in air and task set, nothing happen
    
    fsm:run({})
    plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_FlyOrbit end
    verify(plane2:getObject():inAir())
    verify(plane2:clearFSM())
  end

  function test_FSM_Element_Start:test_run_taskSet_flagUpdate() 
    local plane1 = getCapPlane()
    plane1:getObject().inAir = function() return true end
    plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.AbstractPlane_FSM end
    
    local elem = CapElement:create({plane1})
    local fsm = FSM_Element_Start:create(elem)
    fsm.isInAir = false
    
    --aircraft in air, set task
    fsm:run()
    plane1.getCurrentFSM = CapPlane.getCurrentFSM --remove mock
    lu.assertEquals(fsm.isInAir, true)
    lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyOrbit)
    lu.assertEquals(plane1.FSM_stack:getCurrentState().task, fsm.task)
  end 
end

test_FSM_Element_FlyFormation = {}
do 
function test_FSM_Element_FlyFormation:test_creation() 
  local elem = getElement()
  local point = mist.fixedWing.buildWP({x = 0, y = 0})
  
  local fsm = FSM_Element_FlyFormation:create(elem, FSM_FlyToPoint, point)
  
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.name, "FSM_Element_FlyFormation")
  lu.assertEquals(fsm.state, FSM_FlyToPoint)
  lu.assertEquals(fsm.stateArg[1], point)
  lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_FlyFormation)
  --lu.assertEquals(fsm.enumerator, CapElement.FSM_States.FSM_Element_FlyToPoint)
  lu.assertIs(fsm.object, elem)
  lu.assertEquals(tostring(fsm.object), tostring(elem))
  end

function test_FSM_Element_FlyFormation:test_setup() 
  --lead FSM is created passed FSM with passed args
  --wingmans in FSM_Formation to lead
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local elem = CapElement:create({plane1, plane2})
  
  local point = mist.fixedWing.buildWP({x = 0, y = 0})
  
  local fsm = FSM_Element_FlyFormation:create(elem, FSM_FlyToPoint, point)
  
  local GROUP_ID = 991
  plane1.getGroupID = function() return GROUP_ID end
  
  fsm:setup()
  --verify states and args
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1], point)
  
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Formation)
  lu.assertEquals(plane2.FSM_stack:getCurrentState().task.params.groupId, GROUP_ID)
  end

function test_FSM_Element_FlyFormation:test_run() 
  --args waypoints and newTarget passed to lead
  --no setup() called
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local elem = CapElement:create({plane1, plane2})
  local m = mockagne.getMock()
  
  local fsm = FSM_Element_FlyFormation:create(elem, FSM_FlyToPoint, point)
  fsm.setup = m.setup
  
  plane1.setFSM_Arg = m.setFSM_Arg
  
  fsm:run({newTarget = "0", waypoint = "1"})
  verify(plane1:setFSM_Arg("newTarget", "0"))
  verify(plane1:setFSM_Arg("waypoint", "1"))
  
  verify_no_call(fsm:setup())
end

function test_FSM_Element_FlyFormation:test_run_planeDead() 
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local elem = CapElement:create({plane1, plane2})
  local m = mockagne.getMock()
  
  local fsm = FSM_Element_FlyFormation:create(elem, FSM_FlyToPoint, point)
  fsm.setup = m.setup
  
  fsm.numberPlanes = 9
  fsm:run({})
  
  lu.assertEquals(fsm.numberPlanes, 2)
  verify(fsm:setup())
  end



end
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
do
test_FSM_Element_Intercept = {}
test_FSM_Element_Intercept.orginalGetIntercept = utils.getInterceptPoint

function  test_FSM_Element_Intercept:teardown() 
  utils.getInterceptPoint = test_FSM_Element_Intercept.orginalGetIntercept
  end

function test_FSM_Element_Intercept:test_creation() 
  --verify name, enum, object, tactic
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Intercept:create(element, tactic)
  
  lu.assertEquals(fsm.object, element)
  lu.assertEquals(fsm.tactic, tactic)
  lu.assertEquals(fsm.name, "FSM_Element_Intercept")
  lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_Intercept)
  
  lu.assertEquals(tostring(fsm.object), tostring(element))
  lu.assertEquals(tostring(fsm.tactic), tostring(tactic))
end

function test_FSM_Element_Intercept:test_getInterceptPoint() 
  --first set, target speed 0, should use speed 300
  --verify all fields exist in result
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  local m = mockagne:getMock()
  m.alt = 10000
  local fsm = FSM_Element_Intercept:create(element, m)
  
  group.target:getLead().getVelocity = function() return {x = 1, y = 0, z = 0} end
  local result = fsm:getInterceptPoint()
  
  lu.assertNotNil(result.x)
  lu.assertNotNil(result.y)
  lu.assertEquals(result.alt, 10000)
  lu.assertEquals(result.speed, 300)
end

function test_FSM_Element_Intercept:test_run_flyToPoint() 
  --interceptCheck return false, no return
  --3 planes
  --1 lead recieve point from getInterceptPoint()
  --2 - to far, recieve point to intercept lead
  --3 -ok , recieve same point as lead
  local interceptLeadPoint = {x = 1, y = 1, z = 1}
  local interceptTargetPoint = {x = 9, y = 9, z = 9}
  
  local m = mockagne.getMock()
  local plane1 = getCapPlane()
  plane1.getPoint = function() return {x = 0, y = 0, z = 0 } end
  plane1.getVelocity = function() return {x = 100, y = 0, z = 0 } end
  plane1.setFSM_Arg = m.setFSM_Arg
  local plane2 = getCapPlane()
  plane2.getPoint = function() return {x = 20000, y = 0, z = 0 } end
  plane2.setFSM_Arg = m.setFSM_Arg
  local plane3 = getCapPlane()
  plane3.getPoint = plane1.getPoint
  plane3.setFSM_Arg = m.setFSM_Arg
  
  local group = CapGroup:create({plane1, plane2, plane3})
  group.target = getTargetGroup()
  local element = group.elements[1]
  local fsm = FSM_Element_Intercept:create(element, m)
  when(m:checkIntercept()).thenAnswer(false)
  
  fsm.getInterceptPoint = m.getInterceptPoint
  when(m.getInterceptPoint(fsm)).thenAnswer(interceptTargetPoint)
  
  utils.getInterceptPoint = m.getPoint
  when(m.getPoint(plane1, plane2, 100)).thenAnswer(interceptLeadPoint)

  fsm:run({})
  verify(plane1:setFSM_Arg("waypoint", interceptTargetPoint))
  --use alt of lead plane
  verify(plane2:setFSM_Arg("waypoint", mist.fixedWing.buildWP(interceptLeadPoint, "turningpoint", 500, plane1:getPoint().y, "BARO")))
  verify(plane3:setFSM_Arg("waypoint", interceptTargetPoint))
  end
end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
do
test_FSM_Element_Attack = {}  

function test_FSM_Element_Attack:test_tryAddTarget_notTargeted() 
  --get plane and list of sorted target, if target not targeted set in to plane, and set state to FSM_Attack
  --target should be setTargeted(true) and plane.target = target
  --we have target11 with .targeted == true, it has higher priority then target2, but not inside range Mar + 10000
  local m = mockagne.getMock()
  local element = getElement()
  element.myGroup = m
  when(m:getBestMissile()).thenAnswer({MaxRange = 50000, MAR = 25000})
  when(m:getHighestThreat()).thenAnswer({MaxRange = 50000, MAR = 25000})
  
  element.myGroup.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = 1,
    [AbstractTarget.TypeModifier.ATTACKER] = 0.5,
    [AbstractTarget.TypeModifier.HELI] = 0.1
  }
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getTargetGroup = m.getTargetGroup
  when(fsm:getTargetGroup()).thenAnswer(m)
  
  local target1 = getTarget()
  target1.getPoint = function() return {x = 50000, y = 0, z = 0} end
  target1.getTargeted = function() return true end
  local target2 = getTarget()
  target2.getPoint = target1.getPoint
  
  local sortedTargets = {
    {tgt = target1, priority = 10},
    {tgt = target2, priority = 5}
  }
  
  local plane = element.planes[1]
  fsm:tryAddTarget(plane, sortedTargets)
  
  lu.assertEquals(plane.target, target2)
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Attack)
  lu.assertEquals(plane.FSM_stack:getCurrentState().task.params.unitId, target2:getID())
  lu.assertEquals(target2:getTargeted(), true)
  end

function test_FSM_Element_Attack:test_tryAddTarget_selectTargeted() 
  --target1 is targeted but priority much higher that returned from 
  --CalculateTargetPriority() for analogous target
  local m = mockagne.getMock()
  local element = getElement()
  
  element.myGroup = m
  when(m:getBestMissile()).thenAnswer({MaxRange = 50000, MAR = 25000})
  when(m:getHighestThreat()).thenAnswer({MaxRange = 50000, MAR = 25000})
  
  element.myGroup.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = 1,
    [AbstractTarget.TypeModifier.ATTACKER] = 0.5,
    [AbstractTarget.TypeModifier.HELI] = 0.1
  }
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getTargetGroup = m.getTargetGroup
  when(fsm:getTargetGroup()).thenAnswer(m)
  
  local target1 = getTarget()
  target1.getTargeted = function() return true end
  local target2 = getTarget()
  
  local sortedTargets = {
    {tgt = target1, priority = 21},
    {tgt = target2, priority = 20}
  }
  
  fsm.calculatePriority = m.calculatePriority
  when(fsm:calculatePriority(target1, 300, 8000, 1, element.myGroup:getBestMissile().MaxRange)).thenAnswer(10)
  
  local plane = element.planes[1]
  fsm:tryAddTarget(plane, sortedTargets)
  
  lu.assertEquals(plane.target, target1)
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Attack)
  lu.assertEquals(plane.FSM_stack:getCurrentState().task.params.unitId, target1:getID())
  end

function test_FSM_Element_Attack:test_tryAddTarget_noTarget() 
  --target1 is targeted and priority ration not bih enough
  --nothing set
  local m = mockagne.getMock()
  local element = getElement()
  

  element.myGroup = m
  when(m:getBestMissile()).thenAnswer({MaxRange = 50000, MAR = 25000})
  when(m:getHighestThreat()).thenAnswer({MaxRange = 50000, MAR = 25000})
  
  element.myGroup.priorityForTypes = {
    [AbstractTarget.TypeModifier.FIGHTER] = 1,
    [AbstractTarget.TypeModifier.ATTACKER] = 0.5,
    [AbstractTarget.TypeModifier.HELI] = 0.1
  }
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getTargetGroup = m.getTargetGroup
  when(fsm:getTargetGroup()).thenAnswer(m)
  
  local target1 = getTarget()
  target1.getTargeted = function() return true end
  
  local sortedTargets = {
    {tgt = target1, priority = 21},
  }
  
  fsm.calculatePriority = m.calculatePriority
  when(fsm:calculatePriority(target1, 300, 8000, 1, element.myGroup:getBestMissile().MaxRange)).thenAnswer(22)
  
  local plane = element.planes[1]
  --mock plane methods to verify nothing was called
  plane.setTarget = m.setTarget
  plane.setFSM = m.setFSM
  
  fsm:tryAddTarget(plane, sortedTargets)
  
  lu.assertEquals(plane.target, nil)
  verify_no_call(plane:setTarget(any()))
  verify_no_call(plane:setFSM(any()))
  end

function test_FSM_Element_Attack:test_tryReplaceTarget_nothing() 
  --plane has target, but ratio to low
  --nothing set
  local m = mockagne.getMock()
  local element = getElement()
  local plane = element.planes[1] 
  local target1 = getTarget()
  plane:setTarget(target1)
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getTargetGroup = m.getTargetGroup
  when(fsm:getTargetGroup()).thenAnswer(m)
  
  fsm.getDataForPriorityCalc = function(target) return target, 0, 0, 0, 0 end
  fsm.calculatePriority = m.calculatePriority
  when(m.calculatePriority(fsm, fsm:getDataForPriorityCalc(plane.target))).thenAnswer(25)
  
  local target2 = getTarget()
  local sortedTargets = {
    {tgt = target1, priority = 25},
    {tgt = target2, priority = 25},
  }
  
  plane.setFSM_Arg = m.setFSM_Arg
  
  fsm:tryReplaceTarget(plane, sortedTargets)
  verify_no_call(plane:setFSM_Arg("newTarget", any()))
  lu.assertEquals(plane.target, target1)
end


function test_FSM_Element_Attack:test_tryReplaceTarget_replace() 
  --plane has target, ratio ok
  --set new target to plane
  local m = mockagne.getMock()
  local element = getElement()
  local plane = element.planes[1] 
  local target1 = getTarget()
  plane:setTarget(target1)
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getTargetGroup = m.getTargetGroup
  when(fsm:getTargetGroup()).thenAnswer(m)
  
  fsm.getDataForPriorityCalc = function(target) return target, 0, 0, 0, 0 end
  fsm.calculatePriority = m.calculatePriority
  when(m.calculatePriority(fsm, fsm:getDataForPriorityCalc(plane.target))).thenAnswer(25)
  
  local target2 = getTarget()
  local sortedTargets = {
    {tgt = target1, priority = 25},
    {tgt = target2, priority = 50},
  }
  
  plane.setFSM_Arg = m.setFSM_Arg
  
  fsm:tryReplaceTarget(plane, sortedTargets)
  verify(plane:setFSM_Arg("newTarget", target2:getID()))
  lu.assertEquals(plane.target, target2)
  end


function test_FSM_Element_Attack:test_attackCycle() 
  --element with 2 planes
  local m = mockagne.getMock()
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local element = group.elements[1]
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getInterceptPoint = function() return mist.fixedWing.buildWP({x = 0, y = 0}) end
  
  plane1:clearFSM()
  plane2:clearFSM()
  plane1:setFSM_NoCall(FSM_FlyToPoint:create(plane1, mist.fixedWing.buildWP({x = 0, y = 0})))
  plane2:setFSM_NoCall(FSM_FlyToPoint:create(plane1, mist.fixedWing.buildWP({x = 0, y = 0})))
  
  local target1 = getTarget()
  local target2 = getTarget()
  local targetGroup = TargetGroup:create({target1, target2})
  
  --step1: target group with 2 targets, one is targeted, lead plane defending, nothing set, second get a target2 
  plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  group.target = targetGroup
  target1:setTargeted(true)
  
  fsm.prioritizeTargets = function()
    return {{tgt = target1, priority = 10}, {tgt = target2, priority = 15}}
  end
  fsm.getDataForPriorityCalc = function(target) return target, 0, 0, 0, 0 end
  fsm.calculatePriority = m.calculatePriority
  when(fsm:calculatePriority(target1, 300, 8000, 1, group:getBestMissile().MaxRange)).thenAnswer(10)
  
  fsm:run({})
  
  lu.assertEquals(plane1.target, nil)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Defence)
  
  lu.assertEquals(plane2.target, target2)
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Attack)
  
  --step2:first plane stop defending, target1 still targeted and to far, plane1 remain in intercept
  --plane2 same
  plane1.getCurrentFSM = plane2.getCurrentFSM
  plane1.setFSM_Arg = m.setFSM_Arg
  
  --add mock for target 2, it also targetted
  when(fsm:calculatePriority(target2, 300, 8000, 1, group:getBestMissile().MaxRange)).thenAnswer(15)
  --add mock for replaceTarget() calls
  when(fsm:calculatePriority(fsm:getDataForPriorityCalc(plane2.target))).thenAnswer(10)
  
  fsm:run({})
  
  lu.assertEquals(plane1.target, nil)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  verify(plane1:setFSM_Arg("waypoint", fsm:getInterceptPoint()))
  
  --step3:target1 targeted set to false, set to target1
  target1:setTargeted(false)
  target2.isExist = function() return false end
  
  plane2.setFSM_Arg = m.setFSM_Arg
  
  fsm:run({})
  
  lu.assertEquals(plane1.target, target1)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Attack)
end

function test_FSM_Element_Attack:test_sorting() 
  --element with 2 planes
  local m = mockagne.getMock()
  
  local plane1 = getCapPlane()
  plane1.name = "PLANE 1"
  local plane2 = getCapPlane()
  plane2.name = "PLANE 2"
  plane1.getPoint = function() return {x = 40000, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 40000, y = 0, z = 0} end
  
  local group = CapGroup:create({plane1, plane2})
  local element = group.elements[1]
  
  local tactic = FSM_Element_Tactic:create(element)
  local fsm = FSM_Element_Attack:create(element, tactic)
  fsm.getInterceptPoint = function() return mist.fixedWing.buildWP({x = 0, y = 0}) end
  
  plane1:clearFSM()
  plane2:clearFSM()
  plane1:setFSM_NoCall(FSM_FlyToPoint:create(plane1, mist.fixedWing.buildWP({x = 0, y = 0})))
  plane2:setFSM_NoCall(FSM_FlyToPoint:create(plane1, mist.fixedWing.buildWP({x = 0, y = 0})))
  
  local target1 = getTarget()
  target1.name = "target 1"
  local target2 = getTarget()
  target2.name = "target 2"
  
  --mock targets, so they almost identical, except second higher
  target1.getPoint = function() return {x = 0, y = 10, z = 0} end
  target2.getPoint = function() return {x = 0, y = 5000, z = 0} end
  
  target1.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  target2.getTypeModifier = target1.getTypeModifier
  
  --move toward plane
  target1.getVelocity = function() return {x = 100, y = 0, z = 0} end
  target2.getVelocity = target1.getVelocity
  
  local targetGroup = TargetGroup:create({target1, target2})
  group.target = targetGroup
  
  --second is higher, so higher pririty
  lu.assertTrue(fsm:calculatePriority(fsm:getDataForPriorityCalc(target1)) < fsm:calculatePriority(fsm:getDataForPriorityCalc(target2)))
  
  fsm:setup()
  lu.assertEquals(plane1.target, target2)
  lu.assertEquals(plane2.target, target1)
  
  fsm:run({})
  lu.assertEquals(plane1.target, target2)
  lu.assertEquals(plane2.target, target1)
end
end
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

test_FSM_Element_Crank = {}

function test_FSM_Element_Crank:test_getCrankPoint() 
  --verify point will be set at correct direction
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  local plane = element.planes[1] 
  local tactic = FSM_Element_Tactic:create(element)
  
  local fsm = FSM_Element_Crank:create(element, tactic, 90, FSM_Element_Crank.DIR.Right)
  
  group.target.getPoint = function() return {x = 50000, y = 0, z = 0} end
  element.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  --crank should be at Left, point should be 50km away from element
  local result = fsm:getCrankPoint()
  lu.assertAlmostEquals(result.x, 0, 1)--1meter margin enough
  lu.assertAlmostEquals(result.z, 50000, 1)
  
  fsm.side = FSM_Element_Crank.DIR.Left
  result = fsm:getCrankPoint()
  lu.assertAlmostEquals(result.x, 0, 1)--1meter margin enough
  lu.assertAlmostEquals(result.z, -50000, 1)
  end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

test_FSM_Element_FlyParallel = {}

function test_FSM_Element_FlyParallel:test_getTargetPointHotTarget() 
  --target hot, should use negative velocity*20000
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  local plane = element.planes[1] 
  local tactic = FSM_Element_Tactic:create(element)
  
  --20km lateral separation
  element.getPoint = function() return {x = 0, y = 0, z = 20000} end
  group.target.getPoint = function() return {x = 50000, y = 0, z = 0} end
  group.target:getLead().getVelocity = function() return {x = -1, y = 0, z = 0} end --target moving toward us
  group.target:getLead().getAA = function() return 0 end
  
  local fsm = FSM_Element_FlyParallel:create(element, tactic)
  
  local result = fsm:getTargetPoint()
  lu.assertEquals(result.x, 20000)
  lu.assertEquals(result.y, 0)
  lu.assertEquals(result.z, 20000)
end

function test_FSM_Element_FlyParallel:test_getTargetPointColdTarget() 
  --target hot, should use velocity*20000
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  local plane = element.planes[1] 
  local tactic = FSM_Element_Tactic:create(element)
  
  --20km lateral separation
  element.getPoint = function() return {x = 0, y = 0, z = 20000} end
  group.target.getPoint = function() return {x = 50000, y = 0, z = 0} end
  group.target:getLead().getVelocity = function() return {x = 1, y = 0, z = 0} end --target moving from us
  group.target:getLead().getAA = function() return 180 end
  
  local fsm = FSM_Element_FlyParallel:create(element, tactic)
  
  local result = fsm:getTargetPoint()
  lu.assertEquals(result.x, 20000)
  lu.assertEquals(result.y, 0)
  lu.assertEquals(result.z, 20000)
  end

--]]

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
test_FSM_Element_GroupEmul = {}
test_FSM_Element_GroupEmul.originalRandom = mist.random

function test_FSM_Element_GroupEmul:teardown() 
  mist.random = test_FSM_Element_GroupEmul.originalRandom
  end

function test_FSM_Element_GroupEmul:test_creation_signleton() 
  --verify object, name, enum
  --should copy ALR/preferredTactics from group, countPlanes == 1
  --should contain one element, plane should be registered to new element, element registered to this state
  --target set to targeted
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  --set custom options
  group.alr = CapGroup.ALR.High
  group.preferableTactics = {CapGroup.tactics.Banzai}
  
  local element = group.elements[1]
  local plane = element.planes[1]
  
  group.target:setTargeted(false)
  local fsm = FSM_Element_GroupEmul:create(element, group.target)
  
  lu.assertEquals(group.target:getTargeted(), true)
  
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.name, "Element Wrapper-" .. group.target:getName())
  lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  lu.assertEquals(fsm.alr, CapGroup.ALR.High)
  lu.assertEquals(fsm.preferableTactics, {CapGroup.tactics.Banzai})
  lu.assertEquals(fsm.countPlanes, 1)
  
  lu.assertEquals(#fsm.elements, 1)
  
  local wrappedElem = fsm.elements[1]
  lu.assertEquals(#wrappedElem.planes, 1)
  lu.assertEquals(wrappedElem.myGroup, fsm)
  
  lu.assertEquals(plane.myElement, wrappedElem)
  lu.assertEquals(plane.myGroup, fsm)
end

function test_FSM_Element_GroupEmul:test_creation_2Planes() 
  --verify object, name, enum
  --countPlanes == 2
  --should contain 2 elements, elements registered to each other
  --verify planes myElement/myGroup registraction
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local group = CapGroup:create({plane1, plane2})
  group.target = getTargetGroup()
  --set custom options
  group.alr = CapGroup.ALR.High
  group.preferableTactics = {CapGroup.tactics.Banzai}
  
  local element = group.elements[1]
  local fsm = FSM_Element_GroupEmul:create(element, group.target)
  
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.countPlanes, 2)
  
  lu.assertEquals(#fsm.elements, 2)
  
  local wrappedElem1 = fsm.elements[1]
  lu.assertEquals(#wrappedElem1.planes, 1)
  lu.assertEquals(wrappedElem1.myGroup, fsm)
  lu.assertEquals(plane1.myElement, wrappedElem1)
  lu.assertEquals(plane1.myGroup, fsm)
  
  local wrappedElem2 = fsm.elements[2]
  lu.assertEquals(#wrappedElem2.planes, 1)
  lu.assertEquals(wrappedElem2.myGroup, fsm)
  lu.assertEquals(plane2.myElement, wrappedElem2)
  lu.assertEquals(plane2.myGroup, fsm)
end

function test_FSM_Element_GroupEmul:test_canBeUsedForTacticSelection() 
  --call getWeight() on all tactics and verify no errors
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  
  local element = group.elements[1]
  local plane = element.planes[1]
  local fsm = FSM_Element_GroupEmul:create(element, group.target)
  
  lu.assertNumber(FSM_Element_Skate:getWeight(fsm))
  lu.assertNumber(FSM_Element_SkateGrinder:getWeight(fsm))
  lu.assertNumber(FSM_Element_SkateOffset:getWeight(fsm))
  lu.assertNumber(FSM_Element_SkateOffsetGrinder:getWeight(fsm))
  lu.assertNumber(FSM_Element_ShortSkate:getWeight(fsm))
  lu.assertNumber(FSM_Element_ShortSkateGrinder:getWeight(fsm))
  lu.assertNumber(FSM_Element_Bracket:getWeight(fsm))
  lu.assertNumber(FSM_Element_Banzai:getWeight(fsm))
end

function test_FSM_Element_GroupEmul:test_setup() 
  --select tactic using same technic as capGroup does, set to elements
  --should be first tactic
  mist.random = function() return 0 end

  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  
  local element = group.elements[1]
  local plane = element.planes[1]
  
  --verify skate will be selected
  element.getBestMissile = function() return {MaxRange = 99999, MAR = 99999} end
  group.target.getHighestThreat = function() return {MaxRange = 1000, MAR = 1000} end
  group.preferredTactics = {CapGroup.tactics.Skate}
  
  local fsm = FSM_Element_GroupEmul:create(element, group.target)
  fsm:setup()
  
  lu.assertEquals(fsm.elements[1].FSM_stack.data[1].enumerator, CapElement.FSM_Enum.FSM_Element_Skate)
end

function test_FSM_Element_GroupEmul:test_teardown() 
  --planes fsm should be resetted and set to FlyToPoint
  --planes link should be updated to original group/element
  --target setTargeted(false)
  mist.random = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.target = getTargetGroup()
  
  local element = group.elements[1]
  
  --verify skate will be selected
  element.getBestMissile = function() return {MaxRange = 99999, MAR = 99999} end
  group.target.getHighestThreat = function() return {MaxRange = 1000, MAR = 1000} end
  group.preferredTactics = {CapGroup.tactics.Skate}
  
  local fsm = FSM_Element_GroupEmul:create(element, group.target)
  fsm:setup()
  group.target:setTargeted(true)
  
  lu.assertNotEquals(tostring(plane1.myGroup), tostring(group))
  lu.assertNotEquals(tostring(plane2.myGroup), tostring(group))
  lu.assertNotEquals(tostring(plane1.myElement), tostring(element))
  lu.assertNotEquals(tostring(plane2.myElement), tostring(element))
  
  fsm:teardown()
  
  lu.assertEquals(group.target.targeted, false)

  lu.assertEquals(plane1.FSM_stack.topItem, 1)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  --verify reference to same object
  lu.assertEquals(tostring(plane1.myElement), tostring(element))
  lu.assertEquals(tostring(plane1.myGroup), tostring(group))
  
  lu.assertEquals(plane2.FSM_stack.topItem, 1)
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(tostring(plane2.myElement), tostring(element))
  lu.assertEquals(tostring(plane2.myGroup), tostring(group))
end

function test_FSM_Element_GroupEmul:test_updateAllAlive() 
  --2 planes all alive
  --2 elements after update, verify secondElement() set
  --plane countUpdates
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.target = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target)
  plane1.isExist = function() return true end
  plane2.isExist = plane1.isExist
  
  fsm:update()
  lu.assertEquals(fsm.countPlanes, 2)
  lu.assertEquals(#fsm.elements, 2)
  lu.assertEquals(tostring(fsm.elements[1]:getSecondElement()), tostring(fsm.elements[2]))
  lu.assertEquals(tostring(fsm.elements[2]:getSecondElement()), tostring(fsm.elements[1]))
  end

function test_FSM_Element_GroupEmul:test_DeleteDead() 
  --2 planes one dead
  --1 element after update, getSecondElement() return nil
  --plane countUpdates
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.target = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target)
  plane1.isExist = function() return true end
  plane2.isExist = function() return false end
  
  fsm:update()
  lu.assertEquals(fsm.countPlanes, 1)
  lu.assertEquals(#fsm.elements, 1)
  lu.assertEquals(fsm.elements[1]:getSecondElement(), nil)
end

function test_FSM_Element_GroupEmul:test_capGroupUpdateWorkWithIt() 
  --2 planes one dead
  --capGroup:update() called plane deleted from element
  --fsm:update() called, one element deleted
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.target = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target)
  plane1.isExist = function() return true end
  plane2.isExist = function() return false end
  
  group:update()
  lu.assertEquals(group.countPlanes, 1)
  
  fsm:update()
  lu.assertEquals(fsm.countPlanes, 1)
  lu.assertEquals(#fsm.elements, 1)
  lu.assertEquals(fsm.elements[1]:getSecondElement(), nil)
end

function test_FSM_Element_GroupEmul:test_capGroupUpdate_elementDies() 
  --2 planes in group, 1 in each element
  --capGroup:update() called plane deleted from element
  --element with emulator dies, element deletes
  --target was set to targeted = false
  --verify no errors even if plane dead(no dcsObject and controller)

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target)
  group.elements[2]:setFSM_NoCall(fsm)
  plane1.isExist = function() return true end
  plane2.isExist = function() return false end
  plane2.dcsObject = nil
  plane2.controller = nil
  
  group.target:setTargeted(true)
  
  group:update()
  lu.assertEquals(group.target:getTargeted(), false)
  lu.assertEquals(group.countPlanes, 1)
  lu.assertEquals(#group.elements, 1)
end

function test_FSM_Element_GroupEmul:test_capGroup_mergeElementsWorkWithIt() 
  --2 planes in group, 1 in each element
  --1 element with emulator
  --mergeElement() called and plane move to element
  --target was set to targeted = false
  --verify no errors even if plane dead(no dcsObject and controller)

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target)
  group.elements[2]:setFSM_NoCall(fsm)
  
  group.target:setTargeted(true)
  
  lu.assertEquals(#group.elements, 2)
  group:mergeElements()
  lu.assertEquals(#group.elements, 1)
  lu.assertEquals(group.target:getTargeted(), false)
end

function test_FSM_Element_GroupEmul:test_runTargetDead() 
  --passed target dead return back

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  local elemTgt = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[2], elemTgt)
  group.elements[2]:setFSM_NoCall(fsm)
  
  --set group to close
  elemTgt.isExist = function() return false end
  
  fsm:run({})
  lu.assertNotEquals(group.elements[2]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Element_GroupEmul:test_runSameTargetGroup() 
  --lead element recieve same target as a element, return

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  local elemTgt = getTargetGroup()
  elemTgt.isExist = function() return true end
  elemTgt.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  local fsm = FSM_Element_GroupEmul:create(group.elements[2], elemTgt, false)
  group.elements[2]:setFSM_NoCall(fsm)
  
  fsm:run({})
  lu.assertEquals(group.elements[2]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --group target changes
  group.target = elemTgt
  fsm:run({})
  lu.assertNotEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Element_GroupEmul:test_runSameTargetElement() 
  --element split, then recieve same target as group.target - > return back

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  local elemTgt = getTargetGroup()
  elemTgt.isExist = function() return true end
  elemTgt.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  local fsm = FSM_Element_GroupEmul:create(group.elements[2], elemTgt, false)
  group.elements[2]:setFSM_NoCall(fsm)
  
  fsm:run({})
  lu.assertEquals(group.elements[2]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --group target changes
  group.elements[2]:setFSM_Arg('newTarget', group.target)
  fsm:run({})
  lu.assertNotEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Element_GroupEmul:test_runAttackGroupTarget_groupTargetChanges() 
  --element attack group target
  --group target changes should return

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  local elemTgt = getTargetGroup()
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[1], group.target, true)
  group.elements[1]:setFSM_NoCall(fsm)
  
  fsm:run({})
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --group target changes
  group.target = elemTgt
  fsm:run({})
  lu.assertNotEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Element_GroupEmul:test_runAttack_targetTypeChanges() 
  --element attack group target
  --group target changes should return

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  local elemTgt = getTargetGroup()
  elemTgt.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  
  local fsm = FSM_Element_GroupEmul:create(group.elements[2], elemTgt)
  group.elements[2]:setFSM_NoCall(fsm)
  
  fsm:run({})
  lu.assertEquals(group.elements[2]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --target type changes, return back
  elemTgt.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end
  
  fsm:run({})
  lu.assertNotEquals(group.elements[2]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end
--]]

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()