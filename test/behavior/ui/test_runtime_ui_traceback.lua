local lu = require("luaunit")
local luax = require("test.support.luax")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches

TestRuntimeUiTraceback = {}

do
  TestRuntimeUiTraceback["test_invokes global traceback function when defined and uses its return as the rethrown error"] = function(self)
    local marker = "[MARK_TB]"
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = function(err) return marker .. tostring(err) end },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-A", function()
          error("boom_err_marker")
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate from with_client_role")
      lu.assertEvalToTrue(type(captured) == "string", "expected captured error to be a string, got " .. type(captured))
      lu.assertEvalToTrue(captured:find(marker, 1, true) ~= nil,
        "expected marker '" .. marker .. "' in rethrown error: " .. tostring(captured))
      lu.assertEvalToTrue(captured:find("boom_err_marker", 1, true) ~= nil,
        "expected original error text in rethrown error: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_returns err verbatim when global traceback is nil (sandbox fallback arm)"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local sentinel = "sentinel_NoTB_err"
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-B", function()
          error(sentinel)
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(type(captured) == "string", "expected captured error to be a string")
      lu.assertEvalToTrue(captured:find(sentinel, 1, true) ~= nil,
        "expected raw err propagated when traceback absent: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_returns err verbatim when global traceback is a non-function value"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = "not_a_function" },
    }, function()
      local sentinel = "sentinel_StringTB_err"
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("role-C", function()
          error(sentinel)
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(captured:find(sentinel, 1, true) ~= nil,
        "expected raw err when traceback is non-function: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_restores previous client_role even when fn errors and traceback fallback is in play"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = "previous_role_id" } },
      { key = "traceback", value = nil },
    }, function()
      pcall(function()
        runtime_ui.with_client_role("transient_role_id", function()
          error("transient_fn_error")
        end)
      end)
      lu.assertEvalToTrue(UIManager.client_role == "previous_role_id",
        "expected previous_role_id restored after fn error, got " .. tostring(UIManager.client_role))
    end)
  end
end


do
  -- 守卫消息钉(runtime_ui 缺参断言):消息->nil 变异后 has_error 消息不匹配即露馅。
  TestRuntimeUiTraceback["test_with_client_role_asserts_descriptive_error_without_fn"] = function(self)
    luax.has_error(function()
      runtime_ui.with_client_role("role-A", nil)
    end, "missing fn")
  end

  TestRuntimeUiTraceback["test_for_each_role_or_global_asserts_descriptive_error_without_fn"] = function(self)
    luax.has_error(function()
      runtime_ui.for_each_role_or_global(nil)
    end, "missing fn")
  end

  TestRuntimeUiTraceback["test_query_nodes_asserts_descriptive_error_without_name"] = function(self)
    luax.has_error(function()
      runtime_ui.query_nodes(nil)
    end, "missing ui node name")
  end

  -- L63 两个位点:and->or 变异走 nil 调用报错,消息->nil 变异无消息——
  -- 消息钉 "missing UIManager.query_nodes_by_name" 两者皆杀。
  TestRuntimeUiTraceback["test_query_nodes_asserts_when_uimanager_lacks_query_nodes_by_name"] = function(self)
    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = nil } },
    }, function()
      luax.has_error(function()
        runtime_ui.query_nodes("test")
      end, "missing UIManager.query_nodes_by_name")
    end)
  end

  -- L65 and->or:变异后 nodes=nil 走 nodes[1] 索引报错,消息与钉不匹配。
  TestRuntimeUiTraceback["test_query_nodes_asserts_when_query_returns_no_nodes"] = function(self)
    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return nil end } },
    }, function()
      luax.has_error(function()
        runtime_ui.query_nodes("test")
      end, "missing ui node: test")
    end)
  end

  TestRuntimeUiTraceback["test_set_node_texture_keep_size_asserts_without_node"] = function(self)
    luax.has_error(function()
      runtime_ui.set_node_texture_keep_size(nil, "ICON")
    end, "missing image node")
  end

  TestRuntimeUiTraceback["test_set_node_texture_keep_size_asserts_without_image_key"] = function(self)
    luax.has_error(function()
      runtime_ui.set_node_texture_keep_size({}, nil)
    end, "missing image key")
  end
end


do
  -- #541:宿主 traceback 全局不拼原始 msg 时(真机实测:日志只剩空
  -- "stack traceback:"),重抛文本也必须含错误正文;err 为非字符串
  -- (宿主错误对象)时以 tostring 形式保留。
  TestRuntimeUiTraceback["test_preserves original message when host traceback drops it"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = function() return "stack traceback: <frames only>" end },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role(nil, function()
          error("swallowed_msg_marker")
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(type(captured) == "string", "expected string error, got " .. type(captured))
      lu.assertEvalToTrue(captured:find("swallowed_msg_marker", 1, true) ~= nil,
        "original message must survive even when host traceback drops it: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_preserves non-string error via tostring when host traceback drops it"] = function(self)
    local err_obj = { code = "E_HOST_PUSH" }
    local expected = tostring(err_obj)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = function() return "stack traceback: <frames only>" end },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role(nil, function()
          error(err_obj)
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(type(captured) == "string",
        "non-string err must be rethrown as text, got " .. type(captured))
      lu.assertEvalToTrue(captured:find(expected, 1, true) ~= nil,
        "tostring(err) must survive: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_preserves non-string error via tostring when traceback absent"] = function(self)
    local err_obj = { code = "E_HOST_PUSH" }
    local expected = tostring(err_obj)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role(nil, function()
          error(err_obj)
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(type(captured) == "string",
        "non-string err must be rethrown as text, got " .. type(captured))
      lu.assertEvalToTrue(captured:find(expected, 1, true) ~= nil,
        "tostring(err) must survive without traceback global: " .. tostring(captured))
    end)
  end

  -- #541:role 作用域内的失败须带目标 role 标识,事后仅凭日志可分辨
  -- 是哪个角色的推送炸了。
  TestRuntimeUiTraceback["test_rethrown error carries role id for table role"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local role = { get_roleid = function() return 4242 end }
      local ok, captured = pcall(function()
        runtime_ui.with_client_role(role, function()
          error("role_ctx_boom")
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(tostring(captured):find("4242", 1, true) ~= nil,
        "rethrown error must carry role id: " .. tostring(captured))
      lu.assertEvalToTrue(tostring(captured):find("role_ctx_boom", 1, true) ~= nil,
        "original message must survive alongside role id: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_rethrown error carries tostring(role) when role has no get_roleid"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role("plain_role_text", function()
          error("role_fallback_boom")
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(tostring(captured):find("plain_role_text", 1, true) ~= nil,
        "rethrown error must carry tostring(role) fallback: " .. tostring(captured))
    end)
  end

  TestRuntimeUiTraceback["test_no role prefix when role is nil"] = function(self)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { key = "traceback", value = nil },
    }, function()
      local ok, captured = pcall(function()
        runtime_ui.with_client_role(nil, function()
          error("no_role_boom")
        end)
      end)
      lu.assertEvalToTrue(ok == false, "expected error to propagate")
      lu.assertEvalToTrue(tostring(captured):find("[role=", 1, true) == nil,
        "nil role must not add a role prefix: " .. tostring(captured))
      lu.assertEvalToTrue(tostring(captured):find("no_role_boom", 1, true) ~= nil,
        "original message must survive: " .. tostring(captured))
    end)
  end
end


return TestRuntimeUiTraceback
