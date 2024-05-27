
--timer singleton stubs
local timer = {}

function timer.getTime() 
  return 0
end

function timer.getAbsTime() 
  return 0
end

function timer.getTime0() 
  return 0
end

function timer.scheduleFunction(functionToCall, anyFunctionArguement, modelTime) 
  return 0
end

function timer.removeFunction(functionId) 
end

 function timer.setFunctionTime(functionId , modelTime) 
end

return timer