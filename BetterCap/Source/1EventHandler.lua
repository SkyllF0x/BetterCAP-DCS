-------------------------------------------------------------------
---- EventHander signleton which track all related to script objects
-------------------------------------------------------------------

EventHandler = {
  _inst = nil
  }

function EventHandler:create() 
  if not self._inst then 
      local instance = {}  
      
      instance.objects = {}--all objects stored here
      world.addEventHandler(instance)
      self._inst = setmetatable(instance,  {__index = self, __eq = utils.compareTables})
    end
    return self._inst
  end

  function EventHandler:onEvent(event) 
    local result, err = xpcall(function() 
        
      if event.id == world.event.S_EVENT_SHOT then 
        for _, obj in pairs(self.objects) do 
          obj:shotEvent(event)
        end
      elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
        for _, obj in pairs(self.objects) do 
          obj:engineOffEvent(event)
        end
      elseif event.id == world.event.S_EVENT_MISSION_END then
        self:shutdown()
      end
    end, debug.traceback)
  
    if not result then 
      GlobalLogger:create():warning("EventHandler: error during processing event: " .. tostring(err))
    end
  end
  
  function EventHandler:registerObject(object)  
   self.objects[object:getID()] = object
  end
  
  function EventHandler:removeObject(object) 
    self.objects[object:getID()] = nil
  end
  
  function EventHandler:shutdown() 
    world.removeEventHandler(self)
    EventHandler._instance = nil
  end

-------------------------------------------------------------------
-- End of EventHandler
-------------------------------------------------------------------