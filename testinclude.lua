---@meta testClass

do
    ---@class test
    ---@field private val boolean
    ---@field val2 integer
    ---@field tbl2 {['key']: integer, ["me"]: test}
    ---@field create fun(self: test): test
    ---@field getVal fun(self: test): boolean 
    ---@field setVal fun(self: test, val: boolean?): nil
    test = {}
    ---@return test
    function  test:create()
        local tbl = {
            val = false,
            val2 = 1,
            tbl2 = {key = 5, me = test}
        }
        return setmetatable(tbl, {__index = self})
    end

    ---@class test
    ---@param self test
    function  test:getVal()
        return self.val
    end


    ---@class test
    ---@param self test
    ---@param val boolean
    function test:setVal(val)
        print("\n 1 arg version")

        self.val = val
    end
end

test:setVal(false)
test:setVal()
CapGroup:create()
local a = CapPlane:create()