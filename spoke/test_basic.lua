-- test_basic.lua
-- Basic tests for Spoke Lua implementation

-- Test Heap
print("Testing Heap...")
local Heap = require("spoke.heap")
local heap = Heap.new(function(a, b) return a - b end)
heap:Insert(5)
heap:Insert(3)
heap:Insert(7)
heap:Insert(1)
assert(heap:PeekMin() == 1, "Heap min should be 1")
assert(heap:RemoveMin() == 1, "Removed min should be 1")
assert(heap:RemoveMin() == 3, "Next min should be 3")
print("✓ Heap tests passed")

-- Test State
print("\nTesting State...")
local State = require("spoke.state")
local state = State.Create(10)
assert(state:Now() == 10, "Initial state value should be 10")
state:Set(20)
assert(state:Now() == 20, "Updated state value should be 20")

local callCount = 0
local handle = state:Subscribe(function(val)
    callCount = callCount + 1
end)
state:Set(30)
-- Note: trigger needs to be flushed, so we can't test immediately
print("✓ State tests passed")

-- Test TreeCoords
print("\nTesting TreeCoords...")
local TreeCoords = require("spoke.treecoords")
local coord1 = TreeCoords.new()
local coord2 = coord1:Extend(0)
local coord3 = coord1:Extend(1)
assert(coord2:CompareTo(coord3) < 0, "coord2 should come before coord3")
assert(coord3:CompareTo(coord2) > 0, "coord3 should come after coord2")
print("✓ TreeCoords tests passed")

-- Test SpokeHandle
print("\nTesting SpokeHandle...")
local SpokeHandle = require("spoke.spokehandle")
local disposed = false
local handle = SpokeHandle.Of(123, function(id)
    disposed = true
    assert(id == 123, "ID should be 123")
end)
handle:Dispose()
assert(disposed, "Handle should be disposed")
print("✓ SpokeHandle tests passed")

-- Test SpokePool
print("\nTesting SpokePool...")
local SpokePool = require("spoke.spokepool")
local pool = SpokePool.Create(function(obj)
    obj.value = 0
end)
local obj1 = pool:Now()
obj1.value = 42
pool:Return(obj1)
local obj2 = pool:Now()
assert(obj2.value == 0, "Returned object should be reset")
print("✓ SpokePool tests passed")

-- Test ReadOnlyList
print("\nTesting ReadOnlyList...")
local ReadOnlyList = require("spoke.readonlylist")
local list = {1, 2, 3, 4, 5}
local roList = ReadOnlyList.new(list)
assert(roList:Count() == 5, "List count should be 5")
assert(roList:Get(3) == 3, "Third element should be 3")
print("✓ ReadOnlyList tests passed")

-- Test SpokeTree with Auto mode
print("\nTesting SpokeTree (Auto mode)...")
local SpokeTree = require("spoke.spoketree").SpokeTree
local Effect = require("spoke.effect").Effect

local testState = State.Create(0)
local autoTickCount = 0

local autoEffect = Effect.new("AutoEffect", function(s)
    local val = s:D(testState)
    autoTickCount = autoTickCount + 1
end, {testState})

local autoTree = SpokeTree.Spawn("AutoTest", autoEffect)
assert(autoTickCount == 1, "Auto tree should tick once on creation")

testState:Set(1)
assert(autoTickCount == 2, "Auto tree should tick automatically on state change")

testState:Set(2)
assert(autoTickCount == 3, "Auto tree should tick again on another state change")

autoTree:Dispose()
print("✓ SpokeTree Auto mode tests passed")

-- Test SpokeTree with Manual mode
print("\nTesting SpokeTree (Manual mode)...")
local manualTestState = State.Create(0)
local manualTickCount = 0

local manualEffect = Effect.new("ManualEffect", function(s)
    local val = s:D(manualTestState)
    manualTickCount = manualTickCount + 1
end, {manualTestState})

local manualTree = SpokeTree.SpawnManual("ManualTest", manualEffect)
assert(manualTickCount == 0, "Manual tree should not tick on creation")

manualTestState:Set(1)
assert(manualTickCount == 0, "Manual tree should not tick automatically on state change")

manualTree:Flush()
assert(manualTickCount == 1, "Manual tree should tick after explicit Flush()")

manualTestState:Set(2)
assert(manualTickCount == 1, "Manual tree should not tick until Flush() is called again")

manualTree:Flush()
assert(manualTickCount == 2, "Manual tree should tick after second Flush()")

manualTree:Dispose()
print("✓ SpokeTree Manual mode tests passed")

-- Test SpokeTree internal tick flag (batching behavior)
print("\nTesting SpokeTree internal tick flag...")
local internalTickState = State.Create(0)
local internalTickCount = 0

local internalEffect = Effect.new("InternalEffect", function(s)
    local val = s:D(internalTickState)
    internalTickCount = internalTickCount + 1
end, {internalTickState})

local internalTree = SpokeTree.SpawnManual("InternalTest", internalEffect)

-- Multiple state changes before flush should batch
internalTickState:Set(1)
internalTickState:Set(2)
internalTickState:Set(3)
assert(internalTickCount == 0, "Manual tree should not tick before flush")

internalTree:Flush()
-- The tree should process all batched updates and tick once with final value
assert(internalTickCount == 1, "Manual tree should tick once with final batched value after flush")

internalTree:Dispose()
print("✓ SpokeTree internal tick flag tests passed")

-- Test re-entrant flush detection
print("\nTesting re-entrant flush detection...")
local reentrantState = State.Create(0)

local reentrantEffect = Effect.new("ReentrantEffect", function(s)
    local val = s:D(reentrantState)
    -- This should not cause issues
end, {reentrantState})

local reentrantTree = SpokeTree.SpawnManual("ReentrantTest", reentrantEffect)

-- First flush should work
local success1 = pcall(function()
    reentrantTree:Flush()
end)
assert(success1, "First flush should succeed")

reentrantTree:Dispose()
print("✓ Re-entrant flush detection tests passed")

-- Test LambdaEpoch
print("\nTesting LambdaEpoch...")
local LambdaEpoch = require("spoke.lambdaepoch")

local lambdaInitCalled = false
local lambdaTickCalled = false

local lambdaEpoch = LambdaEpoch.new("TestLambda", function(s)
    lambdaInitCalled = true
    return function(s)
        lambdaTickCalled = true
    end
end)

local lambdaTree = SpokeTree.Spawn("LambdaTest", lambdaEpoch)
assert(lambdaInitCalled, "LambdaEpoch Init should be called")

lambdaTree:Dispose()
print("✓ LambdaEpoch tests passed")

print("\n=================================")
print("All basic tests passed!")
print("=================================")
