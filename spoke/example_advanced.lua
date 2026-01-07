-- example_advanced.lua
-- Advanced usage example of Spoke Lua implementation

-- This example demonstrates a complete reactive application
-- with state management, effects, and tree lifecycle

local SpokeTree = require("spoke.spoketree").SpokeTree
local State = require("spoke.state")
local Effect = require("spoke.effect").Effect
local Memo = require("spoke.memo")
local Reaction = require("spoke.reaction")
local LambdaEpoch = require("spoke.lambdaepoch")

print("=== Spoke Lua Advanced Example ===\n")

-- Create reactive states
local firstName = State.Create("John")
local lastName = State.Create("Doe")
local clickCount = State.Create(0)

-- Create a computed value (Memo)
local fullName = Memo.new("FullName", function(s)
    local first = s:D(firstName)
    local last = s:D(lastName)
    return first .. " " .. last
end, {firstName, lastName})

-- Create an effect that logs the full name
local nameLogger = Effect.new("NameLogger", function(s)
    local name = s:D(fullName)
    print("Full name changed to: " .. name)
end, {fullName})

-- Create a reaction (skips first run)
local clickReaction = Reaction.new("ClickReaction", function(s)
    local count = s:D(clickCount)
    print("Button clicked " .. count .. " times!")
end, {clickCount})

-- Create a main epoch that contains everything
local mainEpoch = LambdaEpoch.new("MainEpoch", function(s)
    -- Call our reactive components
    s:Call(fullName)
    s:Call(nameLogger)
    s:Call(clickReaction)
    
    -- Setup cleanup
    s:OnCleanup(function()
        print("Cleaning up main epoch...")
    end)
    
    return function(s)
        -- Tick block - runs on each tick
        -- In this example, we don't need to do anything here
    end
end)

-- Create and initialize the tree
print("Creating tree...")
local tree = SpokeTree.Spawn("ExampleTree", mainEpoch)

-- Simulate some state changes
print("\n--- Updating first name ---")
firstName:Set("Jane")

print("\n--- Updating last name ---")
lastName:Set("Smith")

print("\n--- Simulating button clicks ---")
clickCount:Set(1)
clickCount:Set(2)
clickCount:Set(3)

print("\n--- Updating both names ---")
firstName:Set("Bob")
lastName:Set("Johnson")

-- Demonstrate manual tree mode
print("\n\n=== Manual Tree Mode ===\n")

local manualTree = SpokeTree.SpawnManual("ManualTree", Effect.new("ManualEffect", function(s)
    local count = s:D(clickCount)
    print("Manual tree sees count: " .. count)
end, {clickCount}))

print("Changing click count (manual tree won't react yet)...")
clickCount:Set(4)

print("Now flushing manual tree...")
manualTree:Flush()

print("\n--- Cleaning up ---")
tree:Dispose()
manualTree:Dispose()

print("\n=== Example Complete ===")

--[[
Expected output:

=== Spoke Lua Advanced Example ===

Creating tree...
Full name changed to: John Doe

--- Updating first name ---
Full name changed to: Jane Doe

--- Updating last name ---
Full name changed to: Jane Smith

--- Simulating button clicks ---
Button clicked 1 times!
Button clicked 2 times!
Button clicked 3 times!

--- Updating both names ---
Full name changed to: Bob Smith
Full name changed to: Bob Johnson

=== Manual Tree Mode ===

Changing click count (manual tree won't react yet)...
Now flushing manual tree...
Manual tree sees count: 4

--- Cleaning up ---
Cleaning up main epoch...

=== Example Complete ===
]]
