-- Input handling module

local input = {}

function input.handle_key(key, Game)
    if not key then return end
    key = string.lower(key)
    print("Key pressed: " .. tostring(key))

    -- 如果正在等待确认，优先处理确认键
    if Game.is_waiting_for_input and Game.is_waiting_for_input() then
        if key == "y" or key == "return" or key == "kpenter" or key == "space" then
            if Game.choose_yes then Game.choose_yes() end
            return
        end
        if key == "n" or key == "escape" or key == "backspace" then
            if Game.choose_no then Game.choose_no() end
            return
        end
        -- 其它按键继续向下，让模式切换等仍然生效
    end

    if key == "escape" then
        love.event.quit()
        return
    end

    -- 空格键：推进游戏/手动模式下的下一步
    if key == "space" then
        if not Game.is_auto_mode() then
            Game.next_step()
        end
        return
    end

    -- A键：切换自动/手动模式
    if key == "a" then
        local is_auto = Game.toggle_auto_mode()
        print("游戏模式: " .. (is_auto and "自动" or "手动"))
        return
    end

    -- +/-键：调整自动模式速度
    if key == "=" or key == "+" or key == "kp+" then
        Game.set_auto_speed(1.0)
        print("速度设为正常")
        return
    end

    if key == "-" or key == "kp-" then
        Game.set_auto_speed(2.0)
        print("速度设为慢速")
        return
    end

    if key == "0" then
        Game.set_auto_speed(0.1)
        print("速度设为快速")
        return
    end

    -- B键：购买地块
    if key == "b" then
        Game.buy_property()
        return
    end

    -- U键：升级地块
    if key == "u" then
        Game.upgrade_property()
        return
    end

    -- S键：跳过当前操作
    if key == "s" then
        Game.skip_action()
        return
    end

    -- Y/N键：选择是/否
    if key == "y" then
        if Game.choose_yes then
            Game.choose_yes()
        end
        return
    end

    if key == "n" then
        if Game.choose_no then
            Game.choose_no()
        end
        return
    end

    -- H键：显示帮助
    if key == "h" then
        print("=== 游戏操作帮助 ===")
        print("A - 切换自动/手动模式")
        print("空格 - 手动模式下推进游戏")
        print("B - 购买当前地块")
        print("U - 升级当前地块")
        print("S - 跳过当前操作")
        print("+ - 正常速度")
        print("- - 慢速")
        print("0 - 快速")
        print("H - 显示帮助")
        print("ESC - 退出游戏")
        return
    end

    -- 未处理的按键，输出调试信息
    print("未绑定的按键: " .. tostring(key))
end

return input
