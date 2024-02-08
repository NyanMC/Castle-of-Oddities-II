--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local sampleNPC = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local sampleNPCSettings = {
	id = npcID,
	width = 32, 
	height = 32, 
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	score = 2,
	speed = 2,
	playerblock=false,
	playerblocktop=false,
	npcblock=false,
	npcblocktop=false,
	spinjumpsafe=false,
	nowaterphysics=false,
	noblockcollision=false,
	cliffturn=false,
	nogravity = false,
	nofireball=false,
	noiceball=true,
	noyoshi=false,
	iswaternpc=false,
	iscollectablegoal=false,
	isvegetable=false,
	isvine=false,
	isbot=false,
	iswalker=true,
	grabtop = false,
	grabside = false,
	foreground=false,
	isflying=false,
	iscoin=false,
	isshoe=false,
	nohurt = false,
	jumphurt = false,
	isinteractable=true,
	iscoin=false,
	notcointransformable = true,
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
	lightradius = 100,
	lightbrightness = 1,
	lightoffsetx = 0,
	lightoffsety = 0,
	lightcolor = Color.F8D870

	--Define custom properties below
}

--Applies NPC settings
npcManager.setNpcSettings(sampleNPCSettings)

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
function sampleNPC.onPostNPCKill(killedNPC, killReason)
	if killedNPC.id == NPC_ID and npcManager.collected(killedNPC, killReason) then
		Misc.coins(50,false)
		SFX.play("goldmushroom.ogg")
		Effect.spawn(78,killedNPC.x + 0.5 * killedNPC.width, killedNPC.y + 0.5 * killedNPC.height)
	end
end

registerEvent(sampleNPC, "onPostNPCKill")
--Register events
function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onDrawNPC")
	--registerEvent(sampleNPC, "onNPCKill")
end

--Gotta return the library table!
return sampleNPC