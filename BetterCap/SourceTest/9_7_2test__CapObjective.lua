dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_CapObjective = {}

function test_CapObjective:test_creation() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, true, false)
  
  --verify point
  lu.assertEquals(inst.point, {x = 0, y = 0, z = 0})
  --verify zone
  lu.assertIs(inst.zone, zone)
  --verify cap/gci flags
  lu.assertEquals(inst.requestCap, true)
  lu.assertEquals(inst.requestGci, false)
  --verify priority and func set
  lu.assertEquals(inst.priority, CapObjective.Priority.Low)
  
  lu.assertEquals(inst.modifierFighter, 1)
  lu.assertEquals(inst.modifierOther, 0.25)
  lu.assertNumber(inst.capRequestAmount)
  lu.assertNumber(inst.maxGciPlanes)
end

function test_CapObjective:test_setCountModifier() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  --passed both
  inst:setCountModifier(10, 5)
  lu.assertEquals(inst.modifierFighter, 10)
  lu.assertEquals(inst.modifierOther, 5)
  
  --passed first
  inst:setCountModifier(5)
  lu.assertEquals(inst.modifierFighter, 5)
  lu.assertEquals(inst.modifierOther, 5)
  
  --passed second
  inst:setCountModifier(nil, 51)
  lu.assertEquals(inst.modifierFighter, 5)
  lu.assertEquals(inst.modifierOther, 51)
end

function test_CapObjective:test_setPriorityLow() 
  --verify priority and function updated
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, true, false, CapObjective.Priority.High)
  
  inst:setPriority(CapObjective.Priority.Low)
  lu.assertEquals(inst.priority, CapObjective.Priority.Low)
  lu.assertEquals(inst.modifierFighter, CapObjective.PriorityModifiers[CapObjective.Priority.Low].fighter)
  lu.assertEquals(inst.modifierOther, CapObjective.PriorityModifiers[CapObjective.Priority.Low].other)
  lu.assertEquals(inst.capRequestAmount, CapObjective.PriorityModifiers[CapObjective.Priority.Low].capReq)
  lu.assertEquals(inst.maxGciPlanes, 4)
end

function test_CapObjective:test_setPriorityNormal() 
  --verify priority and function updated
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.High)
  
  inst:setPriority(CapObjective.Priority.Normal)
  lu.assertEquals(inst.priority, CapObjective.Priority.Normal)
  lu.assertEquals(inst.modifierFighter, CapObjective.PriorityModifiers[CapObjective.Priority.Normal].fighter)
  lu.assertEquals(inst.modifierOther, CapObjective.PriorityModifiers[CapObjective.Priority.Normal].other)
  lu.assertEquals(inst.capRequestAmount, CapObjective.PriorityModifiers[CapObjective.Priority.Normal].capReq)
  lu.assertEquals(inst.maxGciPlanes, math.huge)
end

function test_CapObjective:test_setPriorityHigh() 
  --verify priority and function updated
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  inst:setPriority(CapObjective.Priority.High)
  lu.assertEquals(inst.modifierFighter, CapObjective.PriorityModifiers[CapObjective.Priority.High].fighter)
  lu.assertEquals(inst.modifierOther, CapObjective.PriorityModifiers[CapObjective.Priority.High].other)
  lu.assertEquals(inst.capRequestAmount, CapObjective.PriorityModifiers[CapObjective.Priority.High].capReq)
  lu.assertEquals(inst.maxGciPlanes, math.huge)
end

function test_CapObjective:test_addCapPlanes() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  inst:addCapPlanes(2)
  lu.assertEquals(inst.aircraftAssigned, 2)
  
  inst:addCapPlanes(2)
  lu.assertEquals(inst.aircraftAssigned, 4)
  
  --verify negative works
  inst:addCapPlanes(-2)
  lu.assertEquals(inst.aircraftAssigned, 2)
end

function test_CapObjective:test_addSquadron() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  lu.assertEquals(#inst.squadrons, 0)
  
  local sqn = getCapSquadronMock()
  sqn.getPoint = function() return {x = 1, y = 0, z = 0} end
  
  --elist empty, add to beginning
  inst:addSquadron(sqn)
  lu.assertEquals(#inst.squadrons, 1)
  lu.assertEquals(inst.squadrons[1], {squadron  = sqn, range = 1})
  --verify priority used
  verify(sqn:getPriorityModifier())
  
  --try add same sqn, nothing added
  inst:addSquadron(sqn)
  lu.assertEquals(#inst.squadrons, 1)
  lu.assertEquals(inst.squadrons[1], {squadron  = sqn, range = 1})
  
  --same range as prev, should add after squadron which already in list
  local sqn2 = getCapSquadronMock()
  sqn2.getPoint = function() return {x = 1, y = 0, z = 0} end
  inst:addSquadron(sqn2)
  lu.assertEquals(#inst.squadrons, 2)
  lu.assertEquals(inst.squadrons[2], {squadron  = sqn2, range = 1})
  
  --to far, exluded
  local sqn3 = getCapSquadronMock()
  sqn3.getPoint = function() return {x = 99999, y = 0, z = 0} end
  sqn3.getCombatRadius = function() return 100 end
  inst:addSquadron(sqn3)
  lu.assertEquals(#inst.squadrons, 2)
  
  --add to end
  local sqn4 = getCapSquadronMock()
  sqn4.getPoint = function() return {x = 99999, y = 0, z = 0} end
  inst:addSquadron(sqn4)
  lu.assertEquals(#inst.squadrons, 3)
end

function test_CapObjective:test_removeSquadron()
  --squadron removes and order presumed
  
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  local sqn = getCapSquadronMock()
  sqn.getPoint = function() return {x = 1, y = 0, z = 0} end
  inst:addSquadron(sqn)
  
  local sqn2 = getCapSquadronMock()
  sqn2.getPoint = function() return {x = 99999, y = 0, z = 0} end
  inst:addSquadron(sqn2)
  
  local sqn3 = getCapSquadronMock()
  sqn3.getPoint = function() return {x = 599, y = 0, z = 0} end
  inst:addSquadron(sqn3)
  lu.assertEquals(#inst.squadrons, 3)
  
  --remove sqn3(number 2 in arr)
  lu.assertEquals(inst.squadrons[2].squadron, sqn3)
  inst:removeSquadron(sqn3)
  lu.assertEquals(#inst.squadrons, 2)
  lu.assertEquals(inst.squadrons[2].squadron, sqn2)
  
  --remove sqn1(number 1 in arr)
  lu.assertEquals(inst.squadrons[1].squadron, sqn)
  inst:removeSquadron(sqn)
  lu.assertEquals(#inst.squadrons, 1)
  lu.assertEquals(inst.squadrons[1].squadron, sqn2)
  
  --remove last sqn
  --remove sqn1(number 1 in arr)
  lu.assertEquals(inst.squadrons[1].squadron, sqn2)
  inst:removeSquadron(sqn2)
  lu.assertEquals(#inst.squadrons, 0)
end

function test_CapObjective:test_getSquadrons() 
  --verify return only squadrons(not entire structure from .squadrons), and order presumed
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  local sqn = getCapSquadronMock()
  sqn.getPoint = function() return {x = 1, y = 0, z = 0} end
  inst:addSquadron(sqn)
  
  local sqn2 = getCapSquadronMock()
  sqn2.getPoint = function() return {x = 99999, y = 0, z = 0} end
  inst:addSquadron(sqn2)
  
  local sqn3 = getCapSquadronMock()
  sqn3.getPoint = function() return {x = 599, y = 0, z = 0} end
  inst:addSquadron(sqn3)
  lu.assertEquals(#inst.squadrons, 3)
  
  local function checkOrder(result) 
    for i = 1, #result do 
      if result[i] ~= inst.squadrons[i].squadron then 
        return false
      end
    end
    return true
  end
  
  local r = {}
  for _, item in inst:getSquadrons() do 
    r[#r+1] = item
  end
  
  lu.assertTrue(checkOrder(r))
end


function test_CapObjective:test_updateGeneral() 
  --verify calculateThreat called for each target 
  --threatsAircraft updated
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  local t1 = getTargetGroup()
  local t2 = getTargetGroup()
  
  local m = mockagne.getMock()
  inst.calculateThreat = m.calculateThreat
  when(inst:calculateThreat(t1)).thenAnswer(1)
  when(inst:calculateThreat(t2)).thenAnswer(3)
  
  inst:update({t1, t2})
  
  lu.assertEquals(inst.threatsAircraft, 4)
  verify(inst:calculateThreat(t1))
  verify(inst:calculateThreat(t2))
end

function test_CapObjective:test_update_0Threat()
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  inst.calculateThreat = function() return 0 end
  
  local t1 = getTargetGroup()
  
  inst:update({t1})
  lu.assertEquals(inst.threatsAircraft, 0)
end

function test_CapObjective:test_update_below1Threat()
  --amount of threatsAircraft below 1 but above 0, increment to 1
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  inst.calculateThreat = function() return 0.1 end
  
  local t1 = getTargetGroup()
  
  inst:update({t1})
  lu.assertEquals(inst.threatsAircraft, 1)
end

function test_CapObjective:test_update_above1Threat()
  --amount of threatsAircraft above 1, should round to lowest int
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  inst.calculateThreat = function() return 5.9 end
  
  local t1 = getTargetGroup()
  
  inst:update({t1})
  lu.assertEquals(inst.threatsAircraft, 5)
  
  inst.calculateThreat = function() return 4 end
  inst:update({t1})
  lu.assertEquals(inst.threatsAircraft, 4)
end


function test_CapObjective:test_getGciRequest_noThreats_noFlag() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, true, CapObjective.Priority.Low)
  
  --no threats
  inst.threatsAircraft = 0
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --has threats, but no flag
  inst.requestGci = false
  inst.threatsAircraft = 99
  lu.assertEquals(inst:getGciRequest(), 0)
end

function test_CapObjective:test_getGciRequest_lowPriority() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, true, CapObjective.Priority.Low)
  
  --no planes assigned, request 1, should return 2(minimum size)
  inst.threatsAircraft = 1
  inst.aircraftAssigned = 0
  lu.assertEquals(inst:getGciRequest(), 2)
  
  --has 2 planes, need 3, request 1(delta between threat and planes)
  inst.threatsAircraft = 3
  inst.aircraftAssigned = 2
  lu.assertEquals(inst:getGciRequest(), 1)
  
  --has 2 planes, need 2, request 0
  inst.threatsAircraft = 2
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --has 4 planes, need 2, request 0
  inst.aircraftAssigned = 4
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --has 0, need 6, request 4(max amount for low priority)
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 0
  lu.assertEquals(inst:getGciRequest(), 4)
  
  --has 2, need 6, request 2(can't request more than 4 planes)
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 2
  lu.assertEquals(inst:getGciRequest(), 2)
  
  --has 4, need 6, request 0(can't request more than 4 planes)
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 4
  lu.assertEquals(inst:getGciRequest(), 0)
end

function test_CapObjective:test_getGciRequest_notLowPriority() 
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, true, CapObjective.Priority.Normal)
  
  --no planes assigned, request 0, should return 0
  inst.threatsAircraft = 0
  inst.aircraftAssigned = 0
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --no planes assigned, request 1, should return 2(minimum size)
  inst.threatsAircraft = 1
  inst.aircraftAssigned = 0
  lu.assertEquals(inst:getGciRequest(), 2)
  
  --has 2 planes, need 3, request 1(delta between threat and planes)
  inst.threatsAircraft = 3
  inst.aircraftAssigned = 2
  lu.assertEquals(inst:getGciRequest(), 1)
  
  --has 2 planes, need 2, request 0
  inst.threatsAircraft = 2
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --has 4 planes, need 2, request 0
  inst.aircraftAssigned = 4
  lu.assertEquals(inst:getGciRequest(), 0)
  
  --has 0, need 6, request 6
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 0
  lu.assertEquals(inst:getGciRequest(), 6)
  
  --has 2, need 6, request 4
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 2
  lu.assertEquals(inst:getGciRequest(), 4)
  
  --has 4, need 6, request 2
  inst.threatsAircraft = 6
  inst.aircraftAssigned = 4
  lu.assertEquals(inst:getGciRequest(), 2)
end

function test_CapObjective:test_getCapRequest() 
  --amount of threatsAircraft above 1, should round to lowest int
  local zone = CircleZone:create({x = 0, y = 0, z = 0}, 1000)
  local inst = CapObjective:create({x = 0, y = 0, z = 0}, zone, false, false, CapObjective.Priority.Low)
  
  --low priority, always 0
  lu.assertEquals(inst:getCapRequest(), 0)
  
  --normal priority, but no option
  inst:setPriority(CapObjective.Priority.Normal)
  lu.assertEquals(inst:getCapRequest(), 0)
  
  --option set, return 2
  inst:setRequestCap(true)
  lu.assertEquals(inst:getCapRequest(), 2)
  
  --has 2 planes, return 0
  inst:addCapPlanes(2)
  lu.assertEquals(inst:getCapRequest(), 0)
  
  --has 4 planes, return 0
  inst:addCapPlanes(2)
  lu.assertEquals(inst:getCapRequest(), 0)
  
  --has 4 planes, return 4
  inst.aircraftAssigned = 0
  inst:setPriority(CapObjective.Priority.High)
  lu.assertEquals(inst:getCapRequest(), 4)
  
  --has 2 planes, request another 2
  inst:addCapPlanes(2)
  lu.assertEquals(inst:getCapRequest(), 2)
end
  
  
local runner = lu.LuaUnit.new()
runner:runSuite()