local textplus = require("textplus")
local pauseMenu = require("pauseMenu")
local hudoverride = require("hudoverride")
local starcoin = require("npcs/ai/starcoin")

local littleDialogue = require("littleDialogue")

local scoreFont = textplus.loadFont("1.ini")
local numberFont = textplus.loadFont("11.ini")

local totalscore = 0

local scoreWalls = {
    w2barrier = 30000,
    w3barrier = 100000,
    w4barrier = 175000,
    w5barrier = 250000
}

local funEvents = {
    {event = "fun1", min = 1, max = 7},
    {event = "fun2", min = 8, max = 12}
}

pauseMenu.options = {
	{name = "Resume",     action = pauseMenu.Resume,    confirm = false, text = "lol"},
	{name = "Unstuck",    action = pauseMenu.Restart,   confirm = true,  text = "This will send you to the castle entrance."},
	{name = "Save Game", action = pauseMenu.Save,   confirm = false, text = "lol"},
	{name = "Exit Game",  action = pauseMenu.Quit,      confirm = true,  text = "This will quit the game. Your progress will be saved."}
}

local function validCoin(t, i)
	return t[i] and (not t.alive or t.alive[i])
end
--[[
    we need our own copy of this function and getEpisodeCollected
    because the basegame ones count weak collected star coins for some reason
]]
local function getLevelCollected(name)
	local list = starcoin.getLevelList(name)
	local LtotalNum = 0
	for i = 1,list.maxID do
		if validCoin(list,i) and list[i] == 1 then
			LtotalNum = LtotalNum + 1
		end
	end
	return LtotalNum
end

local function getEpisodeCollected()
	local GtotalNum = 0
	for k in pairs(SaveData._basegame.starcoin) do
		GtotalNum = GtotalNum + getLevelCollected(k)
	end
	return GtotalNum
end

function onStart()
    for i,v in pairs(SaveData.topscores) do
        totalscore = totalscore + v
    end
    Progress.value = totalscore
    hudoverride.visible.score = false

    for i,v in pairs(scoreWalls) do
        if totalscore >= v then
            Layer.get(i):hide(true)
        end
    end

    -- hardcoded this check because i'm lazy
    if totalscore >= 175000 then
        Section(1).musicPath = "hub/bowsers_castle_b.mp3"
    end

    for i,v in pairs(funEvents) do
        if (SaveData.fun >= v.min and SaveData.fun <= v.max) or SaveData.fun > 100 then
            triggerEvent(v.event)
        end
    end

    if require("cheatedcookies").tasteAwful() then
        Layer.get("cheatedcookies"):show(true)
    end

    changeWindowName("Inside the walls of the")
end

function onDraw()
    local sparse = textplus.parse("<emoji letterp.png> "..tostring(totalscore), {font = scoreFont, xscale = 1, yscale = 1})
    local slayout = textplus.layout(sparse)
    textplus.render({x = ((camera.width / 2) - slayout.width * 0.5), y = 40, layout = slayout})

    sparse = textplus.parse("<emoji starcoin.png> "..tostring(getEpisodeCollected()), {font = scoreFont, xscale = 1, yscale = 1})
    slayout = textplus.layout(sparse)
    textplus.render({x = ((camera.width / 2) - slayout.width * 0.5), y = 60, layout = slayout})

    local intersecting = Warp.getIntersectingEntrance(player.x, player.y, player.x + player.width, player.y + player.width)[1]

    if intersecting then
        local levelfilename = intersecting.levelFilename
        if levelfilename ~= "" then
            local rparse = textplus.parse("TOP: "..tostring(SaveData.topscores[levelfilename] or 0), {font = numberFont, xscale = 2, yscale = 2})
            local rlayout = textplus.layout(rparse)
            textplus.render({x = ((player.x + (player.width / 2)) - rlayout.width * 0.5), y = player.y - 60, layout = rlayout, sceneCoords = true})

            local starcoinList = starcoin.getEpisodeList()[levelfilename]

            if starcoinList then
                local starcoinString = ""

                for i = 1, starcoinList.maxID do
                    if validCoin(starcoinList,i) then
                        if starcoinList[i] == 1 then
                            starcoinString = starcoinString.."<emoji starcoin.png>"
                        else
                            starcoinString = starcoinString.."<emoji starcoin_missing.png>"
                        end
                    end
                end


                local rparse = textplus.parse(starcoinString, {font = numberFont, xscale = 2, yscale = 2})
                local rlayout = textplus.layout(rparse)
                textplus.render({x = ((player.x + (player.width / 2)) - rlayout.width * 0.5), y = player.y - 40, layout = rlayout, sceneCoords = true})
            end
        end
    end
end

local function getFunResponse()
    if SaveData.fun > 100 then
        return "Your FUN...is out of this world! <tremble 1>How did this even happen?!</tremble>"
    elseif SaveData.fun <= 0 then
        return "Your FUN...is nonexistent.<br><size 0.5>How boring... You're no FUN.</size>"
    else
        return "Your FUN...yes, I see it. Your FUN is "..SaveData.fun.."!"
    end
end

littleDialogue.registerAnswer("funQuestion",{text = "Tell me more!",addText = "FUN... the Fated Universal Number. Every time an adventure begins, this number is shuffled around.<page>Specific values can cause talkative folks to act differently. Perhaps even new ones will show up, who knows?"})
littleDialogue.registerAnswer("funQuestion",{text = "What is my FUN?",addText = getFunResponse()})

if SaveData.fun > 0 then
    littleDialogue.registerAnswer("funQuestion",{text = "I hate FUN! Get rid of it!",addText = ".<delay 64>.<delay 64>.<delay 64>Very well. Away it goes!",chosenFunction = function()
        SaveData.fun = 0
        Level.load()
    end})
end