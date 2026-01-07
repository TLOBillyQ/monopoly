-- test_robustness.lua
-- Tests for robustness improvements and error handling

local function testError(testName, fn, expectedErrorPattern)
    local success, err = pcall(fn)
    if success then
        error(testName .. " should have thrown an error but didn't")
    end
    if expectedErrorPattern and not string.find(tostring(err), expectedErrorPattern) then
        error(testName .. " threw wrong error. Expected pattern: " .. expectedErrorPattern .. ", got: " .. tostring(err))
    end
    print("✓ " .. testName)
end

print("Testing Heap robustness...")

-- Test heap with nil comparison
testError("Heap with nil comparison", function()
    local Heap = require("spoke.heap")
    Heap.new(nil)
end, "comparison function")

-- Test heap insert nil
testError("Heap insert nil", function()
    local Heap = require("spoke.heap")
    local heap = Heap.new(function(a, b) return a - b end)
    heap:Insert(nil)
end, "Cannot insert nil")

-- Test heap remove from empty
testError("Heap remove from empty", function()
    local Heap = require("spoke.heap")
    local heap = Heap.new(function(a, b) return a - b end)
    heap:RemoveMin()
end, "empty heap")

-- Test heap peek empty
testError("Heap peek empty", function()
    local Heap = require("spoke.heap")
    local heap = Heap.new(function(a, b) return a - b end)
    heap:PeekMin()
end, "empty heap")

print("\nTesting State robustness...")

-- Test State subscribe with non-function
testError("State subscribe non-function", function()
    local State = require("spoke.state")
    local state = State.Create(10)
    state:Subscribe("not a function")
end, "function")

-- Test State unsubscribe with non-function
testError("State unsubscribe non-function", function()
    local State = require("spoke.state")
    local state = State.Create(10)
    state:Unsubscribe(123)
end, "function")

-- Test State unsubscribe with nil (should not error)
local State = require("spoke.state")
local state = State.Create(10)
state:Unsubscribe(nil)
print("✓ State unsubscribe nil (graceful)")

-- Test State update with non-function
testError("State update non-function", function()
    local State = require("spoke.state")
    local state = State.Create(10)
    state:Update("not a function")
end, "function")

-- Test State update with nil (should not error)
state:Update(nil)
print("✓ State update nil (graceful)")

print("\nTesting Trigger robustness...")

-- Test Trigger subscribe with non-function
testError("Trigger subscribe non-function", function()
    local Trigger = require("spoke.trigger")
    local trigger = Trigger.Create()
    trigger:Subscribe(42)
end, "function")

-- Test Trigger unsubscribe with non-function
testError("Trigger unsubscribe non-function", function()
    local Trigger = require("spoke.trigger")
    local trigger = Trigger.Create()
    trigger:Unsubscribe({})
end, "function")

-- Test Trigger unsubscribe with nil (should not error)
local Trigger = require("spoke.trigger")
local trigger = Trigger.Create()
trigger:Unsubscribe(nil)
print("✓ Trigger unsubscribe nil (graceful)")

print("\nTesting TreeCoords robustness...")

-- Test TreeCoords extend with nil
testError("TreeCoords extend nil", function()
    local TreeCoords = require("spoke.treecoords")
    local coord = TreeCoords.new()
    coord:Extend(nil)
end, "nil index")

-- Test TreeCoords extend with non-number
testError("TreeCoords extend non-number", function()
    local TreeCoords = require("spoke.treecoords")
    local coord = TreeCoords.new()
    coord:Extend("string")
end, "number")

-- Test TreeCoords compare with nil
testError("TreeCoords compare nil", function()
    local TreeCoords = require("spoke.treecoords")
    local coord = TreeCoords.new()
    coord:CompareTo(nil)
end, "nil")

print("\nTesting SpokeRuntime robustness...")

-- Test SpokeRuntime Batch with non-function
testError("SpokeRuntime Batch non-function", function()
    local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
    SpokeRuntime.Batch(nil)
end, "function")

-- Test SpokeRuntime push nil frame
testError("SpokeRuntime push nil", function()
    local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
    SpokeRuntime.Local:Push(nil)
end, "nil frame")

-- Test SpokeRuntime pop empty stack
testError("SpokeRuntime pop empty", function()
    local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
    local rt = SpokeRuntime.new()
    rt:Pop()
end, "empty stack")

-- Test SpokeRuntime schedule nil
testError("SpokeRuntime schedule nil", function()
    local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
    local rt = SpokeRuntime.new()
    rt:Schedule(nil)
end, "nil tree")

print("\nTesting SpokePool robustness...")

-- Test SpokePool with non-function reset
testError("SpokePool non-function reset", function()
    local SpokePool = require("spoke.spokepool")
    SpokePool.Create("not a function")
end, "function")

-- Test SpokePool with nil reset (should work)
local SpokePool = require("spoke.spokepool")
local pool = SpokePool.Create(nil)
print("✓ SpokePool nil reset (graceful)")

-- Test SpokePool return nil (should be graceful)
pool:Return(nil)
print("✓ SpokePool return nil (graceful)")

-- Test SpokePool SetConstructor non-function
testError("SpokePool SetConstructor non-function", function()
    local SpokePool = require("spoke.spokepool")
    local pool = SpokePool.Create(nil)
    pool:SetConstructor(123)
end, "function")

print("\nTesting SpokeHandle robustness...")

-- Test SpokeHandle with non-function onDispose
testError("SpokeHandle non-function onDispose", function()
    local SpokeHandle = require("spoke.spokehandle")
    SpokeHandle.Of(1, "not a function")
end, "function")

-- Test SpokeHandle with nil onDispose (should work)
local SpokeHandle = require("spoke.spokehandle")
local handle = SpokeHandle.Of(1, nil)
print("✓ SpokeHandle nil onDispose (graceful)")

-- Test SpokeHandle equals with nil
local handle2 = SpokeHandle.Of(1, function() end)
assert(handle2:Equals(nil) == false, "Handle equals nil should return false")
print("✓ SpokeHandle equals nil (graceful)")

-- Test double dispose (should be safe)
local disposeCount = 0
local handle3 = SpokeHandle.Of(1, function() disposeCount = disposeCount + 1 end)
handle3:Dispose()
handle3:Dispose()
assert(disposeCount == 1, "Double dispose should only call once")
print("✓ SpokeHandle double dispose protection")

print("\nTesting Ticker robustness...")

-- Test Ticker schedule with nil
testError("Ticker schedule nil", function()
    local Ticker = require("spoke.ticker")
    local ticker = Ticker.new()
    ticker:Schedule(nil)
end, "nil epoch")

print("\nTesting SpokeTree robustness...")

-- Test SpokeTree with nil main
testError("SpokeTree nil main", function()
    local SpokeTree = require("spoke.spoketree").SpokeTree
    SpokeTree.new("Test", nil)
end, "main epoch")

-- Test manual tree flush on auto tree
testError("Auto tree manual flush", function()
    local SpokeTree = require("spoke.spoketree").SpokeTree
    local Effect = require("spoke.effect").Effect
    local State = require("spoke.state")
    
    local testState = State.Create(0)
    local effect = Effect.new("Test", function(s) end, {})
    local tree = SpokeTree.Spawn("AutoTree", effect)
    
    tree:Flush()  -- Should error because it's auto mode
end, "Manual")

print("\nTesting Epoch robustness...")

-- Test Epoch attach with nil coords
testError("Epoch attach nil coords", function()
    local Epoch = require("spoke.epoch")
    local epoch = Epoch.new()
    epoch:Attach(nil, nil, nil, nil)
end, "nil coords")

print("\n=================================")
print("All robustness tests passed!")
print("=================================")
