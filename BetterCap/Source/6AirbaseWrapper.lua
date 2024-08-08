----------------------------------------------------
-- Wrapper around airbase
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----------------------------------------------------
AbstractAirbaseWrapper = utils.inheritFrom(DCS_Wrapper)

function AbstractAirbaseWrapper:getParking() 
  
end

--return true if it still usable, so atleas you can get parkings in future
--return false if airbase totally not usable(i.e. captured or destroyed)
function AbstractAirbaseWrapper:isAvail() 
  
end

--how many parking avail()
function AbstractAirbaseWrapper:howManyParkingAvail() 
  return 0
end

----------------------------------------------------
-- end of AbstractAirbaseWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around airbase
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----                  ↓
----            AirbaseWrapper
----------------------------------------------------
AirbaseWrapper = utils.inheritFrom(AbstractAirbaseWrapper)
AirbaseWrapper._instances = {}

function AirbaseWrapper:create(id) 
  
  local key = tostring(id)
  if self._instances[key] then 
    return self._instances[key]
  end
  
  local instance = nil
  
 --find airbase by id
  for _, airbase in pairs(world.getAirbases(nil)) do 
    if airbase:getID() == id then
      instance = self:super():create(airbase)
      break
    end
  end
  
  --check if we find something
  if not instance then 
    GlobalLogger:create():warning("WARNING: AirbaseWrapper CANT FIND AIRBASE WITH ID: " .. tostring(id))
    return
  end
  --save original coalition, cause airfield can be captured
  instance.originalCoalition = instance.dcsObject:getCoalition()
  
  self._instances[key] = instance
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
end

function AirbaseWrapper:getParking()
  --if airbase was captured, return nil
  if self.dcsObject:getCoalition() ~= self.originalCoalition then 
    return nil
  end
  
  --try to return avail parking, if can't just return nil
  return self.dcsObject:getParking(true)[1]
end
  
function AirbaseWrapper:isAvail() 
  --if airbase was captured, return false
  if self.dcsObject:getCoalition() ~= self.originalCoalition then 
    return false
  end
  return true
end
  
  
--how many parking avail(), for carrier return 4 always
function AirbaseWrapper:howManyParkingAvail() 
  local counter = 0
  --[[
   16 : Valid spawn points on runway
   40 : Helicopter only spawn  
   68 : Hardened Air Shelter
   72 : Open/Shelter air airplane only
   104: Open air spawn
  ]]
  local parkings = self.dcsObject:getParking(true)
  if #parkings > 100 then 
    --i think it's big enough
    return 75
  end
  
  for _, park in pairs(parkings) do 
    
    if park.Term_Type == 68 or park.Term_Type == 72 or park.Term_Type == 104 then 
      counter = counter + 1
    end
  end
  
  return counter
end  

----------------------------------------------------
-- end of AirbaseWrapper
----------------------------------------------------

----------------------------------------------------
-- Wrapper around AircraftCarrier
----------------------------------------------------    
----          AbstractCAP_Handler_Object
----                  ↓
----           AbstractDCSObject 
----                  ↓
----             DCS_Wrapper
----                  ↓
----         AbstractAirbaseWrapper
----                  ↓
----            CarrierWrapper
----------------------------------------------------

CarrierWrapper = utils.inheritFrom(AbstractAirbaseWrapper)
CarrierWrapper._instances = {}

function CarrierWrapper:create(id) 
    local key = tostring(id)
    if self._instances[key] then 
      return self._instances[key]
    end
    
    local instance = nil

    for _, airbase in pairs(world.getAirbases()) do 
      if airbase:hasAttribute("AircraftCarrier") and tonumber(airbase:getID()) == id then 
        instance = self:super():create(airbase)
        break
      end
    end
    
    if not instance then 
      GlobalLogger:create():warning("WARNING: CarrierWrapper CANT FIND CARRIER WITH ID: " .. tostring(id))
      return nil
    end

    instance.parkingCount = #instance.dcsObject:getParking()
    self._instances[key] = instance
    return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end


function CarrierWrapper:getParking()
  if not self:isAvail() then 
    --carrier not exist return nil
    return nil
  end
  
  --parkings on carrier broken, return osition of carrier
  local point = self:getPoint()
  return {vTerminalPos = {
      x = point.x,
      y = point.y,
      z = point.z
      }
    }
end

function CarrierWrapper:isAvail() 

 return self:isExist()
end

--how many parking avail(), for carrier return maximum 2 always
--(parking data broken))))
function CarrierWrapper:howManyParkingAvail() 
  if not self:isExist() then 
    return 0
  end
  return #self.dcsObject:getParking(true) - self.parkingCount + 2
end

----------------------------------------------------
-- end of CarrierWrapper
----------------------------------------------------
