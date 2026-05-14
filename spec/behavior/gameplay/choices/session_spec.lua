local function _reload_module(module_name, overrides, fn)
  local original = {}
  for key, value in pairs(overrides or {}) do
    original[key] = package.loaded[key]
    package.loaded[key] = value
  end
  local original_module = package.loaded[module_name]
  package.loaded[module_name] = nil
  local ok, result = pcall(function()
    local loaded = require(module_name)
    return fn(loaded)
  end)
  package.loaded[module_name] = original_module
  for key, value in pairs(original) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

describe("choices_session", function()
  it("_test_choice_session_apply_navigation_tab_select_and_empty_tab_feedback", function()
    local feedback_calls = {}
    _reload_module("src.rules.market.choice.session", {
      ["src.rules.market.choice.builder"] = {
        build = function()
          return {
            title = "Market",
            body_lines = {},
            options = {},
            allow_cancel = true,
            cancel_label = "Cancel",
            active_tab = "item",
            page_index = 1,
            page_count = 2,
            owner_role_id = 2,
            meta = {},
          }
        end,
      },
      ["src.rules.market.choice.feedback"] = {
        emit_buy_failed = function(player, entry, reason, body)
          feedback_calls[#feedback_calls + 1] = { player = player, reason = reason, body = body }
        end,
      },
      ["src.config.choice.contract"] = {
        resolve_owner_role_id = function(choice) return choice.owner_role_id end,
      },
    }, function(choice_session)
      local game = {
        dirty = {},
        find_player_by_id = function(_, id)
          return { id = id, name = "P" .. tostring(id) }
        end,
      }
      local pending_choice = { kind = "market_buy", owner_role_id = 2, active_tab = "legacy", page_index = 3, page_count = 5 }
      local ok = choice_session.apply_navigation(game, pending_choice, { type = "market_tab_select", tab = "item" })
      assert(ok == true, "tab select should succeed")
      assert(pending_choice.active_tab == "item", "should switch active tab")
      assert(pending_choice.page_index == 1, "tab switch should reset page index")
      assert(game.dirty.turn == true and game.dirty.any == true, "should mark choice dirty")
    end)
    assert(#feedback_calls == 1, "empty tab should emit feedback once")
    assert(feedback_calls[1].reason == "empty_tab", "should emit empty_tab reason")
  end)

  it("_test_choice_session_apply_navigation_prev_next_and_rejects", function()
    local build_calls = {}
    _reload_module("src.rules.market.choice.session", {
      ["src.rules.market.choice.builder"] = {
        build = function(_, _, state)
          build_calls[#build_calls + 1] = {
            active_tab = state.active_tab,
            page_index = state.page_index,
            page_count = state.page_count,
          }
          if state.page_index == 9 then
            return nil
          end
          return {
            title = "Market",
            body_lines = {},
            options = { { id = "opt" } },
            allow_cancel = true,
            cancel_label = "Cancel",
            active_tab = state.active_tab,
            page_index = state.page_index,
            page_count = state.page_count,
            owner_role_id = 2,
            meta = {},
          }
        end,
      },
      ["src.rules.market.choice.feedback"] = {
        emit_buy_failed = function() end,
      },
      ["src.config.choice.contract"] = {
        resolve_owner_role_id = function(choice) return choice.owner_role_id end,
      },
    }, function(choice_session)
      local game = {
        dirty = {},
        find_player_by_id = function(_, id)
          if id == 2 then
            return { id = id, name = "P2" }
          end
          return nil
        end,
      }
      local pending_choice = { kind = "market_buy", owner_role_id = 2, active_tab = "item", page_index = 2, page_count = 5 }
      assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_prev" }) == true,
        "prev page should rebuild")
      assert(build_calls[1].page_index == 1, "prev page should decrement page index")
      assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == true,
        "next page should rebuild")
      assert(build_calls[2].page_index == 2, "next page should increment page index from updated state")
      pending_choice.owner_role_id = nil
      assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
        "missing owner should reject")
      pending_choice.owner_role_id = 99
      assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
        "missing player should reject")
      pending_choice.owner_role_id = 2
      pending_choice.page_index = 8
      assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
        "build nil should reject")
    end)
    assert(#build_calls == 3, "should build for prev, next, and nil-spec branch")
  end)

  it("_test_choice_session_refresh_after_paid_callback_rebuilds_pending", function()
    local rebuilt_calls = 0
    local result = _reload_module("src.rules.market.choice.session", {
      ["src.rules.market.choice.builder"] = {
        build = function()
          rebuilt_calls = rebuilt_calls + 1
          return {
            title = "Market",
            body_lines = { "line" },
            options = { { id = 1 } },
            allow_cancel = true,
            cancel_label = "Cancel",
            active_tab = "item",
            page_index = 2,
            page_count = 4,
            owner_role_id = 7,
            meta = { refreshed = true },
          }
        end,
      },
      ["src.config.choice.contract"] = {
        resolve_owner_role_id = function(choice) return choice.owner_role_id end,
      },
    }, function(choice_session)
      local pending_choice = { kind = "market_buy", owner_role_id = 7, active_tab = "item", page_index = 1, page_count = 1 }
      local game = { dirty = {}, turn = { pending_choice = pending_choice } }
      local ok = choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 })
      assert(ok == true, "refresh_after_paid_callback should rebuild pending choice")
      assert(pending_choice.page_index == 2, "should update pending choice page")
      assert(pending_choice.meta.refreshed == true, "should update pending choice meta")
    end)
    assert(result == nil, "reload wrapper should finish")
    assert(rebuilt_calls == 1, "should rebuild exactly once")
  end)

  it("_test_choice_session_refresh_after_paid_callback_rejects_non_owner_and_failed_rebuild", function()
    local warnings = {}
    _reload_module("src.rules.market.choice.session", {
      ["src.rules.market.choice.builder"] = {
        build = function()
          return nil
        end,
      },
      ["src.config.choice.contract"] = {
        resolve_owner_role_id = function(choice) return choice.owner_role_id end,
      },
      ["src.foundation.log.logger"] = {
        warn = function(...)
          warnings[#warnings + 1] = table.concat({ ... }, " ")
        end,
      },
    }, function(choice_session)
      local pending_choice = { kind = "market_buy", owner_role_id = 7, active_tab = "item", page_index = 1, page_count = 1 }
      local game = { dirty = {}, turn = { pending_choice = pending_choice } }
      assert(choice_session.refresh_after_paid_callback(game, { id = 8, name = "P8" }, { product_id = 2001 }) == false,
        "other player callback should be ignored")
      assert(choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 }) == false,
        "failed rebuild should return false")
      game.turn.pending_choice = { kind = "other_kind", owner_role_id = 7 }
      assert(choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 }) == false,
        "non-market pending choice should reject")
    end)
    assert(#warnings == 2, "failed rebuild should emit rebuild warning and callback warning")
  end)
end)
