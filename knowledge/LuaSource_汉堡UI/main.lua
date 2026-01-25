function init_cb()
    require "choose_usage"

    require "UIManager.Utils"

    local test_data = require "test_data"

    LuaAPI.call_delay_frame(1, function()
        UIManager.Builder(test_data)
        --- 你可以使用 UIManager.query_nodes_by_name(_name: string) 获取对应名称的控件，注意，该方法会返回一个数组
        --- 除此之外，你也可以使用 UIManager.query_node_by_id(_id_: string) 获取对应类型的控件。
        --- 你可以使用 UIManager.typeof(_node: UIManager.ENodeUnion?, _type: T) 检查节点类型，这样你便可以轻松通过emmylua访问节点的方法
    end)

    ---分批次处理
    ---其中200是每批次处理数量，1是间隔（单位：帧）
    UIManager.Builder(test_data, 200, 1)

    ---事件回调，每处理完一批触发该事件
    ---@param data {total: integer, processd: integer}
    LuaAPI.global_register_custom_event(UIManager.EVENTS.BUILDER_COMPLETE_ONE_BATCH, function(_, _, data)
        local total = math.tofixed(data.total)
        local processd = math.tofixed(data.processd)
        print(("UI Builder Progress: %.2f%%"):format((processd / total) * 100.0))
    end)

    ---事件回调，全部处理完成触发该事件
    LuaAPI.global_register_custom_event(UIManager.EVENTS.BUILDER_INIT_DONE, function(_, _, data)
        --require "Manager.__init"
        print("UI Manager 初始化完成")
    end)

    LuaAPI.call_delay_frame(1, function()
        local x = UIManager.query_nodes_by_name("正方形")[1] --[[@as UIManager.EImage]]
        x
            :wait(30)
            :done_then(
                function(e)
                    print(e)
                    return { x = 123 }
                end)
            :wait(30)
            :done_then(
                function(e)
                    return { y = e.x }
                end)
            :wait(30)
            :done_then(function(e)
                print(e)
            end)
    end)
end

LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, init_cb)
