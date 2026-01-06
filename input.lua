-- Input handling module

local Input = {}

function Input.handleKey(key, Game)
    if not key then return end
    key = string.lower(key)
    print("Key pressed: " .. tostring(key))

    -- 如果正在等待确认，优先处理确认键
    if Game.isWaitingForInput and Game.isWaitingForInput() then
        if key == "y" or key == "return" or key == "kpenter" or key == "space" then
            if Game.chooseYes then Game.chooseYes() end
            return
        end
        if key == "n" or key == "escape" or key == "backspace" then
            if Game.chooseNo then Game.chooseNo() end
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
        if not Game.isAutoMode() then
            Game.nextStep()
        end
        return
    end
    
    -- A键：切换自动/手动模式
    if key == "a" then
        local isAuto = Game.toggleAutoMode()
        print("游戏模式: " .. (isAuto and "自动" or "手动"))
        return
    end
    
    -- +/-键：调整自动模式速度
    if key == "=" or key == "+" or key == "kp+" then
        Game.setAutoSpeed(1.0)
        print("速度设为正常")
        return
    end
    
    if key == "-" or key == "kp-" then
        Game.setAutoSpeed(2.0)
        print("速度设为慢速")
        return
    end
    
    if key == "0" then
        Game.setAutoSpeed(0.1)
        print("速度设为快速")
        return
    end

    -- B键：购买地块
    if key == "b" then
        Game.buyProperty()
        return
    end
    
    -- U键：升级地块
    if key == "u" then
        Game.upgradeProperty()
        return
    end
    
    -- S键：跳过当前操作
    if key == "s" then
        Game.skipAction()
        return
    end

    -- Y/N键：选择是/否
    if key == "y" then
        if Game.chooseYes then
            Game.chooseYes()
        end
        return
    end

    if key == "n" then
        if Game.chooseNo then
            Game.chooseNo()
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

return Input
