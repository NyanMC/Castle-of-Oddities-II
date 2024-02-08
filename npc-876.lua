--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local sampleNPC = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local sampleNPCSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 32,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 96,
	height = 80,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 1,
	framestyle = 1,
	framespeed = 8, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1,
	--Collision-related
	npcblock = true,
	npcblocktop = true, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = true,
	playerblocktop = true, --Also handles other NPCs walking atop this NPC.

	nohurt=true,
	nogravity = true,
	noblockcollision = true,
	nofireball = false,
	noiceball = false,
	noyoshi= false,
	nowaterphysics = true,
	--Various interactions
	jumphurt = false, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false

	grabside=false,
	grabtop=false,

	--Identity-related flags. Apply various vanilla AI based on the flag:
	--iswalker = false,
	--isbot = false,
	--isvegetable = false,
	--isshoe = false,
	--isyoshi = false,
	--isinteractable = false,
	--iscoin = false,
	--isvine = false,
	--iscollectablegoal = false,
	--isflying = false,
	--iswaternpc = false,
	--isshell = false,

	--Emits light if the Darkness feature is active:
	--lightradius = 100,
	--lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	--lightcolor = Color.white,

	--Define custom properties below
}
local incannonsettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	width = 96,
	height = 80,
	gfxoffsetx = 0,
	gfxoffsety = 0,
	frames = 1,
	framestyle = 1,
	framespeed = 8, --# frames between frame change
	speed = 1,
	npcblock = true,
	npcblocktop = true, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.

	nohurt=true,
	nogravity = true,
	noblockcollision = true,
	nofireball = false,
	noiceball = false,
	noyoshi= false,
	nowaterphysics = true,
	--Various interactions
	jumphurt = true, --If true, spiny-like
	spinjumpsafe = true, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	grabside=false,
	grabtop=false,
}

--Applies NPC settings
npcManager.setNpcSettings(sampleNPCSettings)
--npcManager.setNpcSettings(incannonsettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		--HARM_TYPE_PROJECTILE_USED,
		--HARM_TYPE_LAVA,
		--HARM_TYPE_HELD,
		--HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		--HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		--[HARM_TYPE_JUMP]=10,
		--[HARM_TYPE_FROMBELOW]=10,
		--[HARM_TYPE_NPC]=10,
		--[HARM_TYPE_PROJECTILE_USED]=10,
		--[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_HELD]=10,
		--[HARM_TYPE_TAIL]=10,
		--[HARM_TYPE_SPINJUMP]=10,
		--[HARM_TYPE_OFFSCREEN]=10,
		--[HARM_TYPE_SWORD]=10,
	}
);

--Custom local definitions below
local basesprite = Graphics.loadImageResolved("npc-876b.png")		-- the base (the box)
local flashsprite = Graphics.loadImageResolved("npc-876f.png")		-- a red flash that appears and disappears before getting shot
local toppipesprite = Graphics.loadImageResolved("npc-876tp.png")	-- the pipe the player enters
local sidepipesprite = Graphics.loadImageResolved("npc-876sp.png")	-- the pipe the player gets shot out. it stretches

local wariodashattacking = require("wariodashattacking")		-- load the library to make the player start the dash
local wariodashing = require("wariodashing")
--Register events
function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	npcManager.registerEvent(npcID, sampleNPC, "onDrawNPC")
	npcManager.registerEvent(npcID, sampleNPC, "onStartNPC")
	--registerEvent(sampleNPC, "onNPCKill")
end

function sampleNPC.onStartNPC(v)	-- the whole function's purpose is to set every used variable to their default value
	v.data.stretch = 1		-- stretch; 1 is normal. Used for stretching the exit pipe
	v.data.flashopacity = 0	-- goes up to 1 and back down to 0; the higher it is the more red the screen will flash.
	v.data.insidecannon = false	-- if the player is inside the cannon
	v.data.incannontimer = 0	-- counts down and if it hits 0, the player gets ejected (he was not the impostor)
	v.data.cooldowntimer = 0	-- the time the npc takes to become solid again
end

function sampleNPC.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.initialized = true
	end

	--Depending on the NPC, these checks must be handled differently
	if v:mem(0x12C, FIELD_WORD) > 0    --Grabbed
	or v:mem(0x136, FIELD_BOOL)        --Thrown
	or v:mem(0x138, FIELD_WORD) > 0    --Contained within
	then
		--Handling
	end
	
	--Execute main AI. This template just jumps when it touches the ground.
	if (player.y + player.height - v.y) < 10 and (player.y + player.height - v.y) > -1 and math.abs(player.x + player.width*0.5 - v.x - v.width*0.5) < 16 and player.keys.down and not v.data.insidecannon and not player.holdingNPC then	-- get inside cannon
		Audio.playSFX(17)
		player.speedX = 0
		player.x = v.x + v.width * 0.5 - player.width * 0.5
		v.data.insidecannon = true
		npcManager.setNpcSettings(incannonsettings)
	end
	
	if v.data.insidecannon then	-- code inside the cannon
		v.data.incannontimer = v.data.incannontimer + 1
		v.data.flashopacity = math.sin(v.data.incannontimer * 0.05)
		player.keys.left = false
		player.keys.right = false
		player.keys.altRun = false
		player.keys.jump = false
		player.keys.altJump = false
		player.keys.run = true
		wariodashing.cooldown = 2
		if player.y + player.height - v.y - v.height > 6 then
			player.y = v.y + v.height - player.height
		end
		if v.data.incannontimer >= 60 then
			Defines.player_runspeed = 11
			player.speedX = 11 * v.direction
			player.speedY = -1
			Defines.earthquake = 20
			Audio.playSFX(22)
			player.keys.run = true
			wariodashattacking.dashattacking = true		-- start the dashattack
			wariodashattacking.dashstate = 2			-- let it know that it's from a cannon
			player.direction = v.direction
			v.data.insidecannon = false
			v.data.cooldowntimer = 20	-- also used for the stretching
		end
	elseif not (v.data.insidecannon) and (v.data.cooldowntimer > 0) then	-- freshly getting shot
		v.data.cooldowntimer = v.data.cooldowntimer - 1
		v.data.stretch = 1 + math.sin(v.data.cooldowntimer * 0.1) * 2
	elseif not (v.data.insidecannon) and (v.data.cooldowntimer == 0) then
		npcManager.setNpcSettings(sampleNPCSettings)
		v.data.incannontimer = 0
		v.data.flashopacity = 0
		v.data.stretch = 1
	end
end

function sampleNPC.onDrawNPC(v)
if not (v.isValid or v.isHidden) then return end
	Graphics.drawBox{							-- It's your average ol' metal box
		texture      = basesprite,
		sceneCoords  = true,
		x            = v.x + v.width * 0.5,
		y            = v.y + v.height * 0.5 + 8,
		width        = 48*2 * -v.direction,
		height       = 64, -- v.data.stretch,	-- to make it possible to stretch the cannon when charged and shot
		sourceWidth  = 48,
		sourceHeight = 32,
		centered     = true,
		priority 	 = -23,
	}
		
	Graphics.drawBox{							-- Weeeee Woooo Weee Wooo (flashing warning)
		texture      = flashsprite,
		sceneCoords  = true,
		x            = v.x + v.width * 0.5,
		y            = v.y + v.height * 0.5 + 8,
		width        = 48*2 * -v.direction,
		height       = 64, -- v.data.stretch,	-- to make it possible to stretch the cannon when charged and shot
		sourceWidth  = 48,
		sourceHeight = 32,
		centered     = true,
		priority 	 = -22,
		color = Color.white .. v.data.flashopacity,
	}
	Graphics.drawBox{							-- upper pipe
		texture      = toppipesprite,
		sceneCoords  = true,
		x            = v.x + v.width * 0.5,
		y            = v.y + 10,
		width        = 46*2 * -v.direction,
		height       = 20, -- v.data.stretch,	-- to make it possible to stretch the cannon when charged and shot
		sourceWidth  = 46,
		sourceHeight = 10,
		centered     = true,
		priority 	 = -24,
	}
	Graphics.drawBox{							-- upper pipe
		texture      = sidepipesprite,
		sceneCoords  = true,
		x            = v.x + v.width*0.5 + (v.width*0.5 + 6) * v.direction,
		y            = v.y + v.height*0.5 + 8,
		width        = 18 * v.data.stretch * -v.direction,
		height       = 64, -- v.data.stretch,	-- to make it possible to stretch the cannon when charged and shot
		sourceWidth  = 9,
		sourceHeight = 32,
		centered     = true,
		priority 	 = -24,
	}

end

--Gotta return the library table!
return sampleNPC