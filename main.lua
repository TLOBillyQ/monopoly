package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

local LoveLayer = require("src.ui.love_layer")

LoveLayer.new():attach()
