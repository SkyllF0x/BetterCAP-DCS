dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_AbstractZone = {}

function test_AbstractZone:test_creation() 
  local zone = AbstractZone:create()
  
  lu.assertString(zone.name)
  lu.assertNotNil(zone.id)
  
  lu.assertNotNil(zone:getID())
  lu.assertNotNil(zone:getName())
end

function test_AbstractZone:test_methods() 
  local zone = AbstractZone:create()
  
  lu.assertEquals(zone:getDistance({x = 0, y = 0, z = 0}), -1)
  lu.assertEquals(zone:isInZone({x = 0, y = 0, z = 0}), true)
end

------------------------------------------------------------------------
------------------------------------------------------------------------

test_CircleZone = {}

function test_CircleZone:test_creation() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 9999)
  
  lu.assertString(zone.name)
  lu.assertNotNil(zone.id)
  
  lu.assertNotNil(zone:getID())
  lu.assertNotNil(zone:getName())
end

function test_CircleZone:test_getDistance() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 10000)
  
  --inside zone
  lu.assertEquals(zone:getDistance({x = 9000, y = 0, z = 0}), -1)
  
  --outside zone
  lu.assertEquals(zone:getDistance({x = 19000, y = 0, z = 0}), 9000)
end

function test_CircleZone:test_isInZone() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 10000)
  
  --inside zone
  lu.assertEquals(zone:isInZone({x = 9000, y = 0, z = 0}), true)
  
  --outside zone
  lu.assertEquals(zone:isInZone({x = 19000, y = 0, z = 0}), false)
end

------------------------------------------------------------------------
------------------------------------------------------------------------

test_ShapeZone = {}
--square
test_ShapeZone.points = {
  {x = -5, y = 5}, {x = 5, y = 5},
  {x = 5, y = -5}, {x = -5, y = -5}}

function test_ShapeZone:test_creation() 
  local zone = ShapeZone:create(test_ShapeZone.points)
  
  lu.assertEquals(test_ShapeZone.points, test_ShapeZone.points)
  lu.assertString(zone.name)
  lu.assertNotNil(zone.id)
  
  lu.assertNotNil(zone:getID())
  lu.assertNotNil(zone:getName())
end

function test_ShapeZone:test_getDistance() 
  local zone = ShapeZone:create(test_ShapeZone.points)

  --inside zone
  lu.assertEquals(zone:getDistance({x = 0, y = 0, z = 0}), -1)
  
  --outside zone
  lu.assertEquals(zone:getDistance({x = 10, y = 0, z = 0}), 5)
end

function test_ShapeZone:test_isInZone() 
  local zone = ShapeZone:create(test_ShapeZone.points)
  
  --inside zone
  lu.assertEquals(zone:isInZone({x = 0, y = 0, z = 0}), true)
  
  --outside zone
  lu.assertEquals(zone:isInZone({x = 10, y = 10, z = 0}), false)
end


------------------------------------------------------------------------
------------------------------------------------------------------------

test_DetectionHandler = {}

function test_DetectionHandler:test_creation() 
  
  local inst = DetectionHandler:create(1)
  
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getID())
  
  lu.assertEquals(inst.coalition, 1)
  lu.assertEquals(inst.radars, {})
  lu.assertEquals(inst.airborneRadars, {})
  lu.assertEquals(inst.targets, {})
  
  lu.assertNumber(inst.borderZone)
  lu.assertNumber(inst.trackHoldTime)
  end

function test_DetectionHandler:test_setter() 
  
  local inst = DetectionHandler:create(1)
  
  inst:setTrackHoldTime(99)
  lu.assertEquals(inst.trackHoldTime, 99)
  
  local testUnit = {}
  testUnit.getID = function() return 99 end
  
  inst:addRadar(testUnit)
  lu.assertEquals(inst.radars[testUnit:getID()], testUnit)
  
  inst:addFighterGroup(testUnit)
  lu.assertEquals(inst.airborneRadars[testUnit:getID()], testUnit)
  
  inst:setBorderZone(99)
  lu.assertEquals(inst.borderZone, 99)
end

function test_DetectionHandler:test_radarDelete() 
  local inst = DetectionHandler:create(1)
   
  local testUnit1, testUnit2 = {}, {}
  testUnit1.getID = function() return 99 end
  testUnit2.getID = function() return 98 end
  
  inst:addRadar(testUnit1)
  inst:addRadar(testUnit2)
  inst:addFighterGroup(testUnit1)
  inst:addFighterGroup(testUnit2)
  
  inst:deleteRadar(testUnit2)
  lu.assertNotNil(inst.radars[testUnit1:getID()])
  lu.assertEquals(inst.radars[testUnit2:getID()], nil)
  
  inst:deleteRadar(testUnit1)
  lu.assertEquals(inst.radars[testUnit1:getID()], nil)
  lu.assertEquals(inst.radars[testUnit2:getID()], nil)
  
  inst:deleteFighterGroup(testUnit1)
  lu.assertEquals(inst.airborneRadars[testUnit1:getID()], nil)
  lu.assertEquals(inst.airborneRadars[testUnit2:getID()], testUnit2)
  
  inst:deleteFighterGroup(testUnit2)
  lu.assertEquals(inst.airborneRadars[testUnit1:getID()], nil)
  lu.assertEquals(inst.airborneRadars[testUnit2:getID()], nil)
end

function test_DetectionHandler:test_addBorder() 
  local inst = DetectionHandler:create(1)
  
  local border = CircleZone:create({x = 0, y = 0}, 999)
  inst:addBorder(border)
  
  lu.assertEquals(inst.border, border)
  end

function test_DetectionHandler:test_getRadars() 
  local rdr1 = getRadar()
  local rdr2 = getRadar()
  local rdr3 = getRadar()
  
  local inst = DetectionHandler:create(1)
  inst:addRadar(rdr1)
  inst:addRadar(rdr2)
  inst:addRadar(rdr3)
  
  lu.assertEquals(countElements(inst:getRadars()), 3)
  end
  
function test_DetectionHandler:test_getTargets()   
  local tgt1 = getTargetGroup()
  local tgt2 = getTargetGroup()
  
  local inst = DetectionHandler:create(1)
  inst.targets[tgt1:getID()] = tgt1
  inst.targets[tgt2:getID()] = tgt2
  
  lu.assertEquals(countElements(inst:getTargets()), 2)
end

function test_DetectionHandler:test_getHostileTargets()   
  local tgt1 = getTargetGroup()
  local tgt2 = getTargetGroup()
  
  --should be only tgt2
  tgt1:setROE(AbstractTarget.ROE.Bandit)
  tgt2:setROE(AbstractTarget.ROE.Hostile)
  
  local inst = DetectionHandler:create(1)
  inst.targets[tgt1:getID()] = tgt1
  inst.targets[tgt2:getID()] = tgt2
  
  lu.assertEquals(countElements(inst:getHostileTargets()), 1)
end

function test_DetectionHandler:test_updateRadars()
  --should delete all dead radars
  local rdr1, rdr2, rdr3 = getRadar(), getRadar(), getRadar()
  local airbornRdr1, airbornRdr2 = getRadar(), getRadar()
  
  rdr1.isExist = function() return false end
  rdr2.isExist = function() return true end
  rdr3.isExist = rdr1.isExist
  
  airbornRdr1.isExist = rdr1.isExist
  airbornRdr2.isExist = rdr2.isExist
  
  airbornRdr1.getAutonomous = function() return true end
  airbornRdr2.getAutonomous = airbornRdr1.getAutonomous
  
  local inst = DetectionHandler:create(1)
  inst:addRadar(rdr1)
  inst:addRadar(rdr2)
  inst:addRadar(rdr3)
  inst:addFighterGroup(airbornRdr1)
  inst:addFighterGroup(airbornRdr2)
  
  --check all radars added
  lu.assertNotNil(inst.radars[rdr1:getID()])
  lu.assertNotNil(inst.radars[rdr2:getID()])
  lu.assertNotNil(inst.radars[rdr3:getID()])
  
  lu.assertNotNil(inst.airborneRadars[airbornRdr1:getID()])
  lu.assertNotNil(inst.airborneRadars[airbornRdr2:getID()])
  
  --verify dead radars deleted
  inst:updateRadars()
  lu.assertNil(inst.radars[rdr1:getID()])
  lu.assertNotNil(inst.radars[rdr2:getID()])
  lu.assertNil(inst.radars[rdr3:getID()])
  
  lu.assertNil(inst.airborneRadars[airbornRdr1:getID()])
  lu.assertNotNil(inst.airborneRadars[airbornRdr2:getID()])
  
  --fully clean radars
  rdr2.isExist = rdr1.isExist
  airbornRdr2.isExist = rdr1.isExist
  
  inst:updateRadars()
  lu.assertNil(inst.radars[rdr1:getID()])
  lu.assertNil(inst.radars[rdr2:getID()])
  lu.assertNil(inst.radars[rdr3:getID()])
  
  lu.assertNil(inst.airborneRadars[airbornRdr1:getID()])
  lu.assertNil(inst.airborneRadars[airbornRdr2:getID()])
end

function test_DetectionHandler:test_updateRadars_deleteNotAutonomous()
  --first group ok
  --second is alive but no autonomous
  local airbornRdr1, airbornRdr2 = getRadar(), getRadar()
  local m = mockagne.getMock()
  
  airbornRdr1.isExist = m.isExist
  airbornRdr2.isExist = m.isExist
  when(airbornRdr1:isExist()).thenAnswer(true)
  when(airbornRdr2:isExist()).thenAnswer(true)
  
  airbornRdr1.getAutonomous = m.getAutonomous
  airbornRdr2.getAutonomous = m.getAutonomous
  when(airbornRdr1:getAutonomous()).thenAnswer(true)
  when(airbornRdr2:getAutonomous()).thenAnswer(false)
  
  local inst = DetectionHandler:create(1)

  inst:addFighterGroup(airbornRdr1)
  inst:addFighterGroup(airbornRdr2)
  
  --check all radars added
  lu.assertNotNil(inst.airborneRadars[airbornRdr1:getID()])
  lu.assertNotNil(inst.airborneRadars[airbornRdr2:getID()])
  
  inst:updateRadars()
  lu.assertNotNil(inst.airborneRadars[airbornRdr1:getID()])
  lu.assertNil(inst.airborneRadars[airbornRdr2:getID()])
  
  verify(airbornRdr1:getAutonomous())
  verify(airbornRdr2:getAutonomous())
end

function test_DetectionHandler:test_askRadars() 
  --all containers from all radars in one array
  local rdr1, rdr2 = getRadar(), getRadar()
  local airbornRdr1 = getRadar()
  local mock = mockagne.getMock()
  
  local inst = DetectionHandler:create(1)
  inst:addRadar(rdr1)
  inst:addRadar(rdr2)
  inst:addFighterGroup(airbornRdr1)
  
  local containers = {}
  for i = 1, 5 do 
    containers[i] = getTargetContainer()
  end
  
  rdr1.getDetectedTargets = mock.getDetectedTargets
  when(mock.getDetectedTargets(rdr1)).thenAnswer({containers[1], containers[2], containers[3]})
  
  rdr2.getDetectedTargets = mock.getDetectedTargets
  when(mock.getDetectedTargets(rdr2)).thenAnswer({})--radar 2 has no targets
  
  airbornRdr1.getDetectedTargets = mock.getDetectedTargets
  when(mock.getDetectedTargets(airbornRdr1)).thenAnswer({containers[4], containers[5]})
  
  local result = inst:askRadars()
  lu.assertEquals(#result, 5)
  end

function test_DetectionHandler.test_updateExisted() 
  --should call hasSeen() for all target groups
  --return containers which don't match(hasSeen() return false on all groups)
  local inst = DetectionHandler:create(1)
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  local m = mockagne.getMock()
  
  local containers = {}
  for i = 1, 3 do 
    containers[i] = getTargetContainer()
  end
  
  targetGroup1.hasSeen = m.hasSeen
  when(m.hasSeen(targetGroup1, containers[1])).thenAnswer(false)
  when(m.hasSeen(targetGroup1, containers[2])).thenAnswer(false)
  when(m.hasSeen(targetGroup1, containers[3])).thenAnswer(true)
  
  targetGroup2.hasSeen = m.hasSeen
  when(m.hasSeen(targetGroup2, containers[1])).thenAnswer(true)
  when(m.hasSeen(targetGroup2, containers[2])).thenAnswer(false)
  when(m.hasSeen(targetGroup2, containers[3])).thenAnswer(false)
  
  --firstly test when no containers
  lu.assertEquals(inst:updateExisted({}), {})
  verify_no_call(m.hasSeen(any(), any()))
  
  --no targets, but has containers, should just return containers back
  lu.assertEquals(inst:updateExisted(containers), containers)
  verify_no_call(m.hasSeen(any(), any()))
  
  --add targets
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2

  --containers 1 and 3 has been used
  lu.assertEquals(inst:updateExisted(containers), {containers[2]})
  verify(m.hasSeen(targetGroup1, containers[3]))
  
  verify(m.hasSeen(targetGroup2, containers[1]))

end

function test_DetectionHandler:test_createTargets() 
  --pass containers, should create targets from containers
  --if container wrap target which was created, call hasSeen
  --return dict 'ID' = target 
  local inst = DetectionHandler:create(1)
  
  local containers = {}
  for i = 1, 3 do 
    containers[i] = getTargetContainer()
  end
  
  --this 2 containers 'refers' to 1 target
  containers[1]:getTarget().getID = function() return 999 end
  containers[3]:getTarget().getID = containers[1]:getTarget().getID 
  
  local result = inst:createTargets(containers)
  --count entries, should be only2, cause 1st and 3rd container refers to 1 target
  local count = 0
  for _, target in pairs(result) do 
    count = count + 1
  end
  
  lu.assertEquals(count, 2)
  
  --was seen by 2 containers
  lu.assertEquals(#result[containers[1]:getTarget():getID()].seenBy, 2)
  lu.assertEquals(#result[containers[2]:getTarget():getID()].seenBy, 1)
  end

function test_DetectionHandler:test_tryAdd() 
  --call update on each target
  --tryes add target1 in every group until was accepted, no call after return true
  --target2 can't be accepted, return false
  local inst = DetectionHandler:create(1)
  
  local target1 = getTarget()
  local target2 = getTarget()
  
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  local m = mockagne.getMock()
  
  target1.update = m.update
  target2.update = m.update
  
  targetGroup1.tryAdd = m.tryAdd
  when(m.tryAdd(targetGroup1, target1)).thenAnswer(true)
  when(m.tryAdd(targetGroup1, target2)).thenAnswer(false)

  targetGroup2.tryAdd = m.tryAdd
  when(m.tryAdd(targetGroup2, target1)).thenAnswer(false)
  when(m.tryAdd(targetGroup2, target2)).thenAnswer(false)
  
  lu.assertEquals(countElements(inst.targets), 0)
  
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  lu.assertEquals(countElements(inst.targets), 2)
  
  lu.assertEquals(inst:tryAdd(target1), true)
  verify(m.update(target1))
  verify(m.tryAdd(targetGroup1, target1))--accepted here, no call to second group
  
  lu.assertEquals(inst:tryAdd(target2), false)
  verify(m.update(target2))
  --no accept shoult call all groups
  verify(m.tryAdd(targetGroup1, target2))
  verify(m.tryAdd(targetGroup2, target2))
  end


function test_DetectionHandler:test_mergeGroups_toFar() 
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  local targetGroup3 = getTargetGroup()
  
  targetGroup1.getPoint = function() return {x = 0, y = 0, z = 0} end
  targetGroup2.getPoint = function() return {x = 99999, y = 0, z = 0} end
  targetGroup3.getPoint = function() return {x = -99999, y = 0, z = 0} end
  
  local inst = DetectionHandler:create(1)
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  inst.targets[targetGroup3:getID()] = targetGroup3
  
  lu.assertEquals(countElements(inst.targets), 3)
  lu.assertEquals(countElements(targetGroup1.targets), 2)
  lu.assertEquals(countElements(targetGroup2.targets), 2)
  lu.assertEquals(countElements(targetGroup3.targets), 2)

  inst:mergeGroups() 
  
  lu.assertEquals(countElements(inst.targets), 3)
  lu.assertEquals(countElements(targetGroup1.targets), 2)
  lu.assertEquals(countElements(targetGroup2.targets), 2)
  lu.assertEquals(countElements(targetGroup3.targets), 2)
end

function test_DetectionHandler:test_mergeGroups_3AtOnce() 
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  local targetGroup3 = getTargetGroup()
  
  local inst = DetectionHandler:create(1)
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  inst.targets[targetGroup3:getID()] = targetGroup3
  
  lu.assertEquals(countElements(inst.targets), 3)
  lu.assertEquals(countElements(targetGroup1.targets), 2)
  lu.assertEquals(countElements(targetGroup2.targets), 2)
  lu.assertEquals(countElements(targetGroup3.targets), 2)

  inst:mergeGroups() 
  
  lu.assertEquals(countElements(inst.targets), 1)
  for _, targetG in pairs(inst.targets) do 
    lu.assertEquals(countElements(targetG.targets), 6)
    end
  
end

function test_DetectionHandler:test_mergeGroups_differentROEandTypeModifier() 
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  local targetGroup3 = getTargetGroup()
  
  targetGroup1.getPoint = function() return {x = 0, y = 0, z = 0} end
  targetGroup2.getPoint = targetGroup1.getPoint
  targetGroup3.getPoint = targetGroup1.getPoint
  
  targetGroup1.getTypeModifier = function() return AbstractTarget.TypeModifier.ATTACKER end
  targetGroup2.getTypeModifier = targetGroup1.getTypeModifier
  targetGroup3.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end
  
  targetGroup1.getROE = function() return AbstractTarget.ROE.Hostile end
  targetGroup2.getROE = function() return AbstractTarget.ROE.Bandit end
  targetGroup3.getROE = targetGroup1.getROE
  
  local inst = DetectionHandler:create(1)
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  inst.targets[targetGroup3:getID()] = targetGroup3
  
  lu.assertEquals(countElements(inst.targets), 3)
  lu.assertEquals(countElements(targetGroup1.targets), 2)
  lu.assertEquals(countElements(targetGroup2.targets), 2)
  lu.assertEquals(countElements(targetGroup3.targets), 2)

  inst:mergeGroups() 
  
  lu.assertEquals(countElements(inst.targets), 3)
  lu.assertEquals(countElements(targetGroup1.targets), 2)
  lu.assertEquals(countElements(targetGroup2.targets), 2)
  lu.assertEquals(countElements(targetGroup3.targets), 2)
end

function test_DetectionHandler:test_updateTargets() 
  --update call on all targetGroups
  --targetGroup1 is dead, should delete it, no calls on it after
  --targetGroup2 alive, has excluded targets by TypeModifier, but other group can accept it
  --no new target should be created
  
  local inst = DetectionHandler:create(1)
  local m = mockagne.getMock()
  
  local targetGroup1 = getTargetGroup()
  local targetGroup2, target1, target2 = getTargetGroup()
  local targetGroup3 = getTargetGroup()
  
  targetGroup1.update = m.update
  targetGroup2.update = m.update
  targetGroup3.update = m.update
  
  targetGroup1.isExist = function() return false end
  targetGroup2.isExist = function() return true end
  targetGroup3.isExist = targetGroup2.isExist
  
  targetGroup1.getExcluded = m.getExcluded
  targetGroup2.getExcluded = m.getExcluded
  targetGroup3.getExcluded = m.getExcluded
  
  when(m.getExcluded(targetGroup2)).thenAnswer({target1})
  when(m.getExcluded(targetGroup3)).thenAnswer({})
  
  inst.tryAdd = m.tryAdd
  --accepted
  when(m.tryAdd(inst, target1)).thenAnswer(true)
  
  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  inst.targets[targetGroup3:getID()] = targetGroup3
  lu.assertEquals(countElements(inst.targets), 3)
  
  inst:updateTargets()
  --1 target was deleted, no new created
  lu.assertEquals(countElements(inst.targets), 2)
  lu.assertNotNil(inst.targets[targetGroup2:getID()])
  lu.assertNotNil(inst.targets[targetGroup3:getID()])
  
  verify(m.update(targetGroup1))
  verify(m.update(targetGroup2))
  verify(m.update(targetGroup3))
  --group dead, no call on it
  verify_no_call(m.getExcluded(targetGroup1))
  
  verify(m.getExcluded(targetGroup2))
  verify(m.getExcluded(targetGroup3))
  verify(m.tryAdd(inst, target1))
end

function test_DetectionHandler:test_updateTargets_createFromExcluded()
  --target1 excluded and can't be added to other groups
  --should create new target group
  
  local inst = DetectionHandler:create(1)
  local m = mockagne.getMock()
  
  local targetGroup1,target1, target2 = getTargetGroup()
  targetGroup1.isExist = function() return true end
  
  targetGroup1.getExcluded = function() return {target1} end
  
  inst.tryAdd = m.tryAdd
  when(m.tryAdd(inst, target1)).thenAnswer(false)
  
  inst.targets[targetGroup1:getID()] = targetGroup1
  lu.assertEquals(countElements(inst.targets), 1)
  
  inst:updateTargets()
  lu.assertEquals(countElements(inst.targets), 2)
  end

function test_DetectionHandler:test_updateROE_Bandit() 
  --targetGroup1 is hostile and inside borderZone - no changes
  --targetGroup2 is hostile and outside borderZone - setROE() to bandit
  local inst = DetectionHandler:create(1)
  local m = mockagne.getMock()
  
  local P1, P2 = {x = 0, y = 0, z = 0}, {x = 10, y = 10, z = 0}
  
  inst.border.getDistance = m.getDistance
  when(m.getDistance(any(), P1)).thenAnswer(10000)
  when(m.getDistance(any(), P2)).thenAnswer(99999)
  
  
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  targetGroup1:setROE(AbstractTarget.ROE.Hostile)
  targetGroup2:setROE(AbstractTarget.ROE.Hostile)
  
  targetGroup1.getPoint = function() return P1 end
  targetGroup2.getPoint = function() return P2 end
  
  targetGroup1.hasHostile = function() return true end
  targetGroup2.hasHostile = function() return true end
  
  targetGroup1.isExist = function() return true end
  targetGroup2.isExist = targetGroup1.isExist

  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  
  lu.assertEquals(countElements(inst.targets), 2)
  
  inst:updateROE()
  --group not deleted
  lu.assertEquals(countElements(inst.targets), 2)
  lu.assertNotNil(inst.targets[targetGroup2:getID()])
  
  --roe was set
  lu.assertEquals(targetGroup1:getROE(), AbstractTarget.ROE.Hostile)
  lu.assertEquals(targetGroup2:getROE(), AbstractTarget.ROE.Bandit)  
end

function test_DetectionHandler:test_updateROE_setHostile() 
  --targetGroup1 inside border, set to hostile
  --targetGroup2 ouside border, but have shooter and insize borderZone - set to Hostile
  local inst = DetectionHandler:create(1)
  local m = mockagne.getMock()
  
  local P1, P2 = {x = 0, y = 0, z = 0}, {x = 10, y = 10, z = 0}
  
  inst.border.getDistance = m.getDistance
  when(m.getDistance(any(), P1)).thenAnswer(-1)--insize zone
  when(m.getDistance(any(), P2)).thenAnswer(inst.borderZone - 10)
  
  local targetGroup1 = getTargetGroup()
  local targetGroup2 = getTargetGroup()
  targetGroup1:setROE(AbstractTarget.ROE.Bandit)
  targetGroup2:setROE(AbstractTarget.ROE.Bandit)
  
  targetGroup1.getPoint = function() return P1 end
  targetGroup2.getPoint = function() return P2 end
  
  targetGroup1.hasHostile = function() return false end
  targetGroup2.hasHostile = function() return true end
  
  targetGroup1.isExist = function() return true end
  targetGroup2.isExist = targetGroup1.isExist

  inst.targets[targetGroup1:getID()] = targetGroup1
  inst.targets[targetGroup2:getID()] = targetGroup2
  
  lu.assertEquals(countElements(inst.targets), 2)
  
  inst:updateROE()
  
  lu.assertEquals(targetGroup1:getROE(), AbstractTarget.ROE.Hostile)
  lu.assertEquals(targetGroup2:getROE(), AbstractTarget.ROE.Hostile)  
  end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()