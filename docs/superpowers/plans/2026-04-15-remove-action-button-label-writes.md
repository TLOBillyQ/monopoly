# 彻底删除基础_行动按钮文本写入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 彻底移除代码中对 `基础_行动按钮`（`base_nodes.action_button`）的动态文本写入，并新增 guard 测试防止回归。

**Architecture:** 在 `src/ui/ctl/item_slots.lua` 中删除两处 `set_label` 调用；在测试文件中删除两个旧断言，替换为一个 guard 测试，确保任何场景下都不会再向 action button 写入文本。

**Tech Stack:** Lua 5.5，内部测试框架，luacheck

---

## File Structure

| 文件 | 操作 | 说明 |
|------|------|------|
| `src/ui/ctl/item_slots.lua` | 修改 | 删除 `refresh_item_slots` 中对 `base_nodes.action_button` 的两处 `set_label` 调用 |
| `tests/suites/presentation/_presentation_action_status_item_slots.lua` | 修改 | 删除两个旧测试函数及注册；新增一个 guard 测试函数及注册 |

---

## Task 1: 新增 guard 测试（先写测试）

**Files:**
- Modify: `tests/suites/presentation/_presentation_action_status_item_slots.lua:838-857`

- [ ] **Step 1: 在测试文件中添加 guard 测试函数**

在 `_test_non_passive_action_button_label_restored` 函数之后（第 839 行之后）、`return {` 之前，插入以下 guard 测试：

```lua
local function _test_action_button_label_never_written()
  local label_state = {}
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY", ["2001"] = "ICON2001" }),
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
      set_touch_enabled = function() end,
      set_visible = function() end,
      set_label = function(_, name, text)
        label_state[name] = text
      end,
    },
  }

  -- passive 场景
  local passive_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = { [1] = { 2001 } },
    choice = {
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      options = { { id = 2001 } },
      slot_states = { [1] = { available = true, alert = false } },
    },
  }
  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
  }, function()
    ui_view.refresh_item_slots(state, passive_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)
  _assert_eq(label_state["基础_行动按钮"], nil, "guard: passive should not write action button label")

  -- 非 passive 场景
  local non_passive_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = { [1] = { 2001 } },
    choice = {
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      options = { { id = 2001 } },
    },
  }
  label_state = {}
  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
  }, function()
    ui_view.refresh_item_slots(state, non_passive_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)
  _assert_eq(label_state["基础_行动按钮"], nil, "guard: non-passive should not write action button label")
end
```

- [ ] **Step 2: 注册 guard 测试并移除旧测试注册**

将文件末尾的 `return { ... }` 中的 `tests` 数组修改为：

```lua
return {
  name = "presentation_item_slots",
  tests = {
    { name = "_test_item_slot_uses_keep_size_path", run = _test_item_slot_uses_keep_size_path },
    { name = "_test_item_slot_refresh_shows_only_playable_outlines", run = _test_item_slot_refresh_shows_only_playable_outlines },
    { name = "_test_item_slot_intents_include_outline_nodes", run = _test_item_slot_intents_include_outline_nodes },
    { name = "_test_item_phase_ask_confirm_clears_highlight_suppress", run = _test_item_phase_ask_confirm_clears_highlight_suppress },
    { name = "_test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select", run = _test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select },
    { name = "_test_item_phase_confirmed_skips_replay_before_slot_click", run = _test_item_phase_confirmed_skips_replay_before_slot_click },
    { name = "_test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines", run = _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines },
    { name = "_test_item_slot_refresh_resets_highlight_without_client_role", run = _test_item_slot_refresh_resets_highlight_without_client_role },
    { name = "_test_passive_slot_three_state_rendering", run = _test_passive_slot_three_state_rendering },
    { name = "_test_passive_outlines_highlight_available_slots", run = _test_passive_outlines_highlight_available_slots },
    { name = "_test_action_button_label_never_written", run = _test_action_button_label_never_written },
  },
}
```

注意：已移除 `_test_passive_action_button_shows_continue_label` 和 `_test_non_passive_action_button_label_restored` 的注册项。

- [ ] **Step 3: 删除两个旧测试函数的定义**

删除文件中的以下两个函数：
- `_test_passive_action_button_shows_continue_label`（原第 762-800 行）
- `_test_non_passive_action_button_label_restored`（原第 802-839 行）

- [ ] **Step 4: 运行测试确认 guard 测试当前失败**

```bash
lua tests/behavior.lua presentation_item_slots
```

Expected: 测试运行，`guard: passive should not write action button label` 断言失败，因为生产代码仍在写入 `"继续"`。

- [ ] **Step 5: Commit 测试变更**

```bash
git add tests/suites/presentation/_presentation_action_status_item_slots.lua
git commit -m "$(cat <<'EOF'
test(item_slots): add guard test that action button label is never written

Remove old assertions that expected dynamic label writes and add
a guard test ensuring refresh_item_slots does not touch the
action button label in either passive or non-passive scenarios.
EOF
)"
```

---

## Task 2: 删除生产代码中的 action button 文本写入

**Files:**
- Modify: `src/ui/ctl/item_slots.lua:261-271`

- [ ] **Step 1: 删除两处 set_label 调用**

将 `src/ui/ctl/item_slots.lua` 中的 `refresh_item_slots` 函数从：

```lua
  if ctx.choice and ctx.choice.kind == "item_phase_passive" then
    _refresh_highlight_state(state, ctx, slot_pickable)
    if ctx.ui.set_label then
      ctx.ui:set_label(base_nodes.action_button, "继续")
    end
  else
    if ctx.ui.set_label then
      ctx.ui:set_label(base_nodes.action_button, "")
    end
    _refresh_highlight_state(state, ctx, slot_pickable)
  end
```

改为：

```lua
  if ctx.choice and ctx.choice.kind == "item_phase_passive" then
    _refresh_highlight_state(state, ctx, slot_pickable)
  else
    _refresh_highlight_state(state, ctx, slot_pickable)
  end
```

- [ ] **Step 2: 运行测试确认通过**

```bash
lua tests/behavior.lua presentation_item_slots
```

Expected: PASS

- [ ] **Step 3: Commit 生产代码变更**

```bash
git add src/ui/ctl/item_slots.lua
git commit -m "$(cat <<'EOF'
feat(ui): remove dynamic text writes to action button label

Action button text is now fully owned by the prefab. Code no longer
writes "继续" or "" to base_nodes.action_button during item slot refresh.
EOF
)"
```

---

## Task 3: 全量验证

- [ ] **Step 1: 运行 lint**

```bash
lua tools/quality/lint.lua
```

Expected: 无 error/warning 相关于修改的文件。

- [ ] **Step 2: 运行 behavior 全量测试**

```bash
lua tests/behavior.lua
```

Expected: 全部通过。

- [ ] **Step 3: 运行 guard 测试**

```bash
lua tests/guard.lua
```

Expected: 全部通过。

- [ ] **Step 4: 最终 commit（可选，如果前两步已分开 commit，则此步可跳过）**

如果希望把 lint/fix 的任何改动一起提交，执行：

```bash
git status
```

确认工作区干净后结束。

---

## Self-Review Checklist

| 检查项 | 状态 |
|--------|------|
| 设计文档中的删除生产代码写入要求已覆盖 | ✅ Task 2 |
| 设计文档中的移除旧测试要求已覆盖 | ✅ Task 1 Step 3 |
| 设计文档中的新增 guard 测试要求已覆盖 | ✅ Task 1 Steps 1-2 |
| 验证计划中的 lint 已覆盖 | ✅ Task 3 Step 1 |
| 验证计划中的 behavior 已覆盖 | ✅ Task 3 Step 2 |
| 验证计划中的 guard 已覆盖 | ✅ Task 3 Step 3 |
| 无 TBD/TODO/占位符 | ✅ 已检查 |
