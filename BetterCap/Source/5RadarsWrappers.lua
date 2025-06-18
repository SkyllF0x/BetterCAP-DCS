----------------------------------------------------
-- Abstract Wrapper around radar object for detection
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----------------------------------------------------
AbstractRadarWrapper = utils.inheritFrom(DCS_Wrapper)

function AbstractRadarWrapper:getDetectedTargets() 
end

----------------------------------------------------
-- End of AbstractRadarWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around radar object for detection
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----                  ↓
----             RadarWrapper
----------------------------------------------------
RadarWrapper = utils.inheritFrom(AbstractRadarWrapper)

function RadarWrapper:create(dcsObject) 
  local instance = self:super():create(dcsObject)
  
  instance.detectionRange = 0
  --find detection range in desc table, if can't find leave 0 so it won't affect on go autonomous
  for _, sensor in pairs(dcsObject:getSensors()[1]) do 
    --type 1 for radar, take mean from all 4
    --table for reference: https://wiki.hoggitworld.com/view/DCS_func_getSensors
     if sensor["type"] == 1 then
        instance.detectionRange = (sensor.detectionDistanceAir.upperHemisphere.tailOn + sensor.detectionDistanceAir.upperHemisphere.headOn
          + sensor.detectionDistanceAir.lowerHemisphere.tailOn + sensor.detectionDistanceAir.lowerHemisphere.headOn)/4
        break
      end
  end
  
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function RadarWrapper:getDetectedTargets() 
  --return all detected targets by Radar/Optic/RWR(assume ELINT) wrapped in target Container
  --detection table https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
  local result = {}
  
  for _, contact in pairs(self:getController():getDetectedTargets(1, 2, 4, 16)) do 
      
      local _res, _err = xpcall(function ()
        
        if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") then
            result[#result+1] = TargetContainer:create(contact, self)
          end
      end, --VISUAL/OPTIC/RADAR/RWR
      debug.traceback)
    if not _res then 
      GlobalLogger:create():warning("RadarWrapper: Error when contack processing" .. mist.utils.serialize("\n traceback", _err))
    end
  end
  return result
end

--return true if point inside detection range
function RadarWrapper:inZone(point) 
  return mist.utils.get3DDist(self:getPoint(), point) < self.detectionRange
  end
----------------------------------------------------
-- end of RadarWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around radar object for detection
-- return only targets which 'can' be detected using 
-- line-of-sight and distance checks
-- for now(12.12.2023) if DCS_controller detect unit,
-- it will return it until detected Unit dies
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractRadarWrapper
----                  ↓
----             RadarWrapper
----                  ↓
----         RadarWrapperWithChecks
----------------------------------------------------
RadarWrapperWithChecks = utils.inheritFrom(RadarWrapper)

function RadarWrapperWithChecks:getDetectedTargets() 
  --return all detected targets by Radar/Optic/RWR(assume ELINT) wrapped in target Container
  --detection table https://wiki.hoggitworld.com/view/DCS_func_getDetectedTargets
  local result = {}
  local ourPos = self:getPoint()
  
  for _, contact in pairs(self:getController():getDetectedTargets(1, 2, 4, 16)) do  
      
    local _res,_err = xpcall(function ()
      --this will add target only if it has clear LOS and distance < self.detectionRange * 1.5
      if contact.object and contact.object:isExist() and contact.object:hasAttribute("Air") 
        and land.isVisible(contact.object:getPoint(), ourPos) --CHECK LOS
        and mist.utils.get3DDist(contact.object:getPoint(), ourPos) < self.detectionRange * 1.5 then --check range
          result[#result+1] = TargetContainer:create(contact, self)
      end
    end, 
    debug.traceback)

    if not _res then 
      GlobalLogger:create():warning("RadarWrapperWithChecks: Error when contack processing" .. mist.utils.serialize("\n traceback", _err))
    end
  end
    return result
end