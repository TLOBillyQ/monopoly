# 抽方法重构批次（refactorer → coder 路由）

`extract-method-batch.patch`：21 个 src 文件的等价行为抽方法重构（提取 helper、拆分长函数），从 HEAD 干净应用。smoke / property(61) / crap-regression 全绿。

## 为何路由给 coder

21 个文件全部内嵌 `mutate4lua-manifest`。抽方法引入新 helper、移动并拆分原函数，使每个文件的 manifest 行号 / semanticHash 失配。其中两个文件今天刚被 architect 跑满杀变异：

- `src/rules/board/facing_policy.lua` — `lastMutatedAt=2026-06-01T04:37:24Z`
- `src/rules/items/demolish.lua` — `lastMutatedAt=2026-06-01T03:35:42Z`

refactorer 不跑变异工具、无法重生成 manifest；落地即留陈旧 manifest。按项目约定，desync src 重排归 coder。

## 应用

```
git apply agent_context/coder-restructure/extract-method-batch.patch
```

随后按 coder 角色规则重生成受影响文件的 manifest 并验证。

## 清单（21 文件）

src/app/profile_bootstrap.lua, src/app/testing/test_profiles.lua, src/host/context.lua,
src/host/synthetic_actor_registry.lua, src/rules/board/facing_policy.lua,
src/rules/choice_handlers/item.lua, src/rules/items/demolish.lua, src/rules/items/target_query.lua,
src/turn/actions/validator.lua, src/ui/coord/event_handlers.lua, src/ui/coord/item_slots.lua,
src/ui/input/dispatch/turn_action_port.lua, src/ui/ports/ui_sync/choice_state.lua,
src/ui/render/assets.lua, src/ui/render/board/player_units.lua, src/ui/render/board/visual_sync.lua,
src/ui/render/building_effects.lua, src/ui/render/item_atlas.lua, src/ui/render/status3d/scene.lua,
src/ui/view/choice_builder.lua, src/ui/view/role_context.lua
