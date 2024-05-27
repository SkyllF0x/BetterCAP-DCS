dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_CapPlaneFSM = {}
function test_CapPlaneFSM:mockSetFSM(plane) 
  --update plane's setFSM, so it only set state, but not call it
  plane.setFSM = function(p, state) p.FSM_stack:push(state) end
  
  return plane
  end

function test_CapPlaneFSM:test_checkAoA_startTimer() 
  local plane, group, unit, mock = getCapPlane()
  
  plane.getAoA = mock.getAoA
  when(mock.getAoA(plane)).thenAnswer(25)

  local FSM = AbstractPlane_FSM:create(plane)
  lu.assertIsNil(FSM.AoA_time)--timer not set
  
  lu.assertEquals(FSM:checkAoA(), false)
  lu.assertNotNil(FSM.AoA_time)
end

function test_CapPlaneFSM:test_checkAoA_goFixAoA() 
  local plane, group, unit, mock = getCapPlane()
  
  plane.getAoA = mock.getAoA
  when(mock.getAoA(plane)).thenAnswer(25)

  local FSM = AbstractPlane_FSM:create(plane)
  lu.assertIsNil(FSM.AoA_time)--timer not set
  
  --time more 15
  FSM.AoA_time = timer.getAbsTime() - 15
  
  lu.assertEquals(FSM:checkAoA(), true)
  lu.assertNotNil(FSM.AoA_time)
end

function test_CapPlaneFSM:test_checkAoA_AoAFixed() 
  --timer was set in last iterations, but now AoA ok, need reset it back
  
  local plane, group, unit, mock = getCapPlane()
  
  plane.getAoA = mock.getAoA
  when(mock.getAoA(plane)).thenAnswer(math.rad(10))

  local FSM = AbstractPlane_FSM:create(plane)
  lu.assertIsNil(FSM.AoA_time)--timer not set
  
  --time less 15
  FSM.AoA_time = timer.getAbsTime() - 10
  
  lu.assertEquals(FSM:checkAoA(), false)
  lu.assertIsNil(FSM.AoA_time)--timer should reset
  end

function test_CapPlaneFSM:test_checkMissile_Fox2() 
  --Fox2 missile, should not react
  local plane, group, unit, mock = getCapPlane()
  local FSM = AbstractPlane_FSM:create(plane)

  plane.threatMissiles[1] = MissileWrapper:create(getMissileForWrapper(unit))--add missile
  
  plane.threatMissiles[1].getPoint = mock.getPoint
  when(mock.getPoint(plane.threatMissiles[1])).thenAnswer({x = 15000, y = 0, z = 0})
  plane.threatMissiles[1].getGuidance = mock.getGuidance
  when(mock.getGuidance(plane.threatMissiles[1])).thenAnswer(2)--IR type
  
  plane.getPoint = mock.getPoint
  when(mock.getPoint(plane)).thenAnswer({x = 0, y = 0, z = 0})--Plane in 15km of target, so it should react if it not Fox2
  
  lu.assertEquals(FSM:checkMissile(plane.threatMissiles[1]), false)
end

function test_CapPlaneFSM:test_checkMissile_Fox1_3() 
  --Fox1/Fox3 missile, should react
  local plane, group, unit, mock = getCapPlane()
  local FSM = AbstractPlane_FSM:create(plane)

  plane.threatMissiles[1] = MissileWrapper:create(getMissileForWrapper(unit))--add missile
  plane.threatMissiles[2] = MissileWrapper:create(getMissileForWrapper(unit))--add missile
  
  plane.threatMissiles[1].getPoint = mock.getPoint
  when(mock.getPoint(plane.threatMissiles[1])).thenAnswer({x = 15000, y = 0, z = 0})
  plane.threatMissiles[1].getGuidance = mock.getGuidance
  when(mock.getGuidance(plane.threatMissiles[1])).thenAnswer(3)--ARH type
  
  plane.threatMissiles[2].getPoint = mock.getPoint
  when(mock.getPoint(plane.threatMissiles[2])).thenAnswer({x = 15000, y = 0, z = 0})
  plane.threatMissiles[2].getGuidance = mock.getGuidance
  when(mock.getGuidance(plane.threatMissiles[2])).thenAnswer(4)--SARH type
  
  plane.getPoint = mock.getPoint
  when(mock.getPoint(plane)).thenAnswer({x = 0, y = 0, z = 0})--Plane in 15km of target, so it should react 
  
  lu.assertEquals(FSM:checkMissile(plane.threatMissiles[1]), true)
  lu.assertEquals(FSM:checkMissile(plane.threatMissiles[2]), true)
end

function test_CapPlaneFSM:test_checkMissile_Fox1_3_largeRange() 
  --Fox1/Fox3 missile, should react
  local plane, group, unit, mock = getCapPlane()
  local FSM = AbstractPlane_FSM:create(plane)

  plane.threatMissiles[1] = MissileWrapper:create(getMissileForWrapper(unit))--add missile
  plane.threatMissiles[2] = MissileWrapper:create(getMissileForWrapper(unit))--add missile
  
  plane.threatMissiles[1].getPoint = mock.getPoint
  when(mock.getPoint(plane.threatMissiles[1])).thenAnswer({x = 35000, y = 0, z = 0})
  plane.threatMissiles[1].getGuidance = mock.getGuidance
  when(mock.getGuidance(plane.threatMissiles[1])).thenAnswer(3)--ARH type
  
  plane.getPoint = mock.getPoint
  when(mock.getPoint(plane)).thenAnswer({x = 0, y = 0, z = 0})--Plane in 35km of target, so it should't react
  
  lu.assertEquals(FSM:checkMissile(plane.threatMissiles[1]), false)
end

function test_CapPlaneFSM:test_checkForDefencive() 
  --should call isTrashed
  --if missile valid should call checkMissile()
  --if checkMissile() return true should return true
  --CapPlane.threatMissiles should have only valid missiles after run
  local plane, group, unit, mock = getCapPlane()
  local FSM = AbstractPlane_FSM:create(plane)

  local m1, m2 = MissileWrapper:create(getMissileForWrapper(unit)), MissileWrapper:create(getMissileForWrapper(unit))
  plane.threatMissiles[1] = m1
  plane.threatMissiles[2] = m2
  
  --checkMissile
  FSM.checkMissile = mock.checkMissile
  when(mock.checkMissile(FSM, plane.threatMissiles[2])).thenAnswer(true)
  
  --missiles mock
  plane.threatMissiles[1].isTrashed = mock.isTrashed
  when(mock.isTrashed(plane.threatMissiles[1])).thenAnswer(true)--this missile dead
  
  plane.threatMissiles[2].isTrashed = mock.isTrashed
  when(mock.isTrashed(plane.threatMissiles[2])).thenAnswer(false)--this good
  
  
  lu.assertEquals(FSM:checkForDefencive(), true)
  lu.assertEquals(#plane.threatMissiles, 1)
  
  verify(mock.isTrashed(m1))
  verify(mock.isTrashed(m2))
  
  --verify_no_call(mock.checkMissile(FSM, plane.threatMissiles[1]))--missile trashed, no call
  verify(mock.checkMissile(FSM, m2))
  
  end


function test_CapPlaneFSM:test_pushTask() 
  --verify in popTask from controller and push .task
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  plane.controller = controllerMock
  plane.getController = function() return controllerMock end
  
  local fsm = AbstractPlane_FSM:create(plane)
  fsm.task = "AbstractTask"
  
  fsm:pushTask()
  verify(m2.setTask(plane.controller, fsm.task))
end


function test_CapPlaneFSM:test_checkTask() 
  local plane, group, unit, m = getCapPlane()
  local controllerMock = Controller:create()
  
  plane.controller = controllerMock
  
  controllerMock.hasTask = m.hasTask
  when(m.hasTask(controllerMock)).thenAnswer(false)
  
  local fsm = AbstractPlane_FSM:create(plane)
  fsm.pushTask = m.pushTask
  
  fsm:checkTask()
  verify(m.hasTask(controllerMock))
  verify(m.pushTask(fsm))
  end
  
function test_CapPlaneFSM:test_checkTask_taskOk() 
  local plane, group, unit, m = getCapPlane()
  local controllerMock = Controller:create()

  plane.controller = controllerMock

  controllerMock.hasTask = m.hasTask
  when(m.hasTask(controllerMock)).thenAnswer(true)

  local fsm = AbstractPlane_FSM:create(plane)
  fsm.pushTask = m.pushTask

  fsm:checkTask()
  verify(m.hasTask(controllerMock))
  verify_no_call(m.pushTask(fsm))
end


function test_CapPlaneFSM:test_setOptions_noOverriden() 
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end

  local fsm = AbstractPlane_FSM:create(plane)
  fsm.options[CapPlane.options.ROE] = utils.tasks.command.ROE.Hold
  fsm.options[CapPlane.options.RDR] = utils.tasks.command.RDR_Using.Silent
  
  fsm:setOptions()
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ROE.Hold)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.RDR_Using.Silent)))
end

function test_CapPlaneFSM:test_setOptions_hasOverride() 
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  --other mock needed, cause we call setOptions at creation
  plane.controller = mockagne.getMock()
  
  local fsm = AbstractPlane_FSM:create(plane)
  fsm.options[CapPlane.options.ROE] = utils.tasks.command.ROE.Hold
  fsm.options[CapPlane.options.RDR] = utils.tasks.command.RDR_Using.Silent
  
  --also set option override in plane
  plane:setOption(CapPlane.options.ROE, utils.tasks.command.ROE.Free)
  
  fsm:setOptions()
  verify_no_call(plane.controller.setOption(plane.controller, unpack(utils.tasks.command.ROE.Hold)))
  verify(plane.controller.setOption(plane.controller, unpack(utils.tasks.command.ROE.Free)))
  verify(plane.controller.setOption(plane.controller, unpack(utils.tasks.command.RDR_Using.Silent)))
  end


--------------------------------------------------------
--------------------------------------------------------

test_FSM_WithDefence = {}

function test_FSM_WithDefence:test_defend_goDefencive() 
  local plane, group, unit, m, controllerMock = getCapPlane()
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  local fsm = FSM_WithDefence:create(plane)
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(true)
  
  --should switch state
  lu.assertEquals(fsm:defend(), true)
  
  lu.assertEquals(#plane.FSM_stack.data, 2)
  lu.assertEquals(plane.FSM_stack.data[plane.FSM_stack.topItem].name, "FSM_Defence")
end
--------------------------------------------------------
--------------------------------------------------------

test_FlyToPoint_fsm = {}

function test_FlyToPoint_fsm:test_creation() 
  local plane, group, unit, m = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end
  
  local point = mist.fixedWing.buildWP({x = 0, y = 0})
  local taskTable = { 
  id = 'Mission', 
    params = { 
      airborne = true,
      route = { 
        points = { 
          [1] = point
        } 
      }, 
    } 
  } 

  
  local fsm = FSM_FlyToPoint:create(plane, point)
  plane:setFSM(fsm)
  
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  lu.assertIsNil(fsm.AoA_time)
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.name, "FSM_FlyToPoint")
  lu.assertIsTable(fsm.task)
  lu.assertEquals(fsm.task, taskTable)
  lu.assertEquals(fsm.object, plane)
  
  verify(m2.setTask(controllerMock, taskTable))
  --test setup() was called and all option set
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ROE.Hold)))--weapon hold
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.React_Threat.Evade_Fire)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ECM_Using.Silent)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.RDR_Using.Silent)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.Off)))
  end

function test_FlyToPoint_fsm:test_run_goDefence()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local fsm = FSM_FlyToPoint:create(plane)
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(true)
  
  --just verify task switch(i'm lazy to do isolate test)
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  fsm:run()
  lu.assertEquals(plane:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_Defence)
  end

function test_FlyToPoint_fsm:test_run_ChangePoint()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local point1, point2 = mist.fixedWing.buildWP({x = 0, y = 0}), mist.fixedWing.buildWP({x = 10, y = 10})
  
  local fsm = FSM_FlyToPoint:create(plane, point1)
  fsm.checkForDefencive = m.checkForDefencive
  fsm.pushTask = m.pushTask
  fsm.checkAoA = m.checkAoA
  when(m.checkForDefencive(fsm)).thenAnswer(false)
  
  lu.assertEquals(fsm.task.params.route.points[1], point1)
  
  --field waypoint is present, should call pushTask
  fsm:run({waypoint = point2})
  
  --point was changed
  lu.assertEquals(fsm.task.params.route.points[1], point2)
  verify(m.pushTask(fsm))
  --should be early return
  verify_no_call(m.checkAoA(fsm))
end

function test_FlyToPoint_fsm:test_run_FixAoA()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local point1 = mist.fixedWing.buildWP({x = 10, y = 10})
  
  local fsm = FSM_FlyToPoint:create(plane, point1)
  fsm.checkForDefencive = m.checkForDefencive
  fsm.checkAoA = m.checkAoA
  when(m.checkForDefencive(fsm)).thenAnswer(false)
  when(m.checkAoA(fsm)).thenAnswer(true)
  
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  fsm:run({})

  verify_no_call(m.pushTask(fsm))
  
  lu.assertEquals(#plane.FSM_stack.data, 2)
  lu.assertEquals(plane.FSM_stack.data[plane.FSM_stack.topItem].name, "Fix AoA")
end

function test_FlyToPoint_fsm:test_run()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local point1 = mist.fixedWing.buildWP({x = 10, y = 10})
  
  local fsm = FSM_FlyToPoint:create(plane, point1)
  fsm.checkForDefencive = m.checkForDefencive
  fsm.checkAoA = m.checkAoA
  when(m.checkForDefencive(fsm)).thenAnswer(false)
  when(m.checkAoA(fsm)).thenAnswer(false)
  
  plane.callFSM = m.callFSM
  
  --field waypoint is present, should call pushTask
  fsm:run({})

  verify_no_call(m.callFSM(plane))
  verify_no_call(m.pushTask(fsm))
  end

--------------------------------------------------------
--------------------------------------------------------

test_FSM_FixAoa = {}

function test_FSM_FixAoa:test_creation() 
  --verify pushTask() called on controller with same point but altitude = 100
  --verify setOption() called with BurnerUse = On
  --check AoA_time was set on creation
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end
  
  local point = mist.fixedWing.buildWP({x = 100, y = 0})
  point.alt = 999
  local mission = { 
    id = 'Mission', 
      params = { 
        route = { 
          points = { 
            [1] = point
          } 
        }, 
      } 
    }   
  
  --check mission
  lu.assertEquals(mission.params.route.points[1].alt, 999)
  
  local fsm = FSM_FixAoa:create(plane, point)
  plane:setFSM(fsm)
  
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_FixAoa)
  
  --check altitude was corrected and original table not changed
  lu.assertEquals(fsm.task.params.route.points[1].alt, 100)
  lu.assertEquals(mission.params.route.points[1].alt, 999)
  lu.assertEquals(fsm.AoA_time, timer.getAbsTime())
  lu.assertEquals(fsm.name, "Fix AoA")
  
  verify(m2.setTask(controllerMock, fsm.task))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.On)))
  end


function test_FSM_FixAoa:test_run_goDefence()
  local plane, group, unit, m, controllerMock = getCapPlane()
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  local fsm = FSM_FixAoa:create(plane, mist.fixedWing.buildWP({x = 100, y = 0}))
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(true)
  
  --just verify task switch(i'm lazy to do isolate test)
  fsm:run()
  
  lu.assertEquals(#plane.FSM_stack.data, 2)
  lu.assertEquals(plane.FSM_stack.data[plane.FSM_stack.topItem].name, "FSM_Defence")
  end

function test_FSM_FixAoa:test_run_AoAFixed()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local fsm = FSM_FixAoa:create(plane, mist.fixedWing.buildWP({x = 100, y = 0}))
  fsm.AoA_time = timer.getAbsTime() - 16
  
  plane.popFSM = m.popFSM
  fsm.defend = m.defend 
  when(m.defend(fsm)).thenAnswer(false)
  
  --we done, should switch back
  fsm:run({})
  verify(m.popFSM(plane))
  end

function test_FSM_FixAoa:test_run_goNewPoint()
  --should call pushTask() on controller with new task, point should have corrected altitude
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end
  
  local fsm = FSM_FixAoa:create(plane, mist.fixedWing.buildWP({x = 100, y = 0}))
  local newPoint = mist.fixedWing.buildWP({x = 100, y = 0})
  newPoint.alt = 999  
  
  fsm.defend = m2.defend 
  when(m2.defend(fsm)).thenAnswer(false)
  
  fsm:run({waypoint = newPoint})
  --verify .task change, but original same
  lu.assertEquals(newPoint.alt, 999)
  lu.assertEquals(fsm.task.params.route.points[1].alt, 100)
  
  verify(m2.setTask(controllerMock, fsm.task))
  end


--------------------------------------------------------
--------------------------------------------------------
test_FSM_Formation = {}

function test_FSM_Formation:test_creation() 
  --verify object created
  --verify setup()
  --verify .task correctly created
  
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  plane.getController = m.getController
  when(m.getController(plane)).thenAnswer(controllerMock)
  
  local fsm = FSM_Formation:create(plane, 11)
  fsm.setup = m.setup
  
  local task = {
  id = 'Follow',
  params = {
    groupId = 11,
    pos = {x= -200, y = 0, z = 200},
    lastWptIndexFlag = false,
  }    
}

  plane:setFSM(fsm)
  
  lu.assertNotNil(fsm)
  lu.assertEquals(task, fsm.task)
  lu.assertEquals(fsm.name, "FSM_Formation")
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_Formation)
  
  verify(m.setup(fsm))
end

function test_FSM_Formation:test_setup() 
  --verify AoA_time was reset
  --verify options set: RoeHold, EvadeFire, BurnerOn, radarOff, ECM off
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end
  
  local fsm = FSM_Formation:create(plane, 11)
  fsm.AoA_time = 99
  
  fsm:setup()
  
  lu.assertIsNil(fsm.AoA_time)
  
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ROE.Hold)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.React_Threat.Evade_Fire)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.RDR_Using.Silent)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ECM_Using.Silent)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.Off)))
  end

function test_FSM_Formation:test_run_goDefence() 
  --state should switch
  local plane, group, unit, m, controllerMock = getCapPlane()
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  local fsm = FSM_Formation:create(plane)
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(true)
  
  --just verify task switch(i'm lazy to do isolate test)
  fsm:run()
  
  lu.assertEquals(#plane.FSM_stack.data, 2)
  lu.assertEquals(plane.FSM_stack.data[plane.FSM_stack.topItem].name, "FSM_Defence")
  end


function test_FSM_Formation:test_run_FixAoA()
  local plane, group, unit, m, controllerMock = getCapPlane()
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  local point1 = mist.fixedWing.buildWP({x = 10, y = 10})
  
  local fsm = FSM_Formation:create(plane, point1)
  fsm.checkForDefencive = m.checkForDefencive
  fsm.checkAoA = m.checkAoA
  when(m.checkForDefencive(fsm)).thenAnswer(false)
  when(m.checkAoA(fsm)).thenAnswer(true)
  
  
  --field waypoint is present, should call pushTask
  fsm:run({})
  verify_no_call(m.pushTask(fsm))
  
  lu.assertEquals(#plane.FSM_stack.data, 2)
  lu.assertEquals(plane.FSM_stack.data[plane.FSM_stack.topItem].name, "Fix AoA")
end



--------------------------------------------------------
--------------------------------------------------------
test_FSM_Defence = {}

function test_FSM_Defence:test_creation() 
  --verify object created
  --verify options threatReaction, ECM, Burner set
  --verify name
  --verify pushTask() NOT called(will be called from run())
  
  local plane, group, unit = getCapPlane()
  local controllerMock, m2 = getMockedController()
  
  plane.getController = function() return controllerMock end
  
  local fsm = FSM_Defence:create(plane)
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.name, "FSM_Defence")
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_Defence)
  
  plane:setFSM(fsm)
  
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.React_Threat.Evade_Fire)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ECM_Using.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.On)))
end

function test_FSM_Defence:test_findMissilePumpPoint() 
  --verify point is 180* deg away from missilesMeanPoint
  
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  plane.getPoint = m.getPoint
  when(m.getPoint(plane)).thenAnswer({x = 0, y = 0, z = 0})
  
  local weapon1, weapon2  = MissileWrapper:create(getMissileForWrapper(unit)), MissileWrapper:create(getMissileForWrapper(unit))
  weapon1.getPoint = m.getPoint
  when(m.getPoint(weapon1)).thenAnswer({x = -100, y = -50, z = 0}) 
  weapon2.getPoint = m.getPoint
  when(m.getPoint(weapon2)).thenAnswer({x = -100, y = 50, z = 0}) 
  
  plane.threatMissiles = {weapon1, weapon2}
  
  lu.assertEquals(FSM_Defence:create(plane):getMissilePumpPoint(), {x = 100, y = 0, z = 0})
end

function test_FSM_Defence:test_run_stopDefence() 
  --shoud popFSM()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local fsm = FSM_Defence:create(plane)
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(false)--no more threat
  fsm.pushTask = m.pushTask
  
  plane.popFSM = m.popFSM
  
  fsm:run()
  
  verify(m.popFSM(plane))
  verify_no_call(m.pushTask(fsm))
end

function test_FSM_Defence:test_run_contDefence() 
  --shoud popFSM() and callFSM()
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local fsm = FSM_Defence:create(plane)
  fsm.checkForDefencive = m.checkForDefencive
  when(m.checkForDefencive(fsm)).thenAnswer(true)--threat still there
  fsm.pushTask = m.pushTask
  fsm.getMissilePumpPoint = m.getMissilePumpPoint
  when(m.getMissilePumpPoint(fsm)).thenAnswer({x = 0, y = 0})
  
  fsm:run()
  
  verify(m.getMissilePumpPoint(fsm))
  verify(m.pushTask(fsm))
end


--------------------------------------------------------
--------------------------------------------------------

test_FSM_ForcedAttack = {}


function test_FSM_ForcedAttack:test_creation() 
  --verify instance not Nil
  --verify task populated with correct ID
  --verify options called
  --verify pushTask called

  local plane, group, unit =getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  local controllerMock, m2 = getMockedController()
  plane.getController = function() return controllerMock end
  
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  fsm:setup()
  
  lu.assertNotNil(fsm)
  lu.assertNotNil(fsm.task)
  
  local task = { 
    id = 'AttackUnit', 
    params = { 
      unitId = target:getID(), 
   } 
  }
  
  lu.assertEquals(fsm.task, task)
  lu.assertEquals(fsm.name, "FSM_ForcedAttack")
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_ForcedAttack)
  
  verify(m2.setTask(controllerMock, fsm.task))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ROE.OnlyAssigned)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.React_Threat.Evade_Fire)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.RDR_Using.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ECM_Using.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.AA_Attack_Range.Max_Range)))
  end

function test_FSM_ForcedAttack:test_teardown() 
  --plane.ourMissile is resetted
  --plane:resetTarget() called
  local plane, group, unit, m, controllerMock = getCapPlane()
  plane.target = getTarget()
  plane.ourMissile = getMissileWrapper()
  
  plane.resetTarget = m.resetTarget
  
  local fsm = FSM_ForcedAttack:create(plane, plane.target:getID())
  fsm:teardown()
  verify(plane:resetTarget())
  
  lu.assertNil(plane.ourMissile)
end

function test_FSM_ForcedAttack:test_isTargetValid_targetDead() 
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  target.isExist = m.isExist
  when(m.isExist(target)).thenAnswer(false)
  
  plane:setTarget(target)
  
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  
  lu.assertEquals(fsm:isTargetValid(), false)
end

function test_FSM_ForcedAttack:test_isTargetValid_noTarget() 
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  local fsm = FSM_ForcedAttack:create(plane, plane:getID())
  
  lu.assertIsNil(plane.target)
  lu.assertNil(fsm:isTargetValid())
end

function test_FSM_ForcedAttack:test_isTargetValid_targetOk() 
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  target.isExist = m.isExist
  when(m.isExist(target)).thenAnswer(true)
  
  plane:setTarget(target)
  
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  
  lu.assertEquals(fsm:isTargetValid(), true)
end


function test_FSM_ForcedAttack:test_run_changeTarget() 
  --.task changes
  --pushTask() called
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  plane:setTarget(target)
  
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  fsm.pushTask = m.pushTask
  
  local taskCurrent = mist.utils.deepCopy(fsm.task)
  
  fsm:run({newTarget = 10})
  
  lu.assertNotEquals(fsm.task, taskCurrent)
  lu.assertEquals(fsm.task.params.unitId, 10)
  
  verify(m.pushTask(fsm))
  end

function test_FSM_ForcedAttack:test_run_targetDead() 
  --verify resetTarget() called by .targeted == false
  --target deleted
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  plane = test_CapPlaneFSM:mockSetFSM(plane)
  
  plane:setTarget(target)
  lu.assertEquals(target.targeted, true)
  
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  plane:setFSM(fsm)
  
  fsm.isTargetValid = m.isTargetValid
  when(m.isTargetValid(fsm)).thenAnswer(nil)
  
  fsm:run({})
  lu.assertEquals(target.targeted, false)
  lu.assertEquals(plane.target, nil)

  verify(m.isTargetValid(fsm))
end

function test_FSM_ForcedAttack:test_run_targetGood() 
  --resetTarget() called
  --calls popFSM() and callFSM()
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  plane:setTarget(target)
  
  plane.popFSM = m.popFSM
  plane.callFSM = m.callFSM
 
  local fsm = FSM_ForcedAttack:create(plane, target:getID())
  fsm.isTargetValid = m.isTargetValid
  when(m.isTargetValid(fsm)).thenAnswer(true)

  fsm:run({})

  verify(m.isTargetValid(fsm))
  verify_no_call(m.popFSM(plane))
  verify_no_call(m.callFSM(plane))
end

--------------------------------------------------------
--------------------------------------------------------

test_FSM_Attack = {}

function test_FSM_Attack:test_creation() 
  --check only name, other inherited

  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  plane.controller = controllerMock
  
  local fsm = FSM_Attack:create(plane, target:getID())

  lu.assertEquals(fsm.name, "FSM_Attack")
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_Attack)
  end


function test_FSM_Attack:test_run_goDefence() 
  --verify resetTarget() called
  --no call of run() base class
  
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  plane:setTarget(target)
  
  plane.resetTarget = m.resetTarget
  
  local fsm = FSM_Attack:create(plane, target:getID())
  fsm.defend = m.defend
  when(m.defend(fsm)).thenAnswer(true)
  fsm.super = m.super
  
  fsm:run({})
  verify(m.resetTarget(plane))
  verify(m.defend(fsm))
  verify_no_call(m.super(any()))
end

function test_FSM_Attack:test_run() 
  --verify  resetTarget() not called
  --call of run() base class
  
  local plane, group, unit, m, controllerMock = getCapPlane()
  local target, tgtUnit, radarUnit = getTarget()
  
  plane:setTarget(target)
  
  plane.resetTarget = m.resetTarget
  
  local fsm = FSM_Attack:create(plane, target:getID())
  fsm.defend = m.defend
  when(m.defend(fsm)).thenAnswer(false)
  
  local baseClass = FSM_ForcedAttack:create(plane, target:getID())
  baseClass.run = m.run
  fsm.super = m.super
  when(m.super(fsm)).thenAnswer(baseClass)
  
  fsm:run({})
  verify_no_call(m.resetTarget(plane))
  verify(m.defend(fsm))
  verify(m.run(fsm, {}))
end


--------------------------------------------------------
--------------------------------------------------------

test_FSM_WVR = {}

function test_FSM_WVR:test_creation() 
  --object created
  --correct name
  --task not nil
  --task was sended to DCS CONTROLLER
  local plane, group, unit, m, controllerMock = getCapPlane()
  
  plane.controller = controllerMock
  
  local fsm = FSM_WVR:create(plane)
  lu.assertNotNil(fsm)
  lu.assertEquals(fsm.name, "FSM_WVR")
  lu.assertEquals(fsm.enumerator, AbstractPlane_FSM.enumerators.FSM_WVR)
  lu.assertTable(fsm.task)
  end


function test_FSM_WVR:test_setup() 
  --verify all option set
  local plane, group, unit, m = getCapPlane()
  
  local controllerMock, m2 = getMockedController()
  plane.getController = function() return controllerMock end
  
  local fsm = FSM_WVR:create(plane)
  fsm:setup()
  
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ROE.Free)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.React_Threat.Evade_Fire)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.RDR_Using.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.ECM_Using.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.Burner_Use.On)))
  verify(m2.setOption(controllerMock, unpack(utils.tasks.command.AA_Attack_Range.Max_Range)))
  end

--------------------------------------------------------
--------------------------------------------------------
test_FlyOrbit = {}
test_FlyOrbit.test_taskCircle = { 
 id = 'Orbit', 
 params = { 
   pattern = "Circle",
   point = {x = 0, y = 0},
   speed = 300,
   altitude = 8000
 } 
}

function test_FlyOrbit:test_creation() 
  local plane = getCapPlane()
  
  local inst = FSM_FlyOrbit:create(plane, test_FlyOrbit.test_taskCircle)
  lu.assertNotNil(inst)
  lu.assertEquals(inst.enumerator, AbstractPlane_FSM.enumerators.FSM_FlyOrbit)
  lu.assertEquals(inst.name, "FSM_FlyOrbit")
  lu.assertEquals(inst.task, test_FlyOrbit.test_taskCircle)
end

function test_FlyOrbit:test_setup() 
  --verify task send to controller
  local plane = getCapPlane()
  local m = mockagne.getMock()
  
  plane.controller = m
  
  local inst = FSM_FlyOrbit:create(plane, test_FlyOrbit.test_taskCircle)
  inst:setup()
  verify(m.setTask(m, test_FlyOrbit.test_taskCircle))
end
--------------------------------------------------------
--------------------------------------------------------
test_FSM_PlaneRTB = {}


function test_FSM_PlaneRTB:test_creation() 
  local plane = getCapPlane()
  plane.getPoint = function() return {x = 99, y = 100, z = 88} end
  
  local wp = mist.fixedWing.buildWP({x = 1, y = 2})
  wp.type = "Land"
  local inst = FSM_PlaneRTB:create(plane, wp)
  lu.assertNotNil(inst)
  lu.assertEquals(inst.enumerator, AbstractPlane_FSM.enumerators.FSM_PlaneRTB)
  lu.assertEquals(inst.name, "FSM_PlaneRTB")
  
  --first point is turning point with current pos
  lu.assertEquals(inst.task.params.route.points[1].x, plane.getPoint().x)
  lu.assertEquals(inst.task.params.route.points[1].y, plane.getPoint().z)
  lu.assertEquals(inst.task.params.route.points[1].alt, plane.getPoint().y)
  lu.assertEquals(inst.task.params.route.points[1].type, "Turning Point")
  
  --second is actual land point
  lu.assertEquals(inst.task.params.route.points[2], wp)
end


local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()