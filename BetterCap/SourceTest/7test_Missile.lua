dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_missile = {}

function test_missile:test_creationFail_noTarget() 
  --early return 
  local w, m = Weapon:create(), mockagne.getMock()
  
  w.getTarget = m.getTarget
  when(m.getTarget(w)).thenAnswer(nil)
  
  lu.assertIsNil(MissileWrapper:create(w))
end


function test_missile:test_creationFail_wrongGuidance()
  local w, m = Weapon:create(), mockagne.getMock()
  
  when(m.getDesc(w)).thenAnswer({guidance = 9})
  when(m.getTarget(w)).thenAnswer(Unit:create())
  
  lu.assertIsNil(MissileWrapper:create(w))
end

function test_missile:test_creation() 
  --early return 
  
  local w, m = Weapon:create(), mockagne.getMock()
  
  w.getTarget = m.getTarget
  w.getDesc = m.getDesc
  when(m.getTarget(w)).thenAnswer(Unit:create())
  when(m.getDesc(w)).thenAnswer({guidance = 2})
  
  local inst = MissileWrapper:create(w)
  
  lu.assertNotNil(inst)
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:isExist())
  lu.assertNotNil(inst:getTypeName())
end

function test_missile:test_isTrashed_missileDead() 
  --early return 
  
  local inst, w, m = getMissileWrapper()
  
  w.isExist = m.isExist
  when(m.isExist(w)).thenAnswer(false)
  
  lu.assertNotNil(inst)
  lu.assertEquals(inst:isTrashed(), true)
  verify(m.isExist(w))
end


function test_missile:test_isTrashed_targetDead() 
  --early return 
  local inst, w, m = getMissileWrapper()
  
  inst.target.isExist = m.isExist
  when(m.isExist(inst.target)).thenAnswer(false)
  
  lu.assertEquals(inst:isTrashed(), true)
  verify(m.isExist(inst.target))
end

function test_missile:test_isTrashed_speedSmall() 
  --early return 
  local inst, w, m = getMissileWrapper()
  local target = Unit:create()
  
  inst.getClosingSpeed = m.getClosingSpeed
  when(m.getClosingSpeed(inst)).thenAnswer(1)
  
  lu.assertNotNil(inst)
  lu.assertEquals(inst:isTrashed(), true)
  verify(m.getClosingSpeed(inst))
end

function test_missile:test_isTrashed_ok() 
  --early return 
  local inst, w, m = getMissileWrapper()
  local target = Unit:create()
  
  inst.getClosingSpeed = m.getClosingSpeed
  when(m.getClosingSpeed(inst)).thenAnswer(999)
  
  lu.assertNotNil(inst)
  lu.assertEquals(inst:isTrashed(), false)
  verify(m.getClosingSpeed(inst))
end

function test_missile:test_isActive_Fox2() 
  --always return true
  --distance is much more then pittbull
  local inst, w, m = getMissileWrapper()
  
  inst.getPoint = function() return {x = 0, y = 0, z = 0} end
  inst.getGuidance = function() return Weapon.GuidanceType.IR end
  
  inst.target.getPoint = function() return {x = 99999, y = 0, z = 0} end
  
  lu.assertTrue(inst:isActive())
end

function test_missile:test_isActive_Fox1() 
  --always return false
  --even if distance smaller than pittbull
  local inst, w, m = getMissileWrapper()
  
  inst.getPoint = function() return {x = 0, y = 0, z = 0} end
  inst.getGuidance = function() return Weapon.GuidanceType.RADAR_SEMI_ACTIVE end
  
  inst.target.getPoint = inst.getPoint
  
  lu.assertFalse(inst:isActive())
end

function test_missile:test_isActive_Fox3_toFar() 
  --distance > 18km, return false
  local inst, w, m = getMissileWrapper()
  
  inst.getPoint = function() return {x = 0, y = 0, z = 0} end
  inst.getGuidance = function() return Weapon.GuidanceType.RADAR_ACTIVE end
  
  inst.target.getPoint = function() return {x = 99999, y = 0, z = 0} end
  
  lu.assertFalse(inst:isActive())
end

function test_missile:test_isActive_Fox3_Pitbull() 
  --distance < 18km, return true
  local inst, w, m = getMissileWrapper()
  
  inst.getPoint = function() return {x = 0, y = 0, z = 0} end
  inst.getGuidance = function() return Weapon.GuidanceType.RADAR_ACTIVE end
  
  inst.target.getPoint = inst.getPoint
  
  lu.assertTrue(inst:isActive())
end


local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()