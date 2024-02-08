-- Prints a random gag message to the fourthwall console for players that use it.
-- Cheated cookies taste awful!

local cheatedcookies = {}

local rng = require("base/rng")

local gagTexts = {
	"Remember, cheated points taste awful!\nI mean, regular points probably do too, but...\nYou get what I mean!",
	"Lua execution? In MY episode?\nIt's more likely than you think.",
	"9 out of 10 episodes recommend against\nthe use of cheats.",
	"Guess I'm calling the repairman to\nfix the fourth wall you just broke.",
	"ChromaNyan will remember that.",
	"Cheats are not enabled on this server.",
	"Cheats detected. Erasing save file...",
	"Snooping as usual, I see!"
}

function cheatedcookies.tasteAwful()
	return GameData._cheatedcookies == true
end

local function shouldPrint()
	return not cheatedcookies.tasteAwful()
		and not Misc.inMarioChallenge()
		and Defines.player_hasCheated
end

local function fancyPrint(str)
	if str == nil then
		str = ""
	end
	if str:find("\n") then
		for k,v in ipairs(str:split("\n")) do
			print(v)
		end
	elseif str then
		print(str)
	end
end

function cheatedcookies.onInitAPI()
	registerEvent(cheatedcookies, "onStart")
end

function cheatedcookies.onStart()
	if shouldPrint() then
		fancyPrint(gagTexts[rng.randomInt(1,#gagTexts)])
		fancyPrint("Nah, I'm just kidding. Use this menu all you\nwant, if you can get any use out of it.")
		GameData._cheatedcookies = true
	end
end

return cheatedcookies