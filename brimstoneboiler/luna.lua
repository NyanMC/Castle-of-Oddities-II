hasWorld5EscapeMusic = true
uniquePanicMusic = false

require("switch").setMaxTime(120)

burning = require("transformation_burning")

function onStart()
    changeWindowName("It's so unbearably hot in the")
    Defines.weak_lava = true
end