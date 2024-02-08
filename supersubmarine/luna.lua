local switch = require("switch")

uniquePanicMusic = false
currentlyBoss = true

switch.shouldPause = false
switch.setMaxTime(80)

function onStart()
    switch.activate(30, 30, 761)
    if not Misc.inMarioChallenge() then
        Misc.score(4000)
    end
    changeWindowName("I'll build myself a getaway submarine in the")
end