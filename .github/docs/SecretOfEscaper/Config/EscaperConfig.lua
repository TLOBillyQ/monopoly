
---@type table<EscaperCode, EscaperConfig>
local EscaperConfig = {
    ["miner"] = {
        id = 1073995779,
        name = "卢修斯",
        job = "矿工",
        introduce = ("卢修斯拥有丰富的探宝经验，他擅长使用各种工具和设备来寻找宝藏。(#c%s（带上铲子效果更佳哦）#l)"):format("ff0000"),
        icon = 1620946393,
        ability = {
            [1] = "treasure_hunt",
            [2] = "treasure_bonus",
        }
    },
    ["hunter"] = {
        id = 1073991740,
        name = "亨特",
        job = "猎人",
        introduce = ("亨特喜欢把玩各种枪械，相比其他人，它的猎枪会更加精准。#c%s（请记得携带枪械）#l"):format("ff0000"),
        icon = 1861498978,
        ability = {
            [1] = "dragon_breath_loading",
            [2] = "precision_shooting",
        }
    }
}

return EscaperConfig