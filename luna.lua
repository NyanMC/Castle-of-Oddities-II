local hudoverride = require("hudoverride")
local littleDialogue = require("littleDialogue")
local hudoverride = require("hudoverride")
local switch = require("switch")
local az = require("antizip")
local rng = require("rng")
local pauseMenu = require("pauseMenu")

local newcheats = require("base/game/newcheats")

require("cheatedcookies")

wariorolling = require("wariorolling")
wariodashing = require("wariodashing")
dashattacking = require("wariodashattacking")

burning = require("transformation_burning")
bouncing = require("transformation_bouncing")

Player.setCostume(1,"wario",true)

currentlyBoss = false
isPanic = false
uniquePanicMusic = true
isMetal = false

local windowNamePrefix = nil

SaveData.fun = SaveData.fun or math.random(1, 100)

SaveData.topscores = SaveData.topscores or {}

local function kickIfOutdated()
    if SMBX_VERSION == VER_BETA4_PATCH_4_1 then
        Misc.richDialog(
            "HEY!",
            "You're on an outdated version of the game!",
            "Update to Beta 5 to play this episode!",
            "I repeat, THIS WILL NOT WORK ON BETA 4!",
            true
        )
        Misc.exitEngine()
    end
end

function getWindowName()
    if windowNamePrefix and windowNamePrefix ~= "" then
        return windowNamePrefix.." Castle of Oddities II"
    end
    return "Castle of Oddities II"
end

function changeWindowName(newName)
    windowNamePrefix = newName
    Misc.setWindowTitle(getWindowName())
end

function onStart()

    kickIfOutdated()

	--wariodashing.blacklistBlock(293)	-- STRONG SMB2-Bricks (not breakable anymore)
	--wariodashing.whitelistBlock(124)	-- weak Ghost House Blocks (breakable)
	--wariodashing.whitelistNPC()	-- weak whatever you put in (hittable)
	--wariodashing.blacklistNPC(1)	-- STRONG GOOMBA (not hittable anymore)
	
	wariodashing.whitelistCharacter(1,"shoulderbashingframes.png")
	dashattacking.whitelistCharacter(1,"dashattackingframes.png")
	wariorolling.whitelistCharacter(1,"rollingframes.png")
	bouncing.whitelistCharacter(1,"bouncingframes.png")
	burning.whitelistCharacter(1,"burningframes.png","ashesrisingframes.png")
	
	burning.addFireStarterNPC(307) 	-- firesnake (all of these don't hurt Wario but make him start burning instead)
	burning.addFireStarterNPC(308) 	-- firesnake trail
	burning.addFireStarterNPC(358)	-- Hopping Flame
	burning.addFireStarterNPC(359)	-- and its tail
	burning.addFireStarterNPC(390) 	-- enemy fireball
	burning.addFireStarterNPC(402)	-- Hot Foot
	burning.addFireStarterNPC(260)	-- Firebar
	burning.addFireStarterNPC(384) 	-- dino torch fire horizontal
	burning.addFireStarterNPC(385) 	-- dino torch fire vertical
	
	burning.addFireStarterBlock(1151)	-- hot block
	
	burning.addFlammableBlock(280)	-- red Block (will break when Wario is fully burning and touching it)
	
	burning.addUltraflammableBlock(620) -- frozen coin (will break when run into)
	
	bouncing.addBouncingStarterNPC(617)	-- hammer bro hammers make you bounce now
	bouncing.addBouncingStarterNPC(37)	-- test
	bouncing.addBouncingStarterBlock(630)	-- Stone ball (the thing the roto disks move around)

	hudoverride.visible.itembox = false
    hudoverride.visible.lives = false
    hudoverride.visible.coins = false
    if not Misc.inMarioChallenge() then
        Misc.score(Misc.score() * -1)
        Misc.coins(Misc.coins() * -1)
        mem(0x00B2C5AC, FIELD_FLOAT, 99)
        Misc.setWindowTitle(getWindowName())
    end
end

function onExit()
    player.character = 1 -- we need to do this on exit and not on start otherwise funky behavior happens with wario when restarting guest character levels
    player.powerup = 2
end

function onTick()
	player:mem(0x160, FIELD_WORD, 10)
	if player.powerup == 1 then player.powerup = 2 end
    if Misc.coins() >= 99 then
        Misc.warn("Coin count reached or exceeded 99, consider reducing concentration of coins")
    end
	if Misc.coins() > 25 then -- player has a lot of coins, turn them into points faster to avoid risk of overflowing into a 1-up
		Misc.coins(-5)
        if not isPanic then
            Misc.score(50)
        else
            Misc.score(100)
        end
    elseif Misc.coins() > 0 then
        Misc.coins(-1)
        if not isPanic then
            Misc.score(10)
        else
            Misc.score(20)
        end
    end



    if player.character ~= CHARACTER_MARIO then -- this is stupid
        Defines.jumpheight = 20 -- the costume.lua file doesn't do its job correctly so i have to hardcode the character cleanup here
        Defines.jumpheight_bounce = 20

        player:mem(0x16, FIELD_WORD, 3) -- because of course i have to access this with memory offsets
    end
end

function onPostPlayerHarm(harmedplayer)
    if Misc.inMarioChallenge() then
        harmedplayer:kill()
    end
    if Misc.score() >= 2000 then
        Misc.score(-2000)

        for i=1,10 do
            local newCoin = NPC.spawn(787, player.x + 0.5 * player.width, player.y + 0.5 * player.height, player.section, false, true)
            newCoin.speedX = rng.random(-10,10)
            newCoin.speedY = rng.random(-10,-5)
        end
    else
        Misc.score(Misc.score() * -1)
        if currentlyBoss then
            harmedplayer:kill()
            return
        end
    end
    if player.character == CHARACTER_MARIO then
        local rand = math.random(1, 3)
        SFX.play(Misc.resolveFile("no_"..rand..".wav"))
    end
end

function onPlayerHarm(token, p)
    if (isMetal) then
        token.cancelled = true
    end
end

function onPlayerKill(token, p)
    if not currentlyBoss then
        token.cancelled = true
        if p.screen.top >= 600 then -- player is below the bottom of the screen, there are edge cases where they can be hit from something that isn't a bottomless pit but those are rare
            --p.y = p.sectionObj.boundary.bottom
            p.speedY = -20
            if burning.isBurning then
                burning.isBurning = false
                burning.stage = 0
                frame = 0
                Defines.player_runspeed = defaultspeed
                RisingFromTheAshes = false
                lightstage = nil
                firebrightness = 0
                pLight.brightness = 0
                pLight.radius = 0
                player:mem(0x140,FIELD_WORD,50)	-- 50 I frames
                Audio.playSFX(88)
            end
        end
        p:harm()
    else
        if player.character == CHARACTER_MARIO and player.deathTimer == 0 then
            local rand = math.random(1, 5)
            SFX.play(Misc.resolveFile("scream_"..rand..".wav"))
            Misc.score(Misc.score() * -1)
        end
    end
end

function panic()
    isPanic = true
    SFX.play(Misc.resolveFile("ohboy.wav"))
    if not uniquePanicMusic then return end
	Audio.SeizeStream(-1)
    Audio.MusicOpen("hurry_extreme.ogg")
    Audio.MusicPlay()

    changeWindowName("Panic! at the")
end

function mechanize()
    isMetal = true
    SFX.play(Misc.resolveFile("yahoo.wav"))
	for i = 0, 20 do
		Audio.SeizeStream(i)
		Audio.MusicOpen("metal_wonder.ogg")
		Audio.MusicPlay()
	end
    player.powerup = 3
    Defines.player_grav = 0.6
end

function mamamia()
    if not isMetal then return end
    SFX.play(Misc.resolveFile("mamamia.wav"))
    isMetal = false
    player.powerup = 2
    Defines.player_grav = 0.4
end

function onEvent(name)
	if (name == "panic") then
        panic()
    elseif (name == "levelend") then
        switch.setMaxTime(switch.getRemainingTime() + 15)
		Audio.SeizeStream(-1)
		Audio.MusicStop()
        if not Misc.inMarioChallenge() then -- we don't reset score for mario challengers so don't save their score to file (plus that might screw with mario challenge if i did? idk)
            if (not SaveData.topscores[Level.filename()]) or SaveData.topscores[Level.filename()] < Misc.score() then
                SaveData.topscores[Level.filename()] = Misc.score()
            end
        end
    elseif (name == "mechanize") then
        mechanize()
    elseif (name == "mamamia") then
        mamamia()
	end
end

newcheats.register("collisionhell", { onActivate =
									function()
										if (isOverworld) then
											return true
										end
										az.enabled = false
										return true;
									end, activateSFX = 34})

newcheats.register("pizzatime", { onActivate =
									function()
										if (isOverworld) then
											return true
										end
										switch.activate(30, 30, 761)
										return true;
									end, activateSFX = Misc.resolveSoundFile("pizza")})

newcheats.register("pizzapanic", { onActivate =
									function()
										if (isOverworld) then
											return true
										end
										panic()
										return true;
									end, activateSFX = Misc.resolveSoundFile("ohboy.wav")})

newcheats.register("havesomefun", { onActivate =
                                    function()
                                        if (isOverworld) then
                                            return true
                                        end
                                        SaveData.fun = math.random(1, 100)
                                        return true;
                                    end, activateSFX = Misc.resolveSoundFile("gbaroulette.ogg")})

newcheats.register("funisinfinite", { onActivate =
                                    function()
                                        if (isOverworld) then
                                            return true
                                        end
                                        SaveData.fun = math.huge
                                        return true;
                                    end, activateSFX = Misc.resolveSoundFile("goldmushroom.ogg")})

newcheats.register("mechanize", { onActivate =
									function()
										if (isOverworld) then
											return true
										end
										mechanize()
										return true;
									end, activateSFX = 34})

newcheats.register("mamamia", { onActivate =
									function()
										if (isOverworld) then
											return true
										end
										mamamia()
										return true;
									end, activateSFX = 34})