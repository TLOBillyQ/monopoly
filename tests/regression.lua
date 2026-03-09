local bootstrap = require("tests.bootstrap")
local behavior = require("tests.behavior")
local contract = require("tests.contract")
local guard = require("tests.guard")

bootstrap.install_package_paths()

behavior.run()
contract.run()
guard.run()
