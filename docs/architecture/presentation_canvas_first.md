# Presentation Canvas-First Architecture

## Goals

1. Organize presentation modules by canvas.
2. Keep node definitions and behavior inside the same canvas slice.
3. Avoid cross-canvas imports except through `canvas_runtime`.
4. Resolve local actor identity once per session and reuse it for local-only actions.

## Layout

```text
src/presentation/canvas/
  <canvas_key>/
    nodes.lua
    contract.lua
    intents.lua
    presenter.lua
    touch_policy.lua
src/presentation/canvas_runtime/
  CanvasRegistry.lua
  CanvasState.lua
  CanvasEventRouter.lua
  CanvasCoordinator.lua
  LocalActorResolver.lua
```

## Rules

1. Canvas module must not import other canvas modules directly.
2. Canvas module must not import legacy `src.presentation.shared.UINodes`.
3. Node naming follows UIManagerNodes and belongs to one canvas.
4. Cross-canvas orchestration is done in `canvas_runtime/*`.

## Migration Notes

1. Keep compatibility wrappers while migrating call sites.
2. Remove wrappers only after all call sites are migrated and regression passes.

## New Canvas Template

1. Create `src/presentation/canvas/<canvas_key>/nodes.lua`.
2. Create `src/presentation/canvas/<canvas_key>/contract.lua`.
3. Add `intents.lua` only for clickable nodes in that canvas.
4. Add `presenter.lua` for render/open/close logic.
5. Add `touch_policy.lua` if this canvas has custom touch rules.
6. Register route specs in `src/presentation/canvas_runtime/CanvasRegistry.lua`.
7. Add/adjust regression tests before removing any compatibility mapping.
