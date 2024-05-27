----------------------------------------------------
-- Absract FSM state
----------------------------------------------------

AbstractState = utils.inheritFrom(AbstractCAP_Handler_Object)
AbstractState.enumerator = -999999

--arg - is object which we should control
function AbstractState:create(handedObj) 
  local instance = {}
  
  instance.object = handedObj
  instance.id = utils.getGeneralID()
  instance.enumerator = AbstractState.enumerator --uniq ID of state
  --name used for debug
  instance.name = "AbstractState"
  return setmetatable(instance, {__index = self, __eq = utils.compareTables})
  end
  
--execute current state routines, arg is dictionary, can be empty
function AbstractState:run(arg) 
  
end

--doing all needed setups, hich should be maked only once(on creation or on transition from different state)
--primary set AI options
function AbstractState:setup() 
  
end

--all clean up needed(line target reset)
function AbstractState:teardown() end
----------------------------------------------------
-- end of AbstractState
----------------------------------------------------

----------------------------------------------------
-- Stack used for contain and call FSM states
----------------------------------------------------

FSM_Stack = {}

function FSM_Stack:create()
  local instance = {}
  
  instance.data = {}
  --pointer on top of the stack
  instance.topItem = 0
  return setmetatable(instance, {__index = self})
end

function FSM_Stack:clear()
  --unwind stack
  for i = self.topItem, 1, -1 do 
    self.data[i]:teardown()
  end 
  
  self.topItem = 0
end

--FSM_State is valid AbstractState(or derived) object
--FSM_State added to top of the stack
--calls FSM_state:setup() so state will be properly configured
function FSM_Stack:push(FSM_state)
  self.topItem = self.topItem + 1
  
  self.data[self.topItem] = FSM_state
  self.data[self.topItem]:setup()
end

--delete item from top of the stack
--calls setup() so new active state will be properly configured
function FSM_Stack:pop() 
  --check if stack already empty
  if self.topItem == 1 then 
    return
  end
  
  self.data[self.topItem]:teardown()
  self.topItem = self.topItem - 1
  self.data[self.topItem]:setup()
end

--return state enumerator from top of the stack
function FSM_Stack:getStateEnumerator() 
  return self.data[self.topItem].enumerator
end

--return state  from top of the stack
function FSM_Stack:getCurrentState() 
  return self.data[self.topItem]
  end

--Runs FSM state from top of the stack
--also guaranties arg ~= nil
function FSM_Stack:run(arg) 
  self.data[self.topItem]:run(arg or {})
end

--static function to print stack
function FSM_Stack.printStack(stack, margin) 
  local m = utils.getMargin(margin) .. "STACK:\n"
  
  for i = stack.topItem, 1, -1 do 
    m = m .. utils.getMargin(margin + 2) .. stack.data[i].name .. "\n"
  end
  
  return m
end
