dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")


test_target = {}
--example table
test_target.DetectedTarget = {
  object = nil, --the target
  visible = false, --the target is visible
  type = false, --the target type is known
  distance = false--distance to the target is known
}

local originalLand = mist.utils.deepCopy(land)

function test_target:teardown() 
  EventHandler:create():shutdown()--remove event handler

  end

function test_target:get_mocked_unit() 
  local unit = Unit:create()
  local m = mockagne.getMock()
  
  unit.getPoint = m.getPoint
  unit.getID = m.getID
  unit.getPosition = m.getPosition
  unit.getVelocity = m.getVelocity
  unit.getName = m.getName
  unit.getTypeName = m.getTypeName
  unit.getController = m.getController
  
  local zeroVec = {x = 0, y = 0, z = 0}
  
  when(m.getPoint(any())).thenAnswer(zeroVec)
  when(m.getID(any())).thenAnswer(1)
  when(m.getPosition(any())).thenAnswer({x = zeroVec, y = zeroVec, z = zeroVec, p = zeroVec})
  
  return unit, m
end


function test_target:get_DetectionTable(tgt, visible, type, distance) 
  return {
    object = tgt or nil, --the target
    visible = visible or false, --the target is visible
    type = type or false, --the target type is known
    distance = distance or false--distance to the target is known
  }
end

function test_target:getTarget() 
  local unit = Unit:create()
  return Target:create(TargetContainer:create(self:get_DetectionTable(unit), unit))
end

function test_target:test_creation_typeDetection() 
  local unit,m  = Unit:create(), mockagne.getMock()
  local cont_typeUnk, cont_typeKnown = TargetContainer:create(self:get_DetectionTable(unit), unit), TargetContainer:create(self:get_DetectionTable(unit), unit)
  
  local eventHandler = EventHandler:create()
  eventHandler.registerObject = m.registerObject
  
  unit.getTypeName = m.getTypeName
  cont_typeUnk.isTypeKnown = m.isTypeKnown
  cont_typeKnown.isTypeKnown = m.isTypeKnown
  
  when(m.getTypeName(any())).thenAnswer("Mocked")
  when(m.isTypeKnown(cont_typeKnown)).thenAnswer(true)
  when(m.isTypeKnown(cont_typeUnk)).thenAnswer(false)
  
  local instKnown, instUnk = Target:create(cont_typeKnown), Target:create(cont_typeUnk)

  
  lu.assertEquals(instKnown.typeKnown, true)
  lu.assertEquals(instKnown.typeName, "Mocked")
  
  lu.assertEquals(instUnk.typeKnown, false)
  lu.assertEquals(instUnk.typeName, "Unknown")
  
  --verify tested objects added in EventHandler
  verify(m.registerObject(EventHandler:create(), instKnown))
  verify(m.registerObject(EventHandler:create(), instUnk))
end
  
  
function test_target:test_shotEvent_noTarget() 
  local target, weapon, mock = self:getTarget(), Weapon:create(), mockagne.getMock()
  
  weapon.getTarget = mock.getTarget
  when(mock.getTarget(any())).thenAnswer(nil)
  
  target:shotEvent({
    id = 1,
    time = 0,
    initiator = target.dcsObject,
    weapon = weapon
  })

  lu.assertEquals(target.shooter, false)
  verify(mock.getTarget(any()))
end

function test_target:test_shotEvent_noCoalition() 
  local target, unit, weapon, mock = self:getTarget(), Unit:create(),Weapon:create(), mockagne.getMock()
  
  weapon.getTarget = mock.getTarget
  when(mock.getTarget(any())).thenAnswer(unit)
  
  unit.getCoalition = mock.getCoalition
  target.dcsObject.getCoalition = mock.getCoalition
  --TARGET attack unit same coalition(FF)
  when(mock.getCoalition(unit)).thenAnswer(1)
  when(mock.getCoalition(target.dcsObject)).thenAnswer(1)
  
  target:shotEvent({
    id = 1,
    time = 0,
    initiator = target.dcsObject,
    weapon = weapon
  })

  lu.assertEquals(target.shooter, false)
  verify(mock.getTarget(any()))
end
  
function test_target:test_shotEvent_attackNeutral() 
  local target, unit, weapon, mock = self:getTarget(), Unit:create(),Weapon:create(), mockagne.getMock()
  
  weapon.getTarget = mock.getTarget
  when(mock.getTarget(any())).thenAnswer(unit)
  
  unit.getCoalition = mock.getCoalition
  target.dcsObject.getCoalition = mock.getCoalition
  
  when(mock.getCoalition(unit)).thenAnswer(0)--neutral coalition enum
  when(mock.getCoalition(target.dcsObject)).thenAnswer(1) 
  
  target:shotEvent({
    id = 1,
    time = 0,
    initiator = target.dcsObject,
    weapon = weapon
  })

  lu.assertEquals(target.shooter, false)
  verify(mock.getTarget(any()))
end

function test_target:test_shotEvent_shooter() 
  local target, unit, weapon, mock = self:getTarget(), Unit:create(),Weapon:create(), mockagne.getMock()
  
  weapon.getTarget = mock.getTarget
  weapon.getDesc = function ()
    return {category = Weapon.Category.MISSILE}
  end
  when(mock.getTarget(any())).thenAnswer(unit)
  
  unit.getCoalition = mock.getCoalition
  target.dcsObject.getCoalition = mock.getCoalition
  
  --tested object is coalition 1 and it shoot at coalition 2(which is script coalition)
  when(mock.getCoalition(unit)).thenAnswer(2)
  when(mock.getCoalition(target.dcsObject)).thenAnswer(1) 
  
  target:shotEvent({
    id = 1,
    time = 0,
    initiator = target.dcsObject,
    weapon = weapon
  })

  lu.assertEquals(target.shooter, true)
  verify(mock.getTarget(any()))
  verify(mock.getCoalition(target.dcsObject))
  verify(mock.getCoalition(unit))
end
  


function test_target:test_setTargeted() 
  local target = self:getTarget()
  
  lu.assertEquals(target.targeted, false)
  target:setTargeted(true)
  lu.assertEquals(target.targeted, true)
end

function test_target:test_getTargeted() 
  local target, m = self:getTarget()
  
  lu.assertEquals(target.targeted, false)
  lu.assertEquals(target:getTargeted(), false)
  end

function test_target:test_setROE() 
  local target = getTarget()
  
  lu.assertEquals(target.currentROE, AbstractTarget.ROE.Bandit)
  target:setROE(AbstractTarget.ROE.Hostile)
  
  lu.assertEquals(target.currentROE, AbstractTarget.ROE.Hostile)
end

function test_target:test_getROE() 
  local target = getTarget()
  
  lu.assertEquals(target:getROE(), target.currentROE)
  target:setROE(AbstractTarget.ROE.Hostile)
  
  lu.assertEquals(target:getROE(), AbstractTarget.ROE.Hostile)
end

function test_target:test_isExist_ok() 
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.dcsObject.isExist = m.isExist
  when(m.isExist(any())).thenAnswer(true)
  target.isOutages = m.isOutages
  when(target:isOutages()).thenAnswer(false)
  
  lu.assertEquals(target:isExist(), true)
  verify(m.isExist(target.dcsObject))
end

function test_target:test_isExist_noObj() 
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.dcsObject = nil
  target.lastSeen.L1 = timer.getAbsTime()
  target.lastSeen.L2 = timer.getAbsTime()
  when(m.isExist(any())).thenAnswer(true)
  
  lu.assertEquals(target:isExist(), false)
end

function test_target:test_isExist_objNotExist() 
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.dcsObject.isExist = m.isExist
  target.update = m.update
  when(m.isExist(any())).thenAnswer(false)
  
  lu.assertEquals(target:isExist(), false)
  verify(m.isExist(target.dcsObject))
end


function test_target:test_isExist_targetOutAges() 
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.dcsObject.isExist = m.isExist
  when(m.isExist(any())).thenAnswer(true)
  target.isOutages = m.isOutages
  when(target:isOutages()).thenAnswer(true)
  
  lu.assertEquals(target:isExist(), false)
  verify(m.isExist(target.dcsObject))
end

function test_target:test_getSpeed() 
  local target = self:getTarget()
  target.velocity = {x = 100, y = 0, z = 0}
  lu.assertEquals(target:getSpeed(), 100)
  end

function test_target:test_getAA() 
  local target = self:getTarget()
  target.point = {x = 100, y = 0, z = 0}
  
  target.velocity = {x = 100, y = 0, z = 0}
  lu.assertEquals(target:getAA({x = 0, y = 0, z = 0}), 180)
  
  --90 deg
  target.velocity = {x = 0, y = 10, z = 0}
  lu.assertEquals(target:getAA({x = 0, y = 0, z = 0}), 90)
  
  --0 deg
  target.velocity = {x = -10, y = 0, z = 0}
  lu.assertEquals(target:getAA({x = 0, y = 0, z = 0}), 0)
  
  --Zero velocity, should return 180
  target.velocity = {x = 0, y = 0, z = 0}
  lu.assertEquals(target:getAA({x = 0, y = 0, z = 0}), 180)
  end

function test_target:test_hasSeen() 
  local target, unit1, unit2 = self:getTarget(), Unit:create(), Unit:create()
  
  --should be 1 cause in has container used for creation
  lu.assertEquals(#target.seenBy, 1)
  
  target:hasSeen(unit1)
  lu.assertEquals(#target.seenBy, 2)
  target:hasSeen(unit2)
  lu.assertEquals(#target.seenBy, 3)
end

function test_target:test_flushSeenBy() 
  local target, unit1, unit2 = self:getTarget(), Unit:create(), Unit:create()
  
  target:hasSeen(unit1)
  target:hasSeen(unit2)
  lu.assertEquals(#target.seenBy, 3)
  
  target:flushSeen()
  lu.assertEquals(#target.seenBy, 0)
end

function test_target:test_updateL1() 
  --need verify:
  --1)All data updated using calls from dcsObject(Point, Position, Velocity)
  --2)delta velocity changed
  --3)Level  set to L1
  --4)timers updated
  --7)seenBy flushed
  
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.flushSeen = m.flushSeen

  
  target.dcsObject.getPoint = m.getPoint
  target.dcsObject.getPosition = m.getPosition
  target.dcsObject.getVelocity = m.getVelocity
  
  local pointResult = {x = 9, y = 9, z = 9}
  local positionResult = {x = pointResult, y = pointResult, z = pointResult, p = pointResult}
  local velocityResult = {x = 999, y = 0, z = 0}
  when(m.getPoint(target.dcsObject)).thenAnswer(pointResult)
  when(m.getPosition(target.dcsObject)).thenAnswer(positionResult)
  when(m.getVelocity(target.dcsObject)).thenAnswer(velocityResult)
  
  --prepare fields
  target.point = nil
  target.position = nil
  target.velocity = { x = 0, y = 0, z = 0}--to measure deltaVel
  target.deltaVelocity = nil
  target.lastSeen = {L1 = -999, L2 = -999}
  target.controlType = Target.ControlType.LEVEL3
  
  target:updateLEVEL1()
  
  lu.assertEquals(target:getPoint(), pointResult)
  lu.assertEquals(target:getPosition(), positionResult)
  lu.assertEquals(target:getVelocity(), velocityResult)
  lu.assertEquals(target.deltaVelocity, {x = 999, y = 0, z = 0})
  lu.assertEquals(target.lastSeen, {L1 = timer.getAbsTime(), L2 = timer.getAbsTime(), L3 = timer.getAbsTime()})
  lu.assertEquals(target.controlType, Target.ControlType.LEVEL1)
  
  verify(m.flushSeen(target))
end

function test_target:test_updateL2() 
  --need verify:
  --1)position update without calling real object methods, except getPoint
  --2)position, except position.p blank
  --3)velocity not changes
  --4)deltaVelocity is blank
  --5)timings for L2/L3 updates, but not for L1
  --6)controlLevel set to L2
  --7)seenBy flushed
  
  local target, unit, m = self:getTarget(), Unit:create(), mockagne.getMock()
  
  target.dcsObject.getPoint = m.getPoint
  target.dcsObject.getPosition = m.getPosition
  target.dcsObject.getVelocity = m.getVelocity
  
  local pointResult = {x = 0, y = 0, z = 0}
  when(m.getPoint(target.dcsObject)).thenAnswer(pointResult)
  
  --prepare detector
  unit.getPoint = m.getPoint
  when(m.getPoint(unit)).thenAnswer({x = 50000, y = 0, z = 0})
  target.seenBy[1].detector = unit
  
  target.flushSeen = m.flushSeen
  
  --prepare fields
  target.point = nil
  target.position = nil
  target.velocity = { x = 999, y = 999, z = 999}--should not change
  target.deltaVelocity = nil
  target.lastSeen = {L1 = -999, L2 = -999}
  target.controlType = Target.ControlType.LEVEL1
  
  target:updateLEVEL2()
  
  lu.assertNotNil(target:getPoint())
  lu.assertNotNil(target:getPosition())
  lu.assertEquals(target:getPosition().x, pointResult) --should be blank
  lu.assertEquals(target:getPosition().y, pointResult) --should be blank
  lu.assertEquals(target:getPosition().z, pointResult) --should be blank
  lu.assertEquals(target:getPosition().p, target:getPoint()) 
  lu.assertEquals(target:getVelocity(), {x = 999, y = 999, z = 999})
  lu.assertEquals(target.deltaVelocity, {x = 0, y = 0, z = 0})
  lu.assertEquals(target.lastSeen, {L1 = -999, L2 = timer.getAbsTime(), L3 = timer.getAbsTime()})
  lu.assertEquals(target.controlType, Target.ControlType.LEVEL2)
  
  verify_no_call(m.getPosition(any()))
  verify_no_call(m.getVelocity(any()))
  
  verify(m.flushSeen(target))
end

function test_target:test_updateL3()
  --toTest
  --1)update without calls to object
  --2)position.x/.y/.z blank
  --3)velocity not change
  --4)deltaVelocity blanked
  --5)point change by deltaTime * Velocity
  --6)controlType Level3
  --7)Timers NOT updated except L3
  
  local target, m = self:getTarget(),mockagne.getMock()
  
  target.dcsObject.getPoint = m.getPoint
  target.dcsObject.getPosition = m.getPosition
  target.dcsObject.getVelocity = m.getVelocity
  
  --prepare fields
  target:flushSeen() --should work without any detection
  target.point = { x = 0, y = 0, z = 0}
  target.position = nil
  target.velocity = { x = 100, y = 0, z = 0}--should not change
  target.deltaVelocity = nil
  target.lastSeen = {L1 = -999, L2 = -999, L3 = timer.getAbsTime() - 10}
  target.controlType = Target.ControlType.LEVEL1
  
  target:updateLEVEL3()
  
  lu.assertNotNil(target:getPoint())
  lu.assertEquals(target:getPoint(), mist.vec.scalar_mult(target.velocity, 10))
  lu.assertNotNil(target:getPosition())
  lu.assertEquals(target:getPosition().x, { x= 0, y = 0, z = 0}) --should be blank
  lu.assertEquals(target:getPosition().y, { x= 0, y = 0, z = 0}) --should be blank
  lu.assertEquals(target:getPosition().z, { x= 0, y = 0, z = 0}) --should be blank
  lu.assertEquals(target:getPosition().p, target:getPoint()) 
  lu.assertEquals(target:getVelocity(), {x = 100, y = 0, z = 0})
  lu.assertEquals(target.deltaVelocity, {x = 0, y = 0, z = 0})
  lu.assertEquals(target.lastSeen, {L1 = -999, L2 = -999, L3 = timer.getAbsTime()})
  lu.assertEquals(target.controlType, Target.ControlType.LEVEL3)
  
  verify_no_call(m.getPoint(any()))
  verify_no_call(m.getPosition(any()))
  verify_no_call(m.getVelocity(any()))
  end


function test_target:test_updateType() 
  --if have container with typeKnown == true
  --1)type should update
  --2)modifier should update
  --3)typeKnown flag should be true

  local target, m = self:getTarget(), mockagne.getMock()
  
  target.dcsObject.hasAttribute = m.hasAttribute
  target.dcsObject.getTypeName = m.getTypeName
  
  when(m.hasAttribute(target.dcsObject, "Fighters")).thenAnswer(true)
  when(m.getTypeName(target.dcsObject)).thenAnswer("mocked")
  
  --verify initial state
  lu.assertEquals(target.typeKnown, false)
  lu.assertEquals(target:getTypeName(), "Unknown")
  
  local container = getTargetContainer()
  target.seenBy[#target.seenBy+1] = container
  container.isTypeKnown = function() return true end
  
  target:updateType()
  lu.assertEquals(target.typeKnown, true)
  lu.assertEquals(target:getTypeName(), "mocked")
  verify(m.hasAttribute(target.dcsObject, "Fighters"))
  verify(m.getTypeName(target.dcsObject))
end

function test_target:test_updateType_typeAlreadyKnown() 
  --typeName is known
  --should return immideatly

  local target, m = self:getTarget(), mockagne.getMock()
  local container = getTargetContainer()
  target.seenBy[#target.seenBy+1] = container
  
  container.isTypeKnown = m.isTypeKnown
  
  target.dcsObject.hasAttribute = m.hasAttribute
  target.dcsObject.getTypeName = m.getTypeName

  --verify initial state
  target.typeKnown = true
  lu.assertEquals(target.typeKnown, true)
  
  target:updateType()
  lu.assertEquals(target.typeKnown, true)
  lu.assertEquals(target:getTypeName(), "Unknown")
  verify_no_call(m.hasAttribute(any(), any()))
  verify_no_call(m.getTypeName(any()))
  verify_no_call(m.isTypeKnown(any()))
end

function test_target:test_updateType_noTypeKnown() 
  --typeName is unk
  --all containers don't have a typeName known
  --no update

  local target, m = self:getTarget(), mockagne.getMock()
  local container = getTargetContainer()
  target.seenBy[#target.seenBy+1] = container
  
  container.isTypeKnown = m.isTypeKnown
  when(m.isTypeKnown(container)).thenAnswer(false)
  
  target.dcsObject.hasAttribute = m.hasAttribute
  target.dcsObject.getTypeName = m.getTypeName
  
  --verify initial state
  lu.assertEquals(target.typeKnown, false)
  lu.assertEquals(target:getTypeName(), "Unknown")
  
  target:updateType()
  lu.assertEquals(target.typeKnown, false)
  lu.assertEquals(target:getTypeName(), "Unknown")
  verify(m.isTypeKnown(container))
  --return before typeDeduction
  verify_no_call(m.hasAttribute(any(), any()))
  verify_no_call(m.getTypeName(any()))
end

function test_target:test_update_level3()
  --1)should call updateLEVEL3
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.updateLEVEL3 = m.updateL3
  target.lastSeen.L3 = timer.getAbsTime() - 40
  target:flushSeen() --no detection make
  
  target:update()
  verify(m.updateL3(target))
end

function test_target:test_update_level3_onlyOneOutages()
  --1)should call updateLEVEL3
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.updateLEVEL3 = m.updateL3
  target.lastSeen.L1 = timer.getAbsTime() - target.holdTime
  target.lastSeen.L2 = timer.getAbsTime() - (target.holdTime - 10)
  target:flushSeen() --no detection make
  
  target:update()
  verify(m.updateL3(target))
end

function test_target:test_update_level3_outAge()
  --1)should call updateLEVEL3
  --2)isExist() should return false
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.updateLEVEL3 = m.updateL3
  target.lastSeen.L1 = timer.getAbsTime() - target.holdTime
  target.lastSeen.L2 = timer.getAbsTime() - target.holdTime
  target:flushSeen() --no detection make
  
  target:update()
  lu.assertEquals(target:isExist(), false)
end

function test_target:test_update_level2()
  --1)should call updateLEVEL2
  --2)should call updateType
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.updateLEVEL3 = m.updateL3
  target.updateLEVEL2 = m.updateL2
  target.updateLEVEL1 = m.updateL1
  target.updateType = m.updateType
  target.typeKnown = false
  
  target:update()
  verify_no_call(m.updateL3(target))
  verify_no_call(m.updateL1(target))
  verify(m.updateL2(target))
  verify(m.updateType(target))
end

function test_target:test_update_level1()
  --1)should call updateLEVEL1
  --3)should call updateType
  local target, m = self:getTarget(), mockagne.getMock()
  
  target.updateLEVEL3 = m.updateL3
  target.updateLEVEL2 = m.updateL2
  target.updateLEVEL1 = m.updateL1
  target.updateType = m.updateType
  
  --prepare container
  target.seenBy[1].isRangeKnown = m.isRangeKnown
  when(m.isRangeKnown(target.seenBy[1])).thenAnswer(true)
  
  target:update()
  verify_no_call(m.updateL3(target))
  verify_no_call(m.updateL2(target))
  verify(m.updateL1(target))
  verify(m.updateType(target))
end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()