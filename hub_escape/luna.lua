local switch = require("switch")

switch.shouldPause = false
switch.setMaxTime(210)

function onStart()
    switch.activate(30, 30, 761)
    changeWindowName("We bid farewell to the")
    require("antizip").enabled = false
end