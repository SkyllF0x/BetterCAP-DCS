dofile(".\\BetterCap\\SourceTest\\00test_includes.lua")

test_AbstractFSM = {}

function test_AbstractFSM.test_creation() 
  local object = DCS_Wrapper:create(Unit:create())
  
  local inst = AbstractState:create(object)
  lu.assertNotNil(inst)
  lu.assertEquals(inst.object, object)
  lu.assertNotNil(inst:getName())
  lu.assertNotNil(inst:getID())
end

test_FSMStack = {}

function test_FSMStack.test_creation() 
  local obj = FSM_Stack:create()
  
  lu.assertEquals(obj.data, {})
  lu.assertEquals(obj.topItem, 0)
end


function test_FSMStack.test_clear() 
  --verify setup() call when active state changes
  local obj, m = FSM_Stack:create(), mockagne.getMock()
  
  --just filler
  local state1, state2 = AbstractState:create(Unit:create()),  AbstractState:create(Unit:create())
  state1.teardown = m.teardown
  state2.teardown = m.teardown
  
  obj.data = {state1, state2}
  obj.topItem = 2
  
  obj:clear()
  lu.assertEquals(obj.topItem, 0)
  verify(m.teardown(state2))
  verify(m.teardown(state1))
end


function test_FSMStack.test_push() 
  local obj, m = FSM_Stack:create(), mockagne.getMock()
  
  --just filler
  local state = AbstractState:create(Unit:create())
  state.setup = m.setup
  
  obj:push(state)
  lu.assertNotNil(obj.data[1])
  lu.assertEquals(obj.topItem, 1)
  verify(m.setup(state))
end

function test_FSMStack.test_run_noArg() 
  --verify state run() will anyway have arg
  local obj, m = FSM_Stack:create(), mockagne.getMock()
  
  --just filler
  local state = AbstractState:create(Unit:create())
  state.run = m.run
  
  obj:push(state)
  obj:run()
  verify(m.run(state, {}))
end

function test_FSMStack.test_run() 
  --verify state run() will anyway have arg
  local obj, m = FSM_Stack:create(), mockagne.getMock()
  
  --just filler
  local state = AbstractState:create(Unit:create())
  state.run = m.run
  
  obj:push(state)
  obj:run({1, 2, 3})
  verify(m.run(state, {1, 2, 3}))
end

function test_FSMStack.test_pop() 
  --verify setup() call when active state changes
  local obj, m = FSM_Stack:create(), mockagne.getMock()
  
  --just filler
  local state1, state2 = AbstractState:create(Unit:create()),  AbstractState:create(Unit:create())
  state1.setup = m.setup
  state2.teardown = m.teardown
  
  obj.data = {state1, state2}
  obj.topItem = 2
  
  obj:pop()
  lu.assertEquals(obj.data[1], state1)
  verify(m.setup(state1))
   verify(m.teardown(state2))
end

function test_FSMStack:test_getStateEnumerator() 
  local obj = FSM_Stack:create()
  obj:push(AbstractState:create())
  
  lu.assertNumber(obj:getStateEnumerator())
  lu.assertEquals(obj:getStateEnumerator(), obj.data[obj.topItem].enumerator)
end

function test_FSMStack:test_overflow() 
  local obj = FSM_Stack:create()
  local state = AbstractState:create()
  local state2 = AbstractState:create()

  state.object = Unit:create()
  state2.object =  Unit:create()
  state.run = function ()
    obj:push(state2)
    obj:run()
  end
  state2.run = function ()
    obj:pop()
    obj:run()

  end
  
  obj:push(state)
  obj:run({})
end
local runner = lu.LuaUnit.new()
runner:runSuite()