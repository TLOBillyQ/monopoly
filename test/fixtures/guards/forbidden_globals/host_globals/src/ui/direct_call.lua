local function direct_calls()
  GameAPI.do_something()
  LuaAPI.query_something()
  SceneUI.show_something()
  local _ = Enums.ModelSocket.socket_head
  RegisterCustomEvent("event", function() end)
  UnregisterCustomEvent("event")
end
return direct_calls
