require("switch").setMaxTime(45)

function onStart()
    changeWindowName("A flooded cavern in the")
end

function onEvent(name)
    if (name == "drain") then
        changeWindowName("A drained cavern in the")
        local sect = Section(0)
        sect.isUnderwater = false
        sect.effects.screenEffect = SEFFECT_NONE

        for i,v in pairs(NPC.get({236, 386})) do
            v:kill()
        end
    end
end