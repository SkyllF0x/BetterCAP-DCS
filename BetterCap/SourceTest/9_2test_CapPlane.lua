dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_FighterEntity_FSM = {}

-----------------------------------------------------------

test_capPlane = {}

local originalEventHandler = mist.utils.deepCopy(EventHandler)
local original_getAbsTime = timer.getAbsTime

function test_capPlane:teardown() 
  for name, val in pairs(EventHandler)do 
    if type(EventHandler[name]) == "function" then 
      EventHandler[name] = val
    end
  end
  
  timer.getAbsTime = original_getAbsTime
end

function test_capPlane:test_creation() 
  --1)initialize fsm with FlyToPoint
  --2)add instance to eventHandler
  --3)check derived methods
  
  local unit, group, m = Unit:create(), Group:create(), mockagne.getMock()
  
  EventHandler:create().registerObject = m.registerObject
  
  group.getUnit = m.getUnit
  group.getUnits = m.getUnits
  
  --groupID and unitID should be different
  local UNIT_ID, GROUP_ID = 1, 2
  group.getID = m.getID
  when(m.getID(group)).thenAnswer(GROUP_ID)
  unit.getID = m.getID
  when(m.getID(unit)).thenAnswer(UNIT_ID)
  
  when(m.getUnit(group, 1)).thenAnswer(unit)
  when(m.getUnits(group)).thenAnswer({unit})
  
  group.getController = m.getController
  when(m.getController(group)).thenAnswer(m)
  
  unit.inAir = function() return false end
  
  local inst = CapPlane:create(group)
  
  lu.assertNotNil(inst)
  lu.assertNumber(inst.groupID)
  lu.assertEquals(inst.threatMissiles, {})
  lu.assertNil(inst.ourMissile)
  
  lu.assertEquals(inst.isAirborne, false)
  lu.assertEquals(inst.waitAfterLiftOff, 60)
  
  lu.assertEquals(inst.overridenOptions, {})
  lu.assertNotNil(inst.FSM_stack)
  lu.assertEquals(#inst.FSM_stack.data, 1) --stack should not be empty
  lu.assertNotNil(inst.FSM_args)
  lu.assertNil(inst.target)
  
  verify(m.registerObject(any(), inst))
  verify(m.getController(group))
  
  lu.assertTable(inst:getPoint())
  lu.assertTable(inst:getPosition())
  lu.assertTable(inst:getVelocity())
  lu.assertTable(inst:getController())
  lu.assertNumber(inst:getID())
  lu.assertNumber(inst:getGroupID())
  lu.assertString(inst:getName())
  lu.assertString(inst:getTypeName())
  lu.assertTrue(inst:isExist())
  --check getID() return unitID and getGroupID() return groupID
  lu.assertEquals(inst:getID(), UNIT_ID)
  lu.assertEquals(inst:getGroupID(), GROUP_ID)
  
end



function test_capPlane:test_creationInAir() 
  local unit, group = Unit:create(), Group:create()
  local m = mockagne.getMock()
  
  group.getUnit = function() return unit end
  group.getController = function() return m end

  unit.inAir = function() return true end
  
  local capPlane = CapPlane:create(group)
  
  --shorter time cause we in air 
  lu.assertEquals(capPlane.waitAfterLiftOff, 5)
end 

function test_capPlane:test_getController()
  --verify getController() return group level controller instead of unit
  local unit, group = Unit:create(), Group:create()
  local m = mockagne.getMock()
  
  group.getUnit = function() return unit end
  group.getController = function() return m end

  local capPlane = CapPlane:create(group)
  
  lu.assertEquals(capPlane:getController(), m)
end

function test_capPlane:test_inAir_alreadyAirborne() 
  local plane = getCapPlane()
  plane.isAirborne = true
  plane.liftOffTime = 30
  
  lu.assertTrue(plane:inAir())
end

function test_capPlane:test_inAir() 
  local plane = getCapPlane()
  plane.isAirborne = false
  plane.liftOffTime = nil
  timer.getAbsTime = function() return 30 end
  
  --plane not in air, nothing set
  plane.dcsObject.inAir = function() return false end
  lu.assertFalse(plane:inAir())
  lu.assertNil(plane.liftOffTime)
  
  --plane liftOff
  plane.dcsObject.inAir = function() return true end
  lu.assertFalse(plane:inAir())
  lu.assertEquals(plane.liftOffTime, 30)
  
  --not enough time passed
  timer.getAbsTime = function() return 30+5 end
  lu.assertFalse(plane:inAir())
  
  --time passed
  timer.getAbsTime = function() return 30+65 end
  lu.assertTrue(plane:inAir())
  lu.assertTrue(plane.isAirborne)
  end

function test_capPlane:test_isExist_true() 
  --calls object isExist
  --return true
  local plane, group, unit, mock, controller = getCapPlane()
  
  unit.isExist = mock.isExist
  when(mock.isExist(unit)).thenAnswer(true)
  
  EventHandler:create().removeObject = mock.removeObject 
  
  lu.assertEquals(plane:isExist(), true)
  verify(mock.isExist(unit))
  verify_no_call(mock.removeObject(EventHandler:create(), plane))
end

function test_capPlane:test_isExit_fail() 
  --calls object isExist
  --calls eventHandler to deregister instance
  --call resetTarget()
   local plane, group, unit, mock, controller = getCapPlane()
  
  unit.isExist = mock.isExist
  when(mock.isExist(unit)).thenAnswer(false)
  
  plane.resetTarget = mock.resetTarget
  
  EventHandler:create().removeObject = mock.removeObject 
  
  lu.assertEquals(plane:isExist(), false)
  verify(mock.isExist(unit))
  verify(mock.removeObject(EventHandler:create(), plane))
  verify(plane:resetTarget())
end

function test_capPlane:test_isExit_noObject() 
  --no call object isExist
  --calls eventHandler to deregister instance
  local plane, group, unit, mock, controller = getCapPlane()
  
  unit.isExist = mock.isExist
  
  --delete object
  plane.dcsObject = nil
  
  EventHandler:create().removeObject = mock.removeObject 
  
  lu.assertEquals(plane:isExist(), false)
  verify_no_call(mock.isExist(unit))
  verify(mock.removeObject(EventHandler:create(), plane))
end


function test_capPlane:test_engineOffEvent() 
  --call with wrong object do nothing
  --call with correct object set shutdown flag to true
  local plane, group, unit, mock, controller = getCapPlane()
  
  local eventUnit = Unit:create()
  
  --return different id for comparison
  eventUnit.getID = mock.getID
  when(mock.getID(eventUnit)).thenAnswer(99)
  
  unit.getID = mock.getID
  when(mock.getID(unit)).thenAnswer(80)
  
  local e_wrongObj = {
    id = 19,
    time = 0,
    initiator = eventUnit,
  }
  
  local e = {
    id = 19,
    time = 0,
    initiator = unit,
  }
  
  lu.assertFalse(plane.shutdown)
  plane:engineOffEvent(e_wrongObj)
  lu.assertEquals(plane.shutdown, false)
  
  plane:engineOffEvent(e)
  lu.assertEquals(plane.shutdown, true)
end


function test_capPlane:test_shotEvent_wrongObj() 
  --call with wrong object as target do nothing
  local plane, group, unit, mock, controller = getCapPlane()
  
  local eventUnit = Unit:create()
  
  local e_wrongObj = {
    id = 1,
    time = 0,
    initiator = eventUnit,
    weapon = Weapon:create()
  }
  
  lu.assertEquals(plane.threatMissiles, {})
  lu.assertEquals(plane.ourMissile, nil)
  
  plane:shotEvent(e_wrongObj)
  lu.assertEquals(plane.threatMissiles, {})
  lu.assertEquals(plane.ourMissile, nil)
end

function test_capPlane:test_shotEvent_targeted() 
  --weapon is missile and guiding to us
  --add this weapon wrapped in MissileWrapper to self.threatMissiles
  local plane, group, unit, mock, controller = getCapPlane()
  
  local weapon = getMissileForWrapper(unit)

  local e = {
    id = 1,
    time = 0,
    initiator = Unit:create(), 
    weapon = weapon
  }
  
  lu.assertEquals(plane.threatMissiles, {})
  plane:shotEvent(e)
  lu.assertEquals(#plane.threatMissiles, 1)
end

function test_capPlane:test_shotEvent_shooter() 
  --weapon is missile and we shooter
  --this weapon wrapped in MissileWrapper to self.ownMissiles
  local plane, group, unit, mock, controller = getCapPlane()
  
  local weapon = getMissileForWrapper(Unit:create())
  
  local e = {
    id = 1,
    time = 0,
    initiator = unit, --we shooter
    weapon = weapon
  }
  
  lu.assertEquals(plane.ourMissile, nil)
  plane:shotEvent(e)
  lu.assertTable(plane.ourMissile)
end

function test_capPlane:test_shotEvent_noWeapon_created() 
  --weapon is missile and we shooter
  --this weapon wrapped in MissileWrapper to self.ownMissiles
  local plane, group, unit, mock, controller = getCapPlane()
  
  local weapon = Weapon:create()
  --weapon will have wrong guidance, so wrapper won't created
  weapon.getDesc = mock.getDesc
  when(mock.getDesc(weapon)).thenAnswer({guidance = 99})
  
  local e = {
    id = 1,
    time = 0,
    initiator = unit, --we shooter
    weapon = weapon
  }
  
  lu.assertNil(MissileWrapper:create(weapon))--no weapon created
  
  lu.assertEquals(plane.ourMissile, nil)
  plane:shotEvent(e)
  lu.assertNil(plane.ourMissile)
end

function test_capPlane:test_getFuel() 
  --call getFuel on dcsObject
  local plane, group, unit, m, controller = getCapPlane()
  
  unit.getFuel = m.getFuel
  plane:getFuel()
  verify(m.getFuel(unit))
end

function test_capPlane:test_getBestMissile() 
  --calls getAmmo()
  --return table with most dangerousMissile
  local ammoTbl = {
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "test1"}}, 
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "AIM_9"}},
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "P_77"}},
  }
  
  local plane, group, unit, m, controller = getCapPlane()
  
  unit.getAmmo = m.getAmmo
  when(m.getAmmo(unit)).thenAnswer(ammoTbl)
  
  plane:getAmmo()
  lu.assertEquals(plane:getBestMissile(), utils.WeaponTypes["P_77"])
end

function test_capPlane:test_getBestMissile_fromAir() 
  --calls getAmmo()
  --most valuable missile in air now
  --return table with missile in air
  local ammoTbl = {
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "test1"}}, 
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "AIM_9"}},
  }
  
  local plane, group, unit, m, controller = getCapPlane()
  local missile = getMissileWrapper()
  missile.getTypeName = function() return "P_77" end
  plane.ourMissile = missile
  
  unit.getAmmo = m.getAmmo
  when(m.getAmmo(unit)).thenAnswer(ammoTbl)
  plane:getAmmo()
  
  lu.assertEquals(plane:getBestMissile(), utils.WeaponTypes["P_77"])
end

function test_capPlane:test_getAmmo() 
  --calls getAmmo()
  --return table with all A/A weapons by type(ARH/SARH/IR) 
  local ammoTbl = {
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "test1"}}, 
    {count = 3, desc = {guidance = Weapon.GuidanceType.RADAR_ACTIVE, typeName = "test2"}},
    {count = 1, desc = {guidance = Weapon.GuidanceType.RADAR_SEMI_ACTIVE, typeName = "test3"}},
    {count = 1, desc = {guidance = Weapon.GuidanceType.IR, typeName = "test4"}},
  }
  
  local plane, group, unit, m, controller = getCapPlane()
  
  unit.getAmmo = m.getAmmo
  when(m.getAmmo(unit)).thenAnswer(ammoTbl)
  
  local result = plane:getAmmo()
  
  lu.assertEquals(result[Weapon.GuidanceType.RADAR_ACTIVE], 3)
  lu.assertEquals(result[Weapon.GuidanceType.IR], 2)
  lu.assertEquals(result[Weapon.GuidanceType.RADAR_SEMI_ACTIVE], 1)
end

function test_capPlane:test_getTargets() 
  --calls getTargets()
  local plane, group, unit, m, controller = getCapPlane()
  local targetUnit = Unit:create()
  local detectionTbl = {
    object = targetUnit, --the target
    visible = false, 
    type = false,
    distance = false}
  
  plane.controller = controller
  
  controller.getDetectedTargets = m.getDetectedTargets
  when(m.getDetectedTargets(controller, Controller.Detection.VISUAL, 
      Controller.Detection.OPTIC, Controller.Detection.RADAR, 
      Controller.Detection.IRST, Controller.Detection.RWR)).thenAnswer({detectionTbl})
  
  local result = plane:getDetectedTargets()
  
  lu.assertEquals(#result, 1)
  lu.assertEquals(result[1], detectionTbl)
end

function test_capPlane:test_getNails() 
  --calls getTargets() with RWR detection type
  --return array with targets wrapped in DCS_Wrapper
  local plane, group, unit, m = getCapPlane()
  
  plane.controller.getDetectedTargets = m.getDetectedTargets
  
  plane:getNails()
  verify(m.getDetectedTargets(plane.controller, Controller.Detection.RWR))
end

function test_capPlane:test_registerGroup_registerElement() 
  --add element to myElement
  --plane.element and element is same
  --add group to myGroup
  --plane.myGroup and group is same
  
  local plane, group, unit, m, controller = getCapPlane()
  
  --just table, in real should be a capGroup
  local capGroupMock, elementMock = Group:create(), Group:create()  
  plane:registerGroup(capGroupMock)
  plane:registerElement(elementMock)
  lu.assertIs(capGroupMock, plane.myGroup)
  lu.assertIs(elementMock, plane.myElement)
  end

function test_capPlane:test_setTarget() 
  --plane.target is target
  --plane.target and target is same
  --target.targeted is true after
  local plane, group, unit, m, controller = getCapPlane()
  local target = getTarget()
  
  lu.assertEquals(target.targeted, false)
  
  plane:setTarget(target)
  lu.assertIs(target, plane.target)
  lu.assertEquals(target.targeted, true)
end

function test_capPlane:test_setTarget_overwrite() 
  --rewrite original target
  --new target has .targeted == true
  --old target.targeted == false
  local plane, group, unit, m, controller = getCapPlane()
  local target1 = getTarget()
  local target2 = getTarget()
  
  lu.assertEquals(target1.targeted, false)
  lu.assertEquals(target2.targeted, false)
  
  plane:setTarget(target1)
  lu.assertIs(target1, plane.target)
  lu.assertEquals(target1.targeted, true)
  
  plane:setTarget(target2)
  
  lu.assertEquals(target2.targeted, true)
  lu.assertEquals(target1.targeted, false)
end


function test_capPlane:test_resetTarget() 
  --plane.target is nil
  --target.targeted is false
  local plane, group, unit, m, controller = getCapPlane()
  local target = getTarget()
  
  lu.assertEquals(target.targeted, false)
  
  plane:setTarget(target)
  lu.assertIs(target, plane.target)
  lu.assertEquals(target.targeted, true)
  
  --now reset
  plane:resetTarget()
  lu.assertNil(plane.target)
  lu.assertEquals(target.targeted, false)
end

function test_capPlane:test_resetTargetNoTgt() 
  --no target is set, just return
  local plane, group, unit, m, controller = getCapPlane()
  --now reset
  plane:resetTarget()
  end

function test_capPlane:test_canDropMissile_noMsl() 
  --no missile has been launched
  local plane = getCapPlane()
  plane.ourMissile = nil
  
  lu.assertTrue(plane:canDropMissile())
end

function test_capPlane:test_canDropMissile_MslTrashedOrActive() 
  --missile has been launched
  --return true ause missile active
  --clear missile
  local plane = getCapPlane()
  local missile = getMissileWrapper()
  plane.ourMissile = missile
  
  missile.isActive = function() return true end
  plane:updateOurMissile()
  
  lu.assertTrue(plane:canDropMissile())
  lu.assertNil(plane.ourMissile)
  end

function test_capPlane:test_setOption()
  --option added to .overridenOptions
  --controller setOption called
  --when call with nil, option delete and setOption() called
  local plane, group, unit = getCapPlane()
  local controller, m2 = getMockedController()
  plane.getController = function() return controller end
  
  plane:setOption(CapPlane.options.ROE, utils.tasks.command.ROE.Hold)
  
  lu.assertEquals(plane.overridenOptions[CapPlane.options.ROE], utils.tasks.command.ROE.Hold)
  verify(m2.setOption(controller, unpack(utils.tasks.command.ROE.Hold)))
end

function test_capPlane:test_setOption_delete()
  --pass nil delete option
  --setOption() on FSM called
  
  local plane, group, unit, m, controller = getCapPlane()
  
  plane.FSM_stack:getCurrentState().setOptions = m.setOptions
  
  plane.overridenOptions[CapPlane.options.ROE] = utils.tasks.command.ROE.Hold
  lu.assertEquals(plane.overridenOptions[CapPlane.options.ROE], utils.tasks.command.ROE.Hold)
  
  plane:setOption(CapPlane.options.ROE, nil)
  lu.assertEquals(plane.overridenOptions[CapPlane.options.ROE], nil)
  verify(m.setOptions(plane.FSM_stack:getCurrentState()))
end


function test_capPlane:test_resetOptions()
  --.overridenOptions reset to empty
  --calls setOptions() on current FSM
  
  local plane, group, unit, m, controller = getCapPlane()
  
  plane.FSM_stack:getCurrentState().setOptions = m.setOptions
  
  unit.getController = m.getController
  when(m.getController(unit)).thenAnswer(controller)
  
  plane:setOption(CapPlane.options.ROE, utils.tasks.command.ROE.Hold)
  lu.assertNotEquals(plane.overridenOptions, {})
  
  plane:resetOptions()
  lu.assertEquals(plane.overridenOptions, {})
  verify(m.setOptions(plane.FSM_stack:getCurrentState()))
end



--Derived from FighterEntity_FSM test
function test_capPlane:test_setFSM_Arg() 
  local plane = getCapPlane()
  
  plane:setFSM_Arg("target", {1,2,3})
  
  lu.assertEquals(plane.FSM_args.target, {1, 2, 3})
  end

function test_capPlane:test_setFSM() 
  --add to stack and call it
  local plane = getCapPlane()
  local m = mockagne.getMock()
  
  plane.FSM_stack.push = m.push
  plane.FSM_stack.run = m.run
  
  local args = {testArg = 1}
  plane.FSM_args = args
  
  local state = AbstractState:create(plane)
  plane:setFSM(state)
  verify(m.push(plane.FSM_stack, state))
  verify(plane.FSM_stack:run(args))
end

function test_capPlane:test_clearFSM() 
  local plane = getCapPlane()
  local m = mockagne.getMock()
  
  plane.FSM_stack.clear = m.clear
  
  local state = AbstractState:create(plane)
  plane:clearFSM()
  verify(m.clear(plane.FSM_stack))
end

function test_capPlane:test_callFSM() 
  --call active state with FSM_args
  --call checkTask from active state
  --vipe FSM_args
  
  local plane = getCapPlane()
  local m = mockagne.getMock()
  local state = AbstractState:create(plane)
  
  state.run = m.run
  state.checkTask = m.checkTask
  
  plane:setFSM(state)
  plane.FSM_args = {a = "something", b = "somestuff"}
  
  plane:callFSM()
  verify(m.run(state, plane.FSM_args))
  verify(m.checkTask(state))
  
  lu.assertEquals(plane.FSM_args, {})
end

function test_capPlane:test_popFSM() 
  --return to previous state and call it
  local plane = getCapPlane()
  local m = mockagne.getMock()
  
  plane.FSM_stack.pop = m.pop
  plane.FSM_stack.run = m.run
  
  local args = {testArg = "test"}
  plane.FSM_args = args
  
  plane:popFSM()
  
  verify(plane.FSM_stack:pop())
  verify(plane.FSM_stack:run(args))
end

--return enumerator of current FSM state
function test_capPlane:test_getCurrentFSM() 
  local plane = getCapPlane()
  local m = mockagne.getMock()
  
  plane.FSM_stack.getStateEnumerator = m.getStateEnumerator
  
  plane:getCurrentFSM()
  verify(m.getStateEnumerator(plane.FSM_stack))
end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()