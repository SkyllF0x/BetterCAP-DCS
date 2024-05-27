dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_RadarWrapper = {}
test_RadarWrapper.exampleSensorsGround =  {
  [1] = {
		[1] = 
		{
			["detectionDistanceAir"] = 
			{
				["upperHemisphere"] = 
				{
					["tailOn"] = 40000,
					["headOn"] = 40000,
				}, -- end of ["upperHemisphere"]
				["lowerHemisphere"] = 
				{
					["tailOn"] = 20000,
					["headOn"] = 20000,
				}, -- end of ["lowerHemisphere"]
			}, -- end of ["detectionDistanceAir"]
			["type"] = 1,
			["typeName"] = "SA-11 Buk SR 9S18M1",
		}, -- end of [1]
	} -- end of [1]
}

test_RadarWrapper.exampleSensorsSEA =  {
	[1] = 
	{
		[1] = 
		{
			["detectionDistanceAir"] = 
			{
				["upperHemisphere"] = 
				{
					["tailOn"] = 106998.453125,
					["headOn"] = 106998.453125,
				}, -- end of ["upperHemisphere"]
				["lowerHemisphere"] = 
				{
					["tailOn"] = 106998.453125,
					["headOn"] = 106998.453125,
				}, -- end of ["lowerHemisphere"]
			}, -- end of ["detectionDistanceAir"]
			["type"] = 1,
			["typeName"] = "S-300PS 40B6M tr navy",
		}, -- end of [1]
		[2] = 
		{
			["detectionDistanceAir"] = 
			{
				["upperHemisphere"] = 
				{
					["tailOn"] = 20062.2109375,
					["headOn"] = 20062.2109375,
				}, -- end of ["upperHemisphere"]
				["lowerHemisphere"] = 
				{
					["tailOn"] = 20062.2109375,
					["headOn"] = 20062.2109375,
				}, -- end of ["lowerHemisphere"]
			}, -- end of ["detectionDistanceAir"]
			["type"] = 1,
			["typeName"] = "Osa 9A33 ln",
		}, -- end of [2]
		[3] = 
		{
			["type"] = 1,
			["typeName"] = "moskva search radar",
			["detectionDistanceRBM"] = 400,
		}, -- end of [3]
	}, -- end of [1]
	[0] = 
	{
		[1] = 
		{
			["type"] = 0,
			["typeName"] = "long-range naval optics",
			["opticType"] = 0,
		}, -- end of [1]
		[2] = 
		{
			["type"] = 0,
			["typeName"] = "long-range naval LLTV",
			["opticType"] = 1,
		}, -- end of [2]
		[3] = 
		{
			["type"] = 0,
			["typeName"] = "long-range naval FLIR",
			["opticType"] = 2,
		}, -- end of [3]
	}, -- end of [0]
} -- end of 



test_RadarWrapper.exampleSensortAIR = {
	[1] = 
	{
		[1] = 
		{
			["detectionDistanceAir"] = 
			{
				["upperHemisphere"] = 
				{
					["tailOn"] = 29424.57421875,
					["headOn"] = 59116.64453125,
				}, -- end of ["upperHemisphere"]
				["lowerHemisphere"] = 
				{
					["tailOn"] = 29558.322265625,
					["headOn"] = 59116.64453125,
				}, -- end of ["lowerHemisphere"]
			}, -- end of ["detectionDistanceAir"]
			["type"] = 1,
			["typeName"] = "AN/APG-63",
		}, -- end of [1]
	}, -- end of [1]
	[3] = 
	{
		[1] = 
		{
			["typeName"] = "Abstract RWR",
			["type"] = 3,
		}, -- end of [1]
	}, -- end of [3]
} -- end of 





function test_RadarWrapper:test_creation_ground() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getSensors = m.getSensors
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsGround)

  local inst = RadarWrapper:create(unit)
  
  lu.assertEquals(inst.detectionRange, 30000)--MEAN VAL
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getTypeName())
  lu.assertNotNil(inst:isExist())
end


function test_RadarWrapper:test_creation_SEA() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getSensors = m.getSensors
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsSEA)

  local inst = RadarWrapper:create(unit)
  
  lu.assertEquals(inst.detectionRange > 0, true) --we have something
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getTypeName())
  lu.assertNotNil(inst:isExist())
end

function test_RadarWrapper:test_creation_AIR() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getSensors = m.getSensors
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsSEA)

  local inst = RadarWrapper:create(unit)
  
  lu.assertEquals(inst.detectionRange > 0, true) --we have something
  
  --check methods
  lu.assertNotNil(inst:getPoint())
  lu.assertNotNil(inst:getPosition())
  lu.assertNotNil(inst:getVelocity())
  lu.assertNotNil(inst:getID())
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getTypeName())
  lu.assertNotNil(inst:isExist())
end

function test_RadarWrapper:test_getDetectedTargets() 
  --test:
  --1)return unit wrapped in TargetContainer(will check by calling it methods)
  --2)verify it calls getDetectedTargets() with 1,2,4,16
  
  local unit, controller, m = Unit:create(), Controller:create(), mockagne.getMock()
  local target = Unit:create()

  unit.getController = m.getController
  unit.getSensors = m.getSensors

  controller.getDetectedTargets = m.getDetectedTargets

  when(m.getController(unit)).thenAnswer(controller)
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsGround)
  when(m.getDetectedTargets(controller, 1, 2, 4, 16)).thenAnswer({{
        object = target,
        visible = false, --the target is visible
        type = false, --the target type is known
        distance = false--distance to the target is known
     }})
  
  target.isExist = m.isExist
  target.hasAttribute = m.hasAttribute
  when(m.hasAttribute(target, "Air")).thenAnswer(true)
  when(m.isExist(target)).thenAnswer(true)
  
  local radar = RadarWrapper:create(unit)
  local result = radar:getDetectedTargets()
  
  
  lu.assertEquals(#result, 1)
  --check that we got a targetContainer
  lu.assertEquals(result[1]:isRangeKnown(), false)
  end


function test_RadarWrapper:test_getDetectedTargets_rejectDeadAndNoAir() 
  --test:
  --1)return unit wrapped in TargetContainer(will check by calling it methods)
  --2)verify it calls getDetectedTargets() with 1,2,4,16
  
  local unit, controller, m = Unit:create(), Controller:create(), mockagne.getMock()
  local targets = {}
  
  for i = 1, 4 do 
    targets[i] = {
      object = Unit:create(), --the target
      visible = false, --the target is visible
      type = false, --the target type is known
      distance = false --distance to the target is known
  }
  
    targets[i].object.isExist = m.isExist
    targets[i].object.hasAttribute = m.hasAttribute
    targets[i].object.getID = m.getID
    when(m.getID(targets[i].object)).thenAnswer(i)
    
    --first target: ok
    if i == 1 then 
      when(m.hasAttribute(targets[i].object, "Air")).thenAnswer(true)
      when(m.isExist(targets[i].object)).thenAnswer(true)
    elseif i == 2 then 
      --second target: Alive, but without attribute
      when(m.hasAttribute(targets[i].object, "Air")).thenAnswer(false)
      when(m.isExist(targets[i].object)).thenAnswer(true)
    elseif i == 3 then
      --3rd target: dead, with attribute
      when(m.hasAttribute(targets[i].object, "Air")).thenAnswer(true)
      when(m.isExist(targets[i].object)).thenAnswer(false)
    else
      --4th target: no object supplied
      targets[i].object = nil
    end
  end

  unit.getController = m.getController
  unit.getSensors = m.getSensors

  controller.getDetectedTargets = m.getDetectedTargets

  when(m.getController(unit)).thenAnswer(controller)
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsGround)
  when(m.getDetectedTargets(controller, 1, 2, 4, 16)).thenAnswer(targets)
  
  local radar = RadarWrapper:create(unit)
  local result = radar:getDetectedTargets()
  
  
  lu.assertEquals(#result, 1)
  --check that we got a targetContainer
  lu.assertEquals(result[1]:getTarget():getID(), 1)
end


function  test_RadarWrapper:test_inZone() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getSensors = m.getSensors
  when(m.getSensors(any())).thenAnswer(test_RadarWrapper.exampleSensorsSEA)

  local inst = RadarWrapper:create(unit)
  inst.getPoint = m.getPoint
  when(m.getPoint(inst)).thenAnswer({ x = 0, y = 0, z = 0})
  
  inst.detectionRange = 40000
  
  lu.assertEquals(inst:inZone({x = 10, y = 0, z = 0}), true)
  lu.assertEquals(inst:inZone({x = 50000, y = 0, z = 0}), false)
end


---------------------------------------------------------------------------
---------------------------------------------------------------------------
local originalLand = mist.utils.deepCopy(land)

test_RadarWrapperWithChecks = {}

function test_RadarWrapperWithChecks:teardown() 
  for name, val in pairs(originalLand) do 
    land[name] = val
    end
  end
  
function test_RadarWrapperWithChecks:test_getDetectedTargets() 
  --unit1 is too far, shouldn't been added
  --unit2 ok, shoult return wrap in container
  --unit3 masked, shouldn't been added
  
  local unit1, controller, m = Unit:create(), Controller:create(), mockagne.getMock()
  local unit2, unit3 = Unit:create(), Unit:create()
  
  local radarUnit = Unit:create()
  radarUnit.getSensors = function() return test_RadarWrapper.exampleSensorsGround end
  radarUnit.getController = function() return controller end
    
  local radar = RadarWrapperWithChecks:create(radarUnit)
  radar.getPoint = function() return {x = 0, y = 0, z = 0} end
  radar.detectionRange = 100
  
  unit1.getPoint = function() return {x = 99999, y = 0, z = 0} end
  unit2.getPoint = function() return {x = 10, y = 0, z = 0} end
  unit3.getPoint = function() return {x = 15, y = 0, z = 0} end
  
  unit1.hasAttribute = function() return true end
  unit2.hasAttribute = unit1.hasAttribute 
  unit3.hasAttribute = unit1.hasAttribute 
  
  land.isVisible = m.isVisible
  when(m.isVisible(unit1:getPoint(), radar:getPoint())).thenAnswer(true)
  when(m.isVisible(unit2:getPoint(), radar:getPoint())).thenAnswer(true)
  when(m.isVisible(unit3:getPoint(), radar:getPoint())).thenAnswer(false)
  
  local detectionTables = {
    {object = unit1, type = false, distance = false, visible = false},
    {object = unit2, type = false, distance = false, visible = false},
    {object = unit3, type = false, distance = false, visible = false},
    }
  controller.getDetectedTargets = function() return detectionTables end
  
  --result is only 1 container
  local result = radar:getDetectedTargets()
  lu.assertEquals(#result, 1)
  lu.assertEquals(result[1]:getTarget(), unit2)
  lu.assertEquals(result[1]:getDetector(), radar)
  
  verify(m.isVisible(unit1:getPoint(), radar:getPoint()))
  verify(m.isVisible(unit2:getPoint(), radar:getPoint()))
  verify(m.isVisible(unit3:getPoint(), radar:getPoint()))
  end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()