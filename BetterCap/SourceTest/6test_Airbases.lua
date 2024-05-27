dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

--load airbase example 
dofile(".\\BetterCap\\SourceTest\\airbase.txt")


test_airbase = {}

local originalWorld = mist.utils.deepCopy(world)

function test_airbase:setup() 
  --return back mocked functions
  for name, field in pairs(originalWorld) do 
    if type(field) == "function" then 
      world[name] = field
    end
  end
end

function test_airbase:teardown() 
  AirbaseWrapper._instances = {}
end

function test_airbase:test_creation_fail() 
  local m = mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({})
  
  lu.assertEquals(AirbaseWrapper:create(-99), nil)
  
  verify(m.getAirbases())
end

function test_airbase:test_creation() 
  local airbase, m = Airbase:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  airbase.getID = m.getID
  when(m.getID(airbase)).thenAnswer(99)
  
  local inst = AirbaseWrapper:create(99)
  lu.assertNotNil(inst)
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getTypeName())
  lu.assertNotNil(inst:isExist())
end


function test_airbase:test_getParking() 

  local airbase, m = Airbase:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  airbase.getID = m.getID
  airbase.getParking = m.getParking
  when(m.getID(airbase)).thenAnswer(99)
  when(m.getParking(airbase, true)).thenAnswer(airbaseParking)
  
  local inst = AirbaseWrapper:create(99)
  lu.assertNotNil(inst)
  
  local firstPark = inst:getParking()
  lu.assertNotNil(firstPark)
end

function test_airbase:test_getParking_noAvail() 

  local airbase, m = Airbase:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  airbase.getID = m.getID
  airbase.getParking = m.getParking
  when(m.getID(airbase)).thenAnswer(99)
  when(m.getParking(airbase, true)).thenAnswer({})
  
  local inst = AirbaseWrapper:create(99)
  lu.assertNotNil(inst)
  
  local firstPark = inst:getParking()
  lu.assertIsNil(firstPark)
end

function test_airbase:test_getParking_wasCaptured() 

  local airbase, m = Airbase:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({airbase})
  
  airbase.getID = m.getID
  airbase.getParking = m.getParking
  airbase.getCoalition = m.getCoalition
  when(m.getID(airbase)).thenAnswer(99)
  when(m.getParking(airbase, true)).thenAnswer({})
  when(m.getCoalition(airbase)).thenAnswer(2)
  
  local inst = AirbaseWrapper:create(99)
  lu.assertNotNil(inst)
  
  --change coalition
  inst.originalCoalition = 1
  
  local firstPark = inst:getParking()
  lu.assertIsNil(firstPark)
  --check isAvail method
  lu.assertEquals(inst:isAvail(), false)
end




test_carrier = {}

function test_carrier:setup() 
  --return back mocked functions
  for name, field in pairs(originalWorld) do 
    if type(field) == "function" then 
      world[name] = field
    end
  end
end

function test_carrier:teardown() 
  CarrierWrapper._instances = {}
end

function test_carrier:test_creation_fail() 
  local m = mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({})
  
  lu.assertEquals(CarrierWrapper:create(-99), nil)
  
  verify(m.getAirbases())
end

function test_carrier:test_creation() 
  local carrier, m = Unit:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({carrier, Airbase:create()})
  
  carrier.getID = m.getID
  carrier.hasAttribute = m.hasAttribute
  when(m.getID(carrier)).thenAnswer(99)
  when(m.hasAttribute(carrier, "AircraftCarrier")).thenAnswer(true)
  
  carrier.getParking = function() return {} end
  
  local inst = CarrierWrapper:create(99)
  lu.assertNotNil(inst)
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getTypeName())
  lu.assertNotNil(inst:isExist())
end


function test_airbase:test_getParking() 

  local carrier, m = Unit:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({carrier})
  
  carrier.getParking = function() return {} end
  carrier.getID = m.getID
  carrier.hasAttribute = m.hasAttribute
  when(m.getID(carrier)).thenAnswer(99)
  when(m.hasAttribute(carrier, "AircraftCarrier")).thenAnswer(true)
  
  local inst = CarrierWrapper:create(99)
  lu.assertNotNil(inst)
  
  --mock is Avail
  inst.isAvail = m.isAvail
  when(m.isAvail(inst)).thenAnswer(true)
  
  local firstPark = inst:getParking()
  lu.assertNotNil(firstPark)
  
  verify(m.isAvail(inst))
end

function test_airbase:test_getParking_dead() 

  local carrier, m = Unit:create(), mockagne.getMock()
  
  world.getAirbases = m.getAirbases
  when(m.getAirbases()).thenAnswer({carrier})
  
  carrier.getParking = function() return {} end
  carrier.getID = m.getID
  carrier.hasAttribute = m.hasAttribute
  when(m.getID(carrier)).thenAnswer(99)
  when(m.hasAttribute(carrier, "AircraftCarrier")).thenAnswer(true)
  
  local inst = CarrierWrapper:create(99)
  lu.assertNotNil(inst)
  
  --mock isExist
  inst.isAvail = m.isAvail
  when(m.isAvail(inst)).thenAnswer(false)
  
  local firstPark = inst:getParking()
  --verify(m.isExist(inst))
  lu.assertIsNil(firstPark)
end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()