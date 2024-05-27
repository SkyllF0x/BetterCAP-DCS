dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_CapElement = {}

function test_CapElement:test_Creation_andUpdate() 
  local capPlane1 = getCapPlane()
  local capPlane2 = getCapPlane()
  capPlane1.getPoint = function() return {x = 0, y = 0, z = 0} end
  capPlane2.getPoint = function() return {x = 10, y = 0, z = 0} end
  
  capPlane1.getBestMissile = function() return {MAR = 9999, MaxRange = 9999} end
  capPlane2.getBestMissile = function() return {MAR = 9999, MaxRange = 19999} end
  
  local inst = CapElement:create({capPlane1, capPlane2})
  
  lu.assertIs(inst.planes[1], capPlane1)
  lu.assertIs(inst.planes[2], capPlane2)
  lu.assertString(inst.name)
  lu.assertNumber(inst.id)
  lu.assertNumber(inst:getID())
  lu.assertString(inst:getName())
  
  --verify point updated and now it mean pos
  lu.assertEquals(inst:getPoint(), {x = 5, y = 0, z = 0})
  --verify missile updated and it missile with most range
  lu.assertEquals(inst:getBestMissile(), capPlane2:getBestMissile())
  
  lu.assertNotNil(inst.FSM_stack)
  lu.assertEquals(inst:getCurrentFSM(), AbstractState.enumerator)
  
  --no reference to second element
  lu.assertNil(inst.secondElement)
  
  --verify plane link updated
  lu.assertEquals(capPlane1.myElement, inst)
  lu.assertEquals(capPlane2.myElement, inst)
  
  lu.assertEquals(tostring(capPlane1.myElement), tostring(inst))
  lu.assertEquals(tostring(capPlane2.myElement), tostring(inst))
end

function test_CapElement:test_isExist() 
  --delete dead plane
  --other plane should remain in .planes
  --capPlane2 and new inst.planes[1] is same
  local capPlane1, group, unit, m = getCapPlane()
  local capPlane2 = getCapPlane()
  
  local inst = CapElement:create({capPlane1, capPlane2})
  
  capPlane1.isExist = m.isExist
  when(m.isExist(capPlane1)).thenAnswer(false)
  
  lu.assertEquals(inst:isExist(), true)
  lu.assertIs(inst.planes[1], capPlane2)
end

function test_CapElement:test_isExist_false() 
  --delete dead plane
  --other plane should remain in .planes
  --capPlane2 and new inst.planes[1] is same
  local capPlane1, group, unit, m = getCapPlane()
  
  local inst = CapElement:create({capPlane1})
  
  capPlane1.isExist = m.isExist
  when(m.isExist(capPlane1)).thenAnswer(false)
  
  lu.assertEquals(inst:isExist(), false)
  end

function test_CapElement:test_isSpikedBy_clear() 
  --listContacts is list of Target instances
  local capPlane1, group, unit, mock = getCapPlane()
  local target1 = getTarget()
  local target2 = getTarget()
  
  local target1_ID, target2_ID  = 11, 22
  
  target1:getObject().getID = function() return target1_ID end
  target1.getID = function() return target1_ID end --need override cause id saved of creation
  
  target2:getObject().getID = function() return target2_ID end
  target2.getID = function() return target2_ID end

  
  capPlane1.getNails = mock.getNails 
  --return only 1 contact, should be enough
  when(mock.getNails(capPlane1)).thenAnswer({
      {object = target1:getObject(), visible = false, type = false, distance = false}, --first detection table
    })
  
  local inst = CapElement:create({capPlane1})
  
  lu.assertEquals(inst:isSpikedBy({target1, target2}), true)
end

function test_CapElement:test_isSpikedBy() 
  --listContacts is list of Target instances
  local capPlane1, group, unit, mock = getCapPlane()
  local target1 = getTarget()
  local target2 = getTarget()
  
  local target1_ID, target2_ID  = 11, 22
  
  target1:getObject().getID = function() return target1_ID end
  target1.getID = function() return target1_ID end --need override cause id saved of creation
  
  target2:getObject().getID = function() return target2_ID end
  target2.getID = function() return target2_ID end

  
  capPlane1.getNails = mock.getNails 
  --return only 1 contact, should be enough
  when(mock.getNails(capPlane1)).thenAnswer({
      {object = Unit:create(), visible = false, type = false, distance = false}, --first detection table
    })
  
  local inst = CapElement:create({capPlane1})
  
  lu.assertEquals(inst:isSpikedBy({target1, target2}), false)
  end

function test_CapElement:test_sortByAmmo() 
  --return planes sorted by ammo
  local capPlane1, group, unit, mock = getCapPlane()
  local capPlane2 = getCapPlane()

  local IR, SARH = Weapon.GuidanceType.IR, Weapon.GuidanceType.RADAR_SEMI_ACTIVE    
  local ARH = Weapon.GuidanceType.RADAR_ACTIVE
  --no mocks, cause also need mock getID, this just faster
  capPlane1.getAmmo = function() return {[IR] = 1, [ARH] = 1, [SARH] = 0} end
  capPlane2.getAmmo = function() return {[IR] = 1, [ARH] = 1, [SARH] = 10} end --should be first
  
  local inst = CapElement:create({capPlane1, capPlane2})
  local result = inst:sortByAmmo()
  
  lu.assertEquals(tostring(capPlane1), tostring(result[2]))--object is refers to same address
  lu.assertEquals(tostring(capPlane2), tostring(result[1]))--compare by address
  
  --check original order preserved
  lu.assertEquals(tostring(capPlane1), tostring(inst.planes[1]))
  lu.assertEquals(tostring(capPlane2), tostring(inst.planes[2]))
  result[1].targeted = true
  lu.assertEquals(capPlane2.targeted, true)
  lu.assertEquals(inst.planes[2].targeted, true)
  end


function test_CapElement:test_getSecondElement_noElem() 
  local capGroup = getCapGroup()
  
  local element = capGroup.elements[1]
  
  lu.assertNotNil(element.myGroup)
  lu.assertNil(element.secondElement)
  
  lu.assertNil(element:getSecondElement())
  end

function test_CapElement:test_getSecondElement() 
  local capGroup = getCapGroup()
  local plane2 = getCapPlane()
  
  local element1 = capGroup.elements[1]
  local element2 = CapElement:create({plane2})
  
  capGroup.elements[2] = element2
  
  element1:setSecondElement(element2)
  element2:setSecondElement(element1)
  
  lu.assertEquals(element1:getSecondElement(), element2)
  lu.assertEquals(tostring(element1:getSecondElement()), tostring(element2))
  end

function test_CapElement:test_callPlanes() 
  local elem = getElement()
  local m = mockagne.getMock()
  
  elem.planes[1].callFSM = m.callFSM
  
  elem:callPlanes()
  verify(m.callFSM(elem.planes[1]))
end

function test_CapElement:test_callFSM() 
  --current state run() called with fsm_args
  --callPlanes() called
  --FSM_args viped
  local elem = getElement()
  local m = mockagne.getMock()
  
  elem.FSM_stack:getCurrentState().run = m.run
  elem.callPlanes = m.callPlanes
  
  local args = {radars = 2, waypoint = 55}
  elem.FSM_args = args
  
  elem:callFSM()
  verify(elem.FSM_stack:getCurrentState():run(args))
  verify(elem:callPlanes())
  
  lu.assertEquals(elem.FSM_args, {})
  end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()
