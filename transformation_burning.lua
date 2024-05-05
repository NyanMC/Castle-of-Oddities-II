--[[
	Burning Rush v1.1 - by "Master" of Disaster
	Also known as the Fire transformation in the Wario Land series
	
	What you can configurate:
		burning.isBurning = true			-- makes you start burning
		burning.gfxoffsetX = 12				-- Set the amount of pixels the sprite should be moved to the left (negative values for right) so it plays at the right position
		burning.gfxoffsetY = 20				-- Set the amount of pixels the sprite should be moved upwards so it plays at the right height
		burning.gfxwidth = 50				-- If your spritesheet needs a higher width than 50px, you can change it here
		burning.gfxheight = 50				-- If your spritesheet needs a higher height than 50px, you can change it here
		burning.burningframes = 4			-- If your spritesheet has more or less than 4 frames in the burning animation, you can change it here
		burning.burningendframes = 11		-- If your spritesheet has more or less than 4 frames in the rising animation, you can change it here
		
		burning.addFireStarterNPC(id)		-- add an NPC that starts the burning rush when touched
		burning.addFireStarterBlock(id)		-- add a Block that starts the burning rush when touched

		burning.addFlammableBlock(id)		-- add a Block that breaks when fully burning and touching it
		burning.addUltraflammableBlock(id)	-- add a Block that breaks when touched in the burning rush
		
	You know the deal; credit me or you'll also burn to a crisp
]]--

local burning = {
isBurning = false,	-- if set to true, the character starts to run frantically
stage = 0,			-- 0 - 3; if stage is 3 the player is just a bonfire
gfxoffsetX = 14,
gfxoffsetY = 20,
gfxwidth = 50,
gfxheight = 50,
burningframes = 4,
burningendframes = 11,
}

firestarterNPC = {}

fireproofNPC = {251, 252, 253, 994}
-- added by ChromaNyan, default NPCs are the rupees and gold mushroom as they otherwise have a chance to be instantly vaporized when trying to collect them on fire
-- why in the world is this not a thing by default it fixes so many bugs

firestarterBlock = {1151}	-- default block: Hot Block

flammableBlock = {801}		-- default block: Flammable Block (that does the chain reaction)

ultraflammableBlock = {669}	-- default Block: Icy Block

function burning.addFireStarterNPC(id)
	table.insert(firestarterNPC, id)
end

function burning.addFireProofNPC(id)
	table.insert(fireproofNPC, id)
end

function burning.addFireStarterBlock(id)
	table.insert(firestarterBlock, id)
end

function burning.addFlammableBlock(id)
	table.insert(flammableBlock, id)
end

function burning.addUltraflammableBlock(id)
	table.insert(ultraflammableBlock, id)
end

local currentDirection = 0	-- the direction the player is currently facing; so you can't turn around
local frame = 0				-- the current frame of the animation
local framecounter = 0		-- counts down and changes the animation frame when it reaches 0
local burningtimer = 0		-- is higher than 0 when burning to a crisp, if it reaches 0, the burning stops
local RisingFromTheAshes = false	-- if Wario is rising from the ashes (recovering)
local burningsprites = Graphics.loadImageResolved("burningframes.png")
local risingsprites = Graphics.loadImageResolved("ashesrisingframes.png")
local burningcolliderBlock = Colliders.Rect(0, 0, 1, 1, 0)
local flammablechainblockID = 801
local lightstage = nil		-- influences the light the player emits. If it's nil, there is no light
local firebrightness = 0	
local burnsound = Misc.resolveSoundFile("kirbybomb")
local isRegistered = false
local i = 0					-- index for registered players
Burnplayers = {}
CurrentBurnRegister = {}

local function fireBlockFilter(o)
    if not (o.isHidden) and not (Block.SLOPE_MAP[o.id]) and table.contains(firestarterBlock, o.id) then
        return true
    end
end

local function flammableBlockFilter(o)
	if not (o.isHidden) and not (Block.SLOPE_MAP[o.id]) and table.contains(flammableBlock, o.id) then
        return true
    end
end

local function ultraflammableBlockFilter(o)
	if not (o.isHidden) and not (Block.SLOPE_MAP[o.id]) and table.contains(ultraflammableBlock, o.id) then
        return true
    end
end

local function BurnStop() return (
	player:mem(0x36,FIELD_BOOL)	or			-- In water
	player:mem(0x13C, FIELD_BOOL) or 		-- not alive
	player.isMega or
	player.deathTimer > 0 or				-- currently dying
	player.x - camera.x == 0 or				-- at the left edge of the screen
	player.x + player.width - camera.x - camera.width == 0 or	-- at the right edge of the screen
	Level.winState() ~= 0				-- winning a level
) end

function burning.whitelistCharacter(character,burningsprites,risingsprites,gfxoffsetY,burningframes,burningendframes)
	local whitelistedBurnCharacter = {}
	whitelistedBurnCharacter.character = character
	whitelistedBurnCharacter.burningsprites = Graphics.loadImageResolved(burningsprites)
	whitelistedBurnCharacter.risingsprites = Graphics.loadImageResolved(risingsprites)
	if not gfxoffsetY == nil then
		whitelistedBurnCharacter.gfxoffsetY = gfxoffsetY				-- sets your given one (if provided)
	else
		whitelistedBurnCharacter.gfxoffsetY = burning.gfxoffsetY	-- sets the default otherwise
	end
	if not burningframes == nil then
		whitelistedBurnCharacter.burningframes = burningframes				-- sets your given one (if provided)
	else
		whitelistedBurnCharacter.burningframes = burning.burningframes	-- sets the default otherwise
	end
	if not burningendframes == nil then
		whitelistedBurnCharacter.burningendframes = burningendframes				-- sets your given one (if provided)
	else
		whitelistedBurnCharacter.burningendframes = burning.burningendframes	-- sets the default otherwise
	end
	table.insert(Burnplayers, whitelistedBurnCharacter)
end

registerEvent(burning,"onStart")
registerEvent(burning,"onTick")
registerEvent(burning,"onDraw")
registerEvent(burning,"onTickEnd")
registerEvent(burning,"onPlayerHarm")

function burning.onStart()
	defaultspeed = Defines.player_runspeed
end

function burning.onTickEnd()
	burningcolliderBlock.width 	= player.width + 10
	burningcolliderBlock.height	= player.height + 8
	burningcolliderBlock.x		= player.x + (player.width * 0.5)
	burningcolliderBlock.y		= player.y + (player.height * 0.5)
end

function burning.onTick()	

	if not (table.maxn(Burnplayers) == 0) then		-- checks if the given player is allowed to bounce
		if (CurrentBurnRegister == {}) then
			CurrentBurnRegister = Burnplayers[i]
		else
			if player.character == CurrentBurnRegister.character then
				isRegistered = true
			else
				if not (table.maxn(Burnplayers) <= i) then
					i = i + 1
					CurrentBurnRegister = Burnplayers[i]
					
				else
					i = 0
					isRegistered = false
				end
			end
		end
	end
	
	for p,b in ipairs(Colliders.getColliding{a = burningcolliderBlock, btype = Colliders.BLOCK, filter = fireBlockFilter}) do	-- so non lethal blocks can also trigger the burning rush
		if isRegistered then
			burning.isBurning = true
			player:mem(0x50,FIELD_BOOL,false)	-- stop spinjumping
		end
	end
		
	if burning.isBurning then	-- do all the funny stuff when burning
		player:mem(0x40,FIELD_WORD,0) -- stop the player from climbing
		player:mem(0x3C,FIELD_BOOL,false) -- make the player stop sliding
		if burning.stage == 0 and lightstage == nil then
			lightstage = -1
		end
		if (burning.stage < 3) then
			burningtimer = 100
			Defines.player_runspeed = defaultspeed + 1
			player.speedX = (defaultspeed + 1) * player.direction
			player.keys.down = false
			player.keys.up = false
			player.keys.altRun = false
			player.keys.altJump = false
			if not (player.holdingNPC == nil) then
				player.keys.run = false
			else
				player.keys.run = true
			end
			if (player.direction > 0) and not (player:mem(0x148,FIELD_WORD) == 2 or player:mem(0x14C,FIELD_WORD) == 2) then
				player.keys.left = false
				player.keys.right = true
			elseif (player.direction < 0) and not (player:mem(0x148,FIELD_WORD) == 2 or player:mem(0x14C,FIELD_WORD) == 2) then
				player.keys.left = true
				player.keys.right = false
			elseif (player:mem(0x148,FIELD_WORD) == 2 or player:mem(0x14C,FIELD_WORD) == 2) then
				player.keys.left = false
				player.keys.right = false
			end
			if (player:mem(0x148,FIELD_WORD) == 2 or player:mem(0x14C,FIELD_WORD) == 2) then
				burning.stage = burning.stage + 1
				if (player:mem(0x148,FIELD_WORD) == 2) then	-- left collision
					player.direction = 1
				else											-- right collision
					player.direction = -1
				end
				player.speedX = 6 * player.direction
				player.x = player.x + player.direction * 2
			end
		end
		if (burning.stage == 3) then
			Defines.player_runspeed = defaultspeed * 0.2
			player.keys.jump = false
			player.keys.altJump = false
			player.keys.run = false
			player.keys.altRun = false
			player.keys.down = false
			player.keys.up = false
			for p,b in ipairs(Colliders.getColliding{a = burningcolliderBlock, btype = Colliders.BLOCK, filter = flammableBlockFilter}) do	-- so non lethal blocks can also trigger the burning rush
				Effect.spawn(10,b.x,b.y,1)
				SFX.play(burnsound)
				if (b.id == flammablechainblockID) then
					b:hit(true)
				else
					b:remove(false)
				end
			end
			if burningtimer == 0 and not RisingFromTheAshes then
				frame = 0
				RisingFromTheAshes = true
			end
		end
		if RisingFromTheAshes then
			player.keys.left = false
			player.keys.right = false
			player.keys.up = false
			player.keys.down = false
			player.keys.run = true
			player.keys.jump = false
			player.keys.altJump = false
			player.keys.altRun = false
		end
		if (framecounter == 0) and not RisingFromTheAshes then
			framecounter = 5
			if frame < CurrentBurnRegister.burningframes - 1 then
				frame = frame + 1
			else
				frame = 0
			end
		elseif (framecounter == 0) and RisingFromTheAshes then
			framecounter = 10
			if (frame < CurrentBurnRegister.burningendframes - 1) then
				frame = frame + 1
			else												-- stop burning
				frame = 0										-- reset values
				burning.stage = 0
				Defines.player_runspeed = defaultspeed
				RisingFromTheAshes = false
				burning.isBurning = false
				firebrightness = 0
				lightstage = nil
				player:mem(0x140,FIELD_WORD,50)	-- 50 I frames
			end
		end
		
		for p,b in ipairs(Colliders.getColliding{a = burningcolliderBlock, btype = Colliders.BLOCK, filter = ultraflammableBlockFilter}) do	-- always break very flammable blocks when on fire
				--flame:attach(b)
				--flame:Emit(1)
				Effect.spawn(10,b.x,b.y,1)
				SFX.play(burnsound)
				b:remove(false)
		end
		
		if burning.stage == 0 and not (RisingFromTheAshes)  then -- lighting
			if (lightstage == -1) then
				pLight = Darkness.light(0,0,128,10,Color.canary)
				pLight:Attach(player)
				firebrightness = 10
				Darkness.addLight(pLight)
				lightstage = 0
				Audio.playSFX(16)
			end
		elseif burning.stage == 1 and not (RisingFromTheAshes)  then
			if not (lightstage == 1) then
				firebrightness = 15
				lightstage = 1
				Audio.playSFX(16)
			end
		elseif burning.stage == 2 and not (RisingFromTheAshes) then
			if not (lightstage == 2) then
				firebrightness = 20
				lightstage = 2
				Audio.playSFX(16)
			end
		elseif burning.stage == 3 then
			if not (lightstage == 3) and not (RisingFromTheAshes) then
				lightstage = 3
				firebrightness = 25
				Audio.playSFX(42)
			end
			if RisingFromTheAshes then
				if firebrightness > 0 then
					firebrightness = firebrightness - 0.3
				elseif firebrightness == 0 then
					lightstage = nil
					--Darkness.removeLight(pLight)
				end
			end
		end
		if not (lightstage == nil or lightstage == -1) then		-- emit the light
			pLight.brightness = 0.02 * firebrightness
			pLight.radius = 4 * firebrightness
			pLight.flicker = true
		end
	
		if BurnStop() then
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
		
	if framecounter > 0 then
		framecounter = framecounter - 1
	end
	if burningtimer > 0 then
		burningtimer = burningtimer - 1
	end
	
end

function burning.onPlayerHarm(event,player)
	if event.cancelled or not isRegistered then return end
	if burning.isBurning then	-- if the player is burning then tear through every enemy that does not trigger the burning rush
		for player,n in ipairs(Colliders.getColliding{atype = Colliders.NPC, b = player, filter = function(o) if not o.friendly and not o.isHidden and not (table.contains(firestarterNPC, o.id) or table.contains(fireproofNPC, o.id)) then return true end end}) do
			n:harm()
		end
		event.cancelled = true	-- and don't take damage
	else		-- trigger the burning rush instead of getting damaged when the npc or block is actually not cold enough
		for p,n in ipairs(Colliders.getColliding{atype = Colliders.NPC, b = player, filter = function(o) if not o.friendly and not o.isHidden and (table.contains(firestarterNPC,o.id)) then return true end end}) do
               burning.isBurning = true
			   player:mem(0x50,FIELD_BOOL,false)	-- stop spinjumping
			   event.cancelled = true
		end
		for p,b in ipairs(Colliders.getColliding{a = burningcolliderBlock, btype = Colliders.BLOCK, filter = fireBlockFilter}) do
               burning.isBurning = true
			   player:mem(0x50,FIELD_BOOL,false)	-- stop spinjumping
			   event.cancelled = true
		end
	end
end

function burning.onDraw()
	if burning.isBurning then
		player:setFrame(-50)
		if not RisingFromTheAshes then
			Graphics.drawBox{
				texture      = CurrentBurnRegister.burningsprites,
				sceneCoords  = true,
				x            = player.x + (player.width / 2) - burning.gfxoffsetX * player.direction,
				y            = player.y + (player.height / 2) - CurrentBurnRegister.gfxoffsetY,
				width        = burning.gfxwidth * 2 * player.direction,
				height       = burning.gfxheight * 2,
				sourceX      = 0 + burning.gfxwidth * (player.powerup - 1) * 4 + frame * burning.gfxwidth,
				sourceY      = 0 + burning.gfxheight * burning.stage,
				sourceWidth  = burning.gfxwidth,
				sourceHeight = burning.gfxheight,
				centered     = true,
				priority     = -25,
				color        = Color.white .. 1,--playerOpacity,
				rotation     = 0,
			}
		else
			Graphics.drawBox{
				texture      = CurrentBurnRegister.risingsprites,
				sceneCoords  = true,
				x            = player.x + (player.width / 2) - burning.gfxoffsetX * player.direction,
				y            = player.y + (player.height / 2) - CurrentBurnRegister.gfxoffsetY,
				width        = burning.gfxwidth * 2 * player.direction,
				height       = burning.gfxheight * 2,
				sourceX      = 0 + burning.gfxwidth * (player.powerup - 1),
				sourceY      = 0 + burning.gfxheight * frame,
				sourceWidth  = burning.gfxwidth,
				sourceHeight = burning.gfxheight,
				centered     = true,
				priority     = -25,
				color        = Color.white .. 1,--playerOpacity,
				rotation     = 0,
			}
		end
	end
	--flame:Draw(-30)
end

return burning