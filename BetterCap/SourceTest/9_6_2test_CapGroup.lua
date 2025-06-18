dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_capGroup = {}
test_capGroup.ammoAlias = {
   IR = Weapon.GuidanceType.IR, 
   ARH = Weapon.GuidanceType.RADAR_ACTIVE,
   SARH = Weapon.GuidanceType.RADAR_SEMI_ACTIVE
  }
--real route from dcs group
local route = 
{
	[1] = 
	{
		["alt"] = 2000,
		["type"] = "Turning Point",
		["action"] = "Turning Point",
		["alt_type"] = "BARO",
		["form"] = "Turning Point",
		["y"] = 561714.28571429,
		["x"] = -325142.85714286,
		["speed"] = 225,
		["task"] = 
		{
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
					[1] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "Orbit",
						["number"] = 1,
						["params"] = 
						{
							["altitude"] = 2000,
							["pattern"] = "Race-Track",
							["speed"] = 137.5,
						}, -- end of ["params"]
					}, -- end of [1]
					[2] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "Refueling",
						["number"] = 2,
						["params"] = 
						{
						}, -- end of ["params"]
					}, -- end of [2]
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		}, -- end of ["task"]
	}, -- end of [1]
	[2] = 
	{
		["alt"] = 2000,
		["type"] = "Turning Point",
		["action"] = "Turning Point",
		["alt_type"] = "BARO",
		["form"] = "Turning Point",
		["y"] = 544571.42857143,
		["x"] = -281142.85714286,
		["speed"] = 225,
		["task"] = 
		{
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
					[1] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "Orbit",
						["number"] = 1,
						["params"] = 
						{
							["altitude"] = 2000,
							["pattern"] = "Circle",
							["speed"] = 137.5,
						}, -- end of ["params"]
					}, -- end of [1]
					[2] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "Refueling",
						["number"] = 2,
						["params"] = 
						{
						}, -- end of ["params"]
					}, -- end of [2]
					[3] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "ControlledTask",
						["number"] = 3,
						["params"] = 
						{
							["task"] = 
							{
								["id"] = "Orbit",
								["params"] = 
								{
									["altitude"] = 2000,
									["pattern"] = "Circle",
									["speed"] = 137.5,
								}, -- end of ["params"]
							}, -- end of ["task"]
							["condition"] = 
							{
								["userFlag"] = "0",
							}, -- end of ["condition"]
							["stopCondition"] = 
							{
								["duration"] = 900,
							}, -- end of ["stopCondition"]
						}, -- end of ["params"]
					}, -- end of [3]
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		}, -- end of ["task"]
	}, -- end of [2]
} -- end of route


local originalTriggerMisc = mist.utils.deepCopy(trigger.misc)
local originalMistFunc = {
  getGroupPoints = mist.getGroupPoints,
  getGroupRoute = mist.getGroupRoute
  }

function test_capGroup:teardown() 
  for name, val in pairs(originalTriggerMisc) do 
    trigger.misc[name] = val
  end
  
  --restore mist
  mist.getGroupPoints = originalMistFunc.getGroupPoints
  mist.getGroupRoute = originalMistFunc.getGroupRoute
  end

function test_capGroup:test_creation() 
  local inst = getCapGroup()
  
  lu.assertNotNil(inst)
  --all planes in 1 newly created CapElement
  lu.assertNotNil(inst.elements[1])
  lu.assertEquals(#inst.elements[1].planes, 1)
  lu.assertEquals(inst.countPlanes, 1)
  
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getID())
  
  lu.assertEquals(inst.commitRange, 110000)
  lu.assertNotNil(inst.route)
  lu.assertEquals(inst.rtbWhen, CapGroup.RTBWhen.NoAmmo)
  lu.assertEquals(inst.bingoFuel, 0.3)
  lu.assertEquals(inst.deactivateWhen, CapGroup.DeactivateWhen.OnShutdown)
  lu.assertEquals(inst.alr, CapGroup.ALR.Normal)
  lu.assertEquals(inst.preferableTactics, {})
  lu.assertEquals(inst.autonomous, false)
  
  --verify registraction in element
  lu.assertEquals(inst.elements[1].myGroup, inst)
  lu.assertEquals(inst.elements[1].planes[1].myElement, inst.elements[1])
  lu.assertEquals(inst.elements[1].planes[1].myGroup, inst)
  end

function test_capGroup:test_setRTBWhen() 
  local inst = getCapGroup()
  
  inst:setRTBWhen(CapGroup.RTBWhen.No_ARH)
  lu.assertEquals(inst.rtbWhen, CapGroup.RTBWhen.No_ARH)
  end

function test_capGroup:test_setBingo() 
  local inst = getCapGroup()
  
  inst:setBingo(0.99)
  lu.assertEquals(inst.bingoFuel, 0.99)
end

function test_capGroup:test_setDeactivateWhen() 
  local inst = getCapGroup()
  
  inst:setDeactivateWhen(CapGroup.DeactivateWhen.inAir)
  lu.assertEquals(inst.deactivateWhen, CapGroup.DeactivateWhen.inAir)
  end

function test_capGroup:test_setPriorities() 
  local inst = getCapGroup()
  
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.FIGHTER], 1)
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.ATTACKER], 0.5)
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.HELI], 0.1)
  
  inst:setPriorities(2, nil, 1)
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.FIGHTER], 2)
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.ATTACKER], 0.5)--should not change
  lu.assertEquals(inst.priorityForTypes[AbstractTarget.TypeModifier.HELI], 1)
  end

function test_capGroup:test_addCommitZone() 
  local inst = getCapGroup()
  lu.assertEquals(countElements(inst.commitZones), 0)
  
  inst:addCommitZone(CircleZone:create({x = 0, y = 0}, 9999))
  
  lu.assertEquals(countElements(inst.commitZones), 1)
  
  inst:addCommitZone(CircleZone:create({x = 1, y = 1}, 9999))
  lu.assertEquals(countElements(inst.commitZones), 2)
end

function test_capGroup:test_deleteCommitZone() 
  local inst = getCapGroup()
  
  local zone1, zone2 = CircleZone:create({x = 0, y = 0}, 9999), CircleZone:create({x = 1, y = 1}, 9999)
  inst:addCommitZone(zone1)
  inst:addCommitZone(zone2)

  inst:deleteCommitZone(zone1)
  lu.assertEquals(countElements(inst.commitZones), 1)
  lu.assertNil(inst.commitZones[zone1:getID()])
  lu.assertNotNil(inst.commitZones[zone2:getID()])
  
  inst:deleteCommitZone(zone2)
  lu.assertEquals(countElements(inst.commitZones), 0)
  lu.assertNil(inst.commitZones[zone1:getID()])
  lu.assertNil(inst.commitZones[zone2:getID()])
end

function test_capGroup:test_setCommitRange() 
  local inst = getCapGroup()
  
  inst:setCommitRange(90)
  lu.assertEquals(inst.commitRange, 90)
  end

function test_capGroup:test_setALR() 
  local inst = getCapGroup()
  
  inst:setALR(CapGroup.ALR.High)
  lu.assertEquals(inst.alr, CapGroup.ALR.High)
  end

function test_capGroup:test_setTactics() 
  local inst = getCapGroup()
  
  inst:setTactics({CapGroup.tactics.Skate, CapGroup.tactics.SkateOffset})
  lu.assertEquals(inst.preferableTactics, {CapGroup.tactics.Skate, CapGroup.tactics.SkateOffset})
end




function test_capGroup:test_addCommitZoneByName() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  
  trigger.misc.getZone = m.getZone
  when(m.getZone("test")).thenAnswer({
      point = {x = 0, y = 0, z = 88},
      radius = 999
    })
  
  inst:addCommitZoneByTriggerZoneName("test")
  verify(m.getZone("test"))
  
  lu.assertEquals(countElements(inst.commitZones), 1)
  
  local i, zone = next(inst.commitZones)
  lu.assertEquals(zone.point, {x = 0, y = 88})--vec2 convertion
  lu.assertEquals(zone.radius, 999)
end

function test_capGroup:test_addCommitZoneByGroupName_NoGroup() 
  local inst = getCapGroup()
  
  --no name in mist tbl
  inst:addCommitZoneByGroupName("Name")
  
  lu.assertEquals(countElements(inst.commitZones), 0)--nothing added
end

function test_capGroup:test_addCommitZoneByGroupName() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  local groupNAME = "TEST_NAME"
  local groupPoints = {{x = 0, y = 0}, {x = 10, y = 0}, {x = 10, y = 10}}
  
  mist.getGroupPoints = m.getGroupPoints
  when(m.getGroupPoints(groupNAME)).thenAnswer(groupPoints)
  
  inst:addCommitZoneByGroupName(groupNAME)
  verify(m.getGroupPoints(groupNAME))
  
  lu.assertEquals(countElements(inst.commitZones), 1)
  
  local i, zone = next(inst.commitZones)
  lu.assertEquals(zone.points, groupPoints)
  end

function test_capGroup:test_addPatrolZonesFromTask_noTask() 
  local inst = getCapGroup()
  local groupNAME = "TEST_NAME"
  inst.name = groupNAME
  
  inst:addPatrolZonesFromTask()
  lu.assertEquals(countElements(inst.patrolZones), 0)
end

function test_capGroup:test_addPatrolZonesFromTask() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  local groupNAME = "TEST_NAME"
  inst.name = groupNAME
  inst.route = GroupRoute:create(route)
  
  mist.getGroupRoute = m.getRoute
  when(m.getRoute(groupNAME, true)).thenAnswer(route)
  
  inst:addPatrolZonesFromTask()
  verify(m.getRoute(groupNAME, true))
  --have orbits at 2 wp
  lu.assertEquals(countElements(inst.patrolZones), 2)
  --first wp has 1 zone
  lu.assertEquals(countElements(inst.patrolZones[1]), 1)
  --second wp has 2 zones
  lu.assertEquals(countElements(inst.patrolZones[2]), 2)
  end

function test_capGroup:test_addPatrolZonesFromTask_paramCheck() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  local groupNAME = "TEST_NAME"
  inst.name = groupNAME
  
  local r = mist.utils.deepCopy(route)
  --delete tasks in second WP
  r[2].task = {}
  inst.route = GroupRoute:create(r)
  
  mist.getGroupRoute = m.getRoute
  when(m.getRoute(groupNAME, true)).thenAnswer(r)
  

  inst:addPatrolZonesFromTask()
  verify(m.getRoute(groupNAME, true))
  --zone for only 1 wp
  lu.assertEquals(countElements(inst.patrolZones), 1)
  lu.assertEquals(countElements(inst.patrolZones[1]), 1)
  
  --type Race track
  local i, zone = next(inst.patrolZones[1])

  lu.assertEquals(zone:getTask().params.speed, 137.5)
  lu.assertEquals(zone:getTask().params.point, {x = route[1].x, y = route[1].y})
  lu.assertEquals(zone:getTask().params.altitude, 2000)
  --it's racetrack so should be second point - next WP
  lu.assertEquals(zone:getTask().params.point2, {x = route[2].x, y = route[2].y})
  lu.assertEquals(zone:getTask().params.pattern, "Race-Track")
end

function test_capGroup:test_addPatrolZonesFromTask_conditionChecks() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  local groupNAME = "TEST_NAME"
  inst.name = groupNAME
  
  --delete tasks in first WP
  local r = mist.utils.deepCopy(route)
  r[1].task = {}
  --also delete first orbit in second wp
  r[2].task.params.tasks[1] = nil
  inst.route = GroupRoute:create(r)
  
  mist.getGroupRoute = m.getRoute
  when(m.getRoute(groupNAME, true)).thenAnswer(r)
  

  inst:addPatrolZonesFromTask()
  verify(m.getRoute(groupNAME, true))
  lu.assertEquals(countElements(inst.patrolZones), 1)
  --task in second wp
  lu.assertEquals(countElements(inst.patrolZones[2]), 1)
  
  --type Race track
  local i, zone = next(inst.patrolZones[2])

  lu.assertEquals(zone:getTask().params.speed, 137.5)
  lu.assertEquals(zone:getTask().params.point, {x = route[2].x, y = route[2].y})
  lu.assertEquals(zone:getTask().params.altitude, 2000)
  lu.assertEquals(zone:getTask().params.pattern, "Circle")
  lu.assertEquals(#zone.preConditions, 1)
  lu.assertEquals(zone.preConditions[1].flag, r[2].task.params.tasks[3].params.condition.userFlag)
  --no userFlagValue, should be false
  lu.assertEquals(zone.preConditions[1].val, false)
  
  lu.assertEquals(zone.postConditions[1].duration, r[2].task.params.tasks[3].params.stopCondition.duration)
  end

function test_capGroup:test_setHomePoint() 
  local inst = getCapGroup()
  local m = mockagne.getMock()
  
  inst.route.setHomePoint = m.setHomePoint
  
  inst:setHomePoint({x = 0, y = 0, z = 10})
  verify(m.setHomePoint(inst.route, {x = 0, y = 0, z = 10}))
  end


function test_capGroup:test_setAutonomous_true() 
  --update bool flag
  --call planes:setOption() with rdr use = utils.tasks.command.RDR_Using.On
  
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  plane.setOption = m.setOption
  
  group:setAutonomous(true)
  lu.assertEquals(group.autonomous, true)
  verify(m.setOption(plane, CapPlane.options.RDR, utils.tasks.command.RDR_Using.On))
end

function test_capGroup:test_setAutonomous_true() 
  --update bool flag
  --call planes:setOption() with rdr use = nil
  
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  plane.setOption = m.setOption
  group.autonomous = true
  
  group:setAutonomous(false)
  lu.assertEquals(group.autonomous, false)
  verify(m.setOption(plane, CapPlane.options.RDR))
end

function test_capGroup:test_planesIterator() 
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local group = CapGroup:create({plane1, plane2})
  
  local res = {}
  for idx, plane in group:planes() do 
    res[idx] = plane
  end
  
  lu.assertEquals(#res, 2)
  lu.assertEquals(tostring(res[1]), tostring(plane1))
  end

function test_capGroup:test_basicMethods() 
  local plane = getCapPlane()
  
  --group:getPoint return position of lead plane
  plane.getPoint = function() return {x = 99, y = 99, z = 99} end
  plane.getTypeName = function() return "F-15C" end
  
  local group = CapGroup:create({plane})
  group.point = plane:getPoint()
  
  lu.assertEquals(group:getID(), group.id)
  lu.assertEquals(group:getName(), group.name)
  lu.assertEquals(group:getTypeName(), plane:getTypeName())
  lu.assertEquals(group:getPoint(), plane:getPoint())
  lu.assertEquals(group:getLead(), plane)
  end

function test_capGroup:test_updateAmmo_noAmmo() 
  local group, plane = getCapGroup()
  
  plane.getAmmo = function() return 
    { [test_capGroup.ammoAlias.IR] = 0,
      [test_capGroup.ammoAlias.SARH] = 0,
      [test_capGroup.ammoAlias.ARH] = 0,
      }
    end
  plane.getBestMissile = function() return utils.WeaponTypes["R-60"] end
  
  group.ammoState = CapGroup.AmmoState.ARH
  
  group:updateAmmo()
  lu.assertEquals(group.ammoState, CapGroup.AmmoState.NoAmmo)
  lu.assertEquals(group.missile, utils.WeaponTypes["R-60"])
  end

function test_capGroup:test_updateAmmo_ARH() 
  local group, plane = getCapGroup()
  
  plane.getAmmo = function() return 
    { [test_capGroup.ammoAlias.IR] = 0,
      [test_capGroup.ammoAlias.SARH] = 9,
      [test_capGroup.ammoAlias.ARH] = 9,
      }
    end
  
  group:updateAmmo()
  lu.assertEquals(group.ammoState, CapGroup.AmmoState.ARH)
end

function test_capGroup:test_updateAmmo_SARH() 
  local group, plane = getCapGroup()
  
  plane.getAmmo = function() return 
    { [test_capGroup.ammoAlias.IR] = 1,
      [test_capGroup.ammoAlias.SARH] = 9,
      [test_capGroup.ammoAlias.ARH] = 0,
      }
    end
  group.ammoState = CapGroup.AmmoState.ARH
  
  group:updateAmmo()
  lu.assertEquals(group.ammoState, CapGroup.AmmoState.SARH)
end

function test_capGroup:test_updateAmmo_IR() 
  local group, plane = getCapGroup()
  
  plane.getAmmo = function() return 
    { [test_capGroup.ammoAlias.IR] = 1,
      [test_capGroup.ammoAlias.SARH] = 0,
      [test_capGroup.ammoAlias.ARH] = 0,
      }
    end
  
  group.ammoState = CapGroup.AmmoState.ARH
  group:updateAmmo()
  lu.assertEquals(group.ammoState, CapGroup.AmmoState.IrOnly)
end

function test_capGroup:test_updateAmmo_updateMissile() 
  local group, plane = getCapGroup()
  
  plane.getAmmo = function() return 
    { [test_capGroup.ammoAlias.IR] = 0,
      [test_capGroup.ammoAlias.SARH] = 0,
      [test_capGroup.ammoAlias.ARH] = 0,
      }
    end
  plane.getBestMissile = function() return utils.WeaponTypes["P_24R"] end
  
  group:updateAmmo()
  lu.assertEquals(group.missile, utils.WeaponTypes["P_24R"])
end

--method can be called from update even in no alive elemts
function test_capGroup:test_updateAmmo_noAlivePlanes() 
  local group, plane = getCapGroup()
  
  group.elements = {}
  group:updateAmmo()
end


function test_capGroup:test_update_groupAlive() 
  --counter updates
  --updateAmmo() called
  --updateElementsLink() called
  --alive element:update() called
  
  local group = getCapGroup()
  local secondElement = getElement()
  local m = mockagne.getMock()
  
  group.elements[2] = secondElement
  group.updateAmmo = m.updateAmmo
  group.updateElementsLink = m.updateElementsLink
  
  group.elements[1].update = m.update
  group.elements[2].update = m.update
  
  local totalPlanes = #group.elements[1].planes + #group.elements[2].planes
  
  group:update()
  verify(m.updateAmmo(group))
  verify(m.updateElementsLink(group))
  verify(group.elements[1]:update())
  verify(group.elements[2]:update())
  
  lu.assertEquals(group.countPlanes, totalPlanes)
end

function test_capGroup:test_update_deleteDeadElement() 
  --counter updates
  --dead element delete
  --updateAmmo() called
  --element:update() called only on alive element
  
  local group = getCapGroup()
  local secondElement = getElement()
  local m = mockagne.getMock()
  
  group.elements[1].isExist = function() return false end
  group.elements[2] = secondElement
  group.updateAmmo = m.updateAmmo
  
  local elem1, elem2 = group.elements[1], group.elements[2]
  elem1.update = m.update
  elem2.update = m.update

  local totalPlanes = #group.elements[2].planes

  group:update()
  verify(m.updateAmmo(group))
  verify_no_call(elem1:update())
  verify(elem2:update())

  lu.assertEquals(group.countPlanes, totalPlanes)
  lu.assertEquals(group.elements[1], secondElement)
  lu.assertEquals(tostring(group.elements[1]), tostring(secondElement))--]]
  end

function test_capGroup:test_update_groupDead() 
  --counter to 0
  --self.elements == {}
  --updateAmmo() called and no error
  --updateElementsLink() called and no error
  
  local group = getCapGroup()
  
  group.elements[1].isExist = function() return false end

  group:update()

  lu.assertEquals(group.countPlanes, 0)
  lu.assertEquals(group.elements[1], nil)
  lu.assertEquals(group.elements, {})
  end



function test_capGroup:test_updateElementsLink_groupDead() 
  --self.elements empty
  --countPlanes is 0
  --verify no errors thrown
  local group = getCapGroup()
  group.countPlanes = 0
  group.elements = {}
  
  group:updateElementsLink()
end

function test_capGroup:test_updateElementsLink_1Element() 
  --verify no errors thrown
  --verify element.secondElement set to nil
  local group = getCapGroup()
  group.elements[1]:setSecondElement({})
  
  lu.assertEquals(#group.elements, 1)
  lu.assertEquals(group.elements[1].secondElement, {})
  
  group:updateElementsLink()
  lu.assertEquals(group.elements[1].secondElement, nil)
end

function test_capGroup:test_updateElementsLink_2Elements() 
  --verify no errors thrown
  --verify element.secondElement set to other element 
  local group = getCapGroup()
  group.elements[2] = getElement()
  
  group:updateElementsLink()
  lu.assertEquals(group.elements[1]:getSecondElement(), group.elements[2])
  lu.assertEquals(group.elements[2]:getSecondElement(), group.elements[1])
  
  --verify this is reference
  lu.assertEquals(tostring(group.elements[1]:getSecondElement()), tostring(group.elements[2]))
  lu.assertEquals(tostring(group.elements[2]:getSecondElement()), tostring(group.elements[1]))
end

function test_capGroup:test_isExist() 
  local group = getCapGroup()
  
  group.countPlanes = 1
  lu.assertTrue(group:isExist())
  
  group.countPlanes = 0
  lu.assertFalse(group:isExist())
  end

function test_capGroup:test_getFuel()
  --return lowest fuel in group
  local group = getCapGroup()
  local element = getElement()
  group.elements[2] = element
  
  group.elements[1].planes[1].getFuel = function() return 1 end
  group.elements[2].planes[1].getFuel = function() return 0.25 end
  
  lu.assertEquals(group:getFuel(), 0.25)
end

function test_capGroup:test_updateAutonomous_goAutonomous()
  --amount of radars is lower then threshold
  local group, plane = getCapGroup()
  group.goLiveThreshold = 10
  group.radarRange = 100000
  
  plane.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane.getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  --point ahead lead at radarRange*0.75
  local point = mist.vec.scalar_mult(plane:getVelocity(), group.radarRange*0.75)
  
  local m = mockagne.getMock()
  
  local radar1, radar2 = getRadar(), getRadar()
  local radarTbl = {
    [radar1:getID()] = radar1,
    [radar2:getID()] = radar2
    }
  radar1.inZone = m.inZone
  radar2.inZone = m.inZone
  
  when(m.inZone(radar1, point)).thenAnswer(false)
  when(m.inZone(radar2, point)).thenAnswer(true)
  
  group.setAutonomous = m.setAutonomous
  
  group:updateAutonomous(radarTbl)
  verify(m.setAutonomous(group, true))
  verify(m.inZone(radar1, point))
  verify(m.inZone(radar2, point))
  end

function test_capGroup:test_updateAutonomous_maintainAutonomous()
  --amount of radars is lower then threshold
  local group, plane = getCapGroup()
  group.goLiveThreshold = 10
  group.radarRange = 100000
  group.autonomous = true
  
  plane.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane.getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  --point ahead lead at radarRange*0.75
  local point = mist.vec.scalar_mult(plane:getVelocity(), group.radarRange*0.75)
  
  local m = mockagne.getMock()
  
  local radar1, radar2 = getRadar(), getRadar()
  local radarTbl = {
    [radar1:getID()] = radar1,
    [radar2:getID()] = radar2
    }
  radar1.inZone = m.inZone
  radar2.inZone = m.inZone
  
  when(m.inZone(radar1, point)).thenAnswer(false)
  when(m.inZone(radar2, point)).thenAnswer(true)
  
  group.setAutonomous = m.setAutonomous
  
  group:updateAutonomous(radarTbl)
  verify_no_call(m.setAutonomous(group, any()))
  verify(m.inZone(radar1, point))
  verify(m.inZone(radar2, point))
  end

function test_capGroup:test_updateAutonomous_offAutonomous()
  --amount of radars is lower then threshold
  local group, plane = getCapGroup()
  group.goLiveThreshold = 0
  group.radarRange = 100000
  group.autonomous = true
  
  plane.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane.getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  --point ahead lead at radarRange*0.75
  local point = mist.vec.scalar_mult(plane:getVelocity(), group.radarRange*0.75)
  
  local m = mockagne.getMock()
  
  local radar1 = getRadar()
  local radarTbl = {
    [radar1:getID()] = radar1,
    }
  radar1.inZone = m.inZone
  
  when(m.inZone(radar1, point)).thenAnswer(true)
  
  group.setAutonomous = m.setAutonomous
  
  group:updateAutonomous(radarTbl)
  verify(m.setAutonomous(group, false))
  verify(m.inZone(radar1, point))
end

function test_capGroup:test_updateAutonomous_maintainOffAutonomous()
  --amount of radars is lower then threshold
  local group, plane = getCapGroup()
  group.goLiveThreshold = 0
  group.radarRange = 100000
  group.autonomous = false
  
  plane.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane.getVelocity = function() return {x = 1, y = 0, z = 0} end
  
  --point ahead lead at radarRange*0.75
  local point = mist.vec.scalar_mult(plane:getVelocity(), group.radarRange*0.75)
  
  local m = mockagne.getMock()
  
  local radar1 = getRadar()
  local radarTbl = {
    [radar1:getID()] = radar1,
    }
  radar1.inZone = m.inZone
  
  when(m.inZone(radar1, point)).thenAnswer(true)
  
  group.setAutonomous = m.setAutonomous
  
  group:updateAutonomous(radarTbl)
  verify_no_call(m.setAutonomous(group, any()))
  verify(m.inZone(radar1, point))
end

function test_capGroup:test_callElements() 
  local group = getCapGroup()
  local m = mockagne.getMock()
  
  group.elements[1].callFSM = m.callFSM
  
  group:callElements()
  verify(m.callFSM(group.elements[1]))
end

function test_capGroup:test_callFSM() 
  --run() on state called
  --callElements() called
  --FSM_args viped
  local group = getCapGroup()
  local m = mockagne.getMock()
  
  group.FSM_stack:getCurrentState().run = m.run
  group.callElements = m.callElements
  
  group:setFSM_Arg("radars", {1, 2})
  group:setFSM_Arg("contacts", {3, 4})
  
  local args = mist.utils.deepCopy(group.FSM_args)
  
  group:callFSM()
  verify(group.FSM_stack:getCurrentState():run(args))
  verify(group:callElements())
  
  lu.assertEquals(group.FSM_args.radars, {})
  lu.assertEquals(group.FSM_args.contacts, {})
end

function test_capGroup:test_isAirborne() 
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  plane.inAir = m.inAir
  when(plane:inAir()).thenAnswer(false)
  lu.assertFalse(group:isAirborne())
  verify(plane:inAir())
end


function test_capGroup:test_isLanded() 
  local group, plane = getCapGroup()
  
  plane:getObject().inAir = function() return true end
  lu.assertFalse(group:isLanded())
  
  
  plane:getObject().inAir = function() return false end
  lu.assertTrue(group:isLanded(), false)
end

function test_capGroup:test_isEngineOff() 
  local group, plane = getCapGroup()
  
  plane.shutdown = false
  lu.assertFalse(group:isEngineOff())
  
  
  plane.shutdown = true
  lu.assertTrue(group:isEngineOff())
  end

function test_capGroup:test_shouldDeactivate_inAir() 
  local group, plane = getCapGroup()
  group.deactivateWhen = CapGroup.DeactivateWhen.InAir
  
  --group should be in less then 10km from wp
  group.getPoint = function() return {x = 99990, y = 0, z = 0} end
  group.route.hasAirfield = function() return true end
  group.route.getHomeBase = function() return {x = 0, y = 0, alt = 0, alt_type = "BARO", type = "Turning Point"} end
  
  --to far
  lu.assertFalse(group:shouldDeactivate())
  
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  lu.assertTrue(group:shouldDeactivate())
end

function test_capGroup:test_shouldDeactivate_onLand_noAirfield() 
  --no airfield, use inAir logic, should not call onLand
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  group.deactivateWhen = CapGroup.DeactivateWhen.OnLand
  --group should be in less then 10km from wp
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.route.hasAirfield = function() return false end
  group.route.getHomeBase = function() return {x = 0, y = 0, alt = 0, alt_type = "BARO", type = "Turning Point"} end
  
  group.isLanded = m.isLanded

  lu.assertTrue(group:shouldDeactivate())
  verify_no_call(m.isLanded(any()))
end


function test_capGroup:test_shouldDeactivate_onLand() 
  --no airfield, use inAir logic, should not call onLand
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  group.deactivateWhen = CapGroup.DeactivateWhen.OnLand
  --group should be in less then 10km from wp
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.route.hasAirfield = function() return true end
  group.route.getHomeBase = function() return {x = 0, y = 0, alt = 0, alt_type = "BARO", type = "Turning Point"} end
  
  group.isLanded = m.isLanded
  when(m.isLanded(group)).thenAnswer(true)

  lu.assertTrue(group:shouldDeactivate())
  verify(m.isLanded(any()))
end

function test_capGroup:test_shouldDeactivate_onShutdown_noAirfield() 
  --no airfield, use inAir logic, should not call onLand
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  group.deactivateWhen = CapGroup.DeactivateWhen.OnShutdown
  --group should be in less then 10km from wp
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.route.hasAirfield = function() return false end
  group.route.getHomeBase = function() return {x = 0, y = 0, alt = 0, alt_type = "BARO", type = "Turning Point"} end
  
  group.isEngineOff = m.isEngineOff

  lu.assertTrue(group:shouldDeactivate())
  --no airfield, shouldn't be called
  verify_no_call(m.isEngineOff(any()))
end

function test_capGroup:test_shouldDeactivate_onShutdown() 
  --no airfield, use inAir logic, should not call onLand
  local group, plane = getCapGroup()
  local m = mockagne.getMock()
  
  group.deactivateWhen = CapGroup.DeactivateWhen.OnShutdown
  --group should be in less then 10km from wp
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.route.hasAirfield = function() return true end
  group.route.getHomeBase = function() return {x = 0, y = 0, alt = 0, alt_type = "BARO", type = "Turning Point"} end
  
  group.isEngineOff = m.isEngineOff
  when(m.isEngineOff(group)).thenAnswer(true)

  lu.assertTrue(group:shouldDeactivate())
  --no airfield, shouldn't be called
  verify(m.isEngineOff(group))
  end

function test_capGroup:test_getMaxDistanceToLead_1PlaneGroup() 
  local group, plane = getCapGroup()
  
  lu.assertEquals(group:getMaxDistanceToLead(), 0)
end

function test_capGroup:test_getMaxDistanceToLead() 
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local plane3 = getCapPlane()
  
  plane1.getPoint = function() return {x = 0, y = 0, z = 0} end
  plane2.getPoint = function() return {x = 100, y = 0, z = 0} end
  plane3.getPoint = function() return {x = 10, y = 0, z = 0} end
  
  local group = CapGroup:create({plane1, plane2, plane3})
  
  lu.assertEquals(group:getMaxDistanceToLead(), 100)
end

function test_capGroup:test_needRTB_ammoLow() 
  local group, plane = getCapGroup()
  group:setBingo(0)--set low so no trigger
  
  group:setRTBWhen(CapGroup.RTBWhen.NoARH)
  group.ammoState = CapGroup.AmmoState.ARH
  
  lu.assertFalse(group:needRTB())
  
  group.ammoState = CapGroup.AmmoState.SARH
  lu.assertTrue(group:needRTB())
end

function test_capGroup:test_needRTB_FuelLow() 
  local group, plane = getCapGroup()
  group:setBingo(0)
  
  --set low so no trigger
  group:setRTBWhen(CapGroup.RTBWhen.NoAmmo)
  group.ammoState = CapGroup.AmmoState.ARH
  
  lu.assertFalse(group:needRTB())
  
  group:setBingo(0.5)
  group.getFuel = function() return 0.49 end
  lu.assertTrue(group:needRTB())
end

function test_capGroup:test_mergeElements_1Element()
  --1 element, no changes
  local inst = getCapGroup()
  
  lu.assertEquals(#inst.elements, 1)
  inst:mergeElements()
  lu.assertEquals(#inst.elements, 1)
end

function test_capGroup:test_mergeElements_2Elements()
  --2 elements, after call all planes in first element
  --linkage removed
  --planes linkage update(myElement should update)
  local inst = getCapGroup()
  local plane2 = getCapPlane()
  
  inst.elements[2] = CapElement:create({plane2})
  plane2:registerElement(inst.elements[2])
  plane2:registerGroup(inst)
  
  lu.assertEquals(plane2.myGroup, inst)
  lu.assertEquals(plane2.myElement, inst.elements[2])
  
  inst:updateElementsLink()
  
  lu.assertEquals(#inst.elements, 2)
  lu.assertEquals(#inst.elements[1].planes, 1)
  lu.assertEquals(#inst.elements[2].planes, 1)
  
  inst:mergeElements()
  lu.assertEquals(#inst.elements, 1)
  lu.assertEquals(#inst.elements[1].planes, 2)
  lu.assertEquals(plane2.myElement, inst.elements[1])
  lu.assertEquals(plane2.myGroup, inst)
  
  lu.assertEquals(tostring(inst.elements[1].planes[2]), tostring(plane2))
  lu.assertEquals(tostring(plane2.myElement), tostring(inst.elements[1]))
end

function test_capGroup:test_splitElement_signleton() 
  --1 plane in group, nothing changes
  local inst = getCapGroup()
  
  lu.assertEquals(#inst.elements[1].planes, 1)
  
  inst:splitElement()
  
  --same amount planes
  lu.assertEquals(#inst.elements[1].planes, 1)
  --same amount element
  lu.assertEquals(#inst.elements, 1)
  --no link change
  lu.assertEquals(inst.elements[1].planes[1].myElement, inst.elements[1])
  lu.assertEquals(inst.elements[1].planes[1].myGroup, inst)
end

function test_capGroup:test_splitElement_2Planes() 
  --2 elements, 1 plane in each
  --link to myElement updates
  --link to myGroup no change
  --in second element myGroup is instance
  --verify new element has FSM from first plane
  --verify new element has same first state, except refence and id
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local group = CapGroup:create({plane1, plane2})
  group:setFSM_NoCall(FSM_FlyRoute:create(group))
  
  lu.assertEquals(#group.elements, 1)
  lu.assertEquals(#group.elements[1].planes, 2)
  lu.assertNotNil(plane1.myGroup)
  lu.assertNotNil(plane1.myElement)
  lu.assertEquals(group.elements[1].FSM_stack.data[1].state, FSM_FlyToPoint)
  
  group:splitElement()
  
  lu.assertEquals(#group.elements, 2)
  lu.assertEquals(#group.elements[1].planes, 1)
  lu.assertEquals(#group.elements[2].planes, 1)
  
  lu.assertIs(group.elements[1].myGroup, group)
  lu.assertIs(group.elements[2].myGroup, group)
  
  lu.assertIs(plane1.myElement, group.elements[1])
  lu.assertIs(plane2.myElement, group.elements[2])
  
  lu.assertEquals(tostring(plane1.myElement), tostring(group.elements[1]))
  lu.assertEquals(tostring(plane2.myElement), tostring(group.elements[2]))
  
  --task was copied 
  lu.assertEquals( tostring(group.elements[2].FSM_stack.data[1].object),  tostring(group.elements[2]))
  lu.assertEquals(group.elements[2].FSM_stack.data[1].state, group.elements[1].FSM_stack.data[1].state)
  lu.assertEquals(group.elements[2].FSM_stack.data[1].stateArg, group.elements[1].FSM_stack.data[1].stateArg)
end

function test_capGroup:test_splitElement_3Planes() 
  --2 elements, 2 plane in first, 1 plane in second
  --link to myElement updates
  --link to myGroup no change
  --in second element myGroup is instance
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local plane3 = getCapPlane()
  local group = CapGroup:create({plane1, plane2, plane3})
  
  lu.assertEquals(#group.elements, 1)
  lu.assertEquals(#group.elements[1].planes, 3)
  lu.assertNotNil(plane1.myGroup)
  lu.assertNotNil(plane1.myElement)
  
  group:splitElement()
  
  lu.assertEquals(#group.elements, 2)
  lu.assertEquals(#group.elements[1].planes, 2)
  lu.assertEquals(#group.elements[2].planes, 1)
  
  lu.assertIs(group.elements[1].myGroup, group)
  lu.assertIs(group.elements[2].myGroup, group)
  
  lu.assertIs(plane1.myElement, group.elements[1])
  lu.assertIs(plane2.myElement, group.elements[1])
  lu.assertIs(plane3.myElement, group.elements[2])
  
  lu.assertEquals(tostring(plane1.myElement), tostring(group.elements[1]))
  lu.assertEquals(tostring(plane2.myElement), tostring(group.elements[1]))
  lu.assertEquals(tostring(plane3.myElement), tostring(group.elements[2]))
  end


function test_capGroup:test_checkTargets_notgt() 
  --return table with target == nil
  local group = getCapGroup()
  
  lu.assertNil(group:checkTargets({}).target)
end

function test_capGroup:test_checkTargets_checkFields() 
  local group = getCapGroup()
  local target = getTargetGroup()
  
  --table from detector handler is dict where key is ID
  local tbl = {[target:getID()] = target}
  
  group.calculateCommitRange = function() return 9999 end
  target.getPoint = function() return {x = 8000, y = 0, z = 0} end
  group.getPoint = function() return {x = 0, y = 0, z = 0} end
  group.getTargetPriority = function() return 1234 end
  
  local result = group:checkTargets(tbl)
  lu.assertEquals(result.target, target)
  lu.assertEquals(result.commitRange, group.calculateCommitRange())
  lu.assertEquals(result.range, 8000)
  lu.assertEquals(result.priority, group.getTargetPriority())
end

function test_capGroup:test_checkTargets_notgtInRange() 
  --we have target,  but distance > commitRange
  local group = getCapGroup()
  local target = getTargetGroup()
  
  --table from detector handler is dict where key is ID
  local tbl = {[target:getID()] = target}
  
  target.getPoint = function() return {x = 10000, y = 0, z = 0} end

  group.commitRange = 9000
  
  lu.assertNil(group:checkTargets(tbl).target)
end

function test_capGroup:test_checkTargets_notgtInRange() 
  --we have target,  but distance > commitRange
  local group = getCapGroup()
  local target = getTargetGroup()
  
  --table from detector handler is dict where key is ID
  local tbl = {[target:getID()] = target}
  
  target.getPoint = function() return {x = 10000, y = 0, z = 0} end

  group.commitRange = 9000
  
  lu.assertNil(group:checkTargets(tbl).target)
end

function test_capGroup:test_checkTargets_returnTargetWithMaxPrority() 
  --we have target,  but distance > commitRange
  local group = getCapGroup()
  local target1 = getTargetGroup()
  local target2 = getTargetGroup()
  
  --table from detector handler is dict where key is ID
  local tbl = {[target1:getID()] = target1, [target2:getID()] = target2}
  
  target1.getPoint = function() return {x = 10000, y = 0, z = 0} end
  target2.getPoint = target1.getPoint

  local m = mockagne.getMock()
  group.getTargetPriority = m.getTargetPriority
  when(m.getTargetPriority(group, target1, any(), any(), any(), any(), any())).thenAnswer(1)
  when(m.getTargetPriority(group, target2, any(), any(), any(), any(), any())).thenAnswer(5)

  group.calculateCommitRange = function() return 99999 end
  
  lu.assertEquals(group:checkTargets(tbl).target, target2)
  verify(m.getTargetPriority(group, target1, any(), any(), any(), any(), any()))
  verify(m.getTargetPriority(group, target2, any(), any(), any(), any(), any()))
end

function test_capGroup:test_checkTargets_returnTargetInZone() 
  --we have target,  it's outside commit range but inside one of zones
  local group = getCapGroup()
  local target1 = getTargetGroup()
  
  local tgtPos =  {x = 10000, y = 0, z = 0}
  local zone = CircleZone:create(tgtPos, 5000)
  
  group.commitRange = 10
  --table from detector handler is dict where key is ID
  local tbl = {[target1:getID()] = target1}
  target1.getPoint = function() return tgtPos end
  
  lu.assertEquals(zone:isInZone(target1:getPoint()), true)
  
  --target should be discarded if no zone supplied
  lu.assertNil(group:checkTargets(tbl).target)
  
  group:addCommitZone(zone)
  
  lu.assertEquals(countElements(group.commitZones), 1)
  lu.assertEquals(group:checkTargets(tbl).target, target1)
end

function test_capGroup:test_getAspectFromElements() 
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local group = CapGroup:create({plane1, plane2})
  local elem1 = group.elements[1]
  elem1.getPoint = function() return {x = 10000, y = 0, z = 0} end
  
  local m = mockagne.getMock("1")
  local target = getTargetGroup()
  target.getAA = m.getAA
  when(target:getAA(elem1:getPoint())).thenAnswer(90)
  
  --case1: only 1 element:
  lu.assertEquals(group:getAspectFromElements(target), 90)
  verify(target:getAA(elem1:getPoint()))
  
  --case2: 2 elements, return lowest range
  group:splitElement()
  local elem2 = group.elements[2]
  elem2.getPoint = function() return {x = 9000, y = 0, z = 0} end
  when(target:getAA(elem2:getPoint())).thenAnswer(60)
  
  lu.assertEquals(group:getAspectFromElements(target), 60)
  verify(target:getAA(elem1:getPoint()))
  verify(target:getAA(elem2:getPoint()))
  end

function test_capGroup:test_getAutonomous() 
  local group = getCapGroup()
  group.autonomous = true
  
  lu.assertEquals(group:getAutonomous(), true)
  
  group.autonomous = false
  
  lu.assertEquals(group:getAutonomous(), false)
end

function test_capGroup:test_getDetectedTargets_nothing() 
  --no targets, return empty list
  local group = getCapGroup()
  local m = mockagne.getMock()
  
  for _, plane in group:planes() do 
    plane.getDetectedTargets = m.getDetectedTargets
    when(plane:getDetectedTargets()).thenAnswer({})
  end
  
  lu.assertEquals(group:getDetectedTargets(), {})
end

function test_capGroup:test_getDetectedTargets() 

  local group = getCapGroup()
  local m = mockagne.getMock()
  local target = getTarget()
  
  local t = {
    {object = target:getObject(), type = false, 
    visible = false, --the target is visible
    type = false, --the target type is known
    distance = false
    }
  }
  
  group.elements[1].planes[1].getDetectedTargets = m.getDetectedTargets
  when(m.getDetectedTargets(group.elements[1].planes[1])).thenAnswer(t)
  
  target:getObject().hasAttribute = m.hasAttribute
  when(target:getObject():hasAttribute("Air")).thenAnswer(true)
  target:getObject().isExist = m.isExist
  when(target:getObject():isExist()).thenAnswer(true)
  
  local result = group:getDetectedTargets()
  lu.assertEquals(#result, 1)
  lu.assertEquals(result[1]:getTarget(), target:getObject())
  lu.assertEquals(result[1]:getDetector(), group.elements[1].planes[1])
  
  verify(target:getObject():isExist())
  verify(target:getObject():hasAttribute("Air"))
end

function test_capGroup:test_getDetectedTargets_rejectDeadAndNoAir() 
  --target1 is not alive
  --target2 is ok
  --target3 is alive but not Air
  local group = getCapGroup()
  local m = mockagne.getMock()
  local target1 = getTarget()
  local target2 = getTarget()
  local target3 = getTarget()
  
  local t = {
    {object = target1:getObject(),
    visible = false, --the target is visible
    type = false, --the target type is known
    distance = false
    },
    {object = target2:getObject(),
      visible = false, --the target is visible
      type = false, --the target type is known
      distance = false
    },
    {object = target3:getObject(),
      visible = false, --the target is visible
      type = false, --the target type is known
      distance = false
    }
  }
  
  target1:getObject().isExist = function() return false end
  target2:getObject().isExist = function() return true end
  target3:getObject().isExist = target2.isExist
  
  target1:getObject().hasAttribute = function() return true end
  target2:getObject().hasAttribute = function() return true end
  target3:getObject().hasAttribute = function() return false end
  
  group.elements[1].planes[1].getDetectedTargets = function() return t end
  
  local result = group:getDetectedTargets()
  lu.assertEquals(#result, 1)
  lu.assertEquals(result[1]:getTarget(), target2:getObject())
  lu.assertEquals(result[1]:getDetector(), group.elements[1].planes[1])
end

function test_capGroup:test_getDetectedTargets_askAll() 
  --target1 returned by all planes, result is 2 container
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local m = mockagne.getMock()
  local target1 = getTarget()
  local group = CapGroup:create({plane1, plane2})
  
  local t = {
    {object = target1:getObject(),
    visible = false, --the target is visible
    type = false, --the target type is known
    distance = false
    }
  }
  
  target1:getObject().isExist = function() return true end
  target1:getObject().hasAttribute = function() return true end
  
  plane1.getDetectedTargets = m.getDetectedTargets
  plane2.getDetectedTargets = m.getDetectedTargets
  
  when(plane1:getDetectedTargets()).thenAnswer(t)
  when(plane2:getDetectedTargets()).thenAnswer(t)
  
  local result = group:getDetectedTargets()
  lu.assertEquals(#result, 2)
  
  verify(plane1:getDetectedTargets())
  verify(plane2:getDetectedTargets())
  end

--------------------------------------------------------------------
--------------------------------------------------------------------
--------------------------------------------------------------------

test_CapGroupRoute = {}

function test_CapGroupRoute:test_creation() 
  --objective, squadron saved
  --original size saved
  --objective gciZone added to commit zones
  --create patrol zone at objective 250m/s 7500, second point 20km north from first
  --retask timer set
  --use different classes for rtb/deactivate
  --create new route, first point our home point, second wp is objective at 280/7500
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 9999, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  lu.assertIs(obj, testedInst.objective)
  lu.assertIs(sqn, testedInst.sqn)
  lu.assertEquals(testedInst:getOriginalSize(), 2)
  
  --route test, because we too close to objective climb WP was added
  local route = testedInst.route
  local objPoint = mist.vec.add(obj:getPoint(), {x = 20000, y = 0, z = 0})
  lu.assertEquals(#route.waypoints, 3)
  lu.assertEquals(route.waypoints[2].x, objPoint.x)
  lu.assertEquals(route.waypoints[2].y, objPoint.z)
  lu.assertEquals(route.waypoints[2].alt, 7500)
  lu.assertEquals(route.waypoints[2].speed, 230)
  lu.assertEquals(route.waypoints[3], sqn:getHomeWP())
  
  --commit zone added
  lu.assertEquals(testedInst.commitZones, {[obj:getGciZone():getID()] = obj:getGciZone()})
  
  --check patrolZone added to second WP
  local _, zone = next(testedInst.patrolZones[2])
  lu.assertEquals(zone.task.params.pattern, "Race-Track")
  lu.assertEquals(zone.task.params.speed, 230)
  lu.assertEquals(zone.task.params.altitude, 7500)
  lu.assertEquals(zone.task.params.point2, mist.utils.makeVec2(obj:getPoint()))
  lu.assertEquals(zone.task.params.point, mist.utils.makeVec2(mist.vec.add(obj:getPoint(), {x = 20000, y = 0, z = 0})))
  
  --timer set
  lu.assertNumber(testedInst.canBeRetasked)
  --timer in proper interval
  lu.assertEquals(testedInst.canBeRetasked > timer.getAbsTime() + 300, true)
  lu.assertEquals(testedInst.canBeRetasked < timer.getAbsTime() + 900, true)
  
  --proper classes used
  lu.assertEquals(testedInst.rtbClass, FSM_GroupRTB_Route)
  lu.assertEquals(testedInst.deactivateClass, FSM_Deactivate_Route)
end

function test_CapGroupRoute:test_creation_useParamsFromSqn_3WP() 
  local sqn = getCapSquadronMock()
  sqn.speed = 100
  sqn.alt = 1000
  sqn.alt_type = "RADIO"
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 0, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  
  --case1: objective too close, will create route with 3 wp
  local testedInst = CapGroupRoute:create({plane1}, obj, sqn)
  local route = testedInst.route
  lu.assertEquals(route.waypoints[1].speed, sqn.speed)
  lu.assertEquals(route.waypoints[1].alt, sqn.alt)
  lu.assertEquals(route.waypoints[1].alt_type, sqn.alt_type)
  lu.assertEquals(route.waypoints[2].speed, sqn.speed)
  lu.assertEquals(route.waypoints[2].alt, sqn.alt)
  lu.assertEquals(route.waypoints[2].alt_type, sqn.alt_type)
  lu.assertEquals(#route.waypoints, 3)
  
  --zone also uses alt/speed
  local _, zone = next(testedInst.patrolZones[2])
  lu.assertEquals(zone.task.params.altitude, sqn.alt)
  lu.assertEquals(zone.task.params.speed, sqn.speed)
end

function test_CapGroupRoute:test_creation_useParamsFromSqn_2WP() 
  local sqn = getCapSquadronMock()
  sqn.speed = 100
  sqn.alt = 1000
  sqn.alt_type = "RADIO"
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 99990, y = 0, z = 0} end
  
  local plane1 = getCapPlane()
  
  --case21: objective far enough, fly directly to zone
  local testedInst = CapGroupRoute:create({plane1}, obj, sqn)
  local route = testedInst.route
  lu.assertEquals(route.waypoints[2].speed, sqn.speed)
  lu.assertEquals(route.waypoints[2].alt, sqn.alt)
  lu.assertEquals(route.waypoints[2].alt_type, sqn.alt_type)
  lu.assertEquals(#route.waypoints, 3)
  
  --zone also uses alt/speed
  local _, zone = next(testedInst.patrolZones[2])
  lu.assertEquals(zone.task.params.altitude, sqn.alt)
  lu.assertEquals(zone.task.params.speed, sqn.speed)
end

function test_CapGroupRoute:test_setNewObjective_useParamsFromSqn() 
  local sqn = getCapSquadronMock()
  sqn.speed = 100
  sqn.alt = 1000
  sqn.alt_type = "RADIO"
  local obj = getCapObjectiveMock()

  local plane1 = getCapPlane()
  --case21: objective far enough, fly directly to zone
  local testedInst = CapGroupRoute:create({plane1}, obj, sqn)
  
  local obj2 = getCapObjectiveMock()
  testedInst:setNewObjective(obj2)
  
  local route = testedInst.route
  --speed 300 m/s, other from sqn
  lu.assertEquals(route.waypoints[1].speed, 300)
  lu.assertEquals(route.waypoints[1].alt, sqn.alt)
  lu.assertEquals(route.waypoints[1].alt_type, sqn.alt_type)
  lu.assertEquals(#route.waypoints, 2)
  
  --zone also uses alt/speed
  local _, zone = next(testedInst.patrolZones[1])
  lu.assertEquals(zone.task.params.altitude, sqn.alt)
  lu.assertEquals(zone.task.params.speed, sqn.speed)
end

function test_CapGroupRoute:test_updateGroupDies() 
  --group dies, delete planes from objective
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane2, plane2}, obj, sqn)
  testedInst.isExist = function() return false end
  
  testedInst:update()
  
  verify(obj:addCapPlanes(-testedInst:getOriginalSize()))
end

--we can retask only if time passed and only in FlyRoute/Rejoin/PatrolZone
function test_CapGroupRoute:test_canRetask() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane2, plane2}, obj, sqn)
  
  --case1: not enough time passed
  testedInst.canBeRetasked = timer.getAbsTime() + 99
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_FlyRoute end
  lu.assertFalse(testedInst:canRetask())

  --case2: wrong state
  testedInst.canBeRetasked = timer.getAbsTime() - 99
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_Commit end
  lu.assertFalse(testedInst:canRetask())
  
  --case3: all good(flyRoute)
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_FlyRoute end
  lu.assertTrue(testedInst:canRetask())
  
  --case4: all good(Rejoin)
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_Rejoin end
  lu.assertTrue(testedInst:canRetask())
  
  --case5: all good(PatrolZone)
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_PatrolZone end
  lu.assertTrue(testedInst:canRetask())
end

function test_CapGroupRoute:test_setNewObjective_Preparing() 
  --commit zone replaced
  --patrol zone replaced
  --route replaced, now first point is objective, second home base
  --timer set to new val
  --planes removed from old objective and added to new
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane2, plane2}, obj, sqn)
  
  local newObj = getCapObjectiveMock()
  newObj.getPoint = function() return {x = 5555, y = 0, z = 0} end
  
  testedInst:setNewObjective(newObj)
  
  --commit zone replaced
  lu.assertEquals(testedInst.commitZones, {[newObj:getGciZone():getID()] = newObj:getGciZone()})
  
  --patrol zone replaced, old deleted
  lu.assertEquals(countElements(testedInst.patrolZones), 1)--only 1wp with 1 zone
  lu.assertEquals(countElements(testedInst.patrolZones[1]), 1)--only 1wp with 1 zone
  
  local _, zone = next(testedInst.patrolZones[1])
  lu.assertEquals(testedInst.patrolZones[1], {[zone:getID()] = zone})
  lu.assertEquals(zone.task.params.point, {x = 25555, y = 0})
  lu.assertEquals(zone.task.params.point2, mist.utils.makeVec2(newObj:getPoint()))
  
  --route replaced, now first point is objective north point, second home base
  local objPoint = mist.vec.add(newObj:getPoint() , {x = 20000, y= 0, z = 0})
  local route = testedInst.route
  lu.assertEquals(#route.waypoints, 2)
  lu.assertEquals(route.waypoints[1].x, objPoint.x)
  lu.assertEquals(route.waypoints[1].y, objPoint.z)
  lu.assertEquals(route.waypoints[1].alt, 7500)
  lu.assertEquals(route.waypoints[1].speed, 300)--speed 300m/s
  
  lu.assertEquals(route.waypoints[2], sqn:getHomeWP())
  
  --timer set to new val
  lu.assertNumber(testedInst.canBeRetasked)
  --timer in proper interval
  lu.assertEquals(testedInst.canBeRetasked > timer.getAbsTime() + 300, true)
  lu.assertEquals(testedInst.canBeRetasked < timer.getAbsTime() + 900, true)
  
  --planes removed from old objective and added to new
  verify(obj:addCapPlanes(-testedInst:getOriginalSize()))
  verify(newObj:addCapPlanes(testedInst:getOriginalSize()))
end

function test_CapGroupRoute:test_setNewObjective_FlyRoute() 
  --group in FlyRoute state, call setup(), verify new WP set to plane
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 90000, y = 0, z = 0} end --or will immidiatly trigger rtnb
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  testedInst.needRTB = function() return false end
  testedInst:setFSM_NoCall(FSM_FlyRoute:create(testedInst))
  
  --verify original task set
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1], testedInst.route.waypoints[2])
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].x, obj:getPoint().x + 20000) --north point of hold
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].y, obj:getPoint().z)
  
  local newObj = getCapObjectiveMock()
  newObj.getPoint = function() return {x = 55555, y = 0, z = 0} end
  
  testedInst:setNewObjective(newObj)
  
  local objPoint = mist.vec.add(newObj:getPoint(), {x = 20000, y= 0, z = 0})
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1], testedInst.route.waypoints[1])
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].x, objPoint.x)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].y, objPoint.z)
  --verify we fly at higher speed
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].speed, 300)
end

function test_CapGroupRoute:test_setNewObjective_PatrolZone() 
  --group in PatrolZone state, return to previous state(FlyRoute)
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  local _, patrolZone = next(testedInst.patrolZones[2])--obj close to sqn, group uses climb wp, so it number 2
  testedInst.needRTB = function() return false end
  testedInst:setFSM_NoCall(FSM_FlyRoute:create(testedInst))
  testedInst:setFSM_NoCall(FSM_PatrolZone:create(testedInst, patrolZone))
  
  --group go to patrol state
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  
  local newObj = getCapObjectiveMock()
  newObj.getPoint = function() return {x = 55555, y = 0, z = 0} end
  
  testedInst:setNewObjective(newObj)
  
  --group flyes to next zone
  local objPoint = mist.vec.add(newObj:getPoint(), {x = 20000, y= 0, z = 0})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1], testedInst.route.waypoints[1])
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].x, objPoint.x)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].y, objPoint.z)
  --verify we fly at higher speed
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].speed, 300)
end


--Cases when group cover it's spawn point, so route very compact(right after takeoff group reach end of route, cause
-- it's same point), group should go to FlyRoute and after hold it can immidiatly go to RTB
function test_CapGroupRoute:test_patrolZoneOverField() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 0, y = 0, z = 0} end --or will immidiatly trigger rtb

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  testedInst.needRTB = function() return false end
  --group cover same airfield which he takeoff
  testedInst.getPoint = obj.getPoint
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupStart)
  
  --group take off, and now climbing toward climb wp
  local climbWP = mist.vec.add(sqn:getPoint(), {x = 0, y = 0, z = 35000}) --35km to east from spawn point
  testedInst.isAirborne = function() return true end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].x, climbWP.x)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].y, climbWP.z)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].alt, 7500)
  
  
  --group approach to patrol zone, go patrolling
  --group reach zone wp and in range to switch, enter hold
  testedInst.route.currentWpNumber = 2
  local objPoint = mist.vec.add(obj:getPoint(), {x = 20000, y= 0, z = 0})
  testedInst.getPoint = function() return objPoint end
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.point2, mist.utils.makeVec2(obj:getPoint()))
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.point, {x = 20000, y = 0})
  
  --group too separated, go rejoin
  testedInst.getMaxDistanceToLead = function() return 99999 end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Rejoin)
  
  --group rejoined, return to patrol
  testedInst.getMaxDistanceToLead = function() return 0 end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  
  --group need RTB
  testedInst.needRTB = function() return true end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
end


function test_CapGroupRoute:test_patrolZoneOverField_ChangeToOtherZone() 
--group take off and stay in patrol zone over spawn point as in previous test,
--then change task to other objective which also very close -> group immidiatly goes to PatrolZone over new Zone
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 0, y = 0, z = 0} end --or will immidiatly trigger rtb

  local plane1 = getCapPlane()
  local plane2 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1, plane2}, obj, sqn)
  testedInst.needRTB = function() return false end
  --group cover same airfield which he takeoff
  testedInst.getPoint = obj.getPoint
  
  --group take off, fly to first WP
  testedInst.isAirborne = function() return true end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  
  --group reach zone wp and in range to switch, enter hold
  testedInst.getPoint = function() return mist.vec.add(obj:getPoint(), {x = 19000, y = 0, z = 0}) end
  testedInst.route.currentWpNumber = 2
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  
  local newObj = getCapObjectiveMock()
  newObj.getPoint = function() return {x = 500, y = 0, z = 0} end 
  
  --new objective set, group close enough, go patrol over new zone
  testedInst.getPoint = function() return mist.vec.add(newObj:getPoint(), {x = 19000, y = 0, z = 0}) end
  testedInst:setNewObjective(newObj)
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  
  --verify we patrolling over new Zone
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.point2, mist.utils.makeVec2(newObj:getPoint()))
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.point, {x = 20500, y = 0})
end  

--Cases when group cover far objective, so route is only 2 points, should return to home base
function test_CapGroupRoute:test_patrolZoneNormal() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 500000, y = 0, z = 0} end --or will immidiatly trigger rtb

  local plane1 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1}, obj, sqn)
  testedInst.needRTB = function() return false end
  --group cover same airfield which he takeoff
  testedInst.getPoint = function ()
    return {x=0, y = 0, z = 0} 
  end
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupStart)
  
  --group take off, and now climbing toward climb wp
  testedInst.isAirborne = function() return true end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  
  
  --group approach to patrol zone, go patrolling
  --group reach zone wp and in range to switch, enter hold
  testedInst.getPoint = function ()
    return mist.vec.add(obj:getPoint(), {x = 20000, y = 0, z = 0})
  end
  
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})--will update route
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_PatrolZone)
  
  --group need RTB
  testedInst.needRTB = function() return true end
  testedInst:update()
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  --verify fly toward home
  lu.assertEquals(testedInst.route:getHomeBase(), sqn:getHomeWP())
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].x, sqn:getHomeWP().x)
  lu.assertEquals(plane1.FSM_stack:getCurrentState().task.params.route.points[1].y, sqn:getHomeWP().y)

  --reach home proximity, deactivate
  testedInst.getPoint = function() return sqn:getPoint() end
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_Deactivate)
end

function test_CapGroupRoute:test_updateRemovePlanes() 
  local sqn = getCapSquadronMock()
  local obj = getCapObjectiveMock()
  obj.getPoint = function() return {x = 0, y = 0, z = 0} end --or will immidiatly trigger rtb
  obj:addCapPlanes(1) --simulate adding planes from container

  local plane1 = getCapPlane()
  local testedInst = CapGroupRoute:create({plane1}, obj, sqn)
  testedInst.needRTB = function() return false end
  --group cover same airfield which he takeoff
  testedInst.getPoint = obj.getPoint
  
  --group take off, fly to first WP
  testedInst.isAirborne = function() return true end
  testedInst:setFSM_Arg("contacts", {})
  testedInst:setFSM_Arg("radars", {})
  testedInst:callFSM({})
  testedInst:update()

  
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_FlyRoute)
  
  --group go to RTB, planes removed from objective
  testedInst.needRTB = function() return true end
  testedInst:callFSM()
  testedInst:update()
  lu.assertEquals(testedInst:getCurrentFSM(), CapGroup.FSM_Enum.FSM_GroupRTB)
  verify(obj:addCapPlanes(-1))
  
  --group dies during RTB, no plane deleting
  obj.addCapPlanes = obj.addCapPlanes2 --mock again 
  
  testedInst.isExist = function() return false end
  testedInst:update()
  verify_no_call(obj:addCapPlanes(-1))
  
  --group no RTB, then it should delete
  testedInst.getCurrentFSM = function() return CapGroup.FSM_Enum.FSM_FlyRoute end
  testedInst:update()
  verify(obj:addCapPlanes(-1))
end


local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()