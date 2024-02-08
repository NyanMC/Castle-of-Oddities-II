require("switch").setMaxTime(60)

function onStart()
    wariodashing.blacklistNPC(284) -- SMW lakitu
    changeWindowName("A calm mountain in the")
end

function onLoadSection1()
    Section(0).musicPath = "cloudy_climb/tornado.ogg"
    changeWindowName("Facing terrible weather in the")
end