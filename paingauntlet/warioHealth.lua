--[[
					warioHealth.lua by MrNameless
				A library that gives (basegame) Wario his own 
				  unique health system & some extra stuff.
			
	CREDITS:
	cl.exe - ripped the Wario Land 4 UI sprites used in this library (https://www.spriters-resource.com/game_boy_advance/wl4/sheet/19794/)
	King_Harkinian - ripped the Wario Land 4 SFXs used in this library (https://www.sounds-resource.com/game_boy_advance/warioland4/) 
	
	TO DO:
	-Improve how this is programmed whenever I rewrite this one day. Seriously, this code looks extremely sloppy.
	
	Note: this library was not tested much with other libraries in mind so be careful!
	Another Note: this library wasn't tested much with the other X2 characters aswell!
	
	Version 1.0.0 (Hopefully, this is a somewhat less bad version of the script now.)
]]--

-- respawn rooms stuff --
local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)
respawnRooms = respawnRooms or {}
-------------------------

local warioHealth = {}

-- configurable settings --
warioHealth.HPCap = 3 -- what is the maximum health possible for wario to have? (3 by default, maximum of 8 only.)
warioHealth.startingHP = 2 -- how much health should wario start out with? (2 by default)
warioHealth.forceStartingHP = false -- should wario always be forced to start out with whatever the startingHP is set to (false by default)
warioHealth.coinBarToggle = true -- should wario have a mini bar that gives him 1 health everytime he collects enough coins (true by default)
warioHealth.smallOnLow = false -- should wario become small whenever he has one health left? (false by default)
warioHealth.beepOnLow = true -- should there be a constant beeping sound whenever wario has one health left? (true by default)
warioHealth.hurtKnockback = false -- should wario take a bit of knockback upon getting hurt? (true by default)
warioHealth.keepReserveBox = false -- should wario be able to store backup items like how mario & luigi could? (false by default)
warioHealth.workAllChars = false -- should this script be usable with ALL characters aside from Wario? (false by default)
---------------------------

SaveData.warioHP = SaveData.warioHP or 0
warioHealth.powerupIDs = table.map{9,14,34,169,170,182,183,184,185,249,250,264,277,462}
warioHealth.coinIDs = table.map{10,33,88,103,138,152,251,252,253,258,274,411}
local heartChars = table.map{3,4,5,9,11}
local miscChars = table.map{8,14}
local singleCoiners = table.map{1,3,7,10,11,15} --table.map{2,4,5,6,8,9,12,13,14,16} -- 
local heartIMG = nil

local coinBar = 0
local coinsCollected = 0
local lowHPOffset = 1
local beepTimer = 64
local healthOffsetX = 5
local healthOffsetY = 0

local HPBar = Graphics.loadImage(Misc.resolveFile("warioHealth/warioHPBar.png")) -- graphic used for wario's health bar
local RegenBar = Graphics.loadImage(Misc.resolveFile("warioHealth/warioRegenBar.png")) -- graphic used for wario's HP regen bar
local coinMin = Misc.resolveFile("warioHealth/regen_mini.ogg") -- sound used when wario collects 2 coins to fill up the regen bar
local coinFull = Misc.resolveFile("warioHealth/regen_full.ogg") -- sound used when wario gains a heart
local lowHPBeep = Misc.resolveFile("warioHealth/hp_low.ogg") -- sound used when wario is at one health remaining.
local nothingness = Graphics.loadImageResolved("stock-0.png") -- graphic used to hide the reserve box


local function coinRegen(amount) -- for loop handles coinBar filling
	for i=1,amount,1 do
		if coinBar <= 7 then
			coinBar = coinBar + 1
			SFX.play(coinMin)
		else
			if SaveData.warioHP >= warioHealth.HPCap then 
				coinBar = 8 
			else
				if player.powerup == 1 and player.forcedState == 0 then 
					player.forcedState = 2
					player.forcedTimer = 999
					player:mem(0x140, FIELD_WORD, 50)
					SFX.play(6)
				end
				SaveData.warioHP = SaveData.warioHP + 1
				SFX.play(coinFull)
				coinBar = 0 
			end
		end
	end	
	coinsCollected = 0
end

function warioHealth.onInitAPI()
	registerEvent(warioHealth, "onStart")
	registerEvent(warioHealth, "onTickEnd")
	registerEvent(warioHealth, "onDraw")
	registerEvent(warioHealth, "onBlockHit")
	registerEvent(warioHealth, "onPlayerHarm")
	registerEvent(warioHealth, "onPostNPCCollect")
	registerEvent(warioHealth, "onPlayerKill")
end


function warioHealth.onStart()
	if SaveData.warioHP <= 0 or warioHealth.forceStartingHP then SaveData.warioHP = warioHealth.startingHP end
	if warioHealth.startingHP <= 1 and warioHealth.smallOnLow and SaveData.warioHP <= 0 and (player.character == CHARACTER_WARIO and not warioHealth.workAllChars) then
		player.powerup = 1
	end
end


function warioHealth.onTickEnd()
	if player.deathTimer > 0 then return end
	if player.character ~= CHARACTER_WARIO and not warioHealth.workAllChars then return end 
	if SaveData.warioHP > warioHealth.HPCap then SaveData.warioHP = warioHealth.HPCap end -- failsafe if wario somehow has more health than the set HP cap.
	if (not warioHealth.smallOnLow or SaveData.warioHP > 1) and player.powerup == 1 and player.forcedState == 0 then --failsafe if wario is still small despite having more than 1 health
		player.powerup = 2
	end
	
	if (not warioHealth.keepReserveBox and not miscChars[player.character]) or heartChars[player.character] then -- hides reserve box when keeping the reserve box option off or when playing a "Hearts" system character.
		player.reservePowerup = 0 	
		healthOffsetX = 5
		healthOffsetY = 0
		Graphics.sprites.hardcoded["48-0"].img = nothingness
	else -- shows reserve box & lowers the health bar if the conditions above aren't met.
		healthOffsetX = -4
		healthOffsetY = 55
		Graphics.sprites.hardcoded["48-0"].img = nil
	end
	
	if warioHealth.workAllChars and heartChars[player.character] then -- handles hiding the SMB2 hearts when the characters that have them are allowed to use the script.
		heartIMG = nothingness
	else
		heartIMG = nil
	end

	if SaveData.warioHP > 1 then beepTimer = 64 lowHPOffset = 1 return end

	beepTimer = beepTimer + 1
	-- chunk that handles beeping & animating the heart whenever on low health --
	if beepTimer == 65 then
		if warioHealth.beepOnLow then SFX.play(lowHPBeep) end
		beepTimer = 0
		lowHPOffset = -1
	elseif beepTimer == 33 then
		lowHPOffset = 1
	end
	-- end of chunk --
end

function warioHealth.onDraw()
	if player.character ~= CHARACTER_WARIO and not warioHealth.workAllChars then Graphics.sprites.hardcoded["48-0"].img = nil return end
	if not Graphics.isHudActivated() then return end
	for i=1,2,1 do
		Graphics.sprites.hardcoded["36-".. tostring(i)].img = heartIMG
	end
	Graphics.draw{
		type = RTYPE_IMAGE,
		image = HPBar,
		priority = 5,
		x = (344 + healthOffsetX) + (56.875 - (6.875 * warioHealth.HPCap)),		-- 340 + (8 * warioHealth.HPCap),--468 - (16 * warioHealth.HPCap), -- 340 originally
		y = 27 + healthOffsetY,
		sourceWidth = 16  * warioHealth.HPCap,
		sourceHeight = 14,
		sourceY = 14 * (SaveData.warioHP + lowHPOffset),
	}
	if not warioHealth.coinBarToggle then return end
	Graphics.draw{
		type = RTYPE_IMAGE,
		image = RegenBar,
		priority = 5,
		x = (348 + healthOffsetX),
		y = 43 + healthOffsetY,
		sourceHeight = 12,
		sourceY = 12 * coinBar,
	}
end

function warioHealth.onBlockHit(token,v,above,p)
	if not p then return end
	if (p.character ~= CHARACTER_WARIO and not warioHealth.workAllChars) or not warioHealth.coinBarToggle then return end
	if not singleCoiners[p.character] then return end
	if token.cancelled or v.contentID == 0 or v.contentID > 99 then return end

	coinsCollected = coinsCollected + 1
	if coinsCollected == 2 then
		coinRegen(1)
	end
end

function warioHealth.onPlayerHarm(token,p)
	if require("transformation_burning").isBurning then -- added by ChromaNyan; cancels this event if the player is burning
		p:mem(0x140, FIELD_WORD, 150)
		return
	end

	if p.character ~= CHARACTER_WARIO and not warioHealth.workAllChars then return end
	SaveData.warioHP = SaveData.warioHP - 1
	
	if coinBar >= 8 and SaveData.warioHP >= (warioHealth.HPCap - 1) then -- forces the coinBar to give a heart if both it & the health bar are full.
		SaveData.warioHP = SaveData.warioHP + 1
		SFX.play(coinFull)
		coinBar = 0 
	end
	
	if SaveData.warioHP <= 0 then 
		p:kill() return
	elseif SaveData.warioHP == 1 and warioHealth.smallOnLow then 
		p.powerup = 1
		SFX.play(5)
	elseif player.powerup > 2 then
		p.powerup = 2
		SFX.play(5)
	end
	
	if warioHealth.hurtKnockback == true then
		p.speedX = -4 * player.direction
		p.speedY = -4
	end
	p:mem(0x140, FIELD_WORD, 150) -- this also somehow cancels the harm event so no token needed here.
	SFX.play(76)
end

function warioHealth.onPostNPCCollect(v,p)
	if player.character ~= CHARACTER_WARIO and not warioHealth.workAllChars then return end
	if p.idx ~= 1 then return end
	if warioHealth.coinIDs[v.id] and warioHealth.coinBarToggle then
		coinsCollected = coinsCollected + 1
		if v.id == 252 or v.id == 258 then
			coinRegen(2)
		elseif v.id == 253 then
			coinRegen(4)
		end
		if coinsCollected == 2 then
			coinRegen(1)
		end
	end
	
	if warioHealth.powerupIDs[v.id] then
		p.forcedTimer = 9999 -- used to skip the transformation states of the mushroom & fire/ice flowers.
		if v:mem(0x138, FIELD_WORD) == 2 then return end
		if SaveData.warioHP >= warioHealth.HPCap then return end
		SaveData.warioHP = SaveData.warioHP + 1
		SFX.play(coinFull) 
 	end
end
	
function warioHealth.onPlayerKill()
	if player.character ~= CHARACTER_WARIO and not warioHealth.workAllChars then return end
	SaveData.warioHP = 0
	coinsCollected = 0
	beepTimer = -100
	lowHPOffset = 1 
end

function respawnRooms.onPreReset(fromRespawn) -- respawnRooms compatiblity stuff
	if fromRespawn then
		warioHealth.onStart()
		coinBar = 0
		beepTimer = 64
	end
end

return warioHealth