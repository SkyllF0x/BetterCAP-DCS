dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

function setFSM_NoCall(element, state) 
  --just place in accecible place, without calling setup
  element.setState = state
end

--mock timer.getAbsTime and increment value it return, so elements update() can called
local timerVal = 0
function mockTimer() 
  --just place in acceble place, without calling setup
  timer.getAbsTime = function() return timerVal end
  timerVal = timerVal + 1
  
  if timerVal > 5 then 
    timerVal = 0
  end
end

local originalFunc = utils.missileForAlt

--disable interpolation for alt
function disableMissileInterpolation() 
  utils.missileForAlt = function(missile, alt) return missile end
end

function revertMissileInterpolation() 
  utils.missileForAlt = originalFunc
  end


test_FSM_Element_Tactic = {}

function test_FSM_Element_Tactic:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_Tactic:teardown() 
  revertMissileInterpolation()
end

function test_FSM_Element_Tactic:test_inDefending() 
  --return true if all planes in AbstractPlane_FSM.enumerators.FSM_Defence
  local element = getElement()
  element.planes[1].getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  local fsm = FSM_Element_Tactic:create(element)
  
  lu.assertTrue(fsm:inDefending())
end

function test_FSM_Element_Tactic:test_inDefending_2Planes() 
  --return true if all planes in AbstractPlane_FSM.enumerators.FSM_Defence
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local element = CapElement:create({plane1, plane2})
  plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_ForcedAttack end
  
  local fsm = FSM_Element_Tactic:create(element)
  
  lu.assertFalse(fsm:inDefending())
  
  plane2.getCurrentFSM = plane1.getCurrentFSM
  lu.assertTrue(fsm:inDefending())
  end

function test_FSM_Element_Tactic:test_inWVR() 
  --return true if  one of planes close to target to 15km
  local group = getCapGroup()
  local target1 = getTarget()
  group.target = TargetGroup:create({target1})
  
  local element, plane = group.elements[1], group.elements[1].planes[1]
  local m = mockagne.getMock()
  
  plane.getPoint = m.getPoint
  when(plane:getPoint()).thenAnswer({x = 0, z = 0, y = 0})
  
  target1.getPoint = m.getPoint
  when(target1:getPoint()).thenAnswer({x = 19999, z = 0, y = 0})
  
  local fsm = FSM_Element_Tactic:create(element)
  mockTimer()
  fsm:update()

  lu.assertFalse(fsm:inWVR())
  verify(plane:getPoint())
  verify(target1:getPoint())
end

function test_FSM_Element_Tactic:test_inWVR_2planes2TargetsTrue_ThenSeparate() 
  --plane1 if ok, but plane2 is close enough
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local target1 = getTarget()
  local target2 = getTarget()
  group.target = TargetGroup:create({target1, target2})
  
  local element = group.elements[1]

  plane1.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 5000, y = 0, z = 0} end
  
  target1.getPoint = function() return {x = 16000, y = 0, z = 0} end
  target2.getPoint = function() return {x = 99999, y = 0, z = 0} end--too far from allplanes
  
  local fsm = FSM_Element_Tactic:create(element)
  lu.assertTrue(fsm:inWVR())
  
  target1.getPoint = target2.getPoint --also to far now
  
  mockTimer()
  fsm:update()
  lu.assertFalse(fsm:inWVR())
end

function test_FSM_Element_Tactic:test_isDefending_ALRHigh() 
  --inDefending() CALLED and returned true
  --setFSM() with FSM_Element_DefendingHigh
  --return true
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local m = mockagne.getMock()
  element.FSM_stack.run = m.run
  group.alr = CapGroup.ALR.High
  
  local fsm = FSM_Element_Tactic:create(element)
  fsm.inDefending = m.inDefending
  when(fsm:inDefending()).thenAnswer(true)
  
  lu.assertTrue(fsm:isDefending())
  verify(fsm:inDefending())
  
  lu.assertEquals(element.FSM_stack:getCurrentState().name, "DefendingHigh")
end

function test_FSM_Element_Tactic:test_isDefending_ALRNormal() 
  --inDefending() CALLED and returned true
  --setFSM() with FSM_Element_DefendingHigh
  --return true
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local m = mockagne.getMock()
  
  element.FSM_stack.run = m.run
  group.alr = CapGroup.ALR.Normal
  
  local fsm = FSM_Element_Tactic:create(element)
  fsm.inDefending = m.inDefending
  when(fsm:inDefending()).thenAnswer(true)
  
  lu.assertTrue(fsm:isDefending())
  verify(fsm:inDefending())
  
  lu.assertEquals(element:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  lu.assertEquals(element.FSM_stack:getCurrentState().name, "Defending")
  end


function test_FSM_Element_Tactic:test_isWVR()
  --inWVR called and return true
  --setFSM() to FSM_Element_WVR
  --return true
  
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local m = mockagne.getMock()
  
  local fsm = FSM_Element_Tactic:create(element)
  fsm.inWVR = m.inWVR
  when(fsm:inWVR()).thenAnswer(true)
  element.setFSM = setFSM_NoCall
  
  lu.assertTrue(fsm:isWVR())
  verify(fsm:inWVR())
  
  lu.assertEquals(element.setState.enumerator, CapElement.FSM_Enum.FSM_Element_WVR)
  end


function test_FSM_Element_Tactic:test_distanceToMar()
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local target = getTargetGroup()
  local m = mockagne.getMock()
  
  group.target = target
  
  local missile = {MAR = 10000, MaxRange = 20000}
  target.getHighestThreat = m.getHighestThreat
  when(target:getHighestThreat()).thenAnswer(missile)
  target.getPoint = function() return {x = 11000, y = 0, z = 0} end
  for _, t in pairs(target:getTargets()) do 
    t.getPoint = target.getPoint
  end
  
  element.planes[1].getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local fsm = FSM_Element_Tactic:create(element)
  mockTimer()
  fsm:update()
  lu.assertEquals(fsm:distanceToMar(), 1000)
  
  --inside mar 
  element.planes[1].getPoint = function() return {x = 10000, y = 0, z = 0} end
  mockTimer()
  fsm:update()
  lu.assertEquals(fsm:distanceToMar(), -9000)
end

function test_FSM_Element_Tactic:test_updateSpeedAlt() 
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  local target = getTargetGroup()
  target.getPoint = function() return {x = 0, y = 5000, z = 0} end
  
  group.target = target
  
  local fsm = FSM_Element_Tactic:create(element)
  
  --case1: inside 20nm, go to target alt
  fsm.distance2Target = 30000
  fsm.speed = 300
  fsm.alt = 9999
  
  fsm:updateSpeedAlt()
  lu.assertEquals(fsm.speed, 300)
  lu.assertEquals(fsm.alt, 5000)
  
  --case2: target to low, use 1000m, also change speed
  fsm.distance2Target = 50000
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  fsm:updateSpeedAlt()
  lu.assertEquals(fsm.speed, 250)
  lu.assertEquals(fsm.alt, 1000)
  
  --case3: alt delta high, target high, use target alt or 10000, update speed
  target.getPoint = function() return {x = 0, y = 12000, z = 0} end
  
  fsm:updateSpeedAlt()
  lu.assertEquals(fsm.speed, 300)
  lu.assertEquals(fsm.alt, 10000)
  
  --case3: alt delta not enough, no changes
  target.getPoint = function() return {x = 0, y = 10000, z = 0} end
  
  fsm:updateSpeedAlt()
  lu.assertEquals(fsm.speed, 300)
  lu.assertEquals(fsm.alt, 10000)
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_FSM_Element_SkateGrinder = {}

function test_FSM_Element_SkateGrinder:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_Tactic:teardown() 
  revertMissileInterpolation()
  end

function test_FSM_Element_SkateGrinder:test_creation() 
  --verify object, name, enum, alr check
  local group = getCapGroupNoRun()
  local element = group.elements[1]
  group.alr = CapGroup.ALR.High
  
  local fsm = FSM_Element_SkateGrinder:create(element)
  lu.assertEquals(fsm.object, element)
  lu.assertEquals(fsm.enumerator, CapElement.FSM_Enum.FSM_Element_SkateGrinder)
  lu.assertEquals(fsm.name, "SkateGrinder")
  lu.assertEquals(fsm.ALR_check, fsm.checkAttackHigh)
end

function test_FSM_Element_SkateGrinder:test_setup() 
  --setOption() called for every plane with RDR use, ECM use, Burner Use
  --planes fsm cleared, and set to FSM_FlyToPoint(without call)
  local m = mockagne.getMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  local element = group.elements[1]
  element.FSM_stack.run = m.run
  
  
  group.FSM_stack.run = m.run
  plane1.setOption = m.setOption
  plane2.setOption = m.setOption
  
  local fsm = FSM_Element_SkateGrinder:create(element)
  fsm:setup()
  
  verify(plane1:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On))
  verify(plane1:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On))
  verify(plane1:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On))
  verify(plane2:setOption(CapPlane.options.RDR, utils.tasks.command.RDR_Using.On))
  verify(plane2:setOption(CapPlane.options.ECM, utils.tasks.command.ECM_Using.On))
  verify(plane2:setOption(CapPlane.options.BurnerUse, utils.tasks.command.Burner_Use.On))
  
  --verify stack was cleared
  lu.assertEquals(plane1.FSM_stack.topItem, 1)
  lu.assertEquals(plane2.FSM_stack.topItem, 1)
  
  --verify state was set
  lu.assertEquals(plane1:getCurrentFSM(), AbstractPlane_FSM.enumerators.FSM_FlyToPoint)
  
  --verify no run call
  verify_no_call(group.FSM_stack:run())
end




function test_FSM_Element_SkateGrinder:test_checkForGrinder() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  
  local fsm = FSM_Element_SkateGrinder:create(element)
  
  --with singleton always false
  lu.assertEquals(fsm:checkForGrinder(1, 55555), false)
  
  --when 2 planes, return true only if ourRange > 40000
  lu.assertEquals(fsm:checkForGrinder(2, 20000), false)
  lu.assertEquals(fsm:checkForGrinder(2, 41111), true)
  
  --when > 2 planes, return true 
  lu.assertEquals(fsm:checkForGrinder(3, 41111), true)
  lu.assertEquals(fsm:checkForGrinder(4, 20000), true)
end

function test_FSM_Element_SkateGrinder:test_checkRequrements() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  
  local fsm = FSM_Element_SkateGrinder:create(element)
  
  fsm.checkForGrinder = function() return true end
  
  --no disadvantage
  lu.assertEquals(fsm:checkRequrements(40000, 40000, 1), true)
  --ratio disadvantage
  lu.assertEquals(fsm:checkRequrements(100000*1.3, 100000, 1), false)
  --ratio disadvantage, but delta range not great
  lu.assertEquals(fsm:checkRequrements(19999, 10000, 1), true)
  
  --grinder also affects
  fsm.checkForGrinder = function() return false end
  lu.assertEquals(fsm:checkRequrements(1, 10000, 1), false)
  end




function test_FSM_Element_SkateGrinder:test_coldOps() 
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  lu.assertEquals(#group.elements, 2)
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_SkateGrinder:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_SkateGrinder:create(element2)
  element2:setFSM_NoCall(state2)
  
  --stage1: element1 defending, second element pump, inside MAR just defend
  plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  local defendState = FSM_Element_Defending:create(element1, state1)
  defendState.getTimer = function() return 0 end
  element1:setFSM_NoCall(defendState)
  
  local pumpState = FSM_Element_Pump:create(element2, state2)
  pumpState.getTimer = defendState.getTimer
  element2:setFSM_NoCall(pumpState)

  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage2: both element pump
  plane1.getCurrentFSM = CapPlane.getCurrentFSM
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage3: element1 5nm from MAR, second element pump, continue
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 12000, y = 0, z = 0} end
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 5000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage4: element1 separated, second element pump, return to normal ops
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 5000 + 13001, y = 0, z = 0} end

  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage5: element2 60 sec pump passed, stay in pump
  pumpState.getTimer = function() return 99 end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage6: element1 go defend again, bu outside MAR + 5, just defending
  plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage7: element1 inside MAR + 5nm, timer > 60 elements switch to delouse
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 5000, y = 0, z = 0} end
  element1.setFSM_NoCall = setFSM_NoCall
  element2.setFSM_NoCall = setFSM_NoCall
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Delouse)
  lu.assertEquals(element2.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Delouse)
  
  end

function test_FSM_Element_SkateGrinder:test_AttackPumpCycle() 
  --verify no inf cycle happened, during transitions
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 500, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_SkateGrinder:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_SkateGrinder:create(element2)
  element2:setFSM_NoCall(state2)
  
  --stage1: elements close to MAR, e1 pump, second defending
  local pumpState = FSM_Element_Pump:create(element1, state1)
  element1:setFSM_NoCall(pumpState)
  
  plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  element2:setFSM_NoCall(FSM_Element_Pump:create(element2, state2))

  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --stage2: elements now from MAR + 5nm, element1 go Attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 11000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --stage3: element1 go WVR, element2 stop defending, now inside MAR + 5 
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR, y = 0, z = 0} end
  plane2.getCurrentFSM = CapPlane.getCurrentFSM
  
  --inside WVR
  plane1.getPoint = function() return {x = 15000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage4: element1 WVR, element reach MAR + 5nm go Attack to help
  element1.getCurrentFSM = function() return CapElement.FSM_Enum.FSM_Element_WVR end
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 11111, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage5: element1 exit from WVR and reach good separation, also it to far for attack, goes intercept
  element1.getCurrentFSM = CapElement.getCurrentFSM
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange + 10000, y = 0, z = 0} end
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 11111, y = 0, z = 0} end

  mockTimer()
  element1:update()
  element2:update()
  
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage6: element 2 reach MAR, has missile but target Hot, go Pump, element1 attack
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 5, y = 0, z = 0} end
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR - 1, y = 0, z = 0} end
  
  state2.checkOurMissile = function() return true end

  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage7: element1 dies, element2 switch to standart skate
  mockTimer()
  plane1.isExist = function() return false end
  group:update()
  
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 1000, y = 0, z = 0} end
  element2.setFSM_NoCall = setFSM_NoCall
  
  element2:callFSM({})
  lu.assertEquals(element2.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Skate)
  end


function test_FSM_Element_SkateGrinder:test_elementDiesDuringAttack() 
  --element attack and second element dies, continue attack, and when exit from attack
  ---change state to skate
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  
  --inside MaxRange
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 500, y = 0, z = 0} end
  plane2.getPoint = function() return {x = element1:getBestMissile().MaxRange + 500, y = 0, z = 0} end
  
  local state1 = FSM_Element_SkateGrinder:create(element1)
  element1:setFSM_NoCall(state1)
  local state2 = FSM_Element_SkateGrinder:create(element2)
  element2:setFSM_NoCall(state2)
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --element2 dies
  plane2.isExist = function() return false end
  group:update()
  
  lu.assertNil(element1:getSecondElement())
  lu.assertEquals(#group.elements, 1)
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --element1 reach MAR, switch to pump and then to SKATE
  element1.setFSM_NoCall = setFSM_NoCall
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 500, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Skate)
  end
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_FSM_Element_SkateOffsetGrinder = {}
test_FSM_Element_SkateOffsetGrinder.originalRandom = mist.random
test_FSM_Element_SkateOffsetGrinder.originalOffsetCheckRequrements = FSM_Element_SkateOffset.checkRequrements

--checkPump()/checkColdOps()/checkAttack()/attackNormal()/attackHigh() -> from skateGrinder and tested

function test_FSM_Element_SkateOffsetGrinder:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_SkateOffsetGrinder:teardown()
  mist.random = test_FSM_Element_SkateOffsetGrinder.originalRandom
  FSM_Element_SkateOffset.checkRequrements = test_FSM_Element_SkateOffsetGrinder.originalOffsetCheckRequrements
  revertMissileInterpolation()
end

function test_FSM_Element_SkateOffsetGrinder:test_checkRequrements() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  
  local fsm = FSM_Element_SkateOffsetGrinder:create(element)
  fsm.checkForGrinder = function() return true end
  
  --verify checkRequeremnts calls base class
  local m = mockagne.getMock()
  FSM_Element_SkateOffset.checkRequrements = m.check
  when(FSM_Element_SkateOffset:checkRequrements(40000, 40000)).thenAnswer(true)
  
  lu.assertTrue(fsm:checkRequrements(40000, 40000, 1))
  verify(FSM_Element_SkateOffset:checkRequrements(40000, 40000))
  
  --other tested
  end

function test_FSM_Element_SkateOffsetGrinder:test_checkConditionTacticChanges() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  local element = group.elements[1]
  element.setFSM_NoCall = setFSM_NoCall
  
  local fsm = FSM_Element_SkateOffsetGrinder:create(element)
  
  --all ok, just continue
  fsm.checkForGrinder = function() return true end
  FSM_Element_SkateOffset.checkRequrements = function() return true end
  
  lu.assertFalse(fsm:checkCondition())
  lu.assertNil(element.setState)--nothing was set
  
  --can't go grinder, switch to standart version
  fsm.checkForGrinder = function() return false end
  
  lu.assertTrue(fsm:checkCondition())--state change happened
  lu.assertEquals(element.setState.enumerator, CapElement.FSM_Enum.FSM_Element_SkateOffset)
  
  --can't continue tactic, go to shortSkate Grinder(it then can switch to standart shoty skate)
  fsm.checkForGrinder = function() return true end
  FSM_Element_SkateOffset.checkRequrements = function() return false end
  
  lu.assertTrue(fsm:checkCondition())--state change happened
  lu.assertEquals(element.setState.enumerator, CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder)
  end

function test_FSM_Element_SkateOffsetGrinder:test_directionOfCrank_HotTgt() 
  local m = mockagne.getMock()
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  group.target:getLead().getPoint = function() return {x = 50000, y = 0, z = 0} end
  group.target:getLead().getAA = function() return 15 end --target hot
  group.target:getLead().getVelocity = function() return {x = -100, y = 0, z = 0} end --target hot
  
  local element = group.elements[1]
  element.getPoint = function() return {x = 0, y = 0, z = -20000} end --20km lateral separation
  local fsm = FSM_Element_SkateOffsetGrinder:create(element)
  
  lu.assertEquals(fsm:directionOfCrank(), FSM_Element_Crank.DIR.Left)
  
  element.sideOfElement = nil
  element.getPoint = function() return {x = 0, y = 0, z = 20000} end --20km lateral separation
  lu.assertEquals(fsm:directionOfCrank(), FSM_Element_Crank.DIR.Right)
end

function test_FSM_Element_SkateOffsetGrinder:test_directionOfCrank_ColdTgt() 
  local m = mockagne.getMock()
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  group.target:getLead().getPoint = function() return {x = 50000, y = 0, z = 0} end
  group.target:getLead().getAA = function() return 180 end --target cold
  group.target:getLead().getVelocity = function() return {x = 100, y = 0, z = 0} end --target cold
  
  local element = group.elements[1]
  element.getPoint = function() return {x = 0, y = 0, z = -20000} end --20km lateral separation
  local fsm = FSM_Element_SkateOffsetGrinder:create(element)
  
  lu.assertEquals(fsm:directionOfCrank(), FSM_Element_Crank.DIR.Left)
end


function test_FSM_Element_SkateOffsetGrinder:test_fullAttackCycleNormal() 
  --state1: first contact, tactic set, aspect to low, set random side crank for lead element
    ---second element go pump
  --state2:target cold, lead element intercept, second element still pump
  --stage3:target cranking lead and second element flyParallel
  --stage4:target hot, lead element go Attack, second crank to respective side
  --stage5:lead element defening, target cold, second element go intercept
  --stage6:lead element stop defending, pumping, second element go attack
  --stage7:second element go defend, lead element go attack
  
  local m = mockagne.getMock()
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  
  local state1, state2 = FSM_Element_SkateOffsetGrinder:create(element1), FSM_Element_SkateOffsetGrinder:create(element2)
  
  --state1: first contact, tactic set, aspect to low, set random side crank for lead element
    ---second element go pump
  plane1.getPoint = function() return {x = 100000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mist.random = m.random
  when(mist.random(100)).thenAnswer(66)--should be right
  
  --target hot
  target.getAA = function() return 0 end
  target:getLead().getAA = target.getAA 
  target:getLead().getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  element1:update()
  element2:update()
  element1:setFSM(state1)
  element2:setFSM(state2)
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --state2:target cold, lead element intercept, second element still pump
  target.getAA = function() return 100 end
  target:getLead().getAA = target.getAA 
  target:getLead().getVelocity = function() return {x = 0, y = 0, z = 10} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage3:target cranking lead and second element flyParallel
  target.getAA = function() return 45 end
  target:getLead().getAA = target.getAA 
  
  plane1.getPoint = function() return {x = 75000, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 100000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyParallel)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyParallel)
  
  --stage4:target hot and inside range, lead element go Attack, second crank to respective side
  target.getAA = function() return 0 end
  target:getLead().getAA = target.getAA 
  
  plane1.getPoint = function() return {x = group:getBestMissile().MaxRange - 500, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 70000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --stage5:lead element defening, target cold, second element go intercept
  target.getAA = function() return 95 end
  target:getLead().getAA = target.getAA 

  plane1.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  --stage6:lead element stop defending, pumping, second element go attack
  plane1.getCurrentFSM = CapPlane.getCurrentFSM
  
  plane2.getPoint = function() return {x = group:getBestMissile().MaxRange - 500, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)

  --stage7:second element go defend, lead element go attack
  plane2.getCurrentFSM =  function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  --outside range but still close
  plane1.getPoint = function() return {x = group:getBestMissile().MaxRange + 5000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  --first iteration
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --second call
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  end


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
test_FSM_Element_Bracket = {}

function test_FSM_Element_Bracket:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_Bracket:teardown() 
  revertMissileInterpolation()
  end

function test_FSM_Element_Bracket:test_directionOfCrank_start() 
  --elements fly together, should return different directions
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:splitElement()
  group.target = getTargetGroup()
  
  group.target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local elem1, elem2 = group.elements[1], group.elements[2]
  elem1.getPoint = function() return {x = 10, y = 0, z = 0} end
  elem2.getPoint = function() return {x = 10, y = 0, z = 1} end
  
  local fsm1, fsm2 = FSM_Element_Bracket:create(elem1), FSM_Element_Bracket:create(elem2)
  
  lu.assertNotEquals(fsm1:directionOfCrank(), fsm2:directionOfCrank())
  lu.assertEquals(fsm1:directionOfCrank(), FSM_Element_Crank.DIR.Right)
  end

function test_FSM_Element_Bracket:test_fullAttackCycle() 
  --stage1: start tactic, element start splitting to different direction
  --stage2: target leaning to first element, element continue crankm second element reach MaxRange, but aspect not enough
  --stage3: first element same, second element reach aspect go attack
  --stage4: first element to close, go inverse crank, verify same side and angle 150, second element still attack
  --stage5: target hot on second element, lead element in range go attack, second element remain in attack
  --stage6: lead element attack, second element defending
  --stage7: lead element attack, second element defending stop defending, go inverse crank cause target hot on him
  --stage8: lead element WVR, second element turn hot, go attack(target hot on element, but other element in trouble)
  
  local m = mockagne.getMock()
  local target= getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  
  local state1, state2 = FSM_Element_Bracket:create(element1), FSM_Element_Bracket:create(element2)
  
  --stage1: start tactic, element start splitting to different direction
  plane1.getPoint = function() return {x = 100000, y = 0, z = 1} end--should be left?
  plane2.getPoint = function() return {x = 100000, y = 0, z = -1} end
  
  --target hot
  target.getCount = function() return 1 end -- to prevent exit from tactic
  target.getAA = function() return 0 end
  target:getLead().getAA = target.getAA 
  target:getLead().getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  element1:update()
  element2:update()
  element1:setFSM_NoCall(state1)
  element2:setFSM_NoCall(state2)
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  --verify crank to different directions
  lu.assertEquals(element1.FSM_stack:getCurrentState().side, FSM_Element_Crank.DIR.Left)
  lu.assertEquals(element2.FSM_stack:getCurrentState().side, FSM_Element_Crank.DIR.Right)
  
  --stage2: target leaning to first element, element continue crankm second element reach MaxRange, but aspect not enough
  plane1.getPoint = function() return {x = group:getBestMissile().MaxRange - 1000, y = 0, z = 100} end--should be right?
  plane2.getPoint = function() return {x = group:getBestMissile().MaxRange - 1000, y = 0, z = -100} end
  
  element1:update()
  element2:update()
  
  target.getAA = m.getAA
  when(target:getAA(element1:getPoint())).thenAnswer(0)
  when(target:getAA(element2:getPoint())).thenAnswer(40)
  
  mockTimer()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_FlyParallel)
  
  --stage3: first element same, second element reach aspect go attack
  --change pos a little for mock
  plane2.getPoint = function() return {x = group:getBestMissile().MaxRange - 5000, y = 0, z = -100} end
  
  element1:update()
  element2:update()
  
  when(target:getAA(element2:getPoint())).thenAnswer(61)
  lu.assertEquals(target:getAA(element2:getPoint()), 61)

  mockTimer()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage4: first element to close, go inverse crank, verify same side and angle 150, second element still attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR-500, y = 0, z = 100} end
 
  element1:update()
  element2:update()
  when(target:getAA(element1:getPoint())).thenAnswer(0)
  
  mockTimer()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  lu.assertEquals(element1.FSM_stack:getCurrentState().callback, state1.checkPump)
  lu.assertEquals(element1.FSM_stack:getCurrentState().side, FSM_Element_Crank.DIR.Left)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(150))
  
  --stage5: target hot on second element, lead element in range go attack, second element remain in attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 500, y = 0, z = 100} end
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 5000, y = 0, z = 100} end
  element1:update()
  element2:update()
  
  when(target:getAA(element1:getPoint())).thenAnswer(75)
  when(target:getAA(element2:getPoint())).thenAnswer(0)

  mockTimer()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage6: lead element attack, second element defending
  plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  element1:update()
  element2:update()
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
   --stage7: lead element attack, second element defending stop defending, go pump cause target hot on him
  plane2.getCurrentFSM = CapPlane.getCurrentFSM
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR * 1.1, y = 0, z = 100} end
  
  element1:update()
  element2:update()
  
  when(target:getAA(element2:getPoint())).thenAnswer(0)
  
  mockTimer()
  element1:callFSM()
  element2:callFSM()
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage8: lead element WVR, second element turn hot, go attack(target hot on element, but other element in trouble)
  plane1.getPoint = function() return {x = 14999, y = 0, z = 0} end --close enough to WVR
  target.getAA = function() return 0 end
  
  --verify target still hot on elem2
  lu.assertEquals(target:getAA(element2:getPoint()), 0)
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)--]]
  end


function test_FSM_Element_Bracket:test_PumpAttackCycle_Normal() 
  local target = getTargetGroup()
  target.getCount = function() return 1 end --to satisfy ratio condition check 
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 500, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Bracket:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_Bracket:create(element2)
  element2:setFSM_NoCall(state2)
  
  --stage1: elements close to MAR, elements backward crank
  element1:setFSM_NoCall(FSM_Element_Pump:create(element1, state1))
  element2:setFSM_NoCall(FSM_Element_Pump:create(element2, state2))
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage2:element 2 goes WVR, 
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 500, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 12000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  
  --stage3: element1 in MAR, with target HOT but see second element need help and tur to attack
  target.getAA = function() return 0 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  
  --stage4: element2 exit WVR, now defend, element1 still press
  plane2.getPoint = plane1.getPoint
  plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --stage5: element2 stop defending, both elements pump(element1 reversed crank)
  plane2.getCurrentFSM = CapPlane.getCurrentFSM
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage6: target cold(aspect > 60) elements go attack
  target.getAA = function() return 75 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  
  --stage6: target hot, both reverse crank
  target.getAA = function() return 0 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --stage7: element 2 too far to attack, but other element WVR, turn hot and maintain
  plane1.getPoint = function() return {x = 10000, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 99000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage8: element 1 stop WVR, elem 2 still to FAR, switch to crank
  plane1.getPoint = function() return {x = 20000, y = 0, z = 0} end
   
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(150))--verify it's reverce crank
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2.FSM_stack:getCurrentState().angle, math.rad(60))--verify it's normal crank
  
  --stage9: element1 reach MAR + 5nm, go Normal crank(target hot)
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 11000, y = 0, z = 0} end

  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(60))--verify it's normal crank
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --stage10: element go Attack
  target.getAA = function() return 90 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage11: MAR, has Missile Press
  target.getAA = function() return 70 end
  state1.checkOurMissiles = function() return false end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 1000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage12: MAR, no missile but target cold, press
  target.getAA = function() return 61 end
  state1.checkOurMissiles = function() return true end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage12: MAR, no missile, target hot, reverse crank
  target.getAA = function() return 59 end
  state1.checkOurMissiles = function() return true end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
end


function test_FSM_Element_Bracket:test_CheckAttackCycle_High() 
  local target = getTargetGroup()
  target.getCount = function() return 0.1 end --to satisfy ratio condition check 
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 90 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.High
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  
  
  --inside MaxRange, go Attack
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 500, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Bracket:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_Bracket:create(element2)
  element2:setFSM_NoCall(state2)
  
  --verify correctCheck will be used
  lu.assertEquals(state1.ALR_check, FSM_Element_Bracket.checkAttackHigh)
  lu.assertEquals(state2.ALR_check, FSM_Element_Bracket.checkAttackHigh)
  
  --in attack
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --test1: not in MAR, ,target HOT and no num advantage -> press
  target.getAA = function() return 0 end
  target.getCount = function() return 1 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --test2: in MAR, no num advantage but target cold -> press
  target.getAA = function() return 90 end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 500, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --test3: in MAR target hot and no advantage -> reverse crank
  target.getAA = function() return 0 end
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --continue crank
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --reach AA condition, go Attack
  target.getAA = function() return 90 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
end


function test_FSM_Element_Bracket:test_ElementDiesDuringAttack() 
  --one element dies, otрer in attack, continue Bracket till exit, then go to ShortSkate
  local target = getTargetGroup()
  target.getCount = function() return 0.1 end --to satisfy ratio condition check 
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 90 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  
  
  --inside MaxRange, go Attack
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 500, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Bracket:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_Bracket:create(element2)
  element2:setFSM_NoCall(state2)
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --element2 dies
  plane2.isExist = function() return false end
  group:update()
  
  lu.assertNil(element1:getSecondElement())
  lu.assertEquals(#group.elements, 1)
  lu.assertEquals(group.countPlanes, 1)
  
  mockTimer()
  element1:callFSM({})
  mockTimer()
  element1:callFSM({})
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --element reach MAR and turn to Crank, and switch to shortSkate
  element1.setFSM_NoCall = setFSM_NoCall
  target.getAA = function() return 40 end
  target.getCount = function() return 1 end --no more numerical avantage
  plane1.getPoint = function()  return {x = target:getHighestThreat().MAR - 500, y = 0, z = 0} end
 
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1.setState.enumerator, CapElement.FSM_Enum.FSM_Element_SkateOffsetGrinder)
  end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
test_FSM_Element_Banzai = {}

function test_FSM_Element_Banzai:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_Banzai:teardown() 
  revertMissileInterpolation()
end

--SAME and tested in Bracket
--inRangeForAttack()
--isGoodSeparation()
--needSeparate() 
--directionOfCrank() 
--checkAttack() same
--checkAttackNormal() same
--checkAttackHigh() same
--interceptAspectCheck()


function test_FSM_Element_Banzai:test_AttackPumpCycle() 
  local target = getTargetGroup()
  target.getCount = function() return 0.1 end --to satisfy ratio condition check 
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  
  
  --close to MAR, go Notch
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 10000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Banzai:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_Banzai:create(element2)
  element2:setFSM_NoCall(state2)
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(90))
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2.FSM_stack:getCurrentState().angle, math.rad(90))
  
  --close to MAR, go reverse crank
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 5000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(150))
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2.FSM_stack:getCurrentState().angle, math.rad(150))
  
  --element1 increace distance and now outside self.maxRange, go to crank
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange + 15000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2.FSM_stack:getCurrentState().angle, math.rad(150))
  
  --element2 in WVR, element1 turn to attack even if distance to great
  plane2.getPoint = function() return {x = 10000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)

  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  
  --distance increace, but attack maintained
  plane1.getPoint = function() return {x = 999999, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_WVR)
  
  --element stop WVR
  plane2.getPoint = function() return {x = 25000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  mockTimer()
  --second element see this and also return to crank
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --element in range but aspect to small(< 30)
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 1000, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  lu.assertEquals(element1.FSM_stack:getCurrentState().angle, math.rad(90))
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Crank)
  
  --aspect ok, go attack from notch
  target.getAA = function() return 32 end
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  --now first element see, that second element in problem
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
end
  
function test_FSM_Element_Banzai:test_fullAttackCycle() 
  --stage1: start tactic, element start splitting to different direction
  --stage2: target leaning to first element, lead element crank, second element goes to FlyParallel
  --stage3: elements reach target maxRange, switch to Notch, verify State is Crank, angle 90 deg and side is same
  --stage4:

  
  local m = mockagne.getMock()
  local target= getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1, element2 = group.elements[1], group.elements[2]
  
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 6000} end
  element2.getBestMissile = element1.getBestMissile
  
  local state1, state2 = FSM_Element_Bracket:create(element1), FSM_Element_Bracket:create(element2)
end


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_Skate = {}

function test_Skate:setup() 
  disableMissileInterpolation()
end

function test_Skate:teardown() 
  revertMissileInterpolation()
end

function test_Skate:test_checkConditionTacticChanges() 
  --ratio enemyRange/ourRange > 1.25
  --go skateOffset
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  
  group.target.getHighestThreat = function() return {MaxRange = 10000, MAR = 5000} end
  
  local element = group.elements[1]
  element.getBestMissile = function() return {MaxRange = 10000, MAR = 5000} end
  --just add so we can verify ir
  element.setFSM = function(state) element.FSM_stack.data[1] = state; element.FSM_stack.topItem = 1 end
  
  local fsm = FSM_Element_Skate:create(element)
  lu.assertFalse(fsm:checkCondition())
  
  group.target.getHighestThreat = function() return {MaxRange = 23000, MAR = 5000} end
  lu.assertTrue(fsm:checkCondition())
  lu.assertEquals(element:getCurrentFSM(CapElement.FSM_Enum.FSM_Element_SkateOffset))
  end



test_SkateAttackChecks = {}

function test_SkateAttackChecks:setup() 
  disableMissileInterpolation()
end

function test_SkateAttackChecks:teardown() 
  revertMissileInterpolation()
end

function test_SkateAttackChecks:test_goColdOps() 
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  target.getAA = function() return 0 end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  lu.assertEquals(#group.elements, 2)
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 12000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Skate:create(element1)
  element1:setFSM_NoCall(state1)
  
  local state2 = FSM_Element_Skate:create(element2)
  element2:setFSM_NoCall(state2)
  
  --both elements PUMP, ditance2MAR > 10 NM for first element
  element1:setFSM_NoCall(FSM_Element_Pump:create(element1, state1))
  element2:setFSM_NoCall(FSM_Element_Pump:create(element2, state2))
  
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage2: time in pump lower then 60sec
  element1.FSM_stack:getCurrentState().getTimer = function() return 0 end
  element1.FSM_stack:getCurrentState().getTimer = state1.getTimer
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage3: more 60 sec in pump, go ShortSkateGrinder
  --override setFSM, so it will be just added without setup()
  element1.FSM_stack:getCurrentState().getTimer = function() return 65 end
  element1.setFSM_NoCall = function(element, state) 
    element.setState = state
  end
  element2.setFSM_NoCall = element1.setFSM_NoCall--]]
  
  mockTimer()
  element1:callFSM({})
  element2:callFSM({})

  lu.assertEquals(element1.setState.enumerator, CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder)
  lu.assertEquals(element2.setState.enumerator, CapElement.FSM_Enum.FSM_Element_ShortSkateGrinder)
  
  --variant2: more 60 sec in pump,close to MAR, go Delouse 
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint

  mockTimer()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Delouse)
  lu.assertEquals(element2.setState.enumerator, CapElement.FSM_Enum.FSM_Element_Delouse)--]]
  end

function test_SkateAttackChecks:test_SkateSingleElementNormalCycle() 
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local group = CapGroup:create({plane1})
  group.alr = CapGroup.ALR.Normal
  --split elements
  group:splitElement()
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  
  local state1 = FSM_Element_Skate:create(element1)
  element1:setFSM_NoCall(state1)
  --element1:setFSM_NoCall(FSM_Element_Pump:create(element1, state1))
  
  --stage1: inside MAR, target HOT continue pump
  target.getAA = function() return 0 end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage2: target cold, still in MAR, continues
  target.getAA = function() return 180 end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)

  --stage4: 5 miles from mar, target hot continue
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 5*1850, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage5: distance from mar ok, target hot turn hot, distance to great for Attack go intercept
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange + 10000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  --stage6: inside maxRange, go attack, not in MAR, continues
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 5, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage7: in MAR, missile in AIR and target cold -> press
  state1.checkOurMissiles = function() return false end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  target.getAA = function() return 91 end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage8: in MAR, target cold and missile pittbull/trashed
  state1.checkOurMissiles = function() return true end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage9: distance ok, go attack
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 5, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage10: in MAR, missile in air, target cold -> press
  state1.checkOurMissiles = function() return false end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  target.getAA = function() return 91 end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage10: in MAR, missile in air, target hot -> pump
  state1.checkOurMissiles = function() return true end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  end




function test_SkateAttackChecks:test_SkateSingleElementHighCycle() 
  --test attack -> pump cycling cause no stack overflow
  --now with ALR high
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.High
  --no split element, 2 planes scenaries
  lu.assertEquals(#group.elements[1].planes, 2)
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  local state1 = FSM_Element_Skate:create(element1)
  element1:setFSM_NoCall(state1)
  element1:setFSM_NoCall(FSM_Element_Attack:create(element1, state1))
  
  --stage1: Attack not in MAR -> continue
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 5000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage2: inside MAR numerical advantage 2:1 and target hot -> press
  target.getCount = function() return 1 end
  target.getAA = function() return 0 end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 1000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage3: inside MAR numerical advantage below 2:1 but target cold -> press
  target.getCount = function() return 2 end
  target.getAA = function() return 91 end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --stage4: inside MAR numerical advantage below 2:1 target hot -> pump
  target.getAA = function() return 89 end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage5: outside MAR but not far(<10nm) continue pump
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 1000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage5: outside MAR, distance2MAR > 10nm -> attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 20000, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  
  end


function test_SkateAttackChecks:test_Skate2ElementsNormalCycle() 
  --test attack -> pump cycling causing no stack overflow
  --2 elements 1 plane in each, ALR normal
  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group.alr = CapGroup.ALR.Normal
  group:splitElement()
  lu.assertEquals(#group.elements, 2)
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  local element2 = group.elements[2]
  element1.getBestMissile = function() return {MaxRange = 50000, MAR = 20000} end
  element2.getBestMissile = element1.getBestMissile
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  plane2.getPoint = plane1.getPoint
  
  --plane defending
  plane2.getCurrentFSM = function() return AbstractPlane_FSM.enumerators.FSM_Defence end
  
  local state1, state2 = FSM_Element_Skate:create(element1), FSM_Element_Skate:create(element2)
  element1:setFSM_NoCall(state1)
  element1:setFSM_NoCall(FSM_Element_Pump:create(element1, state1))
  
  element2:setFSM_NoCall(state2)
  element2:setFSM_NoCall(FSM_Element_Pump:create(element2, state2))
  
  --stage1: element1 PUMP, inside MAR, element2 defending
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --stage2: element2 11km from MAR, element2 still defending, elem1 -> attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 11000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Defending)
  
  --stage3: element1 attacking, element2 stop defending, pump
  plane2.getCurrentFSM = CapPlane.getCurrentFSM
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 11111, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage4: element1 MAR, has Missile, target hot -> pump, second element pumping
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR - 5, y = 0, z = 0} end
  target.getAA = function() return 0 end
  state1.checkOwnMissile = function() return false end
  
  mockTimer()
  element1:update()
  element2:update()
  
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage5: element1 pump, second element MAR+10nm -> Attack
  plane2.getPoint = function() return {x = target:getHighestThreat().MAR + 19000, y = 0, z = 0} end
  
  mockTimer()
  element1:update()
  element2:update()
  element1:callFSM({})
  element2:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  lu.assertEquals(element2:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  end


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_SkateOffset = {}

function test_SkateOffset:setup() 
  disableMissileInterpolation()
end

function test_SkateOffset:teardown() 
  revertMissileInterpolation()
end

function test_SkateOffset:test_checkRequrements() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  
  group.target.getHighestThreat = function() return {MaxRange = 10000, MAR = 5000} end
  
  local element = group.elements[1]
  element.getBestMissile = function() return {MaxRange = 10000, MAR = 5000} end
  
  local fsm = FSM_Element_SkateOffset:create(element)
  
  --targetRange/ourRange > 1.5 
  lu.assertFalse(fsm:checkRequrements(70000, 40000))
  
  --ratio > 1.5 but range delta < 20000
  lu.assertTrue(fsm:checkRequrements(29000, 10000))
  
  --ratio < 1.5 but range delta > 20000
  lu.assertTrue(fsm:checkRequrements(149000, 100000))
  end

function test_SkateOffset:test_checkConditionTacticChanges() 
  --ratio enemyRange/ourRange > 1.5
  --go skateOffset
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()
  
  group.target.getHighestThreat = function() return {MaxRange = 10000, MAR = 5000} end
  
  local element = group.elements[1]
  element.getBestMissile = function() return {MaxRange = 10000, MAR = 5000} end
  --just add so we can verify ir
  element.setFSM = function(state) element.FSM_stack.data[1] = state; element.FSM_stack.topItem = 1 end
  
  local fsm = FSM_Element_SkateOffset:create(element)
  lu.assertFalse(fsm:checkCondition())
  
  --check ratio
  group.target.getHighestThreat = function() return {MaxRange = 75000*1.5, MAR = 5000} end
  element.getBestMissile = function() return {MaxRange = 75000, MAR = 5000} end
  lu.assertTrue(fsm:checkCondition())
  lu.assertEquals(element:getCurrentFSM(CapElement.FSM_Enum.FSM_Element_SkateOffset))
  
  --check no change if range delta not big
  --ratio 2:1 but range delta < 20000
  group.target.getHighestThreat = function() return {MaxRange = 20000, MAR = 5000} end
  element.getBestMissile = function() return {MaxRange = 10000, MAR = 5000} end
  lu.assertFalse(fsm:checkCondition())
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_FSM_Element_ShortSkateGrinder = {}

function test_FSM_Element_ShortSkateGrinder:setup() 
  disableMissileInterpolation()
end

function test_FSM_Element_ShortSkateGrinder:teardown() 
  revertMissileInterpolation()
end

--checkColdOps()/checkPump()/checkAttack()/checkAttackNormal()/checkAttackHigh() from skateGrinder and tested?


function test_FSM_Element_ShortSkateGrinder:test_checkConditionStateChanges() 
  --if we can't continue use grinder should switch to standart shortSkate
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()

  local element = group.elements[1]
  element.setFSM_NoCall = setFSM_NoCall
  local fsm = FSM_Element_ShortSkateGrinder:create(element)
  
  fsm.checkForGrinder = function() return true end
  
  lu.assertFalse(fsm:checkCondition())
  lu.assertNil(element.setState)--nothing was set
  
  --no grinder
  fsm.checkForGrinder = function() return false end
  
  lu.assertTrue(fsm:checkCondition())
  lu.assertEquals(element.setState.enumerator, CapElement.FSM_Enum.FSM_Element_ShortSkate)
end

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

test_ShortSkate = {}
test_ShortSkate.originalTimer = timer.getAbsTime

function test_ShortSkate:setup() 
  disableMissileInterpolation()
end

function test_ShortSkate:teardown() 
  timer.getAbsTime = test_ShortSkate.originalTimer
  revertMissileInterpolation()
end

function test_ShortSkate:test_updateSpeedAlt() 
  local group = getCapGroupNoRun()
  group.target = getTargetGroup()

  local element = group.elements[1]
  element.setFSM_NoCall = setFSM_NoCall
  local fsm = FSM_Element_ShortSkate:create(element)
  
  --case1: too far, use lower alt
  group.target.getPoint = function() return {x = 40000, y = 6100, z = 0} end
  for _, target in pairs(group.target:getTargets()) do 
    target.getPoint = group.target.getPoint
    end
  fsm:update()--verify called derived version
  lu.assertEquals(fsm.alt, 3100)
  
  --case2: use 1000
  group.target.getPoint = function() return {x = 0, y = 1000, z = 0} end
  fsm:updateSpeedAlt()--verify called derived version
  
  lu.assertEquals(fsm.alt, 1000)
  
  --case3: target to high, stay below 5000
  group.target.getPoint = function() return {x = 0, y = 12000, z = 0} end
  fsm:updateSpeedAlt()--verify called derived version
  
  lu.assertEquals(fsm.alt, 5000)
  
  --case4: to close, go to target alt
  fsm.distance2Target = 30000
  group.target.getPoint = function() return {x = 0, y = 12000, z = 0} end
  fsm:updateSpeedAlt()--verify called derived version
  
  lu.assertEquals(fsm.alt, 12000)
end

function test_ShortSkate:test_inRangeForAttackGetLowestVal() 

  local target = getTargetGroup()
  target.getHighestThreat = function() return {MaxRange = 50000, MAR = 20000} end
  target.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local group = CapGroup:create({plane1})
  group.alr = CapGroup.ALR.Normal
  group.target = target
  group.missile = {MaxRange = 50000, MAR = 20000}
  
  local element1 = group.elements[1]
  element1.getBestMissile = function() return {MaxRange = 35000, MAR = 20000} end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 10000, y = 0, z = 0} end
  
  local state1 = FSM_Element_ShortSkate:create(element1)
  element1:setFSM_NoCall(state1)
  element1:setFSM_NoCall(FSM_Element_Pump:create(element1, state1))
  
  --stage1: element defending, 5NM from MAR
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Pump)
  
  --stage2: element defending, 10nm from MAR(45km from target, outside MaxRange) -> intercept
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 25000, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  --stage3: inside MaxRange but not inside MAR + 5m, continue
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 5, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  --stage4: inside MAR + 5nm, go Attack
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 9900, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
  
  --MaxRange below MAR + 5nm, inside Mar + 5 continue intercept
  --return to intercept
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 99900, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  element1.getBestMissile = function() return {MaxRange = 22000, MAR = 20000} end
  plane1.getPoint = function() return {x = target:getHighestThreat().MAR + 9900, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Intercept)
  
  --now inside MaxRange
  plane1.getPoint = function() return {x = element1:getBestMissile().MaxRange - 5, y = 0, z = 0} end
  
  mockTimer()
  element1:callFSM({})
  lu.assertEquals(element1:getCurrentFSM(), CapElement.FSM_Enum.FSM_Element_Attack)
end


--other is tested?
--checkColdOps()/checkPump()/checkAttack()/checkAttackNormal()/checkAttackHigh() from skate and tested?
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()