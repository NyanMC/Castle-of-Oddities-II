hasWorld5EscapeMusic = true
uniquePanicMusic = false
doHurtEffects = false
currentlyBoss = true
scoreMult = 3

require("switch").setMaxTime(20)

local warioHealth = require("warioHealth")

warioHealth.HPCap = 6
warioHealth.startingHP = 6
warioHealth.forceHP = true
warioHealth.workAllChars = true
warioHealth.coinBarToggle = false

function onStart()
    SaveData.warioHP = warioHealth.HPCap
    changeWindowName("The journey's climax in the")
end