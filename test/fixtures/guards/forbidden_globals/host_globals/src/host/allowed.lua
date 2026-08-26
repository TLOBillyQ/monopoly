local function allowed_in_host()
  GameAPI.do_something()
  LuaAPI.query_something()
  SceneUI.show_something()
  local _ = Enums.ModelSocket.socket_head
  RegisterCustomEvent("event", function() end)
  UnregisterCustomEvent("event")
end
return allowed_in_host
