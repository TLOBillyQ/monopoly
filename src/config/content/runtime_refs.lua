local refs = {}

refs.images = {
    -- AI 头像
    ["AI1"] = 1770400215,
    ["AI2"] = 1842528546,
    ["AI3"] = 1779938314,
    ["AI4"] = 1657905732,

    -- skin
    ["5001"] = 1625626309,
    ["5002"] = 1664857351,
    ["5003"] = 1686351773,
    ["5004"] = 1676356936,
    ["5005"] = 1799342735,
    ["5006"] = 1772857142,

    -- 自带资源
    ["Empty"] = 16208,
    -- 道具卡
    ["2001"] = 1730173258,
    ["2002"] = 1869270079,
    ["2003"] = 1859579308,
    ["2004"] = 1658935810,
    ["2005"] = 1677722781,
    ["2006"] = 1757144381,
    ["2007"] = 1767508539,
    ["2008"] = 1852170293,
    ["2009"] = 1834133244,
    ["2010"] = 1809142368,
    ["2011"] = 1785777241,
    ["2012"] = 1773839994,
    ["2013"] = 1842841196,
    ["2014"] = 1842468460,
    ["2015"] = 1865401085,
    ["2016"] = 1750629837,
    ["2017"] = 1795346303,
    ["2018"] = 1825434656,
    ["2019"] = 1782763968,

    -- 机会卡
    ["3001"] = 1699803985,
    ["3002"] = 1797426152,
    ["3003"] = 1686860744,
    ["3004"] = 1658996113,
    ["3005"] = 1815746155,
    ["3006"] = 1655942628,
    ["3007"] = 1698067311,
    ["3008"] = 1875950072,
    ["3009"] = 1612100495,
    ["3010"] = 1744590258,
    ["3011"] = 1689754490,
    ["3012"] = 1671256992,
    ["3013"] = 1798850449,
    ["3014"] = 1714149459,
    ["3015"] = 1727970747,
    ["3016"] = 1684729430,
    ["3017"] = 1715616338,
    ["3018"] = 1657612711,
    ["3019"] = 1738712194,
    ["3020"] = 1775988476,
    ["3021"] = 1745476610,
    ["3022"] = 1651781854,
    ["3023"] = 1675247082,
    ["3024"] = 1623305436,
    ["3025"] = 1741360853,
    ["3026"] = 1869906820,
    ["3027"] = 1726387111,
    ["3028"] = 1860319285,
    ["3029"] = 1826780275,
    ["3030"] = 1817901049,
    ["3031"] = 1719548096,
    ["3032"] = 1708881239,
    ["3033"] = 1704030257,
    ["3034"] = 1863582123,
    ["3035"] = 1720310934,
    ["3036"] = 1730625745,
    ["3037"] = 1622750435,
}

refs.audio = {
-- 音效资源 ID 来自策划原稿抽取。
    cash_receive = 3814,
    mountain_stun = 5112,
    hospital_shock = 5112,
    mine_blast = 5112,
    tax_wave = 5112,
    move_step_pounce = 5083,
    bankruptcy_slam = 4232,
    generic_negative = 5112,
    turn_started = 4233,
}

refs.effects = {
-- 特效资源 ID 来自策划原稿抽取。
    item_stop_highlight = 2346,
    upgrade_land_smoke = 4286,
    cash_burst = 3414,
    mountain_stun = 1973,
    hospital_shock = 4185,
    mine_blast = 1288,
    tax_wave = 2165,
    rich_deity = 4845,
    angel_deity = 2359,
    bankruptcy_slam = 4278,
}

refs.board_feedback = {
    item_stop_highlight = {
        effect_id_ref = "item_stop_highlight",
        scale = 1.8,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
    },
    upgrade_land_smoke = {
        effect_id_ref = "upgrade_land_smoke",
        sound_id_ref = "cash_receive",
        scale = 3.0,
        duration = 1.0,
        volume = 1.0,
        followup_sounds = {
            { delay = 0.6, sound_id_ref = "turn_started", duration = 1.0, volume = 1.0 },
        },
        allow_missing_resource = true,
    },
    cash_burst = {
        effect_id_ref = "cash_burst",
        sound_id_ref = "cash_receive",
        scale = 1.6,
        duration = 0.6,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_cash_fx_head_offset",
        allow_missing_resource = true,
    },
    mountain_stun = {
        effect_id_ref = "mountain_stun",
        sound_id_ref = "mountain_stun",
        scale = 1.6,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
    },
    hospital_shock = {
        effect_id_ref = "hospital_shock",
        sound_id_ref = "hospital_shock",
        scale = 1.8,
        duration = 1.2,
        volume = 1.0,
        allow_missing_resource = true,
    },
    mine_blast = {
        effect_id_ref = "mine_blast",
        sound_id_ref = "mine_blast",
        scale = 2.0,
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
    },
    tax_wave = {
        effect_id_ref = "tax_wave",
        sound_id_ref = "tax_wave",
        scale = 1.6,
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
    },
    rich_deity = {
        effect_id_ref = "rich_deity",
        scale = 1.4,
        duration = 2.0,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_one",
        allow_missing_resource = true,
    },
    angel_deity = {
        effect_id_ref = "angel_deity",
        scale = 1.4,
        duration = 2.0,
        volume = 1.0,
        bind_to_player = true,
        socket_name = "Bip001",
        bind_offset = "v3_one",
        allow_missing_resource = true,
    },
    move_step_pounce = {
        sound_id_ref = "move_step_pounce",
        duration = 0.4,
        volume = 0.9,
        allow_missing_resource = true,
    },
    bankruptcy_slam = {
        effect_id_ref = "bankruptcy_slam",
        sound_id_ref = "bankruptcy_slam",
        duration = 1.0,
        volume = 1.0,
        allow_missing_resource = true,
    },
    generic_negative = {
        sound_id_ref = "generic_negative",
        duration = 0.8,
        volume = 1.0,
        allow_missing_resource = true,
    },
    turn_started = {
        sound_id_ref = "turn_started",
        duration = 0.8,
        volume = 1.0,
        allow_missing_resource = true,
    },
}

refs.skins = {
    ["5001"] = 1073897515,
    ["5002"] = 1073868867,
    ["5003"] = 1073913977,
    ["5004"] = 1073905737,
    ["5005"] = 1073909878,
    ["5006"] = 1073901580,
}

-- 兼容兜底：宿主没有 reset_model 时，脱下皮肤才退回这个默认 creature key。
refs.default_creature = 1

refs.synthetic_ai = {
    names = {
        [1] = "红绒绒",
        [2] = "黄澄澄",
        [3] = "蓝盖盖",
        [4] = "紫圈圈",
    },
    unit_keys = { 9000601, 9000602, 9000603, 9000604, 9000605, 9000607 },
}

return refs

--[[ mutate4lua-manifest
version=2
projectHash=660dd07f4f8494fd
scope.0.id=chunk:src/config/content/runtime_refs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=237
scope.0.semanticHash=36a839dbd81b0131
]]
