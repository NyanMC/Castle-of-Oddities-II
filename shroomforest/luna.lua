require("spawnzones")

uniquePanicMusic = false -- use speed jungle 2 even in the panic escape

require("switch").setMaxTime(120)

function onStart()
    changeWindowName("A guest appearance in the")
end

function onLoadSection1()
    Section(0).musicPath = "shroomforest/speed_jungle_sonic.ogg"
    Section(2).musicPath = "shroomforest/speed_jungle_sonic.ogg"
end