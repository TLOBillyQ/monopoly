-- Input handling module

local Input = {}

function Input.handleKey(key, Game)
    if key == "escape" then
        love.event.quit()
        return
    end

    if key == "space" then
        Game.advance()
        return
    end

    if key == "y" then
        Game.chooseYes()
        return
    end

    if key == "n" then
        Game.chooseNo()
        return
    end
end

return Input
