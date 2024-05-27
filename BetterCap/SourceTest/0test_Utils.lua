dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")


test_Utils = {}

function test_Utils:teardown() 
  utils.generalID = 0 --used for internal purposes(i.e. zone ID or detector handler)
  utils.unitID = 0   -- for DCS UNIT
  utils.groupID = 0 --for DCS GROUP

  utils.defaultMissile = utils.WeaponTypes['P_27R']
  utils.defaultPlane = {Missile = utils.defaultMissile, RadarRange = 1000}
  end

function test_Utils:test_getID() 
  local generalID, unitID, groupID = utils.getGeneralID(), utils.getUnitID(), utils.getGroupID()
  lu.assertIsNumber(generalID)
  lu.assertIsNumber(unitID)
  lu.assertIsNumber(groupID)
  
  --check for autoincrement
  lu.assertEquals(utils.getGeneralID() - 1, 1)
  lu.assertEquals(utils.getUnitID() - 1, 1)
  lu.assertEquals(utils.getGroupID() - 1, 1)
end 


function test_Utils.test_compareTables() 
  local obj1, obj2 = Unit:create(), Unit:create()
  local objMock = mockagne.getMock()
  
  obj1.getID, obj2.getID = objMock.getID, objMock.getID
  
  when(objMock.getID(obj1)).thenAnswer(1)
  when(objMock.getID(obj2)).thenAnswer(1)
  
  lu.assertEquals(utils.compareTables(obj1, obj2), true)
  verify(objMock.getID(obj1))
  verify(objMock.getID(obj2))
end


function test_Utils.test_itemInTable_noItem() 
  local tbl = {1, 2, 3}
  
  lu.assertEquals(utils.itemInTable(tbl, nil), false)
end


function test_Utils.test_itemInTable_sameTypes() 
  local tbl = {1, 2, 3}
  
  lu.assertEquals(utils.itemInTable(tbl, 1), true)
  lu.assertEquals(utils.itemInTable(tbl, 5), false)
end


function test_Utils.test_itemInTable_diffTypes() 
  local tbl = {1, 2, 3}
  
  lu.assertEquals(utils.itemInTable(tbl, "1"), true)
  lu.assertEquals(utils.itemInTable(tbl, "5"), false)
end


function test_Utils.test_concatTables_oneEmpty() 
  local tbl1, tbl2 = {}, {1, 2}
  
  lu.assertEquals(utils.concatTables(tbl1, tbl2), {1, 2})
  lu.assertEquals(utils.concatTables(tbl2, tbl1), {1, 2})
end

function test_Utils.test_concatTables() 
  local tbl1, tbl2 = {3, 4}, {1, 2}
  
  lu.assertEquals(utils.concatTables(tbl1, tbl2), {3, 4, 1, 2})
  lu.assertEquals(utils.concatTables(tbl2, tbl1), {1, 2, 3, 4})
end

function test_Utils.test_removeFrom_noItem() 
  local tbl1 = {3, 4}
  
  lu.assertEquals(utils.removeFrom(tbl1, nil), tbl1)
  lu.assertEquals(utils.removeFrom(tbl1, 1), tbl1)
end

function test_Utils.test_removeFrom() 
  local unit = Unit:create()
  local tbl1 = {3, 4, unit}
  
  lu.assertEquals(utils.removeFrom(tbl1, 3), {4, unit})
  lu.assertEquals(utils.removeFrom( {4, unit}, unit), {4})
  lu.assertEquals(utils.removeFrom( {4}, 4), {})
  lu.assertEquals(utils.removeFrom( {}, 4), {})
end

function test_Utils.test_distance2Line_pointInside() 
  local segment = {{x = 0, y = 0}, {x = 10, y = 0}}
  local point1, point2 = {x = 5, y = 5}, {x = 5, y = 0}
  
  lu.assertEquals(utils.distance2Line(segment, point1), 5)
  lu.assertEquals(utils.distance2Line(segment, point2), 0)
end

function test_Utils.test_distance2Line_HorizontalAndVerticalLines() 
  local segment1 = {{x = -5, y = 5}, {x = 5, y = 5}}--horizontal 
  local segment2 = {{x = 5, y = 5}, {x = 5, y = -5}}--vertical
  local point1 = {x = 0, y = 0}
  
  lu.assertEquals(utils.distance2Line(segment1, point1), 5)
  lu.assertEquals(utils.distance2Line(segment2, point1), 5)
end

--should return distance to closest segment point
function test_Utils.test_distance2Line_pointOutside() 
  local segment = {{x = 0, y = 0}, {x = 10, y = 0}}
  local point1 = {x = 20, y = 0}
  
  lu.assertEquals(utils.distance2Line(segment, point1), 10)
end

function test_Utils.test_round() 
  
  lu.assertEquals(utils.round(1.22222), 1)
  lu.assertEquals(utils.round(1.22222, 3), 1.222)
  lu.assertEquals(utils.round(1.22299, 3), 1.223)
  end

function test_Utils.test_getItemsByPrefix_noFind() 
  local tbl = {}
  
  lu.assertEquals(utils.getItemsByPrefix(tbl, "prefix"), {})
  
  local mock = mockagne.getMock()
  
  for i = 1, 3 do 
    tbl[i] = Unit:create()
    tbl[i].getName = mock.getName
    
    when(mock.getName(tbl[i])).thenAnswer("prefix-"..tostring(i))
  end
  
  lu.assertEquals(utils.getItemsByPrefix(tbl, "name"), {})
end

function test_Utils.test_getItemsByPrefix() 
  local tbl, m = {}, mockagne.getMock()
  
  for i = 1, 3 do 
    tbl[i] = Object:create()
    tbl[i].getName = m.getName
    
    if i ~= 1 then 
      when(m.getName(tbl[i])).thenAnswer("prefix-" .. tostring(i))
    else
      when(m.getName(tbl[i])).thenAnswer("name")
    end 
  end
  
  lu.assertEquals(#utils.getItemsByPrefix(tbl, "prefix"), 2)
end

function test_Utils:test_chainContainer() 
  local group1 = getCapGroup()
  local group2 = getCapGroup()
  
  local m = mockagne.getMock()
  group1.setALR = m.setALR
  group1.setBingo = m.setBingo
  group2.setALR = m.setALR
  group2.setBingo = m.setBingo

  local cont = utils.chainContainer:create({group1, group2}) 
  cont:setALR(CapGroup.ALR.High):setBingo(5)
  verify(group1:setALR(CapGroup.ALR.High))
  verify(group1:setBingo(5))
  verify(group2:setALR(CapGroup.ALR.High))
  verify(group2:setBingo(5))
end


function test_Utils:test_defaultSetters()
  local missile = {MaxRange = 9999, MAR = 9999}
  local plane = {Missile = missile, RadarRange = 10000}
  
  utils.setDefaultMissile(missile)
  lu.assertEquals(utils.WeaponTypes['default'], missile)
  
  utils.setDefaultPlane(plane)
  lu.assertEquals(utils.PlanesTypes['default'], plane)
  
  --verify metatable works
  lu.assertEquals(utils.WeaponTypes["unknown missile"], missile)
  lu.assertEquals(utils.PlanesTypes["unknown plane"], plane)
end

local runner = lu.LuaUnit.new()
runner:runSuite()