# Code Reduction Roadmap

## Executive Summary

This document provides a systematic roadmap to significantly reduce the line count of the Monopoly game codebase while maintaining all existing functionality and improving maintainability.

## Current State

### Codebase Statistics
- **Total Lines**: 5,214 lines of Lua code
- **File Count**: 52 .lua files
- **Largest File**: src/gameplay/domain/item.lua (747 lines)

### Module Distribution
```
src/gameplay/     2,540 lines (48.7%)
src/adapters/     1,245 lines (23.9%)
src/config/         394 lines (7.6%)
src/core/           327 lines (6.3%)
scripts/            304 lines (5.8%)
src/util/            87 lines (1.7%)
src/bootstrap/       31 lines (0.6%)
```

## Optimization Roadmap

### Phase 1: Eliminate Code Duplication (Est. 200-300 lines reduction)
- Extract repeated `get_service` function to common utility module (6 duplicates)
- Extract repeated `tile_state` function to common utility module (3 duplicates)
- Consolidate repeated service access patterns

### Phase 2: Simplify item.lua (Est. 150-200 lines reduction)
- Refactor item_handlers and post_consume_handlers using table-driven design
- Extract common target selection logic
- Merge similar item effect handler functions

### Phase 3: Optimize Rendering Layer (Est. 100-150 lines reduction)
- Simplify modal dialog logic in love_layer.lua
- Merge repeated patterns in board_renderer.lua and panel_renderer.lua
- Extract common UI building helper functions

### Phase 4: Data-Driven Chance and Land Effects (Est. 100-150 lines reduction)
- Convert handlers table in chance.lua to configuration-driven
- Simplify conditional check logic in land.lua
- Unify effect handling interface

### Phase 5: Service Layer Optimization (Est. 80-120 lines reduction)
- Simplify communication patterns between services
- Reduce conditional branches in turn_manager.lua
- Standardize error handling patterns

### Phase 6: Configuration and Utilities Optimization (Est. 60-100 lines reduction)
- Simplify items.lua configuration structure
- Optimize script files
- Remove unused code

## Expected Results

### Quantitative Metrics
| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| Total Lines | 5,214 | 4,200-4,500 | -700 to -1,000 lines (13-19%) |
| Largest File | 747 lines | <550 lines | -200 lines (26%) |
| Duplicate Functions | 9+ | 0 | -100% |
| Average File Size | 100 lines | 80 lines | -20% |

### Quality Improvements
1. **Maintainability**
   - Reduced code duplication
   - Clearer separation of concerns
   - Unified coding patterns

2. **Readability**
   - Less nesting
   - Clearer intent
   - Less boilerplate code

3. **Extensibility**
   - Configuration-driven design makes adding new features easier
   - Modular structure supports independent testing
   - Clear interface definitions

## Implementation Timeline

### Week 1: Foundation Refactoring
- Phase 1: Eliminate code duplication
- Run regression tests to ensure functionality

### Week 2: Core Simplification
- Phase 2: Simplify item.lua
- Phase 4: Data-driven effect system
- Run comprehensive tests

### Week 3: UI and Service Optimization
- Phase 3: Optimize rendering layer
- Phase 5: Service layer optimization
- Integration testing

### Week 4: Finalization and Verification
- Phase 6: Configuration optimization
- Complete regression testing
- Performance verification
- Documentation updates

## Key Optimization Techniques

### 1. Table-Driven Design
Convert imperative code with many conditionals into data structures:
```lua
-- Before: 100+ lines of handler functions
-- After: Configuration table + generic handler (30 lines)
```

### 2. Extract Common Patterns
Identify and extract repeated code blocks:
```lua
-- Before: get_service function in 6 files
-- After: Single Services utility module
```

### 3. Configuration Over Code
Move logic from code to configuration:
```lua
-- Before: One function per item type
-- After: Item configuration with type and parameters
```

### 4. Reduce Nesting
Flatten conditional logic using early returns and guard clauses.

### 5. Merge Similar Functions
Combine functions that differ only in parameters by adding configuration.

## Risk Mitigation

### Risk 1: Functionality Breakage
**Mitigation**:
- Run regression tests after each phase
- Small, incremental refactoring steps
- Use git branches for isolation

### Risk 2: Introduction of New Bugs
**Mitigation**:
- Enhance test coverage
- Code review for each change
- Manual testing of critical paths

### Risk 3: Performance Degradation
**Mitigation**:
- Performance testing before and after optimization
- Avoid over-abstraction
- Keep hot paths direct

## Maintenance Recommendations

1. **Establish Code Review Standards**
   - Check if new code introduces duplication
   - Evaluate if existing abstractions can be used
   - Limit maximum lines per file

2. **Continuous Refactoring Culture**
   - Regularly review code quality metrics
   - Schedule refactoring time windows
   - Encourage small improvements

3. **Documentation Maintenance**
   - Update architecture docs to reflect new structure
   - Record design decisions and patterns
   - Maintain example code

---

**Version**: 1.0  
**Date**: 2026-01-12  
**Author**: GitHub Copilot  
**Status**: Pending Approval
