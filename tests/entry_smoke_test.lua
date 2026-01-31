dofile("tests/test_bootstrap.lua")

local Entry = require("Manager.GameManager.Entry")

assert(type(Entry.install) == "function", "Entry.install should exist")

print("ok - entry load")
