local world = {}
world.event = {
  S_EVENT_INVALID = 0,
  S_EVENT_SHOT = 1,
  S_EVENT_HIT = 2,
  S_EVENT_TAKEOFF = 3,
  S_EVENT_LAND = 4,
  S_EVENT_CRASH = 5,
  S_EVENT_EJECTION = 6,
  S_EVENT_REFUELING = 7,
  S_EVENT_DEAD = 8,
  S_EVENT_PILOT_DEAD = 9,
  S_EVENT_BASE_CAPTURED = 10,
  S_EVENT_MISSION_START = 11,
  S_EVENT_MISSION_END = 12,
  S_EVENT_TOOK_CONTROL = 13,
  S_EVENT_REFUELING_STOP = 14,
  S_EVENT_BIRTH = 15,
  S_EVENT_HUMAN_FAILURE = 16,
  S_EVENT_DETAILED_FAILURE = 17,
  S_EVENT_ENGINE_STARTUP = 18,
  S_EVENT_ENGINE_SHUTDOWN = 19,
  S_EVENT_PLAYER_ENTER_UNIT = 20,
  S_EVENT_PLAYER_LEAVE_UNIT = 21,
  S_EVENT_PLAYER_COMMENT = 22,
  S_EVENT_SHOOTING_START = 23,
  S_EVENT_SHOOTING_END = 24,
  S_EVENT_MARK_ADDED  = 25, 
  S_EVENT_MARK_CHANGE = 26,
  S_EVENT_MARK_REMOVED = 27,
  S_EVENT_KILL = 28,
  S_EVENT_SCORE = 29,
  S_EVENT_UNIT_LOST = 30,
  S_EVENT_LANDING_AFTER_EJECTION = 31,
  S_EVENT_PARATROOPER_LENDING = 32,
  S_EVENT_DISCARD_CHAIR_AFTER_EJECTION = 33, 
  S_EVENT_WEAPON_ADD = 34,
  S_EVENT_TRIGGER_ZONE = 35,
  S_EVENT_LANDING_QUALITY_MARK = 36,
  S_EVENT_BDA = 37, 
  S_EVENT_AI_ABORT_MISSION = 38, 
  S_EVENT_DAYNIGHT = 39, 
  S_EVENT_FLIGHT_TIME = 40, 
  S_EVENT_PLAYER_SELF_KILL_PILOT = 41, 
  S_EVENT_PLAYER_CAPTURE_AIRFIELD = 42, 
  S_EVENT_EMERGENCY_LANDING = 43,
  S_EVENT_UNIT_CREATE_TASK = 44,
  S_EVENT_UNIT_DELETE_TASK = 45,
  S_EVENT_SIMULATION_START = 46,
  S_EVENT_WEAPON_REARM = 47,
  S_EVENT_WEAPON_DROP = 48,
  S_EVENT_UNIT_TASK_TIMEOUT = 49,
  S_EVENT_UNIT_TASK_STAGE = 50,
  S_EVENT_MAC_SUBTASK_SCORE = 51, 
  S_EVENT_MAC_EXTRA_SCORE = 52,
  S_EVENT_MISSION_RESTART = 53,
  S_EVENT_MISSION_WINNER = 54, 
  S_EVENT_POSTPONED_TAKEOFF = 55, 
  S_EVENT_POSTPONED_LAND = 56, 
  S_EVENT_MAX = 57,
}



world.BirthPlace = {
  "wsBirthPlace_Air",
  "wsBirthPlace_RunWay",
  "wsBirthPlace_Park",
  "wsBirthPlace_Heliport_Hot",
  "wsBirthPlace_Heliport_Cold",
}

world.VolumeType = {
  "SEGMENT",
  "BOX",
  "SPHERE",
  "PYRAMID"
}

--create instance for mocking
function world:create()
  return setmetatable({}, {__index = self})
end

function world.addEventHandler(handler) 
  
end

function world.removeEventHandler(handler) 
  
end

function world.getPlayer() 
  return {}
end

---@param coalitionId? number
function world.getAirbases(coalitionId) 
  return {}
end

function world.searchObjects(objectCat, volume, handler, data) 
  return {}
end

function world.getMarkPanels() 
  return {}
end

function world.eventremoveJunk(searchVolume )
  return 0
  end
return world