env = require "DCS_Stubs\\Source\\Singletons\\env_stub"
world = require "DCS_Stubs\\Source\\Singletons\\world_stub"
timer = require "DCS_Stubs\\Source\\Singletons\\timer_stub"
trigger = require "DCS_Stubs\\Source\\Singletons\\trigger_stub"
land = require "DCS_Stubs\\Source\\Singletons\\land_stub"
coalition = require "DCS_Stubs\\Source\\Singletons\\coalition_enums"
dofile(".\\DCS_Stubs\\Source\\Classes\\DCS_Object.lua")

dofile(".\\3rdParty\\mist_4_5_126.lua")
lu = require "3rdParty\\luaunit_3_4\\luaunit"
mockagne = require "3rdParty\\mockagne"

dofile(".\\BetterCap\\BetterCap_Compiled.lua")

when = mockagne.when
verify = mockagne.verify
verify_no_call = mockagne.verify_no_call
any = mockagne.any

function countElements(tbl)
  local counter = 0
  
  for _, elem in pairs(tbl) do 
    counter = counter + 1
  end
  return counter
  end

--for passing in event
function getMissileForWrapper(target)
  local w, m = Weapon:create(), mockagne.getMock()
  
  w.getTarget = m.getTarget
  w.getDesc = m.getDesc 
  when(m.getTarget(w)).thenAnswer(target)
  when(m.getDesc(w)).thenAnswer({guidance = 2})
  
  return w
end

function getMissileWrapper()
  local w, m = Weapon:create(), mockagne.getMock()
  
  w.getTarget = m.getTarget
  w.getDesc = m.getDesc 
  when(m.getTarget(w)).thenAnswer(Unit:create())
  when(m.getDesc(w)).thenAnswer({guidance = 2})
  
  return MissileWrapper:create(w), w, m
end

function getMockedController() 
  local m = mockagne.getMock()
  local controllerMock = Controller:create()
  controllerMock.name = "MockedCONTR"
  controllerMock.setTask = m.setTask
  controllerMock.pushTask = m.pushTask
  controllerMock.popTask = m.popTask
  controllerMock.hasTask = m.hasTask
  controllerMock.setOption = m.setOption
  controllerMock.setCommand = m.setCommand
  controllerMock.setTask = m.setTask
  
  return controllerMock, m
end

function getCapPlane() 
  local m = mockagne.getMock()
  
  local unit = Unit:create()
  local group = Group:create()
  
  local controllerMock = Controller:create()
  
  group.getUnit = function() return unit end
  group.getUnits = function() return {unit} end
  
  group.getController = function() return controllerMock end
  
  local plane = CapPlane:create(group)
  --in tests mist return nil
  plane.spawnInAir = true
  plane.getAoA = function() return 0 end
  
  return plane, group, unit, m, controllerMock
end


function getElement() 
  local plane, group, unit, m, cont = getCapPlane()
  
  return CapElement:create({plane}), plane, group, unit, m, cont
  end

function getTargetContainer() 
  local tgt, radar = Unit:create(), Unit:create()
  
  local idTGT, idRDR = utils.getGeneralID(), utils.getGeneralID()
  tgt.getID = function() return idTGT end
  radar.getID = function() return idRDR end
  
  return TargetContainer:create({object = tgt, visible = false, type = false, distance = false}, radar)
  end

function getTarget() 
  local tgt, radar = Unit:create(), Unit:create()
  
  local inst = Target:create(TargetContainer:create({object = tgt, visible = false, type = false, distance = false}, radar))
  local id = utils.getGeneralID()
  inst.getID = function() return id end
  
  return inst, tgt, radar
end

function getTargetGroup() 
  local target1 = getTarget()
  local target2 = getTarget()
  
  local ID1, ID2 = utils.getUnitID(), utils.getUnitID()
  
  --mock getID
  target1.getID = function() return ID1 end
  target2.getID = function() return ID2 end
  target1.getPoint = function() return {x = 0, y = 0, z = 0} end
  target2.getPoint = target1.getPoint
  
  local inst = TargetGroup:create({target1, target2})
  
  local id = utils.getGeneralID()
  inst.getID = function() return id end
  
  return inst, target1, target2--no groupRange specified, should be default 30000
end


function getRadar() 
  local unit, m = Unit:create(), mockagne.getMock()
  
  unit.getSensors = m.getSensors
  when(m.getSensors(any())).thenAnswer({
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
  })

  local rdr = RadarWrapper:create(unit)
  local id = utils.getGeneralID()
  rdr.getID = function() return id end
  
  return rdr
end


function getCapGroup()
  local plane = getCapPlane()
  
  local group = CapGroup:create({plane})
  group:update()
  return group, plane
end

--stack run() overriden, no call to newly set FSMs
function getCapGroupNoRun()
  local group, plane = getCapGroup()
  group.FSM_stack.run = function() end
  return group
end

function getAirbaseMock() 
  local m = mockagne.getMock('airbase')
  m.afb_id = utils.getGeneralID()
  m.afbName = "airbase " .. tostring(m.sqn_id)
  
  when(m:getID()).thenAnswer(m.afb_id)
  when(m:getName()).thenAnswer(m.afbName)
  when(m:getPoint()).thenAnswer({x = 0, y = 0, z = 0})
  when(m:getParking()).thenAnswer({
    ["Term_Index"] = 56,
    ["vTerminalPos"] = {x = 0, y = 0, z = 0}, 
    ["TO_AC"] = false,
    ["Term_Index_0"] = -1,
    ["Term_Type"] = 68,
    ["fDistToRW"] = 451.77697753906,
  })
  when(m:isAvail()).thenAnswer(true)
  when(m:howManyParkingAvail()).thenAnswer(99)
  
  return m
end

function getCapSquadronMock() 
  local m = mockagne.getMock('squadron')
  m.alt = 7500
  m.alt_type = "BARO"
  m.speed = 230

  m.sqn_id = utils.getGeneralID()
  m.sqnName = "squadron " .. tostring(m.sqn_id)
  m.home = getAirbaseMock()
  m.homeWP = mist.fixedWing.buildWP({x = 0, y = 0})
  m.obj = getCapObjectiveMock() 
  
  when(m:getID()).thenAnswer(m.sqn_id)
  when(m:getName()).thenAnswer(m.sqnName)
  when(m:getPoint()).thenAnswer({x = 0, y = 0, z = 0})
  when(m:getHomeWP()).thenAnswer(m.homeWP)
  when(m:getCombatRadius()).thenAnswer(200000)
  when(m:getReadyCount()).thenAnswer(2)
  when(m:getCounter()).thenAnswer(10)
  when(m:getCountry()).thenAnswer(1)
  when(m:getAirbase()).thenAnswer(m.home)
  when(m:getObjective()).thenAnswer(m.obj)
  when(m:getPriorityModifier()).thenAnswer(1)

  return m
end


function getCapObjectiveMock() 
  local m = mockagne.getMock('objective')
  m.zone = CircleZone:create({x = 0, y = 0}, 100000)
  m.obj_id = utils.getGeneralID()
  m.objName = "objective " .. tostring(m.sqn_id)
  
  when(m:getID()).thenAnswer(m.obj_id)
  when(m:getName()).thenAnswer(m.objName)
  when(m:getPoint()).thenAnswer({x = 0, y = 0, z = 0})
  when(m:getGciZone()).thenAnswer(m.zone)
  when(m:getCapRequest()).thenAnswer(2)
  when(m:getGciRequest()).thenAnswer(2)

  return m
end


AbstractMocksForSqn = {}
AbstractMocksForSqn.groupVal = Group:create()--this will return by coalition.addGroup
AbstractMocksForSqn.unit = Unit:create()
AbstractMocksForSqn.groupVal.getUnit = function() return AbstractMocksForSqn.unit end
AbstractMocksForSqn.unit.getGroup = function() return AbstractMocksForSqn.groupVal end

AbstractMocksForSqn.groupTable = {
  name = "group",
  task = "CAP",
  units = {
    {
      name = "1",
      type = "abstract unit",
      x = 0, 
      y = 0,
      alt = 0,
      speed = 0,
      alt_type = "BARO",
      payload = {},
      }
    },
  route = {
    points = {
      [1] = {
        x = 0, 
        y = 0,
        alt = 0,
        alt_type = "BARO",
        action = "Turning Point",
        type = "Turning Point",
      },
      [2] = {
        x = 10, 
        y = 10,
        alt = 10,
        alt_type = "BARO",
        action = "Turning Point",
        type = "Turning Point",
        },
      }
    }
  }

AbstractMocksForSqn.originalAddGroup = coalition.addGroup
AbstractMocksForSqn.originalGetGroupTable = mist.getGroupTable
AbstractMocksForSqn.originalTimer = timer.getAbsTime


function AbstractMocksForSqn:setup() 
  coalition.addGroup = function() return self.groupVal end
  mist.getGroupTable = function() return self.groupTable end
end

function AbstractMocksForSqn:teardown() 
  coalition.addGroup = AbstractMocksForSqn.originalAddGroup
  mist.getGroupTable = AbstractMocksForSqn.originalGetGroupTable
  
  timer.getAbsTime = AbstractMocksForSqn.originalTimer
end