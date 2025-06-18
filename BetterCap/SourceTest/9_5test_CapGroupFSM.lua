dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")


test_FSM_GroupStart = {}

function test_FSM_GroupStart:test_creation() 
  --verify name, enum, obj
  
  local group = getCapGroup()
  local inst = FSM_GroupStart:create(group)
  
  lu.assertEquals(inst.name, "FSM_GroupStart")
  lu.assertEquals(inst.enumerator, CapGroup.FSM_Enum.FSM_GroupStart)
  lu.assertEquals(inst.object, group)
  lu.assertEquals(tostring(inst.object), tostring(group))
end

function test_FSM_GroupStart:test_run_notInAir() 
  --if group on ground, do nothing, just callElements()
  --all planes has task set
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local inst = FSM_GroupStart:create(group)
  local m = mockagne.getMock()
  
  group.isAirborne = m.isAirborne
  when(m.isAirbone(group)).thenAnswer(false)

  group:setFSM(inst)
  inst:run()
  --no changes
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupStart)
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Start)
end

function test_FSM_GroupStart:test_run() 
  --if group in air, switch to FSM_FlyRoute
  
  local group = getCapGroup()
  local inst = FSM_GroupStart:create(group)
  local m = mockagne.getMock()
  
  group.route = m
  --need mock route, cause it used in FSM_FlyRoute:setup()
  when(group.route:getCurrentWaypoint()).thenAnswer({})
  when(group.route:isReachEnd()).thenAnswer(false)
  
  group.isAirborne = m.isAirborne
  when(m.isAirborne(group)).thenAnswer(true)
  group.FSM_stack.run = m.run
  
  inst:run()

  verify(m.isAirborne(group))
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
end

--***************************************************************************
--***************************************************************************
--***************************************************************************

test_FSM_GroupChecks = {}

function test_FSM_GroupChecks:test_checkAttack_noTarget() 
  --checkTargets() called with FSM_args.contacts and return no target
  --return false, no state change
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  group.setFSM = m.setFSM
  group.checkTargets = m.checkTargets
  when(group.checkTargets(group, group.FSM_args.contacts)).thenAnswer({target = nil, range = 0, priority = 0})
  
  lu.assertFalse(inst:checkAttack(group.FSM_args.contacts))
  verify_no_call(m.setFSM(any(), any()))--no state change
  verify(group.checkTargets(group, group.FSM_args.contacts))
end

function test_FSM_GroupChecks:test_checkAttack_TargetInCommitRange() 
  --checkTargets() called with FSM_args.contacts and return target in CR
  --return true, set state to FSM_Engage
  local group = getCapGroupNoRun()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  local target = getTargetGroup()
  
  group:setFSM_Arg("contacts", {target})
  group.commitRange = 11

  group.callFSM = m.callFSM
  group.checkTargets = m.checkTargets
  when(group.checkTargets(group, group.FSM_args.contacts)).thenAnswer({target = target, range = 9, priority = 0, commitRange = 10})
  
  lu.assertTrue(inst:checkAttack(group.FSM_args.contacts))
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  verify(group.checkTargets(group, group.FSM_args.contacts))
  end

function test_FSM_GroupChecks:test_checkAttack_TargetOutsideCommitRange() 
  --checkTargets() called with FSM_args.contacts and return target outside CR + 10nm margin
  --return true, set state to FSM_Commit
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  local target = getTargetGroup()
  
  group:setFSM_Arg("contacts", {target})
  group.commitRange = 11
  --mock run(), so new state won't be called
  group.FSM_stack.run = m.run

  group.checkTargets = m.checkTargets
  when(group.checkTargets(group, group.FSM_args.contacts)).thenAnswer({target = target, range = 30000, priority = 0, commitRange = 10})
  
  lu.assertTrue(inst:checkAttack(group.FSM_args.contacts))
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Commit)
  verify(group.checkTargets(group, group.FSM_args.contacts))
end

function test_FSM_GroupChecks:test_setBurnerOn() 
  --verify option set on all Aircraft
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  plane1.setOption = m.setOption
  plane2.setOption = m.setOption
  
  inst:setBurner(true)
  verify(plane1:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On))
  verify(plane2:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On))
end

function test_FSM_GroupChecks:test_setBurnerOff() 
  --verify option set on all Aircraft
  --option should be nil
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  plane1.setOption = m.setOption
  plane2.setOption = m.setOption
  
  inst:setBurner(false)
  verify(plane1:setOption(CapPlane.options.BurnerUse, nil))
  verify(plane2:setOption(CapPlane.options.BurnerUse, nil))
end

function test_FSM_GroupChecks:test_checkForBurner_NotNeeded() 
  --burner usage = false, and speed is ok, should do nothing
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  inst:setTargetSpeed(151)
  lu.assertEquals(inst.targetSpeed, 151)
  
  inst.setBurner = m.setBurner
  
  group:getLead().getVelocity = m.getVelocity
  when(group:getLead():getVelocity()).thenAnswer({x = 200, y = 0, z = 0})
  
  inst:checkForBurner()
  verify_no_call(inst:setBurner(any()))
  end

function test_FSM_GroupChecks:test_checkForBurner_SwitchOn() 
  --burner usage = false, and speed is to low, should call setBurner()
  -- and change burnerAllowed to true
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  inst:setTargetSpeed(151)
  lu.assertEquals(inst.targetSpeed, 151)
  
  inst.setBurner = m.setBurner
  
  group:getLead().getVelocity = m.getVelocity
  when(group:getLead():getVelocity()).thenAnswer({x = 99, y = 0, z = 0})
  
  inst:checkForBurner()
  lu.assertEquals(inst.burnerAllowed, true)
  verify(inst:setBurner(true))
  end

function test_FSM_GroupChecks:test_checkForBurner_ContinueOn() 
  --burner usage = true, and speed is to low, should do nothing
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  inst.burnerAllowed = true
  inst:setTargetSpeed(151)
  lu.assertEquals(inst.targetSpeed, 151)
  
  inst.setBurner = m.setBurner
  
  group:getLead().getVelocity = m.getVelocity
  when(group:getLead():getVelocity()).thenAnswer({x = 99, y = 0, z = 0})
  
  inst:checkForBurner()
  verify_no_call(inst:setBurner(any()))
end

function test_FSM_GroupChecks:test_checkForBurner_SwitchOff() 
  --burner usage = true, and speed is ok, return back
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  inst.burnerAllowed = true
  inst:setTargetSpeed(151)
  lu.assertEquals(inst.targetSpeed, 151)
  
  inst.setBurner = m.setBurner
  
  group:getLead().getVelocity = m.getVelocity
  when(group:getLead():getVelocity()).thenAnswer({x = 151, y = 0, z = 0})
  
  inst:checkForBurner()
  lu.assertEquals(inst.burnerAllowed, false)
  verify(inst:setBurner(false))
  end

function test_FSM_GroupStart:test_groupChecks_RTB() 
  --shouldRTB() return true
  --state set to RTB and callFSM() called, return true
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  
  inst.checkAttack = m.checkAttack
  group.needRTB = m.needRTB
  when(group:needRTB()).thenAnswer(true)
  
  --mock, so new state won't be called
  group.FSM_stack.run = m.run
  
  lu.assertTrue(inst:groupChecks())
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  verify_no_call(m.checkAttack(inst))--verify no call, early return
  verify(m.needRTB(group))
end

function test_FSM_GroupStart:test__groupChecks_CheckAutonomousAndSpeed() 
  --shouldRTB() and checkAttack() return false
  --updateAutonomous() called with FSM_args.radars
  --checkForBurner() called
  --no state change
  --no callFSM()
  --return false
  local group = getCapGroup()
  local inst = FSM_GroupChecks:create(group)
  local m = mockagne.getMock()
  local r1, r2 = getRadar(), getRadar()
  
  group:setFSM_Arg("radars", {r1, r2})
  
  inst.checkAttack = m.checkAttack
  inst.checkForBurner = m.checkForBurner
  group.callFSM = m.callFSM
  group.needRTB = m.needRTB
  group.updateAutonomous = m.updateAutonomous
  when(group:needRTB()).thenAnswer(false)
  when(inst:checkAttack(group.FSM_args.contacts)).thenAnswer(false)
  
  lu.assertFalse(inst:groupChecks(group.FSM_args))
  --lu.assertEquals(group:getCurrentFSM(), inst.enumerator)
  
  verify(m.checkForBurner(inst))
  verify(m.updateAutonomous(group, group.FSM_args.radars))
  verify(m.needRTB(group))
  verify(m.checkAttack(inst, group.FSM_args.contacts))--verify no call, early return
  verify_no_call(m.callFSM(group))
  end


--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_Rejoin = {}

function test_FSM_Rejoin:test_creation() 
  --verify name, enumerator, object, task
  local group = getCapGroup()
  group.getPoint = function() return {x = 100, y = 2000, z = 99} end
  
  local inst = FSM_Rejoin:create(group)
  
  lu.assertEquals(inst.object, group)
  lu.assertEquals(inst.name, "FSM_Rejoin")
  lu.assertEquals(inst.enumerator, CapGroup.FSM_Enum.FSM_Rejoin)
  lu.assertEquals(inst.task.id, "Orbit")
  lu.assertEquals(inst.task.params.pattern, "Circle")
  lu.assertEquals(inst.task.params.point, {x = 100, y = 99})
  lu.assertEquals(inst.task.params.altitude, 6000)
end

function test_FSM_Rejoin:test_setup() 
  --verify element in FSM_Element_FlyOrbit
  --verify mergeElements called
  --verify planes has proper task
  --targetSpeed == 0
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local m = mockagne.getMock()
  
  group.getPoint = function() return {x = 100, y = 2000, z = 99} end
  group.mergeElements = m.mergeElements
  
  local inst = FSM_Rejoin:create(group)
  lu.assertEquals(group.elements[1]:getCurrentFSM() ~= CapElement.FSM_Enum.FSM_Element_FlyFormation, true)
  
  inst:setup()
  lu.assertEquals(inst.targetSpeed, 0)
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyFormation)
  
  --check task
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.point, {x = 100, y = 99})
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.altitude, 6000)
  
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyOrbit)
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Formation)
  
  verify(group:mergeElements())
end

function test_FSM_Rejoin:test_run_groupCheck_return()
  --verify early return
  --no callElements()
  local group = getCapGroup()
  local m = mockagne.getMock()
  
  local inst = FSM_Rejoin:create(group)
  inst.callElements = m.callElements
  inst.groupChecks = m.groupChecks
  when(inst:groupChecks()).thenAnswer(true)
  
  group.getMaxRange = m.getMaxRange
  group.popFSM = m.popFSM
  
  inst:run()
  
  verify_no_call(group:getMaxRange())
  verify_no_call(group:popFSM())
  verify_no_call(inst:callElements())
  end

function test_FSM_Rejoin:test_run_groupCheck_notRejoined()
  --groupCheck() return false
  --getMaxRange() return > 10000
  --callElements() called
  --no popFSM() call

  local group = getCapGroup()
  local m = mockagne.getMock()
  
  local inst = FSM_Rejoin:create(group)
  inst.groupChecks = m.groupChecks
  when(inst:groupChecks()).thenAnswer(false)

  group.getMaxDistanceToLead = m.getMaxDistanceToLead
  when(group:getMaxDistanceToLead()).thenAnswer(21111)
  group.popFSM = m.popFSM
  
  inst:run()
  
  verify(group:getMaxDistanceToLead())
  verify_no_call(group:popFSM())
end

function test_FSM_Rejoin:test_run_groupCheck_Rejoined()
  --groupCheck() return false
  --getMaxRange() return < 10000
  --popFSM() call
  --no callElements()

  local group = getCapGroup()
  local m = mockagne.getMock()
  
  local inst = FSM_Rejoin:create(group)
  inst.groupChecks = m.groupChecks
  when(inst:groupChecks()).thenAnswer(false)
  
  group.getMaxDistanceToLead = m.getMaxDistanceToLead
  when(group:getMaxDistanceToLead()).thenAnswer(9999)
  group.popFSM = m.popFSM
  
  inst:run()
  
  verify(group:getMaxDistanceToLead())
  verify(group:popFSM())
  end



--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_GroupRTB = {}

function test_FSM_GroupRTB:test_creation() 
  --verify object, name, enumerator
  --verify waypoint is HomeBase from route
  local group = getCapGroup()
  local m = mockagne.getMock()
  
  local WP = {x = 0, y = 0, alt = 50}
  group.route.getHomeBase = m.getHomeBase
  when(group.route:getHomeBase()).thenAnswer(WP)
  
  local fsm = FSM_GroupRTB:create(group)
  verify(group.route:getHomeBase())
  
  lu.assertEquals(fsm.object, group)
  lu.assertEquals(fsm.name, "FSM_GroupRTB")
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_GroupRTB)
  lu.assertEquals(fsm.waypoint, WP)
end


function test_FSM_GroupRTB:test_setup_hasAirfield() 
  --hasAirfield return true
  --planes to FSM_PlaneRTB with wp is point from
  --route:getHomeBase()
  --group:mergeElements() called
  --verify burner usage prohibited
  --verify set inf fuel
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local group = CapGroup:create({plane1, plane2})
  local m = mockagne.getMock()
  local WP = {x = 0, y = 0, alt = 50}
  
  group.route.hasAirfield = m.hasAirfield
  when(group.route:hasAirfield()).thenAnswer(true)
  group.route.getHomeBase = m.getHomeBase
  when(group.route:getHomeBase()).thenAnswer(WP)
  group.mergeElements = m.mergeElements 
  
  plane1.setOption = m.setOption
  plane2.setOption = m.setOption

  plane1.getController = function ()
    return m
  end
  plane2.getController = plane1.getController
  
  local fsm = FSM_GroupRTB:create(group)
  fsm:setup()
  verify(group.route:hasAirfield())
  verify(group.route:getHomeBase())
  verify(group:mergeElements())
  
  --verify burner usage option
  verify(plane1:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off))
  verify(plane2:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off))

  --verify inf fuel
  verify(m:setCommand({ 
    id = 'SetUnlimitedFuel', 
    params = { 
      value = true 
    } 
  }))
  
  --top of the stack is first element, so it was cleared
  lu.assertEquals(group.elements[1].FSM_stack.topItem, 1)
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlySeparatly)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_PlaneRTB)
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_PlaneRTB)
  
  --verify tasks properly set for first plane
  lu.assertEquals(plane1.FSM_stack.topItem, 1)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.id, "Mission")
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[2], WP)
end

function test_FSM_GroupRTB:test_setup_noAirfield()  
  --hasAirfield return false
  --element FSM should be wiped and set Element to FSM_Element_FlyFormation
  --first plane to FSM_FlyToPoint with wp is point from
  --group:mergeElements() called
  --verify burner usage prohibited
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local group = CapGroup:create({plane1, plane2})
  local m = mockagne.getMock()
  local WP = {x = 0, y = 0, alt = 50}
  
  group.route.hasAirfield = m.hasAirfield
  when(group.route:hasAirfield()).thenAnswer(false)
  
  group.route.getHomeBase = m.getHomeBase
  when(group.route:getHomeBase()).thenAnswer(WP)
  group.mergeElements = m.mergeElements 
  
  plane1.setOption = m.setOption
  plane2.setOption = m.setOption
  
  local fsm = FSM_GroupRTB:create(group)
  fsm:setup()
  verify(group.route:hasAirfield())
  verify(group.route:getHomeBase())
  verify(group:mergeElements())
  
  --verify burner usage option
  verify(plane1:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off))
  verify(plane2:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.Off))
  
   --top of the stack is first element, so it was cleared
  lu.assertEquals(group.elements[1].FSM_stack.topItem, 1)
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyFormation)
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(plane2:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Formation)
  
  --verify tasks properly set for first plane
  lu.assertEquals(plane1.FSM_stack.topItem, 1)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.id, "Mission")
  --should be newly created WP at position of WP and alt of 5000
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1], mist.fixedWing.buildWP(WP, "turningpoint", 250, 5000, "BARO"))
  
  --verify tasks properly set for second plane
  lu.assertEquals(plane2.FSM_stack.topItem, 1)
  lu.assertEquals(plane2.FSM_stack:getCurrentState().task.id, "Follow")
  lu.assertEquals(plane2.FSM_stack:getCurrentState().task.params.groupId, plane1:getGroupID())
  end


function test_FSM_GroupRTB:test_run_normalOp()
  --shouldDeactivate() return false
  --does nothing
  local group = getCapGroup()
  group.shouldDeactivate = function() return false end
  
  local fsm = FSM_GroupRTB:create(group)
  group:setFSM(fsm)
  fsm:run()
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
end

function test_FSM_GroupRTB:test_run_goDeactivate()
  --shouldDeactivate() return false
  --does nothing
  local group = getCapGroup()
  group.shouldDeactivate = function() return true end
  
  local fsm = FSM_GroupRTB:create(group)
  group:setFSM(fsm)
  fsm:run()
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Deactivate)
  end


--***************************************************************************
--***************************************************************************
--***************************************************************************

test_FSM_GroupRTB_Route = {}

--check on setup we delete our planes from objective
function test_FSM_GroupRTB_Route:test_setup() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  
  testedInst:setFSM(testedInst.rtbClass:create(testedInst))
  verify(obj:addCapPlanes(-testedInst:getOriginalSize()))
end


--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_FlyRoute = {}

function test_FSM_FlyRoute:test_creation() 
  --verify object, name, enumerator
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  
  lu.assertEquals(fsm.object, group)
  lu.assertEquals(fsm.name, "FSM_FlyRoute")
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_FlyRoute)
  end

function test_FSM_FlyRoute:test_checkBaseProximity_notEndReached() 
  --we close to airbase, but still not reach end of route(i.e. we just take off)
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local zeroPos = {x = 0, y = 0, z = 0}
  
  group.route.isReachEnd = function() return false end
  group.route.getHomePoint = function() return zeroPos end
  group.getPoint = function() return zeroPos end
  
  lu.assertFalse(fsm:checkBaseProximity())
end

function test_FSM_FlyRoute:test_checkBaseProximity_tooFar() 
  --we reach end of route, but distance to great
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local zeroPos = {x = 0, y = 0, z = 0}
  
  group.route.isReachEnd = function() return true end
  group.route.getHomePoint = function() return zeroPos end
  group.getPoint = function() return {x = 99999, y = 0, z = 0} end
  
  lu.assertFalse(fsm:checkBaseProximity())
end

function test_FSM_FlyRoute:test_checkBaseProximity() 
  --we reach end of route, and distance is small
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local zeroPos = {x = 0, y = 0, z = 0}
  
  group.route.isReachEnd = function() return true end
  group.route.getHomePoint = function() return zeroPos end
  group.getPoint = function() return zeroPos end
  
  lu.assertTrue(fsm:checkBaseProximity())
  end

function test_FSM_FlyRoute:test_setup_FlyingHome() 
  --verify checkWpChange()
  --verify :mergeElements()
  --isReachEnd() return true
  --should set elements to FSM_Element_FlyFormation
  --first plane FSM is FSM_FlyToPoint
  --point is newly created waypoint with position of 
  --HomeBase altitude 8000 BARO and speed 200
  --targetSpeed is 200
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  group.route = m

  group.mergeElements = m.mergeElements
  group.route.isReachEnd = m.isReachEnd 
  when(group.route:isReachEnd()).thenAnswer(true)
  group.route.getHomeBase = m.getHomeBase
  when(group.route:getHomeBase()).thenAnswer({x = 50, y = 50, alt = 0, type = "Landing"})
  
  fsm:setup()
  
  verify(group:mergeElements())
  verify(group.route:isReachEnd())
  verify(group.route:getHomeBase())
  verify(group.route:checkWpChange(group:getPoint()))
  
  --verify speed
  lu.assertEquals(fsm.targetSpeed, 200)
  
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyFormation)
  lu.assertEquals(group.elements[1].FSM_stack.topItem, 1)--verify stack was cleared
  
  --verify first plane task
  lu.assertEquals(group.elements[1].planes[1]:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(group.elements[1].planes[1].FSM_stack.topItem, 1)--verify stack was cleared
  local taskAlias = group.elements[1].planes[1].FSM_stack:getCurrentState().task
  lu.assertEquals(taskAlias.id, "Mission")
  lu.assertEquals(taskAlias.params.route.points[1].x, group.route:getHomeBase().x)
  lu.assertEquals(taskAlias.params.route.points[1].y, group.route:getHomeBase().y)
  lu.assertEquals(taskAlias.params.route.points[1].speed, 200)
  lu.assertEquals(taskAlias.params.route.points[1].alt, 8000)
  lu.assertEquals(taskAlias.params.route.points[1].type, "Turning Point")
end

function test_FSM_FlyRoute:test_setup_notFlyingHome() 
  --verify :mergeElements()
  --isReachEnd() return false
  --should set elements to FSM_Element_FlyFormation
  --first plane FSM is FSM_FlyToPoint
  --point is newly created waypoint with route:getCurrentWaypoint()
  --targetSpeed set to speed from waypoint
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  group.route = m
  
  group.mergeElements = m.mergeElements
  group.route.isReachEnd = m.isReachEnd 
  when(group.route:isReachEnd()).thenAnswer(false)
  
  group.route.getCurrentWaypoint = m.getCurrentWaypoint
  when(group.route:getCurrentWaypoint()).thenAnswer({x = 50, y = 50, alt = 0, speed = 333})
  group.route.getHomeBase = m.getHomeBase
  
  fsm:setup()
  verify(group.route:getCurrentWaypoint())
  verify_no_call(group.route.getHomeBase())
  
  lu.assertEquals(fsm.targetSpeed, group.route:getCurrentWaypoint().speed)
  --verify elements
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyFormation)
  lu.assertEquals(group.elements[1].FSM_stack.topItem, 1)--verify stack was cleared
  
  --verify first plane task
  lu.assertEquals(group.elements[1].planes[1]:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(group.elements[1].planes[1].FSM_stack.topItem, 1)--verify stack was cleared
  
  local taskAlias = group.elements[1].planes[1].FSM_stack:getCurrentState().task
  lu.assertEquals(taskAlias.id, "Mission")
  lu.assertEquals(taskAlias.params.route.points[1], group.route:getCurrentWaypoint())
  end

function test_FSM_FlyRoute:test_checkPatrolZone_noZones() 
  --no zones present, return false
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  
  lu.assertFalse(fsm:checkPatrolZone())
end

function test_FSM_FlyRoute:test_checkPatrolZone_toFarFromAll() 
  --zones present, but to far from any zone return false
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  
  local zone1 = OrbitTask:create({x = 99999, y = 9999}, 8000, 200)
  local zone2 = OrbitTask:create({x = -99999, y = 9999}, 8000, 200)
  
  local WP_INDEX = 1
  
  group:addPatrolZone(WP_INDEX, zone1)--at current WP, but too far
  group:addPatrolZone(2, zone2)--at next wp
  
  group.route.getWaypointNumber = function() return WP_INDEX end
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  lu.assertFalse(fsm:checkPatrolZone())
end

function test_FSM_FlyRoute:test_checkPatrolZone_switch() 
  --has zone close enough
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  
  local zone1 = OrbitTask:create({x = 99999, y = 9999}, 8000, 200)
  local zone2 = OrbitTask:create({x = 20000, y = 9999}, 8000, 200)
  
  group.FSM_stack.run = function() end
  
  local WP_INDEX = 1
  group:addPatrolZone(WP_INDEX + 1, zone1) --at next wp, excluded
  group:addPatrolZone(WP_INDEX, zone2) --at current wp
  
  --at next wp, excluded
  local m = mockagne.getMock()
  zone1.getPoint = m.getPoint
  
  group.route.getWaypointNumber = function() return WP_INDEX end
  group.getPoint = function() return {x = 17000, y = 9999, z = 0} end
  
  lu.assertTrue(fsm:checkPatrolZone())
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  verify_no_call(zone1:getPoint())
end

function test_FSM_FlyRoute:test_run_groupCheckReturns() 
  --groupChecks() return true, verfify early return
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  fsm.groupChecks = m.groupChecks
  when(fsm:groupChecks()).thenAnswer(true)
  fsm.checkBaseProximity = m.checkBaseProximity
  
  fsm:run()
  
  verify(fsm:groupChecks())
  verify_no_call(m.checkBaseProximity(any()))
end

function test_FSM_FlyRoute:test_run_toCloseToAirbase() 
  --groupChecks() return false,
  --checkBaseProximity() return true, switch to RTB
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  --mock run(), so new state won't be called
  group.FSM_stack.run = m.run
  
  fsm.groupChecks = m.groupChecks
  when(fsm:groupChecks()).thenAnswer(false)
  fsm.checkBaseProximity = m.checkBaseProximity
  when(fsm:checkBaseProximity()).thenAnswer(true)
  fsm.checkPatrolZone = m.checkPatrolZone
  
  fsm:run()
  
  verify(fsm:groupChecks())
  verify(fsm:checkBaseProximity())
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  end

function test_FSM_FlyRoute:test_run_goRejoin() 
  --groupChecks() return false,
  --checkBaseProximity() return false
  --MaxDistance to great, go rejoin
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  --mock run(), so new state won't be called
  group.FSM_stack.run = m.run
  
  fsm.groupChecks = function() return false end
  fsm.checkBaseProximity = fsm.groupChecks
  group.getMaxDistanceToLead = m.getMaxDistanceToLead
  when(group:getMaxDistanceToLead()).thenAnswer(99999)
  
  fsm:run()
  verify(group:getMaxDistanceToLead())
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Rejoin)
end

function test_FSM_FlyRoute:test_run_goZonePatrol() 
  --groupChecks() return false,
  --checkBaseProximity() return false
  --MaxDistance is ok
  --patrol zone nearby go FSM_PatrolZone
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  --mock run(), so new state won't be called
  group.FSM_stack.run = m.run
  
  fsm.groupChecks = function() return false end
  fsm.checkBaseProximity = fsm.groupChecks
  group.getMaxDistanceToLead = function() return 0 end
  
  local WP_INDEX = 1
  local zone1 = OrbitTask:create({x = 0, y = 0}, 8000, 200)
  group:addPatrolZone(WP_INDEX, zone1)
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.route.getWaypointNumber = function() return WP_INDEX end
  
  fsm:run()

  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  end

function test_FSM_FlyRoute:test_run_goNextWp() 
  --all previous checks return false
  --checkWpChange(group position) return true
  --call setNextWP()
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  fsm.setNextWP = m.setNextWP
  fsm.groupChecks = function() return false end
  fsm.checkBaseProximity = fsm.groupChecks
  fsm.checkPatrolZone = fsm.groupChecks
  group.getMaxDistanceToLead = function() return 0 end
  
  group.getPoint = m.getPoint
  when(group:getPoint()).thenAnswer({})
  group.route.checkWpChange = m.checkWpChange
  when(group.route:checkWpChange({})).thenAnswer(true)
  
  fsm:run()
  verify(fsm:setNextWP())
end

function test_FSM_FlyRoute:test_run_NoNextWp() 
  --all checks return false
  --checkWpChange(group position) return false
  -- no call setNextWP()
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  fsm.setNextWP = m.setNextWP
  fsm.groupChecks = function() return false end
  fsm.checkBaseProximity = fsm.groupChecks
  fsm.checkPatrolZone = fsm.groupChecks
  group.getMaxDistanceToLead = function() return 0 end
  
  group.getPoint = m.getPoint
  when(group:getPoint()).thenAnswer({})
  group.route.checkWpChange = m.checkWpChange
  when(group.route:checkWpChange({})).thenAnswer(false)
  
  fsm:run()
  verify_no_call(fsm:setNextWP())
  end

function test_FSM_FlyRoute:test_setNextWP_flyRoute() 
  --route.isReachEnd return false
  --just call setFSM_Arg with new waypoint
  --target speed is waypoint speed
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  group.elements[1].setFSM_Arg = m.setFSM_Arg
  group.route.isReachEnd = m.isReachEnd
  when(group.route:isReachEnd()).thenAnswer(false)
  
  group.route.getCurrentWaypoint = m.getCurrentWaypoint
  when(group.route:getCurrentWaypoint()).thenAnswer({x = 99, y = 99, speed = 99})
  
  fsm:setNextWP()
  lu.assertEquals(fsm.targetSpeed, 99)
  
  verify(m.setFSM_Arg(group.elements[1], "waypoint", group.route:getCurrentWaypoint()))
end

function test_FSM_FlyRoute:test_setNextWP_flyHome() 
  --route.isReachEnd return trur
  --just call setFSM_Arg with newly create WP, with position of homePoint
  --targetSpeed is 200
  
  local group = getCapGroup()
  local fsm = FSM_FlyRoute:create(group)
  local m = mockagne.getMock()
  
  group.elements[1].setFSM_Arg = m.setFSM_Arg
  group.route.isReachEnd = m.isReachEnd
  when(group.route:isReachEnd()).thenAnswer(true)
  
  group.route.getCurrentWaypoint = m.getCurrentWaypoint
  when(group.route:getHomeBase()).thenAnswer({x = 99, y = 99})
  
  fsm:setNextWP()
  lu.assertEquals(fsm.targetSpeed, 200)
  
  verify(m.setFSM_Arg(group.elements[1], "waypoint", mist.fixedWing.buildWP(group.route:getHomeBase(), nil, 200, 8000, "BARO")))
  end

--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_Deactivate = {}

function test_FSM_Deactivate:test_creation() 
  local group = getCapGroup()
  local fsm = FSM_Deactivate:create(group)
  
  lu.assertEquals(fsm.object, group)
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_Deactivate)
  lu.assertEquals(fsm.name, "FSM_Deactivate")
end

function test_FSM_Deactivate:test_run() 
  --verify call of destroy on all planes
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local m = mockagne.getMock()
  local fsm = FSM_Deactivate:create(group)
 
  plane1:getObject().destroy = m.destroy
  plane2:getObject().destroy = m.destroy
  
  fsm:run({})
  
  verify(plane1:getObject():destroy())
  verify(plane1:getObject():destroy())
  end

--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_Deactivate_Route = {}

--verify planes return to sqn
function test_FSM_Deactivate_Route:test_setup() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  
  testedInst:setFSM(testedInst.deactivateClass:create(testedInst))
  verify(sqn:returnAircrafts(testedInst.countPlanes))
end


--***************************************************************************
--***************************************************************************
--***************************************************************************
test_FSM_Commit = {}

test_FSM_Commit.originalGetIntercept = utils.getInterceptPoint

function test_FSM_Commit:teardown() 
  utils.getInterceptPoint = test_FSM_Commit.originalGetIntercept
  end

function test_FSM_Commit:test_creation() 
  --check name,  enumerator, object
  --check target set to group
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  
  lu.assertEquals(fsm.object, group)
  lu.assertEquals(fsm.name, "FSM_Commit")
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_Commit)
  lu.assertEquals(tostring(group.target), tostring(target))
end

function test_FSM_Commit:test_setup_noTarget() 
  --no target was set
  --return to previous state
  local group = getCapGroup()
  local fsm = FSM_Commit:create(group)
  local m = mockagne.getMock()
  
  group.FSM_stack.run = m.run

  group:setFSM(fsm)
  lu.assertEquals(group.FSM_stack.topItem, 1)--nothing was added
  end

function test_FSM_Commit:test_setup_noTargetAlive() 
  --target was set but target is dead
  --return to previous state
  local group = getCapGroup()
  local m = mockagne.getMock()
  local target = getTargetGroup()
  
  group.route = m
  --need mock route, cause it used in FSM_FlyRoute:setup()
  when(group.route:getCurrentWaypoint()).thenAnswer({})
  when(group.route:isReachEnd()).thenAnswer(false)
  
  local AdditionalState = FSM_FlyRoute:create(group)
  AdditionalState.run = function() end
  group:setFSM(AdditionalState)
  lu.assertEquals(group.FSM_stack.topItem, 2)
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  
  target.isExist = m.isExist
  when(target:isExist()).thenAnswer(false)
  
  local fsm = FSM_Commit:create(group, target)

  group:setFSM(fsm)
  lu.assertEquals(group.FSM_stack.topItem, 2)--nothing was added
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  verify(target:isExist())
end


function test_FSM_Commit:test_setup() 
  --merge element called
  --element FSM cleared and set to FSM_Element_FlyFormation
  --plane set to FSM_FlyToPoint
  --point is waypoint from getInterceptWaypoint(290)
  --autonomous set to true
  --targetSpeed updated
  
  local group = getCapGroup()
  local m = mockagne.getMock()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  
  group.mergeElements = m.mergeElements
  group.setAutonomous = m.setAutonomous
  fsm.getInterceptWaypoint = m.getInterceptWaypoint 
  when(fsm:getInterceptWaypoint(290)).thenAnswer(mist.fixedWing.buildWP({x = 0, y = 0}))
  
  fsm:setup()
  verify(group:mergeElements())
  verify(group:setAutonomous(true))
  
  lu.assertEquals(fsm.targetSpeed, 290)
  
  --element
  lu.assertEquals(group.elements[1]:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlySeparatly)
  lu.assertEquals(group.elements[1].FSM_stack.topItem, 1)
  
  local plane = group.elements[1].planes[1]
  lu.assertEquals(plane.FSM_stack.topItem, 1)--verify stack cleared
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)--verify stack cleared
  lu.assertEquals(plane.FSM_stack:getCurrentState().task.params.route.points[1], fsm:getInterceptWaypoint(290))
  end

function test_FSM_Commit:test_teardown() 
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  
  lu.assertEquals(target, group.target)
  fsm:teardown()
  lu.assertNil(group.target)
end

function test_FSM_Commit:test_getInterceptWaypoint() 
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  local m = mockagne.getMock()
  
  local point = {x = 0, y = 0, z = 0}
  utils.getInterceptPoint = m.getInterceptPoint
  when(utils.getInterceptPoint(target:getLead(), group:getLead(), 290)).thenAnswer(point)
  
  lu.assertEquals(fsm:getInterceptWaypoint(290), mist.fixedWing.buildWP(point, nil, 290, target:getPoint().y, "BARO"))
  end


function test_FSM_Commit:test_checkTargetStatus_noTarget() 
  --no target should return back
  
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  local m = mockagne.getMock()
  
  group.popFSM = m.popFSM
  group.checkTargets = m.checkTargets
  when(group:checkTargets({})).thenAnswer({target = nil, range = 0, priority = 0})
  
  lu.assertTrue(fsm:checkTargetStatus({}))
  verify(group:popFSM())
end

function test_FSM_Commit:test_checkTargetStatus_newTarget_goEngage() 
  --new target returned, should change it
  --new target inside commit range, go to Engage, return true
  
  local group = getCapGroup()
  local target1 = getTargetGroup()
  local target2 = getTargetGroup()
  local fsm = FSM_Commit:create(group, target1)
  local m = mockagne.getMock()
  
  lu.assertEquals(group.target, target1)
  
  group.checkTargets = m.checkTargets
  when(group:checkTargets({})).thenAnswer({target = target2, range = 10, priority = 0, commitRange = 60000})
  group.calculateCommitRange = m.calculateCommitRange
  when(group:calculateCommitRange(target2)).thenAnswer(15)
  
  group.FSM_stack.run = m.run
  
  lu.assertTrue(fsm:checkTargetStatus({}))
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
end

function test_FSM_Commit:test_checkTargetStatus_noChange() 
  --same target, still not in range, return false
  
  local group = getCapGroup()
  local target1 = getTargetGroup()
  local fsm = FSM_Commit:create(group, target1)
  local m = mockagne.getMock()
  
  lu.assertEquals(group.target, target1)
  
  group.checkTargets = m.checkTargets
  when(group:checkTargets({})).thenAnswer({target = target1, range = 90000, priority = 0, commitRange = 60000})
  group.calculateCommitRange = m.calculateCommitRange
  when(group:calculateCommitRange(target1)).thenAnswer(5)
  
  group.FSM_stack.run = m.run
  
  lu.assertFalse(fsm:checkTargetStatus({}))
  end


function test_FSM_Commit:test_run_rtb() 
  --needRTB() return false
  --switch state to FSM_GroupRTB
  --early return
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  local m = mockagne.getMock()
  
  group.FSM_stack.run = m.run
  
  group.needRTB = m.needRTB
  when(group:needRTB()).thenAnswer(true)
  fsm.checkTargetStatus = m.checkTargetStatus
  
  fsm:run({})
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  lu.assertEquals(group.target, nil)
  
  verify(group:needRTB())
  verify_no_call(fsm:checkTargetStatus())
  end


function test_FSM_Commit:test_run_checkTargetReturn() 
  --check target status return true
  --early return
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  local m = mockagne.getMock()
  
  group.FSM_stack.run = m.run
  
  group.needRTB = function() return false end
  fsm.checkTargetStatus = m.checkTargetStatus
  when(fsm:checkTargetStatus()).thenAnswer(true)
  
  group.elements[1].setFSM_args = m.setFSM_Args
  
  fsm:run({})
  
  verify(fsm:checkTargetStatus())
  verify_no_call(m.setFSM_Args(group.elements[1], any(), any()))
end

function test_FSM_Commit:test_run_continueIntercept() 
  --no early return
  --verify lead plane recieve new waypoint
  local group = getCapGroup()
  local target = getTargetGroup()
  local fsm = FSM_Commit:create(group, target)
  local m = mockagne.getMock()
  
  group.elements[1].planes[1].setFSM_Arg = m.setFSM_Arg
  group.needRTB = function() return false end
  fsm.checkTargetStatus = group.needRTB
  
  fsm.getInterceptWaypoint = m.getInterceptWaypoint
  when(fsm:getInterceptWaypoint(290)).thenAnswer({x = 0, y = 0, z = 0})
  
  fsm:setup()
  fsm:run({})
  group.elements[1]:callFSM()
  
  verify(fsm:getInterceptWaypoint(290))
  verify(m.setFSM_Arg(group.elements[1].planes[1], "waypoint", fsm:getInterceptWaypoint(290)))
  end


--***************************************************************************
--***************************************************************************
--***************************************************************************

test_FSM_Pump = {}

function test_FSM_Pump:test_creation() 
  --verify object, name, enum
  local group = getCapGroup()
  local fsm = FSM_Pump:create(group)
  
  lu.assertEquals(fsm.name, "FSM_Pump")
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_Pump)
  lu.assertEquals(fsm.object, group)
end

function test_FSM_Pump:test_setup() 
  --verify mergeElements()
  --verify FSM was cleaned
  --verify option set
  --verify task set(same point as homeBase, but at 12000 and speed 660)
  --verify infinite fuel set
  local group = getCapGroup()
  local m = mockagne.getMock()
  local fsm = FSM_Pump:create(group)
  
  group.mergeElements = m.mergeElements
  group.route.getHomeBase = m.getHomeBase
  when(group.route:getHomeBase()).thenAnswer({x = 99, y = 99})
  
  group.elements[1].planes[1].getController = function ()
    return m
  end

  fsm:setup()
  
  verify(m.mergeElements(group))
  verify(group.route:getHomeBase())
  --verify inf fuel
  verify(m:setCommand({ 
      id = 'SetUnlimitedFuel', 
      params = { 
        value = true 
      } 
    }))
  
  --check elements was set
  local element = group.elements[1]
  lu.assertEquals(element:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlySeparatly)
  lu.assertEquals(element.FSM_stack.topItem, 1)--stack was cleared
  
  local plane = group.elements[1].planes[1]
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertEquals(plane.FSM_stack.topItem, 1)--stack was cleared
  --verify task set
  lu.assertEquals(plane.overridenOptions[CapPlane.options.BurnerUse], utils.tasks.command.Burner_Use.On)
end

function test_FSM_Pump:test_teardown() 
  --verify option was removed
  local group = getCapGroup()
  local m = mockagne.getMock()
  local fsm = FSM_Pump:create(group)
  local plane = group.elements[1].planes[1]
  
  fsm:setup()
  
  --verify task set
  lu.assertEquals(plane.overridenOptions[CapPlane.options.BurnerUse], utils.tasks.command.Burner_Use.On)
  fsm:teardown()
  
  lu.assertNil(plane.overridenOptions[CapPlane.options.BurnerUse])
end

function test_FSM_Pump:test_run_pop() 
  --fuel below bingo, popFSM
  
  local group = getCapGroup()
  local m = mockagne.getMock()
  local fsm = FSM_Pump:create(group)
  
  group.getFuel = m.getFuel
  when(group:getFuel()).thenAnswer(0)
  group.shouldDeactivate = function() return false end
  
  fsm:run({contacts = {}})
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  end


--***************************************************************************
--***************************************************************************
--***************************************************************************

test_FSM_PatrolZone = {}

function test_FSM_PatrolZone:test_creation() 
  local group = getCapGroup()
  local zone = OrbitTask:create({x = 0, y = 0})
  local fsm = FSM_PatrolZone:create(group, zone)
  
  lu.assertEquals(fsm.name, "FSM_PatrolZone")
  lu.assertEquals(fsm.enumerator, CapGroup.FSM_Enum.FSM_PatrolZone)
  lu.assertEquals(fsm.zone, zone)
  lu.assertEquals(fsm.object, group)
end

function test_FSM_PatrolZone:test_setup() 
  --mergeElements() called
  --stack in element cleaned
  --element set to FSM_Element_FlyFormation
  --plane set to FSM_FlyOrbit
  --plane task == zone:getTask()
  --speed set to task.speed or 0
  
  local group = getCapGroup()
  local m = mockagne.getMock()
  local zone = OrbitTask:create({x = 0, y = 0})
  local fsm = FSM_PatrolZone:create(group, zone)
  
  group.mergeElements = m.mergeElements
  
  fsm:setup()
  verify(group:mergeElements())
  
  --verify speed
  lu.assertEquals(fsm.targetSpeed, 0)
  
  --verify elem
  local elem = group.elements[1]
  lu.assertEquals(elem:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyFormation)
  lu.assertEquals(elem.FSM_stack.topItem, 1)--stack was cleaned
  
  --verify planes
  local plane = elem.planes[1]
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyOrbit)
  lu.assertEquals(plane.FSM_stack.topItem, 1)--stack was cleaned
  lu.assertEquals(plane.FSM_stack:getCurrentState().task, zone:getTask())
  end


function test_FSM_PatrolZone:test_setupSpeedSet() 
  --zone has speed set -> targetSpeed should be set
  
  local group = getCapGroup()
  local m = mockagne.getMock()
  local zone = OrbitTask:create({x = 0, y = 0}, 299)
  local fsm = FSM_PatrolZone:create(group, zone)
  
  group.mergeElements = m.mergeElements
  
  fsm:setup()
  verify(group:mergeElements())
  
  --verify speed
  lu.assertEquals(fsm.targetSpeed, 299)
  end


  function test_FSM_PatrolZone:test_GoEngage() 
    --mergeElements() called
    --stack in element cleaned
    --element set to FSM_Element_FlyFormation
    --plane set to FSM_FlyOrbit
    --plane task == zone:getTask()
    --speed set to task.speed or 0
    
    local group = getCapGroup()
    local m = mockagne.getMock()
    local zone = OrbitTask:create({x = 0, y = 0})
    local fsm = FSM_PatrolZone:create(group, zone)
    local target = getTargetGroup()
    target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
    target.getPoint = function() return {x = 0, y = 0, z = 0} end
    group.mergeElements = m.mergeElements
    group.needRTB = function ()
      return false
    end
    group:setFSM(fsm)
    group:setFSM_Arg("contacts", {target})

    group:callFSM()
    group:setFSM_Arg("contacts", {target})
    group:callFSM()
    group:setFSM_Arg("contacts", {target})

  end
--***************************************************************************
--***************************************************************************
--***************************************************************************

test_FSM_Engaged = {} 
test_FSM_Engaged.random = mist.random

function test_FSM_Engaged:teardown() 
   mist.random = test_FSM_Engaged.random 
  end
--[[
function test_FSM_Engaged:test_selectTactic_OnlyOne() 
  --only 1 tactic can be selected(short skate)
  --return tacticClass which can be instanciated
  local group = getCapGroup()
  group.target = getTargetGroup()
  
  group.target.getCount = function() return 99 end --prevent selection of Bracket/Banzai
  group.target.getHighestThreat = function() return {MaxRange = 999999, MAR = 999999} end --verify range disadvantage
  
  local fsm = FSM_Engaged:create(group, group.target)
  lu.assertNotNil(fsm:selectTactic())
  local tactic = fsm:selectTactic():create(group.elements[1])
  lu.assertEquals(tactic.enumerator, CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder)
end--]]

function test_FSM_Engaged:test_returnTargetToFar() 
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local target2 = getTargetGroup()
  target2.getHighestThreat = target.getHighestThreat
  target2.getPoint = function() return {x = 20000, y = 50000, z = 0} end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  group.ammoState = CapGroup.AmmoState.ARH
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  element1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  element2.getPoint = element1.getPoint
  
  --group always targeted
  group.checkTargets = function() return {target = target, range = 50000, commitRange = 60000} end
  group:setFSM(FSM_Engaged:create(group, target))
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  
  --now target turn cold and calculateCommitRange return lower range, but we still in 10nm margin
  group.checkTargets = function() return {target = target, range = 50000, commitRange = 40000} end
  group:callFSM()
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  
  --now outside 10nm margin, return back
  group.checkTargets = function() return {target = target, range = 50000, commitRange = 30000} end
  group:callFSM()
  
  lu.assertNotEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
end

function test_FSM_Engaged:test_selectTactic_highLowBound() 
  --only 1 tactic can be selected(short skate)
  --mist.random return min/max vals(0, 100)
  --return tacticClass which can be instanciated
  local group = getCapGroup()
  group.target = getTargetGroup()
  
  group.target.getCount = function() return 99 end --prevent selection of Bracket/Banzai
  group.target.getHighestThreat = function() return {MaxRange = 999999, MAR = 999999} end --verify range disadvantage
  
  local fsm = FSM_Engaged:create(group, group.target)
  mist.random = function() return 0 end
  lu.assertNotNil(fsm:selectTactic())
  mist.random = function() return 100 end
  lu.assertNotNil(fsm:selectTactic())
  end



function test_FSM_Engaged:test_goSplitCycle() 
  local m = mockagne.getMock()
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local target2 = getTargetGroup()
  target2.getHighestThreat = target.getHighestThreat
  target2.getPoint = function() return {x = 20000, y = 50000, z = 0} end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  group.ammoState = CapGroup.AmmoState.ARH
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  element1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  element2.getPoint = element1.getPoint
  
  --group always targeted
  group.checkTargets = function() return {target = target, range = 999, commitRange = 60000} end
  group:setFSM(FSM_Engaged:create(group, target))
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  --stage0:  element 2 to close for other target, but target is not a fighter type, skip it
  element2.getPoint = function() return {x = target2:getPoint().x + target2:getHighestThreat().MAR + 5000, y = target2:getPoint().y, z = 0} end
  
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.ATTACKER end
  
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --stage 1: element 2 to close for other target, elements switch to FSM_Element_GroupEmul, element1 with original target,
  -- element2 with new target
  element2.getPoint = function() return {x = target2:getPoint().x + target2:getHighestThreat().MAR + 5000, y = target2:getPoint().y, z = 0} end
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element1.FSM_stack:getCurrentState().target, target)
  lu.assertEquals(#element1.FSM_stack:getCurrentState().elements, 1)
  
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element2.FSM_stack:getCurrentState().target, target2)
  lu.assertEquals(#element2.FSM_stack:getCurrentState().elements, 1)
  
  --stage 2: element2 too far from target, element return back
  element2.getPoint = function() return {x = target2:getPoint().x + target2:getHighestThreat().MAR + 25000, y = target2:getPoint().y, z = 0} end

  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --stage 3: element1 also return back
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Engaged:test_goSplit_atPredifinedRange()
  --our range and small, mar high, should use Predefined distances 
  local m = mockagne.getMock()
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 100000, MAR = 50000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local target2 = getTargetGroup()
  target2.getHighestThreat = target.getHighestThreat
  target2.getPoint = function() return {x = 20000, y = 50000, z = 0} end
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 1, MAR = 1}
  group.ammoState = CapGroup.AmmoState.ARH
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 1, MAR = 1} end
  element2.getBestMissile = element1.getBestMissile
  element1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  element2.getPoint = element1.getPoint
  
  --group always targeted
  group.checkTargets = function() return {target = target, range = 999, commitRange = 60000} end
  group:setFSM(FSM_Engaged:create(group, target))
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  --stage 1: continue normal operation
  element2.getPoint = function() return {x = target2:getPoint().x + 30000, y = target2:getPoint().y, z = 0} end
  
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --stage 2: inside 15NM, go split
  element2.getPoint = function() return {x = target2:getPoint().x + 25000, y = target2:getPoint().y, z = 0} end
  
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element1.FSM_stack:getCurrentState().target, target)
  lu.assertEquals(#element1.FSM_stack:getCurrentState().elements, 1)
  
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element2.FSM_stack:getCurrentState().target, target2)
  lu.assertEquals(#element2.FSM_stack:getCurrentState().elements, 1)
  
  --stage 2: inside 20NM, continue
  element2.getPoint = function() return {x = target2:getPoint().x + 30000, y = target2:getPoint().y, z = 0} end
  
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)

  --stage 2: outside 20NM, return from split
  element2.getPoint = function() return {x = target2:getPoint().x + 36000, y = target2:getPoint().y, z = 0} end
  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  --lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  end

function test_FSM_Engaged:test_goSplitCycle_capGroupGroupMerges() 
  --geoup split up and then group.target merges with element target
  
  local m = mockagne.getMock()
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local target2 = getTargetGroup()
  target2.getHighestThreat = target.getHighestThreat
  target2.getPoint = function() return {x = 20000, y = 50000, z = 0} end
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  --need mock route, cause it used in FSM_FlyRoute:setup()
  group.route = m
  when(group.route:getCurrentWaypoint()).thenAnswer({})
  when(group.route:isReachEnd()).thenAnswer(false)
  group:setFSM_NoCall(FSM_FlyRoute:create(group))
  
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  group.ammoState = CapGroup.AmmoState.ARH
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  element1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  element2.getPoint = element1.getPoint
  
  --group always targeted
  group.checkTargets = function() return {target = target, range = 5000, priority = 0, commitRange = 60000} end
  group:setFSM(FSM_Engaged:create(group, target))
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  --stage 1: element 2 to close for other target, elements switch to FSM_Element_GroupEmul, element1 with original target,
  -- element2 with new target
  element2.getPoint = function() return {x = target2:getPoint().x + target2:getHighestThreat().MAR, y = target2:getPoint().y, z = 0} end

  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element1.FSM_stack:getCurrentState().target, target)
  
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element2.FSM_stack:getCurrentState().target, target2)
  
  --stage 2: group target merges with element target(all targets move to target2 and target no more sends to group)
  -- group return to FlyRoute and then engage to new target
  target2:mergeWith(target)
  group.checkTargets = function() return {target = target2, range = 5000, priority = 0, commitRange = 60000} end

  group:setFSM_Arg('contacts', {target2})
  group:callFSM()
  
  --group now targets to new group
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  lu.assertEquals(group.target, target2)
  
  lu.assertNotEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  end

function test_FSM_Engaged:test_goSplitCycle_elementGroupMerges() 
  --group split up and element target merges with group.target
  
  local m = mockagne.getMock()
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local target2 = getTargetGroup()
  target2.getHighestThreat = target.getHighestThreat
  target2.getPoint = function() return {x = 20000, y = 50000, z = 0} end
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.FIGHTER end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  --need mock route, cause it used in FSM_FlyRoute:setup()
  group.route = m
  when(group.route:getCurrentWaypoint()).thenAnswer({})
  when(group.route:isReachEnd()).thenAnswer(false)
  group:setFSM_NoCall(FSM_FlyRoute:create(group))

--split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  group.ammoState = CapGroup.AmmoState.ARH
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  element1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  element2.getPoint = element1.getPoint
  
  --group always targeted
  group.checkTargets = function() return {target = target, range = 5000, priority = 0, commitRange = 60000} end
  group:setFSM(FSM_Engaged:create(group, target))
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  --stage 1: element 2 to close for other target, elements switch to FSM_Element_GroupEmul, element1 with original target,
  -- element2 with new target
  element2.getPoint = function() return {x = target2:getPoint().x + target2:getHighestThreat().MAR, y = target2:getPoint().y, z = 0} end

  group:setFSM_Arg('contacts', {target, target2})
  group:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element1.FSM_stack:getCurrentState().target, target)
  
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertEquals(element2.FSM_stack:getCurrentState().target, target2)
  
  --stage 2: element target merges with group.target, element return to normal ops
  target:mergeWith(target2)

  group:setFSM_Arg('contacts', {target})
  group:callFSM()
  
  lu.assertEquals(group:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Engaged)
  lu.assertEquals(group.target, target)
  
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  
  --stage 3: first element also return to normal ops
  target:mergeWith(target2)

  group:setFSM_Arg('contacts', {target})
  group:callFSM()
  
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
  lu.assertNotEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_GroupEmul)
end

function test_FSM_Engaged:test_targetDies() 
  --target dies. check bug when it causes overflow
  local m = mockagne.getMock()
  
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  plane1.controller = Controller:create()--replace controller with stub instead of mock
  local plane2 = getCapPlane()
  plane2.controller = Controller:create()--replace controller with stub instead of mock
  local group = CapGroup:create({plane1, plane2})
  group.getPoint = function() return {x = 40000, y = 0, z = 0} end
  
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  group.ammoState = CapGroup.AmmoState.ARH
  --need mock route, cause it used in FSM_FlyRoute:setup()
  group.route = m
  when(group.route:getCurrentWaypoint()).thenAnswer({})
  when(group.route:isReachEnd()).thenAnswer(false)
  group:setFSM_NoCall(FSM_FlyRoute:create(group))
  
  target.isExist = function() return false end
  group:setFSM_Arg("contacts", {target})
  
  group:callFSM({})
end 

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()