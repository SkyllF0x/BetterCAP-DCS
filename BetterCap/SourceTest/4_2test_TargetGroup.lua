dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_TargetGroup = {}

function test_TargetGroup:test_creation() 
  --inst.target contains target
  --all fields initialized
  
  local target = getTarget()
  --local m = mockagne.getMock()
  
  local tgtGroup = TargetGroup:create({target}, 25000)
  
  lu.assertNotNil(tgtGroup)
  lu.assertNotNil(tgtGroup.targets[target:getID()])
  
  --check basic methods
  lu.assertString(tgtGroup:getName())
  lu.assertNumber(tgtGroup:getID())
  lu.assertEquals(tgtGroup.groupRange, 25000)
  lu.assertEquals(tgtGroup:getCount(), 1)
  lu.assertEquals(tgtGroup:getROE(), AbstractTarget.ROE.Bandit)
  lu.assertEquals(tgtGroup:getHighestThreat(), {MAR = 0, MaxRange = 0})
  lu.assertEquals(tgtGroup:getTargets(), tgtGroup.targets)
  --verify targetGroup and target refence to same obj
  lu.assertEquals(tostring(tgtGroup.targets[target:getID()]), tostring(target))
  end

function test_TargetGroup:test_setTargeted_checkCreationWithoutRange() 

  local target = getTarget()
  
  local tgtGroup = TargetGroup:create({target})--no groupRange specified, should be default 30000
  
  lu.assertEquals(tgtGroup.groupRange, 30000)
  
  lu.assertEquals(tgtGroup:getTargeted(), false)
  
  tgtGroup:setTargeted(true)
  lu.assertEquals(tgtGroup:getTargeted(), true)
end

function test_TargetGroup:test_setROE() 
  --target group and all targets set to same ROE
  local tgtGroup, target1, target2 = getTargetGroup()--no groupRange specified, should be default 30000
  
  lu.assertEquals(target1:getROE(), AbstractTarget.ROE.Bandit)
  
  target2:setROE(AbstractTarget.ROE.Hostile)
  lu.assertEquals(target2:getROE(), AbstractTarget.ROE.Hostile)
  
  tgtGroup:setROE(AbstractTarget.ROE.Hostile)
  
  lu.assertEquals(tgtGroup:getROE(), AbstractTarget.ROE.Hostile)
  lu.assertEquals(target1:getROE(), AbstractTarget.ROE.Hostile)
  lu.assertEquals(target2:getROE(), AbstractTarget.ROE.Hostile)
  end

function test_TargetGroup:test_hasHostile_no() 
  --all planes don't have shooter flag, should return false
  local tgtGroup, target1, target2 = getTargetGroup()
  
  target1.isShooter = function() return false end
  target2.isShooter = target1.isShooter
  
  lu.assertEquals(tgtGroup:hasHostile(), false)
  end

function test_TargetGroup:test_hasHostile_true() 
  --atleast one plane has shooter to true
  local tgtGroup, target1, target2 = getTargetGroup()
  
  target1.isShooter = function() return false end
  target2.isShooter = function() return true end
  
  lu.assertEquals(tgtGroup:hasHostile(), true)
  end

function test_TargetGroup:test_update() 
  --counter should update
  --point should update to mean point
  --should delete dead targets
  --should update highestThreat
  --should update typeModifier()
  
  local target1 = getTarget()
  local target2 = getTarget()
  local target3 = getTarget()
  
  target1.getID = function() return 1 end
  target2.getID = function() return 2 end
  target3.getID = function() return 3 end
  
  local tgtGroup = TargetGroup:create({target1, target2, target3})--no groupRange specified, should be default 30000
  --prepare for test
  tgtGroup.targetCount = 99
  tgtGroup.point = {x = 0, y = 0, z = 0}
  tgtGroup.highestThreat = {MaxRange = 0, MAR = 0}
  tgtGroup.typeModifier = AbstractTarget.TypeModifier.HELI
  
  --first target dead
  target1.isExist = function() return false end
  target2.isExist = function() return true end
  target3.isExist = target2.isExist
  --another two should return point
  target2.getPoint = function() return {x = 100, y = 0, z = 0} end
  target3.getPoint = function() return {x = 50, y = 0, z = 0} end
  
  --for missile update, we need typeName
  target2.getTypeName = function() return "Unknown" end --first unknown
  target3.getTypeName = function() return "F-15C" end
  
  target2.getTypeModifier = function() return AbstractTarget.TypeModifier.Fighter end --should be first, take it typeModifier
  target3.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end --
  tgtGroup:update()
  
  lu.assertEquals(tgtGroup:getCount(), 2)
  lu.assertEquals(tgtGroup:getPoint(), {x = 75, y = 0, z = 0})--mean of 2 points
  lu.assertEquals(tgtGroup:getTargets()[target1:getID()], nil)
  lu.assertEquals(tostring(tgtGroup:getTargets()[target2:getID()]), tostring(target2))
  lu.assertEquals(tostring(tgtGroup:getTargets()[target3:getID()]), tostring(target3))
  lu.assertEquals(tgtGroup:getHighestThreat(), utils.PlanesTypes[target3:getTypeName()].Missile)
  lu.assertEquals(tgtGroup:getTypeModifier(), AbstractTarget.TypeModifier.Fighter)
  end

function test_TargetGroup:test_update_groupDies() 
  --isExist() return false
  --counter should be 0
  --position remain same
  --typename not updates
  local tgtGroup, target1, target2 = getTargetGroup()
  
  tgtGroup.typeModifier = AbstractTarget.TypeModifier.HELI
  tgtGroup.point = {x = 999, y = 999, z = 999}
  
  target1.isExist = function() return false end
  target2.isExist = target1.isExist
  
  target1.getTypeModifier = function() return AbstractTarget.TypeModifier.ATTACKER end
  target2.getTypeModifier = target1.getTypeModifier
  
  tgtGroup:update()
  
  lu.assertEquals(tgtGroup:getCount(), 0)
  lu.assertEquals(tgtGroup:isExist(), false)
  lu.assertEquals(tgtGroup:getPoint(), {x = 999, y = 999, z = 999})
  lu.assertEquals(tgtGroup:getTypeModifier(), AbstractTarget.TypeModifier.HELI)
  end


function test_TargetGroup:test_getExcluded()
  --remove target that far more than groupingDistance
  --remove target that has different typename
  --return removed targets
  --update counter

  local target1 = getTarget()
  local target2 = getTarget()
  local target3 = getTarget()
  local target4 = getTarget()
  
  target1.getID = function() return 1 end
  target2.getID = function() return 2 end
  target3.getID = function() return 3 end
  target4.getID = function() return 3 end
  
  local tgtGroup = TargetGroup:create({target1, target2, target3, target4}, 25000)
  tgtGroup.typeModifier = AbstractTarget.TypeModifier.ATTACKER
  
  target1.getPoint = function() return {x = 0, y = 0, z = 0} end
  target2.getPoint = function() return {x = 27000, y = 0, z = 0} end --should be excluded because range
  target3.getPoint = function() return {x = 24999, y = 0, z = 0} end --in range 
  target4.getPoint = target3.getPoint --in range but different typeModifier
  
  target1.getTypeModifier = function() return  AbstractTarget.TypeModifier.ATTACKER end
  target2.getTypeModifier = target1.getTypeModifier 
  target3.getTypeModifier  = target1.getTypeModifier 
  target4.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end
  
  local result = tgtGroup:getExcluded()
  
  lu.assertEquals(#result, 2)
  lu.assertEquals(tostring(result[1]), tostring(target2))
  lu.assertEquals(tostring(result[2]), tostring(target4))
  
  lu.assertNil(tgtGroup:getTargets()[target2:getID()])
  lu.assertNil(tgtGroup:getTargets()[target4:getID()])
  
  lu.assertEquals(tgtGroup:getCount(), 2)
end

function test_TargetGroup:test_tryAdd() 
  --target1 to far, shouldn't be accepted
  --target2 ok, should be added counter should increase
  --target3 inside range but different typeModifier
  local tgtGroup, t1, t2 = getTargetGroup()
  local target1 = getTarget()
  local target2 = getTarget()
  local target3 = getTarget()
  
  local id1, id2, id3 = utils.getGeneralID(), utils.getGeneralID(), utils.getGeneralID()
  target1.getID = function() return id1 end
  target2.getID = function() return id2 end
  target2.getID = function() return id3 end
  
  t1.getPoint = function() return {x = 0, y = 0, z = 0} end
  target1.getPoint = function() return {x = 35000, y = 0, z = 0} end
  target2.getPoint = t1.getPoint
  target3.getPoint = t1.getPoint
  
  tgtGroup.typeModifier = AbstractTarget.TypeModifier.ATTACKER
  target1.getTypeModifier = function() return AbstractTarget.TypeModifier.ATTACKER end
  target2.getTypeModifier = target1.getTypeModifier
  target3.getTypeModifier = function() return AbstractTarget.TypeModifier.HELI end
  
  lu.assertEquals(tgtGroup:tryAdd(target1), false)
  lu.assertEquals(tgtGroup:getTargets()[target1:getID()], nil)
  
  lu.assertEquals(tgtGroup:tryAdd(target2), true)
  lu.assertEquals(tgtGroup:getTargets()[target2:getID()], target2)
  
  lu.assertEquals(tgtGroup:tryAdd(target3), false)
  lu.assertEquals(tgtGroup:getTargets()[target3:getID()], nil)
  end

function test_TargetGroup:test_hasSeen() 
  --target1 in group, should call hasSeen with container and return true
  --target3 not in group, should return false
  local tgtGroup, target1, target2 = getTargetGroup()
  local radar, m = Unit:create(), mockagne.getMock()
  
  local target3 = getTarget()
  target1.dcsObject.getID = function() return target1:getID() end
  target2.dcsObject.getID = function() return target2:getID() end
  target3.dcsObject.getID = function() return 99 end
  
  local container1, container2 = TargetContainer:create({object = target1.dcsObject}, radar), TargetContainer:create({object = target3.dcsObject}, radar)
  
  target1.hasSeen = m.hasSeen
  target2.hasSeen = m.hasSeen
  
  lu.assertEquals(tgtGroup:hasSeen(container1), true) --target1 in group, should call hasSeen
  verify(m.hasSeen(target1, container1))
  verify_no_call(m.hasSeen(target2, container1))

  lu.assertEquals(tgtGroup:hasSeen(container2), false) --target3 not in group, should reject
  verify_no_call(m.hasSeen(target2, container2))
  verify_no_call(m.hasSeen(target1, container2))
  end

function test_TargetGroup:test_isExist() 
  local tgtGroup = getTargetGroup()
  
  tgtGroup.targetCount = 11
  lu.assertEquals(tgtGroup:isExist(), true)
  
  tgtGroup.targetCount = 0
  lu.assertEquals(tgtGroup:isExist(), false)
  end 

function test_TargetGroup:test_getAA() 
  local tgtGroup, target1, target2 = getTargetGroup()
  
  target1.getAA = function() return 90 end
  target2.getAA = function() return 22 end
  
  lu.assertEquals(tgtGroup:getAA({x = 0, y = 0, z = 0}), 22)
  end

function test_TargetGroup:test_mergeWith() 
  --all targets from group moved to inst
  local testedInst = getTargetGroup()
  local group, target1, target2 = getTargetGroup()
  
  
  lu.assertNil(testedInst.targets[target1:getID()])
  lu.assertNil(testedInst.targets[target2:getID()])
  
  testedInst:mergeWith(group)
  
  lu.assertEquals(testedInst.targets[target1:getID()], target1)
  lu.assertEquals(testedInst.targets[target2:getID()], target2)
  
  --target donor is dead now
  lu.assertFalse(group:isExist())
  end

local runner = lu.LuaUnit.new()
---runner:setOutputType("tap")
runner:runSuite()