dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_GciCapHandler = utils.inheritFrom(AbstractMocksForSqn)

function test_GciCapHandler:getSumInContainers(inst) 
  local sum = 0
  for _, cont in pairs(inst.deferredGroups) do 
    sum = sum + cont:getOriginalSize()
  end
  
  return sum
end 

function test_GciCapHandler:getSqn(handler) 
  local inst = CapSquadronAir:create("1")
  inst.getCoalition = function() return handler.coalition end
  
  return inst
end

function test_GciCapHandler:getGroup(sqn, obj) 
  local plane = getCapPlane()
  return CapGroupRoute:create({plane}, obj, sqn)
end

function test_GciCapHandler:getObj() 
  return CapObjective:create({x = 0, y = 0, z = 0}, CircleZone:create({x = 0, y = 0}, 99999))
end


function test_GciCapHandler:setup()
  --need to see debug from protected func
  GlobalLogger:create():setNewSettings(GlobalLogger.settingsPrefab.allOn)
  GlobalLogger:create():getSettings().level = GlobalLogger.LEVELS.WARNING
  GlobalLogger:create():getSettings().levelInGame = GlobalLogger.LEVELS.WARNING
  
  self:super().setup(self)
end

function test_GciCapHandler:test_creation() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED, 6)
  
  --verify different group class
  lu.assertEquals(inst.groupClass, CapGroupRouteWithChecks)
  
  --verify fields
  lu.assertEquals(inst.squadrones, {})
  lu.assertEquals(inst.objectives, {})
  lu.assertEquals(inst.airborneGroupLimit, 6)
  lu.assertNumber(inst.minimumGroupSize)
end

function test_GciCapHandler:test_allowSingletons() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  lu.assertEquals(inst.minimumGroupSize, 2)
  
  inst:allowSignletonGroups(true)
  lu.assertEquals(inst.minimumGroupSize, 1)
  
  inst:allowSignletonGroups(false)
  lu.assertEquals(inst.minimumGroupSize, 2)
end

function test_GciCapHandler:test_addSquadronWrongCoalition() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = getCapSquadronMock()
  sqn.getCoalition = function() return GciCapHandler.coalition.BLUE end
  
  inst:addSquadron(sqn)
  --nothing added
  lu.assertEquals(inst.squadrones, {})
end


function test_GciCapHandler:test_addSquadron() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)

  --verify sqn added with key == sqnID
  inst:addSquadron(sqn, true)
  lu.assertEquals(inst.squadrones, {[sqn:getID()] = sqn})
  
  --verify objective added
  lu.assertEquals(#inst.objectives, 1)
  --verify it's protect sqn
  local v = sqn:getPoint()
  lu.assertEquals(sqn:getPoint(), {x = 0, y = 0, z = 0})

  lu.assertEquals(inst.objectives[1]:getPoint(), sqn:getPoint())
end

function test_GciCapHandler:test_addSquadronWO_objective() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.objectiveActive = function() return false end

  --verify sqn added with key == sqnID
  inst:addSquadron(sqn)
  lu.assertEquals(inst.squadrones, {[sqn:getID()] = sqn})
  
  --verify objective NOT added
  lu.assertEquals(inst.objectives, {})
end

function test_GciCapHandler:test_addSquadron_sqnAddedToObjectives() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj1 = self:getObj()
  local obj2 = self:getObj()
  
  inst:addObjective(obj1)
  inst:addObjective(obj2)
  lu.assertEquals(#inst.objectives, 2)
  
  --sqn will also add objective on his home base
  inst:addSquadron(sqn, true)
  lu.assertEquals(#inst.objectives, 3)
  
  --verify sqn was added to all objectives
  lu.assertEquals(inst.objectives[1].squadrons[1].squadron, sqn)
  lu.assertEquals(inst.objectives[2].squadrons[1].squadron, sqn)
  lu.assertEquals(inst.objectives[3].squadrons[1].squadron, sqn)
end

function test_GciCapHandler:test_addObjective() 
  --all sqns added to objective
  --objective should be sorted in priority descend
  --if priority same then added later -> place after other
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  
  inst:addSquadron(self:getSqn(inst), true)
  inst:addSquadron(self:getSqn(inst), true)
  
  --already has 2 objectives with low priority
  lu.assertEquals(#inst.objectives, 2)
  
  --add objective with high priority, should be first
  local obj1 = self:getObj()
  obj1:setPriority(CapObjective.Priority.High)
  inst:addObjective(obj1)
  
  lu.assertEquals(#inst.objectives, 3)
  lu.assertEquals(inst.objectives[1], obj1)
  --squadrones added
  lu.assertEquals(#obj1.squadrons, 2)
  
  --add another objective with high priority, should be after first
  local obj2 = self:getObj()
  obj2:setPriority(CapObjective.Priority.High)
  inst:addObjective(obj2)
  
  lu.assertEquals(#inst.objectives, 4)
  lu.assertEquals(inst.objectives[1], obj1)
  lu.assertEquals(inst.objectives[2], obj2)
  --squadrones added
  lu.assertEquals(#obj2.squadrons, 2)
end

function test_GciCapHandler:test_spawnGroup_emptyCont() 
  --container return empty array, nothing added
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local container = AirContainer:create(sqn, obj, 3, 999)
  container.activate = function() return {} end
  
  inst.deferredGroups[container:getID()] = container
  inst:spawnGroup(container)
  lu.assertEquals(inst.groups, {})--nothing added
end

function test_GciCapHandler:test_spawnGroup() 
  --container return requested amount of planes, group spawned and added
  --no planes from objective deleted
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local container = AirContainer:create(sqn, obj, 2, 999)
  container.activate = function() return {Group:create(), Group:create()} end

  inst:spawnGroup(container)
  lu.assertNotEquals(inst.groups, {})
  
  local id, group = next(inst.groups)
  lu.assertEquals(group.sqn, sqn)
  lu.assertEquals(group.objective, obj)
  lu.assertEquals(group.originalSize, 2)
  lu.assertNotNil(inst.groupErrors[id]) 
  --no planes from objective deleted
  lu.assertEquals(obj.aircraftAssigned, 2)
end

function test_GciCapHandler:test_spawnGroup_lessPlanes_noDiscard() 
  --container return less planes than requested, delete delta
  --so objective will have actual size
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  inst:setDiscardDamaged(false)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local container = AirContainer:create(sqn, obj, 4, 999)
  container.activate = function() return {Group:create(), Group:create()} end
  --added requested amount
  lu.assertEquals(obj.aircraftAssigned, 4)

  inst:spawnGroup(container)
  lu.assertNotEquals(inst.groups, {})
  
  local id, group = next(inst.groups)
  lu.assertEquals(group.sqn, sqn)
  lu.assertEquals(group.objective, obj)
  lu.assertEquals(group.originalSize, 2)
  --delete 2 planes
  lu.assertEquals(obj.aircraftAssigned, 2)
end

function test_GciCapHandler:test_spawnGroup_lessPlanes_noDiscard() 
  --container return less planes than requested, delete delta
  --so objective will have actual size
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  inst:setDiscardDamaged(false)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local container = AirContainer:create(sqn, obj, 4, 999)
  container.activate = function() return {Group:create(), Group:create()} end
  --added requested amount
  lu.assertEquals(obj.aircraftAssigned, 4)

  inst:spawnGroup(container)
  lu.assertNotEquals(inst.groups, {})
  
  local id, group = next(inst.groups)
  lu.assertEquals(group.sqn, sqn)
  lu.assertEquals(group.objective, obj)
  lu.assertEquals(group.originalSize, 2)
  --delete 2 planes
  lu.assertEquals(obj.aircraftAssigned, 2)
end

function test_GciCapHandler:test_spawnGroup_lessPlanes_Discard() 
  --container return less planes than requested, flag set, 
  --should return alive to sqn, remove from objective
  --and call destroy() on planes
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  inst:setDiscardDamaged(true)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local container = sqn:spawnGroup(4, obj, -99)
  lu.assertEquals(sqn:getCounter(), 6)
  lu.assertEquals(obj.aircraftAssigned, 4)
  
  local returnVal = {Group:create(), Group:create()}
  container.activate = function() return returnVal end
  --added requested amount
  lu.assertEquals(obj.aircraftAssigned, 4)

  inst:spawnGroup(container)
  --not added
  lu.assertEquals(inst.groups, {})
  
  --sqn planes returned
  lu.assertEquals(sqn:getCounter(), 8)
  --obj planes deleted
  lu.assertEquals(obj.aircraftAssigned, 0)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_spawnTypeDependOnFlag() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local result = AirContainer:create(sqn, obj, 2, 33)
  local m = mockagne.getMock()
  sqn.getReadyGroup = m.getReadyGroup
  when(sqn:getReadyGroup(any(), any())).thenAnswer(result)
  sqn.getGroup = m.getGroup
  when(sqn:getGroup(any(), any())).thenAnswer(result)
  
  --don't request spawn ready aircraft, should call getGroup
  inst:createNewGroupsFromSqn(sqn, obj, 2)
  verify(sqn:getGroup(2, obj))
  verify_no_call(sqn:getReadyGroup(2, obj))
  
  --flag true, use getReadyGroup
  inst:createNewGroupsFromSqn(sqn, obj, 2, true)
  verify(sqn:getReadyGroup(2, obj))
end

function test_GciCapHandler:test_createNewGroupsFromSqn_belowMinSize() 
  --trying to request below minimumGroupSize, do nothing
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  inst:createNewGroupsFromSqn(sqn, obj, 1)
  --no container created
  lu.assertEquals(inst.deferredGroups, {})
  --nochanges in objective
  lu.assertEquals(obj.aircraftAssigned, 0)
  --no counter increment
  lu.assertEquals(inst.airborneCount, 0)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_overflowSqn() 
  --trying to request more planes then sqn have
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.aircraftCounter = 2
  local obj = self:getObj()
  
  inst:createNewGroupsFromSqn(sqn, obj, 4)
  --should have container with all planes from sqn
  lu.assertNotEquals(inst.deferredGroups, {})
  
  --added all planes from sqn
  lu.assertEquals(obj.aircraftAssigned, 2)
  
  --sqn now have no planes
  lu.assertEquals(sqn:getCounter(), 0)
  
  --counter incremented
  lu.assertEquals(inst.airborneCount, 1)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_emptySqn() 
  --trying to request from empty sqn, nothing added
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.aircraftCounter = 0
  local obj = self:getObj()
  
  inst:createNewGroupsFromSqn(sqn, obj, 6)
  --nothing added
  lu.assertEquals(inst.deferredGroups, {})
  lu.assertEquals(obj.aircraftAssigned, 0)
  --no planes taken
  lu.assertEquals(sqn:getCounter(), 0)
  --no counter increment
  lu.assertEquals(inst.airborneCount, 0)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_create2Groups() 
  --trying to request more planes then max group capacity(4)
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.aircraftCounter = 10
  local obj = self:getObj()
  
  inst:createNewGroupsFromSqn(sqn, obj, 6)
  --should have 2 containers one 4 and second 2
  lu.assertNotEquals(inst.deferredGroups, {})
  
  --added all planes from sqn
  lu.assertEquals(obj.aircraftAssigned, 6)
  
  --planes deleted from sqn
  lu.assertEquals(sqn:getCounter(), 4)
  
  --total planes sum is 6
  lu.assertEquals(self:getSumInContainers(inst), 6)
  
  --counter incremented
  lu.assertEquals(inst.airborneCount, 2)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_createMultiplyGroups() 
  --trying to request more planes then 2 max group capacity(4)
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.aircraftCounter = 10
  local obj = self:getObj()
  
  inst:createNewGroupsFromSqn(sqn, obj, 10)
  --should have 3 containers with 4, 4, 2 planes
  lu.assertNotEquals(inst.deferredGroups, {})
  
  --added all planes from sqn
  lu.assertEquals(obj.aircraftAssigned, 10)
  
  --planes deleted from sqn
  lu.assertEquals(sqn:getCounter(), 0)
  
  --total planes sum is 10
  lu.assertEquals(self:getSumInContainers(inst), 10)
  
  --counter incremented
  lu.assertEquals(inst.airborneCount, 3)
end

function test_GciCapHandler:test_createNewGroupsFromSqn_airborneLimit() 
  --trying to request multiply groups, sqn can gve it, but has limit only for 1
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  inst.airborneGroupLimit = 4
  inst.airborneCount = 3
  
  inst:createNewGroupsFromSqn(sqn, obj, 10)
  --should have 1 container with 4
  lu.assertNotEquals(inst.deferredGroups, {})
  
   --total planes sum is 4
  lu.assertEquals(self:getSumInContainers(inst), 4)
end

function test_GciCapHandler:test_spawnAircraftsForObjective_BelowMinSize() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  --try request below minimum group size nothing created
  inst:spawnAircraftsForObjective(obj, 1)
  lu.assertEquals(inst.deferredGroups, {})
end

function test_GciCapHandler:test_spawnAircraftsForObjective_spawnFromReady() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  --first sqn has enough arcrafts in total, but not enough ready
  local sqn = self:getSqn(inst)
  sqn.getPoint = function() return {x = 0, y = 0, z = 0} end
  sqn.readyCounter = 0
  sqn.readyAircraft = 10
  
  --second sqn, more far then first, but has enough ready aircraft
  local sqn2 = self:getSqn(inst)
  sqn2.getPoint = function() return {x = 999, y = 0, z = 0} end
  sqn2.readyCounter = 10
  sqn2.readyAircraft = 10
  
  --low on planes, not used
  local sqn3 = self:getSqn(inst)
  sqn3.getPoint = function() return {x = 9999, y = 0, z = 0} end
  sqn3.readyCounter = 1
  sqn3.readyAircraft = 1
  
  local obj = self:getObj()
  
  inst:addSquadron(sqn)
  inst:addSquadron(sqn2)
  inst:addSquadron(sqn3)
  inst:addObjective(obj)

  --verify sqn2 is second on obj arr
  lu.assertEquals(obj.squadrons[2].squadron, sqn2)
  
  --should spawn 2 container with 6 planes total from second sqn
  inst:spawnAircraftsForObjective(obj, 6, true)
  lu.assertEquals(self:getSumInContainers(inst), 6)
  lu.assertEquals(obj.aircraftAssigned, 6)
  
  --take 6 planes from sqn2
  lu.assertEquals(sqn2:getCounter(), 4)
  lu.assertEquals(sqn2:getReadyCount(), 4)
  
  --first sqn not affected
  lu.assertEquals(sqn:getCounter(), 10)
end 

function test_GciCapHandler:test_spawnAircraftsForObjective_spawnFromMultiplySqn_hitMinSize() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.getPoint = function() return {x = 0, y = 0, z = 0} end
  sqn.aircraftCounter = 4
  
  local sqn2 = self:getSqn(inst)
  sqn2.getPoint = function() return {x = 999, y = 0, z = 0} end
  
  local obj = self:getObj()
  
  inst:addSquadron(sqn)
  inst:addSquadron(sqn2)
  inst:addObjective(obj)
  
  --try request 5 planes, spawn 4 from first, then exit cause below min size
  inst:spawnAircraftsForObjective(obj, 5)
  lu.assertEquals(self:getSumInContainers(inst), 4)
  lu.assertEquals(obj.aircraftAssigned, 4)
  
  --take 4 planes from sqn1
  lu.assertEquals(sqn:getCounter(), 0)
  lu.assertEquals(sqn:getReadyCount(), 0)
  
end

function test_GciCapHandler:test_spawnAircraftsForObjective_spawnFromMultiplySqn_hitMinSizeMultGroups() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  sqn.getPoint = function() return {x = 0, y = 0, z = 0} end
  sqn.aircraftCounter = 2
  
  local sqn2 = self:getSqn(inst)
  sqn2.getPoint = function() return {x = 999, y = 0, z = 0} end
  
  local obj = self:getObj()
  
  inst:addSquadron(sqn)
  inst:addSquadron(sqn2)
  inst:addObjective(obj)
  
  --try request 5 planes, spawn 2 from first(total amount), 3 from second
  inst:spawnAircraftsForObjective(obj, 5)
  lu.assertEquals(self:getSumInContainers(inst), 5)
  lu.assertEquals(obj.aircraftAssigned, 5)
end

function test_GciCapHandler:test_spawnAircraftsForObjective_spawnEven() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  inst:setForceEvenGroup(true)
  
  local sqn = self:getSqn(inst)
  sqn.getPoint = function() return {x = 0, y = 0, z = 0} end
  sqn.aircraftCounter = 2
  
  local sqn2 = self:getSqn(inst)
  sqn2.getPoint = function() return {x = 999, y = 0, z = 0} end
  
  local obj = self:getObj()
  
  inst:addSquadron(sqn)
  inst:addSquadron(sqn2)
  inst:addObjective(obj)
  
  --try request 5 planes, spawn 2 from first(total amount), 2 from second
  inst:spawnAircraftsForObjective(obj, 5)
  lu.assertEquals(self:getSumInContainers(inst), 4)
  lu.assertEquals(obj.aircraftAssigned, 4)
    
  --try request 5 planes, spawn 4 from first
  sqn.aircraftCounter = 10
  sqn2.aircraftCounter = 10
  obj.aircraftAssigned = 0
  inst.airborneCount = 0
  inst.deferredGroups = {}
  
  inst:spawnAircraftsForObjective(obj, 4)
  lu.assertEquals(self:getSumInContainers(inst), 4)
  lu.assertEquals(obj.aircraftAssigned, 4)
  lu.assertEquals(sqn:getCounter(), 6)
  lu.assertEquals(sqn2:getCounter(), 10)

  --try request 9 planes, 
  --spawn 2 planes from first(total amount)
  --spawn 2 groups 4 + 2 from second
  sqn.aircraftCounter = 2
  sqn2.aircraftCounter = 10
  obj.aircraftAssigned = 0
  inst.airborneCount = 0
  inst.deferredGroups = {}

  inst:spawnAircraftsForObjective(obj, 9)
  lu.assertEquals(self:getSumInContainers(inst), 8)
  lu.assertEquals(obj.aircraftAssigned, 8)
  lu.assertEquals(sqn:getCounter(), 0)
  lu.assertEquals(sqn2:getCounter(), 4)
end

function test_GciCapHandler:test_getGroupsForRetask_excludeNotReady_andFar() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local obj = self:getObj()
  
  --cant't retask
  local group1 = getCapGroup()
  group1.canRetask = function() return false end 
  --can retask but too far
  local group2 = getCapGroup()
  group2.canRetask = function() return true end
  group2.getPoint = function() return {x = 300 * 710, y = 0, z = 0} end --710 sec to go
  
  inst.groups[group1:getID()] = group1
  inst.groups[group2:getID()] = group2
  
  --should return empty
  lu.assertEquals(inst:getGroupsForRetask(obj), {})
end

function test_GciCapHandler:test_getGroupsForRetask_verifySorted() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local obj = self:getObj()
  
  local group1 = getCapGroup()
  group1.canRetask = function() return true end
  group1.getPoint = function() return {x = 300 * 550, y = 0, z = 0} end --550 sec to go(number 3)

  local group2 = getCapGroup()
  group2.canRetask = group1.canRetask
  group2.getPoint = function() return {x = 300 * 100, y = 0, z = 0} end --100 sec to go(number 1)
  
  local group3 = getCapGroup()
  group3.canRetask = group1.canRetask
  group3.getPoint = function() return {x = 300 * 300, y = 0, z = 0} end --300 sec to go(number 2)
  
  inst.groups[group1:getID()] = group1
  inst.groups[group2:getID()] = group2
  inst.groups[group3:getID()] = group3
  
  --should return empty
  lu.assertEquals(inst:getGroupsForRetask(obj), {group2, group3, group1})
end

function test_GciCapHandler:test_addGciForObjective_retaskAndSpawn() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  inst:addSquadron(sqn)
  local obj = self:getObj()
  inst:addObjective(obj)
  
  local group1 = self:getGroup(sqn, obj)
  group1.canRetask = function() return true end
  group1.getPoint = function() return { x = 0, y = 0, z = 0} end 
  group1.originalSize = 2
  inst.groups[group1:getID()] = group1
  obj:addCapPlanes(2)--group assigned
  inst.airborneCount = 1
  
  local obj2 = self:getObj()
  obj2.getPoint = function() return { x = 300 * 100, y = 0, z = 0} end --100 sec from group
  inst:addObjective(obj2)
  
  --request 4 planes, can retask group with 2, retask and spawn another with 2 planes
  inst:addGciForObjective(obj2, 4)
  --counter increased
  lu.assertEquals(inst.airborneCount, 2)
  --sum planes in avaited group is 2
  lu.assertEquals(self:getSumInContainers(inst), 2)
  
  --first objective now without planes
  lu.assertEquals(obj.aircraftAssigned, 0)
  
  --second objective has 4 planes
  lu.assertEquals(obj2.aircraftAssigned, 4)
  
  --group retasked
  lu.assertEquals(group1.objective, obj2)
end


function test_GciCapHandler:test_addGciForObjective_retaskOnly() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  inst:addSquadron(sqn)
  local obj = self:getObj()
  inst:addObjective(obj)
  
  local group1 = self:getGroup(sqn, obj)
  group1.canRetask = function() return true end
  group1.getPoint = function() return { x = 0, y = 0, z = 0} end 
  group1.originalSize = 2
  inst.groups[group1:getID()] = group1
  obj:addCapPlanes(2)--group assigned
  inst.airborneCount = 1
  
  local obj2 = self:getObj()
  obj2.getPoint = function() return { x = 300 * 100, y = 0, z = 0} end --100 sec from group
  inst:addObjective(obj2)
  
  --request 2 planes, can retask group with 2, no spawn
  inst:addGciForObjective(obj2, 2)
  
    --sum planes in avaited group is 2
  lu.assertEquals(self:getSumInContainers(inst), 0)
  
  --first objective now without planes
  lu.assertEquals(obj.aircraftAssigned, 0)
  
  --second objective has 2 planes
  lu.assertEquals(obj2.aircraftAssigned, 2)
end

function test_GciCapHandler:test_addGciForObjective_noRetaskNoLimit() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  inst.airborneCount = 4
  local sqn = self:getSqn(inst)
  inst:addSquadron(sqn)
  local obj = self:getObj()
  inst:addObjective(obj)
  
  local obj2 = self:getObj()
  obj2.getPoint = function() return { x = 300 * 100, y = 0, z = 0} end --100 sec from group
  inst:addObjective(obj2)
  
  --request 2 planes, no groups for retask, limit is full, nothing
  inst:addGciForObjective(obj2, 2)
  
  --sum planes in avaited group is 2
  lu.assertEquals(self:getSumInContainers(inst), 0)
  
  --second objective has 0 planes
  lu.assertEquals(obj2.aircraftAssigned, 0)
end


function test_GciCapHandler:test_addGciForObjective_retaskHitMinSize() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  inst:addSquadron(sqn)
  local obj = self:getObj()
  inst:addObjective(obj)
  
  local group1 = self:getGroup(sqn, obj)
  group1.canRetask = function() return true end
  group1.getPoint = function() return { x = 0, y = 0, z = 0} end 
  group1.originalSize = 2
  inst.groups[group1:getID()] = group1
  obj:addCapPlanes(2)--group assigned
  
  local group2 = self:getGroup(sqn, obj)
  group2.canRetask = function() return true end
  group2.getPoint = function() return { x = 0, y = 0, z = 0} end 
  group2.originalSize = 2
  inst.groups[group2:getID()] = group2
  inst.airborneCount = 2
  
  local obj2 = self:getObj()
  obj2.getPoint = function() return { x = 300 * 100, y = 0, z = 0} end --100 sec from group
  inst:addObjective(obj2)
  
  --request 3 planes, retask first group, no retask/spawn cause min group size will above remaining
  inst:addGciForObjective(obj2, 3)
  
  --sum planes in avaited group is 0
  lu.assertEquals(self:getSumInContainers(inst), 0)
  
  --second objective has 2 planes
  lu.assertEquals(obj2.aircraftAssigned, 2)
end


function test_GciCapHandler:test_addGciForObjective_verifySpawnReady() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  
  local result = AirContainer:create(sqn, obj, 2, 33)
  local m = mockagne.getMock()
  sqn.getReadyGroup = m.getReadyGroup
  when(sqn:getReadyGroup(any(), any())).thenAnswer(result)

  inst:addSquadron(sqn)
  inst:addObjective(obj)
  
  inst:addGciForObjective(obj, 2)
  --no group to retask, should spawn new, verify will try get ready aircraft
  verify(sqn:getReadyGroup(any(), any()))
end

function test_GciCapHandler:test_checkCap_verifyNotReady() 
  local inst = GciCapHandler:create(GciCapHandler.coalition.RED)
  local sqn = self:getSqn(inst)
  local obj = self:getObj()
  obj:setPriority(CapObjective.Priority.Normal)
  obj:setRequestCap(true)
  
  local result = AirContainer:create(sqn, self:getObj(), 2, 33)
  local m = mockagne.getMock()
  sqn.getReadyGroup = m.getReadyGroup
  sqn.getGroup = m.getGroup
  when(sqn:getGroup(any(), any())).thenAnswer(result)

  inst:addSquadron(sqn)
  inst:addObjective(obj)
  
  --check capRequest for all objectives, should add group for obj
  --verify will request non ready version
  inst:checkCap()
  verify(sqn:getGroup(any(), any()))
end

local runner = lu.LuaUnit.new()
--runner:setOutputType("tap")
runner:runSuite()