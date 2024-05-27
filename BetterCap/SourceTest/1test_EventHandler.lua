dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_EventHandler = {}

function test_EventHandler:teardown() 
  EventHandler:shutdown()
  end

function test_EventHandler:test_create() 
  
  local m = mockagne.getMock() 
  local world_inst = world:create()
  world_inst.addEventHandler = m.addEventHandler
  
  local inst = EventHandler:create()
  lu.assertNotNil(inst)
  lu.assertNotNil(EventHandler._inst)  
end

function test_EventHandler:test_registerObject() 
  local tbl, inst  = {},  EventHandler:create()
  
  for i = 1, 2 do 
    tbl[i] = ObjectWithEvent:create(Unit:create())
    
    --add stub func for getID(no mock cause we use ID for compare so we go in inf loop when compare args :)
    tbl[i].getID = function() return i end
  end
  
  lu.assertEquals(tbl[1]:getID(), 1)
  lu.assertEquals(tbl[2]:getID(), 2)
  
  inst:registerObject(tbl[1])
  lu.assertEquals(#inst.objects, 1)
  lu.assertEquals(inst.objects[1], tbl[1])
  
  inst:registerObject(tbl[2])
  lu.assertEquals(#inst.objects, 2)
  lu.assertEquals(inst.objects[2], tbl[2])

end

function test_EventHandler:test_removeObject() 
  local  inst, tbl = EventHandler:create(), {}
  
  for i = 1, 3 do 
    tbl[i] = ObjectWithEvent:create(Unit:create())    
    
    --add stub func for getID(no mock cause we use ID for compare so we go in inf loop when compare args :)
    tbl[i].getID = function() return i end
    inst:registerObject(tbl[i])
  end
  
  lu.assertEquals(#inst.objects, 3)
  
  --test removing object 
  inst:removeObject(tbl[1])
  lu.assertEquals(inst.objects[tbl[1]:getID()], nil)
  lu.assertNotNil(inst.objects[tbl[2]:getID()])
  lu.assertNotNil(inst.objects[tbl[3]:getID()])
  
  --test removing object which not in tbl
  inst:removeObject(tbl[1])
  lu.assertEquals(inst.objects[tbl[1]:getID()], nil)
  lu.assertNotNil(inst.objects[tbl[2]:getID()])
  lu.assertNotNil(inst.objects[tbl[3]:getID()])
  
  inst:removeObject(tbl[2])
  lu.assertEquals(inst.objects[tbl[2]:getID()], nil)
  
  inst:removeObject(tbl[3])
  lu.assertEquals(inst.objects[tbl[3]:getID()], nil)
  
  lu.assertEquals(inst.objects[tbl[1]:getID()], nil)
  lu.assertEquals(inst.objects[tbl[2]:getID()], nil)
  lu.assertEquals(inst.objects[tbl[3]:getID()], nil)
  end

function test_EventHandler:test_onEvent() 
  local m, inst, unit = mockagne.getMock(), EventHandler:create(), ObjectWithEvent:create(Unit:create())
  
  unit.shotEvent = m.shotEvent
  unit.engineOffEvent = m.engineOffEvent  
  
  inst:registerObject(unit)
  
  local shotEvent = {
  id = 1,
  time = 0,
  initiator = unit,
  weapon = Weapon:create()
}
  
  --Shot event
  inst:onEvent(shotEvent)

  verify(m.shotEvent(unit, shotEvent))
  
  local engineOffEvent = {
  id = 19,
  time = 0,
  initiator = unit,
}
  
  --engine off event
  inst:onEvent(engineOffEvent)

  verify(m.engineOffEvent(unit, engineOffEvent))
  end

local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
runner:runSuite()