dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_wrappers = {}

function test_wrappers:test_creation() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getName = m.getName
  unit.getID = m.getID
  unit.getTypeName = m.getTypeName
  
  when(m.getName(unit)).thenAnswer("name")
  when(m.getID(unit)).thenAnswer(1)
  when(m.getTypeName(unit)).thenAnswer("typename")
  
  local inst = DCS_Wrapper:create(unit)
  
  verify(m.getName(unit))
  verify(m.getID(unit))
  verify(m.getTypeName(unit))
end

function test_wrappers:test_methods() 
   local unit, m = Unit:create(), mockagne.getMock()
  
    unit.getName = m.getName
    unit.getID = m.getID
    unit.getTypeName = m.getTypeName
    unit.getPoint = m.getPoint
    unit.getPosition = m.getPosition
    unit.isExist = m.isExist
    unit.hasAttribute = m.hasAttribute
    unit.getVelocity = m.getVelocity
    unit.getController = m.getController
    
    local inst = DCS_Wrapper:create(unit)
    inst:getName()
    inst:getTypeName()
    inst:getID()
    inst:getPoint()
    inst:getPosition()
    unit:isExist()
    unit:hasAttribute("1233")
    unit:getVelocity()
    unit:getController()
    
    verify(m.getName(unit))
    verify(m.getTypeName(unit))
    verify(m.getID(unit))
    verify(m.getPoint(unit))
    verify(m.getPosition(unit))
    verify(m.isExist(unit))
    verify(m.hasAttribute(unit, "1233"))
    verify(m.getVelocity(unit))
    verify(m.getVelocity(unit))
  end



local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
runner:runSuite()