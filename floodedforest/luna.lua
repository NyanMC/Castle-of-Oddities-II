uniquePanicMusic = false

require("switch").setMaxTime(120)

function onStart()
    changeWindowName("Hitting floating blocks in the")
end

function onTick()
    for i,v in ipairs(NPC.get()) do
        v.despawnTimer = 9001
    end
end