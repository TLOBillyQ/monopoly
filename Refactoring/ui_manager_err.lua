local canvas = UIManager.query_nodes_by_name("加载屏")[1]
canvas.visible = true
canvas.disabled = false
print("canvas.visible:", canvas.visible)
print("canvas.disabled:", canvas.disabled)


LuaAPI.call_delay_time(1.0, function()
    canvas = UIManager.query_nodes_by_name("加载屏")[1]

    canvas.disabled = true
    canvas.visible = false

    print("canvas.disabled:", canvas.disabled)
    print("canvas.visible:", canvas.visible)
end)
