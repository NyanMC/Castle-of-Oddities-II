local powerupStates = table.map{
    FORCEDSTATE_POWERUP_BIG,FORCEDSTATE_POWERDOWN_SMALL,FORCEDSTATE_POWERUP_FIRE,FORCEDSTATE_POWERUP_LEAF,FORCEDSTATE_POWERUP_TANOOKI,
    FORCEDSTATE_POWERUP_HAMMER,FORCEDSTATE_POWERUP_ICE,FORCEDSTATE_POWERDOWN_FIRE,FORCEDSTATE_POWERDOWN_ICE,FORCEDSTATE_MEGASHROOM,
}

require("switch").setMaxTime(100)

function onStart()
    changeWindowName("Infiltrating desert tanks in the")
end

function onTick()
    Defines.levelFreeze = (powerupStates[player.forcedState] or mem(0x00B2C62E,FIELD_WORD) > 0)
end

function onLoadSection0()
    changeWindowName("Infiltrating desert tanks in the")
end

function onLoadSection1()
    changeWindowName("It's the Toad hour again in the")
    Section(0).musicPath = "aridsandscape/wildstyle_pistolero.ogg"
end