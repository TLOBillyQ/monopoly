# Spoke Lua Implementation

This directory contains the Lua implementation of the Spoke.Runtime and Spoke.Reactive modules.

## Overview

Spoke is a reactive programming framework originally written in C# for Unity. This Lua port maintains the same architecture and API design while adapting to Lua's language features.

## Modules

### Spoke.Runtime.Lua

The runtime module provides the core VM-like capabilities for managing the Spoke execution model:

- **SpokeRuntime.lua** - Global orchestrator for Spoke trees
- **Epoch.lua** - Base class for all Spoke objects with Init/Tick lifecycle
- **Ticker.lua** - Execution gateways that control tick delivery
- **SpokeTree.lua** - Root ticker for a Spoke tree (Auto or Manual mode)
- **Heap.lua** - Priority queue data structure
- **TreeCoords.lua** - Tree coordinate system for imperative ordering
- **SpokeHandle.lua** - Zero-GC handle for resource disposal
- **SpokePool.lua** - Object pooling for GC optimization
- **Dock.lua** - Dynamic attachment container
- **LambdaEpoch.lua** - Functional composition style epochs
- **SpokeException.lua** - Exception wrapper with stack snapshots
- **SpokeLogger.lua** - Logging interfaces
- **SpokeIntrospect.lua** - Tree introspection utilities
- **ReadOnlyList.lua** - Read-only list wrapper

### Spoke.Reactive.Lua

The reactive module provides reactive programming primitives:

- **State.lua** - Read-write reactive value
- **Trigger.lua** - Event emitter/publisher
- **Computation.lua** - Base for reactive computations
- **Memo.lua** - Computed reactive value (pure function)
- **Effect.lua** - Reactive effect with side effects
- **Reaction.lua** - Effect that skips first invocation
- **Phase.lua** - Conditional effect based on boolean signal
- **BaseEffect.lua** - Abstract base for effects

## Key Differences from C#

1. **Table-based OOP**: Lua uses tables and metatables instead of classes
2. **1-based indexing**: Lua arrays start at index 1 (adjusted throughout)
3. **No static typing**: Type checking is done at runtime
4. **require() instead of using**: Module loading uses Lua's require system
5. **pcall() for exceptions**: Error handling uses protected calls
6. **Simpler generics**: Type parameters handled through conventions

## Usage Example

```lua
local SpokeTree = require("SpokeTree").SpokeTree
local Effect = require("Effect").Effect
local State = require("State")

-- Create a state
local counter = State.Create(0)

-- Create an effect that reacts to state changes
local myEffect = Effect.new("MyEffect", function(s)
    local count = s:D(counter)
    print("Counter is: " .. count)
end, {counter})

-- Create and run a tree
local tree = SpokeTree.Spawn("MyTree", myEffect)

-- Update state
counter:Set(1)  -- Prints: "Counter is: 1"
counter:Set(2)  -- Prints: "Counter is: 2"

-- Manual mode tree
local manualTree = SpokeTree.SpawnManual("ManualTree", myEffect)
counter:Set(3)
manualTree:Flush()  -- Now it runs
```

## Architecture

The Spoke architecture follows these principles:

1. **Epoch-based lifecycle**: Everything inherits from Epoch with Init/Tick phases
2. **Reactive updates**: Changes propagate through dependency graphs
3. **Imperative ordering**: Tree coordinates ensure predictable execution order
4. **Automatic cleanup**: Resources are cleaned up in reverse attachment order
5. **Fault isolation**: Exceptions are caught and propagated with stack traces

## Compatibility

This implementation is designed to be compatible with:
- Lua 5.1+
- LuaJIT
- Unity's Lua integration layers (xLua, slua, etc.)

## Notes

- The implementation maintains the same conceptual model as the C# version
- Memory management follows Lua conventions (GC instead of explicit disposal)
- Object pooling is provided but less critical in Lua's GC environment
- All classes use prototype-based inheritance via metatables
